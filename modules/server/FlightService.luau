--!strict
-- Thin position authority used by HeistService until the full FlightService module is built.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local FlightService = {}
local positions: { [Player]: Vector3 } = {}
local ranges: { [Player]: number } = {}

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

function FlightService.start() end

return FlightService
