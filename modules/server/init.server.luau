--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local WorldBuilder = require(script.WorldBuilder)

-- Prevent characters from auto-spawning before the world is built and
-- RespawnLocation is armed.  seat() re-enables CharacterAutoLoads = true
-- on the first confirmed stable placement so future deaths respawn normally.
local function disableAutoLoad(player: Player)
	player.CharacterAutoLoads = false
end
for _, player in Players:GetPlayers() do
	disableAutoLoad(player)
end
Players.PlayerAdded:Connect(disableAutoLoad)

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

-- World built, RespawnLocation armed.  Now it is safe to spawn characters.
for _, player in Players:GetPlayers() do
	player:LoadCharacter()
end
-- Players who join after boot: DisableAutoLoad already fired via PlayerAdded;
-- this second handler loads their character after WorldBuilder.start() has
-- pre-armed their RespawnLocation.
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

Net.handleFunction("debug:ping", function(_player, _payload)
	return { ok = true, serverTime = os.time() }
end, 30)
