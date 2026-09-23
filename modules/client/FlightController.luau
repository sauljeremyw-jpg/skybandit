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

local function step(dt: number)
	dt = math.min(dt, GameConfig.Flight.MaxDt)
	local root = characterRoot()
	if root and not correcting then
		state.position = root.Position
		state.velocity = root.AssemblyLinearVelocity
	end
	state.altitude = state.position.Y
	state.t += dt
	if correcting then
		applyCorrection(dt)
		if root then
			root.CFrame = CFrame.new(state.position)
		end
	else
		local speed = state.velocity.Magnitude
		local liftForce = math.min(GameConfig.Flight.LiftK * speed * speed + lift, GameConfig.Flight.LiftCap)
		local dragForce = GameConfig.Flight.DragK * speed * speed
		if carrying then
			state.velocity *= GameConfig.Economy.CarrySpeedPenalty
		end
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
			state.position += state.velocity * dt
		end
	end
	snapshotAcc += dt
	local period = 1 / GameConfig.Flight.SnapshotHz
	if snapshotAcc >= period then
		snapshotAcc = 0
		Net.send("flight:state", state)
	end
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
			correctFrom = state.position
			correctTo = payload.position
			correctElapsed = 0
			correcting = true
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		step(dt)
	end)
end

return FlightController
