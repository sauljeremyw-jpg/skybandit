--!strict
-- Server owns carry. Client visuals are a replica; grab/deliver never trust a client position packet.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)
local FlightService = require(script.Parent.FlightService)
local EconomyService = require(script.Parent.EconomyService)
local PetService = require(script.Parent.PetService)

type InternalCarry = {
	islandId: string,
	bounty: number,
	grabbedAtUnix: number,
	rarityRollSeed: number,
}

local HeistService = {}
local carried: { [Player]: InternalCarry } = {}
local nestLocks: { [string]: boolean } = {}
local lastGrabAt: { [Player]: number } = {}
local started = false

local function publicCarry(internal: InternalCarry): Types.CarriedEgg
	return {
		islandId = internal.islandId,
		bounty = internal.bounty,
		grabbedAtUnix = internal.grabbedAtUnix,
	}
end

local function replicate(player: Player)
	local egg = carried[player]
	Net.fireClient("replica:carry", player, if egg then publicCarry(egg) else nil)
end

function HeistService.getCarried(player: Player): Types.CarriedEgg?
	local egg = carried[player]
	if egg == nil then
		return nil
	end
	return publicCarry(egg)
end

function HeistService.forceDrop(player: Player, reason: string)
	local egg = carried[player]
	if egg == nil then
		return
	end
	carried[player] = nil
	nestLocks[egg.islandId] = false
	FlightService.setCarrying(player, false)
	local save = PlayerData.get(player)
	if save then
		save.stats.eggsLost += 1
	end
	warn(string.format("[Heist] forceDrop %s %s %s", player.Name, egg.islandId, reason))
	replicate(player)
end

local function within(a: Vector3, b: Vector3, radius: number): boolean
	return (a - b).Magnitude <= radius
end

local function tryGrab(player: Player, payload: any): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.islandId) ~= "string" then
		return false, "bad_payload"
	end
	local islandId = payload.islandId
	local island = GameConfig.getIsland(islandId)
	if island == nil then
		return false, "unknown_island"
	end
	if carried[player] ~= nil then
		return false, "already_carrying"
	end
	if nestLocks[islandId] then
		return false, "nest_locked"
	end
	local pos = FlightService.getPosition(player)
	if pos == nil then
		return false, "no_position"
	end
	local islandOrigin = GameConfig.islandWorldPosition(islandId)
	if islandOrigin == nil then
		return false, "no_nest"
	end
	local nestPos = islandOrigin + Vector3.new(0, 4, 0)
	if not within(pos, nestPos, GameConfig.World.NestGrabRadius) then
		return false, "too_far"
	end
	if FlightService.getRange(player) < island.rangeNeeded then
		return false, "range"
	end
	local last = lastGrabAt[player]
	if last and (os.clock() - last) < GameConfig.World.NestRespawnSeconds then
		return false, "cooldown"
	end
	nestLocks[islandId] = true
	local seed = math.floor(os.clock() * 1000) + player.UserId
	carried[player] = {
		islandId = islandId,
		bounty = math.floor(GameConfig.Economy.BaseEggBounty * island.bountyMultiplier),
		grabbedAtUnix = os.time(),
		rarityRollSeed = seed,
	}
	lastGrabAt[player] = os.clock()
	FlightService.setCarrying(player, true)
	replicate(player)
	return true, nil
end

local function tryDeliver(player: Player, _payload: any): (boolean, string?)
	local egg = carried[player]
	if egg == nil then
		return false, "not_carrying"
	end
	local pos = FlightService.getPosition(player)
	if pos == nil then
		return false, "no_position"
	end
	local base = Vector3.new(0, GameConfig.World.LaunchEdgeAltitude, 0)
	if not within(pos, base, GameConfig.World.BasePlatformSize.X) then
		return false, "not_at_base"
	end
	if os.time() - egg.grabbedAtUnix < GameConfig.Economy.MinRunSeconds then
		warn(string.format("[Heist] reject instant deliver %s (teleport exploit)", player.Name))
		return false, "too_fast"
	end
	local ok = select(1, EconomyService.grantCoins(player, egg.bounty, "deliver"))
	if not ok then
		return false, "grant_failed"
	end
	PetService.rollAndGrant(player, egg.islandId, egg.rarityRollSeed)
	local save = PlayerData.get(player)
	if save then
		save.stats.eggsDelivered += 1
		save.stats.runs += 1
	end
	carried[player] = nil
	nestLocks[egg.islandId] = false
	FlightService.setCarrying(player, false)
	replicate(player)
	return true, nil
end

function HeistService.transfer(fromPlayer: Player, toPlayer: Player): (boolean, string?)
	local egg = carried[fromPlayer]
	if egg == nil then
		return false, "no_egg"
	end
	if carried[toPlayer] ~= nil then
		return false, "target_busy"
	end
	carried[fromPlayer] = nil
	carried[toPlayer] = egg
	FlightService.setCarrying(fromPlayer, false)
	FlightService.setCarrying(toPlayer, true)
	replicate(fromPlayer)
	replicate(toPlayer)
	return true, nil
end

function HeistService.start()
	if started then
		return
	end
	started = true
	Net.handleEvent("heist:grab", function(player, payload)
		tryGrab(player, payload)
	end)
	Net.handleEvent("heist:deliver", function(player, payload)
		tryDeliver(player, payload)
	end)
	Players.PlayerRemoving:Connect(function(player)
		if carried[player] then
			warn(string.format("[Heist] lost on disconnect %s %s", player.Name, carried[player].islandId))
			local save = PlayerData.get(player)
			if save then
				save.stats.eggsLost += 1
			end
			nestLocks[carried[player].islandId] = false
			carried[player] = nil
			FlightService.setCarrying(player, false)
		end
		lastGrabAt[player] = nil
	end)
end

return HeistService
