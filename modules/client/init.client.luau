--!strict
local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local FlightController = require(script.Parent.FlightController)

Net.start()
FlightController.start()

local gui = Instance.new("ScreenGui")
gui.Name = "SkyBanditHUD"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local label = Instance.new("TextLabel")
label.Name = "Snapshot"
label.Size = UDim2.fromOffset(280, 72)
label.Position = UDim2.fromOffset(16, 16)
label.BackgroundTransparency = 0.3
label.TextXAlignment = Enum.TextXAlignment.Left
label.Text = "SkyBandit"
label.Parent = gui

Net.on("save:snapshot", function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	label.Text = string.format("coins %s  tier %s  pets %s", tostring(payload.coins), tostring(payload.aircraftTier), tostring(payload.petCount))
end)

print("[SkyBandit] debug:ping", Net.invoke("debug:ping", {}))
