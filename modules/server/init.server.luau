--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local WorldBuilder = require(script.Parent.WorldBuilder)
local PlayerData = require(script.Parent.PlayerData)
local HeistService = require(script.Parent.HeistService)

Net.start()
WorldBuilder.build()
WorldBuilder.start()
PlayerData.start()
HeistService.start()

PlayerData.onLoaded(function(player, save)
	Net.fireClient("save:snapshot", player, {
		coins = save.coins,
		aircraftTier = save.aircraftTier,
		petCount = #save.pets,
	})
end)

Net.handleFunction("debug:ping", function(_player, _payload)
	return { ok = true, serverTime = os.time() }
end, 30)
