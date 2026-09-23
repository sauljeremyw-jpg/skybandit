--!strict
-- Multiplexed remotes live here so every service inherits the same rate-limit and size gates.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local GameConfig = require(script.Parent.GameConfig)

export type DropReason = "too_large" | "too_many_entries" | "rate_limited" | "invalid" | "handler_error"

type Bucket = { tokens: number, lastRefill: number }
type Strike = { count: number, windowStart: number }

local FOLDER_NAME = "Net"
local EVENT_NAME = "E"
local FUNC_NAME = "F"

local Net = {}

local buckets: { [Player]: { [string]: Bucket } } = {}
local strikes: { [Player]: Strike } = {}
local eventHandlers: { [string]: (Player, any) -> () } = {}
local functionHandlers: { [string]: (Player, any) -> any } = {}
local limits: { [string]: number } = {}
local clientListeners: { [string]: (any) -> () } = {}

local folder: Folder
local remoteEvent: RemoteEvent
local remoteFunction: RemoteFunction

local function now(): number
	return os.clock()
end

local function approximateSize(value: any, depth: number): number
	if depth <= 0 then
		return 8
	end
	local t = typeof(value)
	if t == "string" then
		return #value
	elseif t == "number" or t == "boolean" then
		return 8
	elseif t == "Vector3" or t == "CFrame" then
		return 32
	elseif t == "table" then
		local size = 8
		for k, v in value do
			size += approximateSize(k, depth - 1) + approximateSize(v, depth - 1)
		end
		return size
	end
	return 16
end

local function recordDrop(player: Player, name: string, reason: DropReason)
	warn(string.format("[Net] drop %s %s %s", player.Name, name, reason))
	local s = strikes[player]
	local t = now()
	if s == nil or (t - s.windowStart) > GameConfig.Net.DropStrikeWindowSeconds then
		s = { count = 0, windowStart = t }
		strikes[player] = s
	end
	s.count += 1
	if s.count >= GameConfig.Net.DropStrikeThreshold then
		warn(string.format("[Net] strike %s after %d drops", player.Name, s.count))
	end
end

local function takeToken(player: Player, name: string): boolean
	local perName = buckets[player]
	if perName == nil then
		perName = {}
		buckets[player] = perName
	end
	local bucket = perName[name]
	local limit = limits[name] or GameConfig.Net.DefaultLimitPerMinute
	local t = now()
	if bucket == nil then
		bucket = { tokens = limit, lastRefill = t }
		perName[name] = bucket
	end
	local elapsed = t - bucket.lastRefill
	bucket.tokens = math.min(limit, bucket.tokens + elapsed * (limit / 60))
	bucket.lastRefill = t
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function validate(player: Player, name: string, payload: any): any?
	if not takeToken(player, name) then
		recordDrop(player, name, "rate_limited")
		return nil
	end
	if approximateSize(payload, 6) > GameConfig.Net.MaxPayloadBytes then
		recordDrop(player, name, "too_large")
		return nil
	end
	if typeof(payload) == "table" then
		local keys = 0
		for _ in payload do
			keys += 1
		end
		if keys > GameConfig.Net.MaxPayloadEntries then
			recordDrop(player, name, "too_many_entries")
			return nil
		end
	end
	return payload
end

local function ensureFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing and existing:IsA("Folder") then
			folder = existing
		else
			local f = Instance.new("Folder")
			f.Name = FOLDER_NAME
			f.Parent = ReplicatedStorage
			folder = f
		end
		local e = folder:FindFirstChild(EVENT_NAME)
		if e and e:IsA("RemoteEvent") then
			remoteEvent = e
		else
			local ev = Instance.new("RemoteEvent")
			ev.Name = EVENT_NAME
			ev.Parent = folder
			remoteEvent = ev
		end
		local fn = folder:FindFirstChild(FUNC_NAME)
		if fn and fn:IsA("RemoteFunction") then
			remoteFunction = fn
		else
			local rf = Instance.new("RemoteFunction")
			rf.Name = FUNC_NAME
			rf.Parent = folder
			remoteFunction = rf
		end
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
		remoteEvent = folder:WaitForChild(EVENT_NAME) :: RemoteEvent
		remoteFunction = folder:WaitForChild(FUNC_NAME) :: RemoteFunction
	end
	return folder
end

function Net.handleEvent(name: string, handler: (Player, any) -> (), limitPerMinute: number?)
	ensureFolder()
	eventHandlers[name] = handler
	if limitPerMinute then
		limits[name] = limitPerMinute
	end
end

function Net.handleFunction(name: string, handler: (Player, any) -> any, limitPerMinute: number?)
	ensureFolder()
	functionHandlers[name] = handler
	if limitPerMinute then
		limits[name] = limitPerMinute
	end
end

function Net.fireClient(name: string, player: Player, payload: any)
	ensureFolder()
	remoteEvent:FireClient(player, name, payload)
end

function Net.fireAll(name: string, payload: any)
	ensureFolder()
	remoteEvent:FireAllClients(name, payload)
end

function Net.send(name: string, payload: any)
	ensureFolder()
	remoteEvent:FireServer(name, payload)
end

function Net.invoke(name: string, payload: any): any
	ensureFolder()
	return remoteFunction:InvokeServer(name, payload)
end

function Net.on(name: string, listener: (any) -> ())
	ensureFolder()
	clientListeners[name] = listener
end

function Net.start()
	ensureFolder()
	if RunService:IsServer() then
		remoteEvent.OnServerEvent:Connect(function(player: Player, name: any, payload: any)
			if typeof(name) ~= "string" then
				return
			end
			local okPayload = validate(player, name, payload)
			if okPayload == nil and payload ~= nil then
				return
			end
			local handler = eventHandlers[name]
			if handler == nil then
				return
			end
			local ok, err = pcall(handler, player, okPayload)
			if not ok then
				warn("[Net] handler_error", name, err)
				recordDrop(player, name, "handler_error")
			end
		end)
		remoteFunction.OnServerInvoke = function(player: Player, name: any, payload: any)
			if typeof(name) ~= "string" then
				return nil
			end
			local okPayload = validate(player, name, payload)
			if okPayload == nil and payload ~= nil then
				return nil
			end
			local handler = functionHandlers[name]
			if handler == nil then
				return nil
			end
			local ok, result = pcall(handler, player, okPayload)
			if not ok then
				warn("[Net] handler_error", name, result)
				recordDrop(player, name, "handler_error")
				return nil
			end
			return result
		end
		Players.PlayerRemoving:Connect(function(player)
			buckets[player] = nil
			strikes[player] = nil
		end)
	else
		remoteEvent.OnClientEvent:Connect(function(name: any, payload: any)
			if typeof(name) ~= "string" then
				return
			end
			local listener = clientListeners[name]
			if listener then
				listener(payload)
			end
		end)
	end
end

return Net
