--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Hud = require(script.Hud)

Net.start()
Hud.start()

local ok, err = pcall(function()
	require(script.FlightController).start()
end)
if not ok then
	Hud.fail(tostring(err))
end
