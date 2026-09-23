--!strict
-- Client predicts glide feel. Snapshots are claims; FlightService owns true position.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local FlightController = {}
local GRAVITY = 60

local aircraftTier = 1
local carrying = false
local lift = 0
local state: Types.FlightState = {
	position = Vector3.zero,
	velocity = Vector3.zero,
	altitude = 0,
	mode = "Grounded",
	t = 0,
}
local correcting = false
local correctFrom: Vector3 = Vector3.zero
local correctTo: Vector3 = Vector3.zero
local correctElapsed = 0
local snapshotAcc = 0
local started = false

local launchedUntil = 0

local function characterRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function humanoidOf(root: BasePart): Humanoid?
	local model = root.Parent
	if model == nil then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid
	end
	return nil
end

function FlightController.getState(): Types.FlightState
	return state
end

function FlightController.setAircraft(tier: number)
	aircraftTier = tier
end

function FlightController.setCarrying(isCarrying: boolean)
	carrying = isCarrying
end

function FlightController.setLift(value: number)
	lift = value
end

local function applyCorrection(dt: number)
	correctElapsed += dt
	local alpha = math.clamp(correctElapsed / GameConfig.Flight.CorrectionLerpSeconds, 0, 1)
	state.position = correctFrom:Lerp(correctTo, alpha)
	if alpha >= 1 then
		correcting = false
	end
end

local function flying(): boolean
	return state.mode == "Gliding" or state.mode == "Launched" or state.mode == "Stalled"
end

local function step(dt: number)
	dt = math.min(dt, GameConfig.Flight.MaxDt)
	local root = characterRoot()
	state.t += dt
	if root and not correcting and not flying() then
		state.position = root.Position
		state.velocity = root.AssemblyLinearVelocity
	end
	if correcting then
		applyCorrection(dt)
	elseif flying() then
		local camera = workspace.CurrentCamera
		local look = if camera then camera.CFrame.LookVector else Vector3.zAxis
		if look.Magnitude < 0.01 then
			look = Vector3.zAxis
		end
		local speed = state.velocity.Magnitude
		if speed > 0.01 then
			local wish = look.Unit * speed
			local alpha = math.clamp(dt * GameConfig.Flight.SnapshotHz, 0, 1)
			state.velocity = state.velocity:Lerp(wish, alpha)
			speed = state.velocity.Magnitude
		end
		local liftForce = math.min(GameConfig.Flight.LiftK * speed * speed + lift, GameConfig.Flight.LiftCap)
		local dragForce = GameConfig.Flight.DragK * speed * speed
		if speed < GameConfig.Flight.StallAirspeed and state.mode == "Gliding" then
			state.mode = "Stalled"
		elseif speed >= GameConfig.Flight.StallAirspeed and state.mode ~= "Grounded" then
			state.mode = "Gliding"
		end
		if state.mode == "Gliding" or state.mode == "Launched" then
			local up = Vector3.yAxis * liftForce
			local drag = if speed > 0 then -state.velocity.Unit * dragForce else Vector3.zero
			local gravity = Vector3.yAxis * -GRAVITY
			state.velocity += (up + drag + gravity) * dt
			if state.velocity.Y < 0 then
				local horizontalLook = Vector3.new(look.X, 0, look.Z)
				if horizontalLook.Magnitude > 0.01 then
					local converted = -state.velocity.Y * GameConfig.Flight.DiveExchangeRate * dt
					state.velocity += horizontalLook.Unit * converted
				end
			end
			local terminal = GameConfig.terminalSpeed(carrying)
			if state.velocity.Magnitude > terminal then
				state.velocity = state.velocity.Unit * terminal
			end
			state.position += state.velocity * dt
		end
	end
	state.altitude = state.position.Y
	if root and flying() and not correcting and state.t >= launchedUntil and state.velocity.Y <= 8 then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local character = root.Parent
		if character then
			params.FilterDescendantsInstances = { character }
		end
		local hit = workspace:Raycast(state.position, Vector3.new(0, -12, 0), params)
		if hit and state.position.Y - hit.Position.Y < 6 then
			state.mode = "Grounded"
			state.velocity = Vector3.zero
			state.position = Vector3.new(state.position.X, hit.Position.Y + 3, state.position.Z)
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.new(state.position)
			local humanoid = humanoidOf(root)
			if humanoid then
				humanoid.PlatformStand = false
			end
		end
	end
	if root and (correcting or flying()) then
		local humanoid = humanoidOf(root)
		if humanoid and flying() then
			humanoid.PlatformStand = true
		elseif humanoid and not flying() then
			humanoid.PlatformStand = false
		end
		root.AssemblyLinearVelocity = state.velocity
		local face = Vector3.new(state.velocity.X, 0, state.velocity.Z)
		if face.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(state.position, state.position + face.Unit)
		else
			root.CFrame = CFrame.new(state.position)
		end
	end
	snapshotAcc += dt
	local period = 1 / GameConfig.Flight.SnapshotHz
	if snapshotAcc >= period then
		snapshotAcc = 0
		Net.send("flight:state", state)
	end
end

local function launch()
	local root = characterRoot()
	if root == nil or flying() then
		return
	end
	local camera = workspace.CurrentCamera
	local look = if camera then camera.CFrame.LookVector else Vector3.zAxis
	if look.Magnitude < 0.01 then
		look = Vector3.zAxis
	end
	state.mode = "Launched"
	state.position = root.Position
	state.velocity = look.Unit * GameConfig.Flight.StallAirspeed
	launchedUntil = state.t + GameConfig.Flight.MaxDt * GameConfig.Flight.SnapshotHz
end

function FlightController.start()
	if started then
		return
	end
	started = true
	Net.on("replica:flight", function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if typeof(payload.tier) == "number" then
			aircraftTier = payload.tier
		end
		if typeof(payload.lift) == "number" then
			lift = payload.lift
		end
		if typeof(payload.carrying) == "boolean" then
			carrying = payload.carrying
		end
		if typeof(payload.position) == "Vector3" then
			local pulled = payload.position - state.position
			if pulled.Magnitude > 1 then
				local radial = Vector3.new(state.position.X, 0, state.position.Z)
				if radial.Magnitude > 1 then
					local outward = radial.Unit
					local outwardSpeed = Vector3.new(state.velocity.X, 0, state.velocity.Z):Dot(outward)
					if outwardSpeed > 0 then
						state.velocity -= outward * outwardSpeed
					end
				end
			end
			correctFrom = state.position
			correctTo = payload.position
			correctElapsed = 0
			correcting = true
		end
	end)
	task.spawn(function()
		local world = workspace:WaitForChild("GeneratedWorld")
		local base = world:WaitForChild("Base")
		local pad = base:WaitForChild("JumpPad")
		if pad:IsA("BasePart") then
			pad.Touched:Connect(function(hit)
				local character = Players.LocalPlayer.Character
				if character and hit:IsDescendantOf(character) then
					launch()
				end
			end)
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		step(dt)
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart")
		if not root:IsA("BasePart") then
			return
		end
		root.Touched:Connect(function(part)
			if state.t < launchedUntil or not flying() then
				return
			end
			if part:IsDescendantOf(character) or part.Name == "JumpPad" then
				return
			end
			if state.velocity.Y > 0 then
				return
			end
			state.mode = "Grounded"
			local humanoid = humanoidOf(root)
			if humanoid then
				humanoid.PlatformStand = false
			end
		end)
	end)
end

return FlightController
