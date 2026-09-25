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
	local pad = part("JumpPad", Vector3.new(16, 2, 16), CFrame.new(0, altitude + size.Y / 2 + 1, size.Z / 2 - 12), Color3.fromRGB(40, 200, 80), base)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LaunchPrompt"
	prompt.ActionText = "Launch"
	prompt.ObjectText = "Green pad"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, altitude + size.Y / 2 + 0.5, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	-- ForceField on respawn so TakeDamage lava cannot loop-kill a respawning character.
	spawn.Duration = 5
	spawn.Enabled = true
	spawn.Parent = base
	base.PrimaryPart = platform
	base.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
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
	local beacon = part("Beacon", Vector3.new(4, 24, 4), CFrame.new(origin + Vector3.new(0, 16, 0)), Color3.fromRGB(255, 220, 40), model)
	beacon.Material = Enum.Material.Neon
	beacon.CanCollide = false
	local guardian = part("Guardian", Vector3.new(8, 16, 8), CFrame.new(origin + Vector3.new(20, 10, 0)), Color3.fromRGB(140, 50, 50), model)
	guardian.CanCollide = false
	-- Orange spring pad: the island is below Base altitude, so players need a
	-- launch boost to carry an egg home. Touch or prompt fires launchHome() on
	-- the client, which redirects velocity toward the origin (Base).
	local homePad = part("HomePad", Vector3.new(12, 2, 12), CFrame.new(origin + Vector3.new(-20, 3, 0)), Color3.fromRGB(255, 140, 0), model)
	homePad.Material = Enum.Material.Neon
	local homePrompt = Instance.new("ProximityPrompt")
	homePrompt.Name = "LaunchHomePrompt"
	homePrompt.ActionText = "Return to Base"
	homePrompt.ObjectText = "Spring Pad"
	homePrompt.HoldDuration = 0
	homePrompt.MaxActivationDistance = 18
	homePrompt.RequiresLineOfSight = false
	homePrompt.Parent = homePad
	islandsById[def.id] = model
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
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
	for _, child in Workspace:GetChildren() do
		-- Terrain is a BasePart subclass; Roblox forbids Destroy() on it.
		if child:IsA("BasePart") and not child:IsA("Terrain") then
			child:Destroy()
		end
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
	for _, child in Workspace:GetDescendants() do
		if child:IsA("SpawnLocation") and not child:IsDescendantOf(folder) then
			child:Destroy()
		end
	end
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	local lava = part("Lava", Vector3.new(12000, 6, 12000), CFrame.new(0, 1, 0), Color3.fromRGB(255, 60, 0), folder)
	lava.Material = Enum.Material.Neon
	lava.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if character == nil then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			-- TakeDamage (not direct Health assignment) so a ForceField from
			-- seat() or SpawnLocation.Duration blocks lava during spawn window.
			humanoid:TakeDamage(humanoid.MaxHealth)
		end
	end)
end

local function spawnPad(): SpawnLocation?
	local world = Workspace:FindFirstChild(ROOT_NAME)
	if world == nil then
		return nil
	end
	local base = world:FindFirstChild("Base")
	if base == nil then
		return nil
	end
	local spawn = base:FindFirstChild("SpawnLocation")
	if spawn and spawn:IsA("SpawnLocation") then
		return spawn
	end
	return nil
end

local function seat(player: Player, character: Model)
	-- CharacterAutoLoads was disabled at boot so the initial spawn could not race
	-- the world build.  Re-enable it now: the world is ready and RespawnLocation
	-- is armed, so any future death auto-respawns at the correct altitude.
	player.CharacterAutoLoads = true
	-- ForceField must exist BEFORE WaitForChild yields so TakeDamage lava
	-- cannot kill the character during the replication gap between CharacterAdded
	-- and the first CFrame teleport.
	local ff = Instance.new("ForceField")
	ff.Visible = false
	ff.Parent = character
	local root = character:WaitForChild("HumanoidRootPart")
	if not root:IsA("BasePart") then
		ff:Destroy()
		return
	end
	local spawn = spawnPad()
	local cf = if spawn then spawn.CFrame + Vector3.new(0, 4, 0) else CFrame.new(0, GameConfig.World.LaunchEdgeAltitude + 8, 0)
	local function place()
		if spawn then
			player.RespawnLocation = spawn
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = cf
	end
	place()
	task.spawn(function()
		for _ = 1, 40 do
			if root.Parent == nil then
				ff:Destroy()
				return
			end
			if root.Position.Y > 70 then
				-- Character confirmed above safe altitude; lava can kill normally now.
				ff:Destroy()
				return
			end
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = cf
			task.wait(0.1)
		end
		ff:Destroy()
	end)
end

local function hookPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		seat(player, character)
	end)
	if player.Character then
		seat(player, player.Character)
	end
end

function WorldBuilder.start()
	-- Pre-arm RespawnLocation before any character auto-loads.  Without this,
	-- a character that dies before seat() runs its WaitForChild yield will
	-- respawn at Roblox's default position (Y≈0) directly onto the lava.
	local spawn = spawnPad()
	local function armPlayer(player: Player)
		if spawn then
			player.RespawnLocation = spawn
		end
		hookPlayer(player)
	end
	for _, player in Players:GetPlayers() do
		armPlayer(player)
	end
	Players.PlayerAdded:Connect(armPlayer)
	Players.PlayerRemoving:Connect(function(player)
		basesByPlayer[player] = nil
	end)
end

return WorldBuilder
