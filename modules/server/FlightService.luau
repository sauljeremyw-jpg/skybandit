--!strict
-- Claims are not position. Reject a move the glide model cannot make, then tell the client where it actually is.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local FlightService = {}
local positions: { [Player]: Vector3 } = {}
local lastClaimAt: { [Player]: number } = {}
local ranges: { [Player]: number } = {}
local lifts: { [Player]: number } = {}
local carrying: { [Player]: boolean } = {}
local tiers: { [Player]: number } = {}
local started = false

local function replica(player: Player, position: Vector3)
	Net.fireClient("replica:flight", player, {
		position = position,
		tier = tiers[player] or 1,
		lift = lifts[player] or 0,
		carrying = carrying[player] == true,
	})
end

function FlightService.getPosition(player: Player): Vector3?
	local cached = positions[player]
	if cached then
		return cached
	end
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

function FlightService.setAuthoritativePosition(player: Player, position: Vector3)
	positions[player] = position
end

function FlightService.getRange(player: Player): number
	return ranges[player] or GameConfig.Aircraft[1].range
end

function FlightService.setRange(player: Player, range: number)
	ranges[player] = range
end

function FlightService.setLift(player: Player, value: number)
	lifts[player] = value
end

function FlightService.setTier(player: Player, tier: number)
	tiers[player] = tier
end

function FlightService.setCarrying(player: Player, isCarrying: boolean)
	carrying[player] = isCarrying
end

local function acceptClaim(player: Player, payload: any)
	if typeof(payload) ~= "table" or typeof(payload.position) ~= "Vector3" then
		return
	end
	local claimed = payload.position
	if claimed.X ~= claimed.X or claimed.Y ~= claimed.Y or claimed.Z ~= claimed.Z then
		return
	end
	local nowClock = os.clock()
	local previous = positions[player]
	local previousAt = lastClaimAt[player]
	lastClaimAt[player] = nowClock
	if previous == nil or previousAt == nil then
		local rootPos = FlightService.getPosition(player)
		positions[player] = rootPos or claimed
		return
	end
	local maxWindow = (1 / GameConfig.Flight.SnapshotHz) / GameConfig.Economy.CarrySpeedPenalty
	local dt = math.clamp(nowClock - previousAt, GameConfig.Flight.MaxDt, maxWindow)
	local allowed = GameConfig.terminalSpeed(carrying[player] == true) * (dt + GameConfig.Flight.MaxDt)
	local corrected = claimed
	if (claimed - previous).Magnitude > allowed then
		corrected = previous
	end
	local flat = Vector3.new(corrected.X, 0, corrected.Z)
	local range = FlightService.getRange(player)
	if flat.Magnitude > range and range > 0 then
		local clamped = flat.Unit * range
		corrected = Vector3.new(clamped.X, corrected.Y, clamped.Z)
	end
	positions[player] = corrected
	if (corrected - claimed).Magnitude > 1 then
		replica(player, corrected)
	end
end

function FlightService.start()
	if started then
		return
	end
	started = true
	Net.handleEvent("flight:state", function(player, payload)
		acceptClaim(player, payload)
	end)
	Players.PlayerRemoving:Connect(function(player)
		positions[player] = nil
		lastClaimAt[player] = nil
		ranges[player] = nil
		lifts[player] = nil
		carrying[player] = nil
		tiers[player] = nil
	end)
end

return FlightService
