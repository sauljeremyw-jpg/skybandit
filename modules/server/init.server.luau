--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local WorldBuilder = require(script.WorldBuilder)

-- Block all character auto-loads at the service level.  Characters are loaded
-- explicitly: initial players get LoadCharacter() after setup; deaths are handled
-- by Humanoid.Died in WorldBuilder so respawns always go through seat() with
-- RespawnLocation already armed.  Player.CharacterAutoLoads is per-Player and
-- does NOT gate the service auto-load; only Players.CharacterAutoLoads does.
Players.CharacterAutoLoads = false

Net.start()
WorldBuilder.build()
WorldBuilder.start()

local PlayerData = require(script.PlayerData)
local FlightService = require(script.FlightService)
local EconomyService = require(script.EconomyService)
local PetService = require(script.PetService)
local HeistService = require(script.HeistService)

PlayerData.start()
FlightService.start()
EconomyService.start()
PetService.start()
HeistService.start()

-- World built, RespawnLocation armed.  Trigger the initial character load.
-- Deaths are handled by Humanoid.Died in WorldBuilder (CharacterAutoLoads stays false).
for _, player in Players:GetPlayers() do
	player:LoadCharacter()
end
-- New joiners: arm RespawnLocation (done by WorldBuilder.start PlayerAdded hook)
-- then load their character.
Players.PlayerAdded:Connect(function(player: Player)
	player:LoadCharacter()
end)

local function pushFlight(player: Player, save: Types.PlayerSave)
	local aircraft = GameConfig.getAircraft(save.aircraftTier)
	local range = if aircraft then aircraft.range else GameConfig.Aircraft[1].range
	local lift = PetService.totalLift(save)
	FlightService.setTier(player, save.aircraftTier)
	FlightService.setRange(player, range)
	FlightService.setLift(player, lift)
	FlightService.setCarrying(player, HeistService.getCarried(player) ~= nil)
	Net.fireClient("replica:flight", player, {
		tier = save.aircraftTier,
		lift = lift,
		carrying = HeistService.getCarried(player) ~= nil,
	})
end

PlayerData.onLoaded(function(player, save)
	pushFlight(player, save)
	Net.fireClient("save:snapshot", player, {
		coins = save.coins,
		aircraftTier = save.aircraftTier,
		petCount = #save.pets,
		perchSlotsLevel = save.upgrades.perchSlots,
	})
end)

Net.handleFunction("shop:aircraft", function(player)
	local ok, err = EconomyService.buyNextAircraft(player)
	if ok then
		local save = PlayerData.get(player)
		if save then
			pushFlight(player, save)
		end
	end
	return { ok = ok, err = err }
end, 20)

Net.handleFunction("shop:upgrade", function(player, payload)
	local name = if typeof(payload) == "table" then payload.name else nil
	local ok, err = EconomyService.buyUpgrade(player, name)
	return { ok = ok, err = err }
end, 20)

-- Client calls this immediately after Hud.start() to get a guaranteed-fresh
-- snapshot even if the PlayerData.onLoaded snapshot fired before the client
-- registered its save:snapshot listener (race with Mock / fast DataStore).
Net.handleFunction("shop:requestSnapshot", function(player)
	local save = PlayerData.get(player)
	if save ~= nil then
		Net.fireClient("save:snapshot", player, {
			coins = save.coins,
			aircraftTier = save.aircraftTier,
			petCount = #save.pets,
			perchSlotsLevel = save.upgrades.perchSlots,
		})
	end
	return { ok = true }
end, 5)

Net.handleFunction("debug:ping", function(_player, _payload)
	return { ok = true, serverTime = os.time() }
end, 30)
