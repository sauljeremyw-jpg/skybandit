--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local FlightController = require(script.Parent.FlightController)
local Hud = require(script.Parent.Hud)

Net.start()
FlightController.start()
Hud.start()

print("[SkyBandit] debug:ping", Net.invoke("debug:ping", {}))
