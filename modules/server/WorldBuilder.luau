--!strict
-- Grey-box world is generated from GameConfig so island spacing and launch altitude stay one source of truth.
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local ROOT_NAME = "GeneratedWorld"
local WorldBuilder = {}
local basesByPlayer: { [Player]: Model } = {}
local islandsById: { [string]: Model } = {}

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function WorldBuilder.getBaseCFrame(): CFrame
	return CFrame.new(0, GameConfig.World.LaunchEdgeAltitude, 0)
end

function WorldBuilder.getIslandModel(id: string): Model?
	return islandsById[id]
end

function WorldBuilder.getNestPosition(id: string): Vector3?
	local origin = GameConfig.islandWorldPosition(id)
	if origin == nil then
		return nil
	end
	return origin + Vector3.new(0, 4, 0)
end

local function buildBase(parent: Folder)
	local base = Instance.new("Model")
	base.Name = "Base"
	base.Parent = parent
	local size = GameConfig.World.BasePlatformSize
	local altitude = GameConfig.World.LaunchEdgeAltitude
	local platform = part("Platform", size, CFrame.new(0, altitude, 0), Color3.fromRGB(90, 90, 90), base)
	part("WallN", Vector3.new(size.X, 12, 2), CFrame.new(0, altitude + 8, -size.Z / 2), Color3.fromRGB(70, 70, 70), base)
	part("WallS", Vector3.new(size.X, 12, 2), CFrame.new(0, altitude + 8, size.Z / 2), Color3.fromRGB(70, 70, 70), base)
	part("WallE", Vector3.new(2, 12, size.Z), CFrame.new(size.X / 2, altitude + 8, 0), Color3.fromRGB(70, 70, 70), base)
	part("JumpPad", Vector3.new(16, 1, 16), CFrame.new(0, altitude + size.Y / 2 + 0.5, size.Z / 2 - 12), Color3.fromRGB(40, 140, 80), base)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, altitude + size.Y / 2 + 0.5, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = base
	base.PrimaryPart = platform
end

local function buildIsland(parent: Folder, def: GameConfig.IslandDef, index: number)
	local origin = GameConfig.islandWorldPosition(def.id, index)
	if origin == nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = def.id
	model.Parent = parent
	part("Ground", Vector3.new(GameConfig.World.IslandRadius * 2, 4, GameConfig.World.IslandRadius * 2), CFrame.new(origin), Color3.fromRGB(110, 120, 90), model)
	part("Nest", Vector3.new(10, 2, 10), CFrame.new(origin + Vector3.new(0, 4, 0)), Color3.fromRGB(180, 140, 60), model)
	part("Guardian", Vector3.new(8, 16, 8), CFrame.new(origin + Vector3.new(20, 10, 0)), Color3.fromRGB(140, 50, 50), model)
	islandsById[def.id] = model
	local nestPos = origin + Vector3.new(0, 4, 0)
	local flat = Vector3.new(nestPos.X, 0, nestPos.Z).Magnitude
	assert(flat <= def.rangeNeeded, def.id .. " nest is outside its rangeNeeded")
end

local function assertAnchored(instance: Instance)
	for _, child in instance:GetDescendants() do
		if child:IsA("BasePart") then
			assert(child.Anchored, child:GetFullName() .. " is not Anchored")
		end
	end
end

function WorldBuilder.build()
	local existing = Workspace:FindFirstChild(ROOT_NAME)
	if existing then
		existing:Destroy()
	end
	islandsById = {}
	local folder = Instance.new("Folder")
	folder.Name = ROOT_NAME
	folder.Parent = Workspace
	buildBase(folder)
	local sliceIndex = 0
	for _, island in GameConfig.Islands do
		if island.inSlice then
			sliceIndex += 1
			buildIsland(folder, island, sliceIndex)
		end
	end
	assertAnchored(folder)
end

function WorldBuilder.start()
	Players.PlayerRemoving:Connect(function(player)
		basesByPlayer[player] = nil
	end)
end

return WorldBuilder
