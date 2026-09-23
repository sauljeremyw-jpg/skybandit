--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local WorldBuilder = require(script.Parent.WorldBuilder)
local PlayerData = require(script.Parent.PlayerData)
local FlightService = require(script.Parent.FlightService)
local EconomyService = require(script.Parent.EconomyService)
local PetService = require(script.Parent.PetService)
local HeistService = require(script.Parent.HeistService)

Net.start()
WorldBuilder.build()
WorldBuilder.start()
PlayerData.start()
FlightService.start()
EconomyService.start()
PetService.start()
HeistService.start()

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
	})
end)

Net.handleFunction("debug:ping", function(_player, _payload)
	return { ok = true, serverTime = os.time() }
end, 30)
