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
local spawnGraceUntil = 0
local timeOverIsland = 0
local timeOverBase = 0

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

local function landOn(root: BasePart, point: Vector3)
	timeOverIsland = 0
	timeOverBase = 0
	state.mode = "Grounded"
	state.velocity = Vector3.zero
	state.position = point
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(point)
	local humanoid = humanoidOf(root)
	if humanoid then
		humanoid.PlatformStand = false
	end
end

-- Mirrors islandUnder for the home Base platform so right-click look-around
-- cannot trap the player hovering above the grey platform.
-- Matches islandUnder pattern: speed-gated time-only force-land, no damp,
-- no altitude trigger.  The altitude trigger was firing immediately after
-- any ring-strip launch that kept the player inside the 90-stud footprint
-- at launchedUntil expiry (e.g. east strip toward Meadowrock: X=86, Z≈83,
-- both ≤ 90 → altitude Y≈163 ≤ platformTop+12=174 → force-land on Base).
local function baseUnder(dt: number): Vector3?
	local half = GameConfig.World.BasePlatformSize.X / 2
	local halfZ = GameConfig.World.BasePlatformSize.Z / 2
	if math.abs(state.position.X) <= half and math.abs(state.position.Z) <= halfZ then
		local platformTop = GameConfig.World.LaunchEdgeAltitude + GameConfig.World.BasePlatformSize.Y / 2
		local landY = platformTop + GameConfig.World.CharacterRootHeight
		-- If the player has fallen through the deck (below platformTop - 2) they are
		-- inside the lava/void under Base.  miss() never fires because XZ is inside
		-- the Base footprint; PlatformStand=flying() freezes them in place.
		-- Snap back to the platform surface immediately.
		if state.position.Y < platformTop - 2 then
			return Vector3.new(state.position.X, landY, state.position.Z)
		end
		local horizSpeed = Vector3.new(state.velocity.X, 0, state.velocity.Z).Magnitude
		if horizSpeed < GameConfig.World.IslandLandSpeedThreshold then
			timeOverBase += dt
		end
		if timeOverBase >= GameConfig.World.BaseLandSeconds then
			return Vector3.new(state.position.X, landY, state.position.Z)
		end
		return nil
	end
	timeOverBase = 0
	return nil
end

-- dt is accumulated to force a land after IslandLandSeconds so lift cannot
-- keep the player hovering above the island indefinitely.
local function islandUnder(dt: number): Vector3?
	for _, island in GameConfig.Islands do
		if island.inSlice then
			local origin = GameConfig.islandWorldPosition(island.id)
			if origin then
				local flat = Vector3.new(state.position.X - origin.X, 0, state.position.Z - origin.Z)
				if flat.Magnitude <= GameConfig.World.IslandRadius - 4 then
					-- Altitude trigger removed: it fired on transit passes (player at
					-- ~130 crosses Meadowrock trigger=142 and got force-landed mid-path
					-- even with angle=65 clearance).  Raising LAE shifts both player
					-- altitude and the trigger proportionally — margin unchanged.
					-- Time-only force-land: slow/hovering players (< IslandLandSpeedThreshold)
					-- accumulate time and land after IslandLandSeconds (2.5 s).
					-- Fast transits (≥50 studs/s, chord=115, ~1.6-1.9 s) never accumulate.
					-- Physical landing via root.Touched handles surface contact at any speed.
					local horizSpeed = Vector3.new(state.velocity.X, 0, state.velocity.Z).Magnitude
					if horizSpeed < GameConfig.World.IslandLandSpeedThreshold then
						timeOverIsland += dt
					end
					local groundTop = origin.Y + GameConfig.World.IslandGroundHeight / 2
					local landY = groundTop + GameConfig.World.CharacterRootHeight
					if timeOverIsland >= GameConfig.World.IslandLandSeconds then
						return Vector3.new(origin.X + flat.X, landY, origin.Z + flat.Z)
					end
					return nil
				end
			end
		end
	end
	timeOverIsland = 0
	return nil
end

local function miss(root: BasePart)
	state.mode = "Grounded"
	state.velocity = Vector3.zero
	local humanoid = humanoidOf(root)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
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
			-- While carrying within the HomePad launch window, hold the homeward
			-- velocity so camera drift cannot veer the player away from Base before
			-- they clear the altitude deficit.  Outbound (not carrying) steers freely.
			if not (carrying and state.t < launchedUntil) then
				local wish = look.Unit * speed
				-- Steer harder toward camera when looking steeply down so velocity
				-- tracks the dive direction quickly for a precise vertical landing.
				local steerMult = if look.Y <= GameConfig.Flight.DiveLookDownY
					then GameConfig.Flight.DiveLookDownSteerMult
					else 1
				local alpha = math.clamp(dt * GameConfig.Flight.SnapshotHz * steerMult, 0, 1)
				state.velocity = state.velocity:Lerp(wish, alpha)
			end
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
				-- Skip dive-to-horizontal conversion when looking steeply down so
				-- the player sinks toward the landing spot instead of being pushed flat.
				if look.Y > GameConfig.Flight.DiveLookDownY then
					local horizontalLook = Vector3.new(look.X, 0, look.Z)
					if horizontalLook.Magnitude > 0.01 then
						local converted = -state.velocity.Y * GameConfig.Flight.DiveExchangeRate * dt
						state.velocity += horizontalLook.Unit * converted
					end
				end
			end
			local terminal = GameConfig.terminalSpeed(carrying)
			if state.velocity.Magnitude > terminal then
				state.velocity = state.velocity.Unit * terminal
			end
			state.position += state.velocity * dt
		end
		local meadow = GameConfig.islandWorldPosition("meadowrock")
		-- Suppress the outbound magnet when carrying: the player has the egg and
		-- needs to fly home; pulling back toward Meadowrock would fight the return.
		if meadow and aircraftTier == 1 and not carrying then
			local toward = Vector3.new(meadow.X - state.position.X, 0, meadow.Z - state.position.Z)
			if toward.Magnitude > 20 then
				local horiz = Vector3.new(state.velocity.X, 0, state.velocity.Z)
				local speed = math.max(horiz.Magnitude, 70)
				local aimed = toward.Unit * speed
				local blend = math.clamp(dt * 3, 0, 0.45)
				horiz = horiz:Lerp(aimed, blend)
				state.velocity = Vector3.new(horiz.X, state.velocity.Y, horiz.Z)
			end
		end
	end
	state.altitude = state.position.Y
	if root and flying() and not correcting and state.t >= launchedUntil then
		local spot = islandUnder(dt)
		if spot then
			landOn(root, spot)
		else
			local baseSpot = baseUnder(dt)
			if baseSpot then
				landOn(root, baseSpot)
			elseif state.position.Y < 40 then
				miss(root)
			elseif state.velocity.Y <= 8 then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				local character = root.Parent
				if character then
					params.FilterDescendantsInstances = { character }
				end
				local ray = Vector3.new(0, -GameConfig.Flight.LandRayLength, 0)
				local hit = workspace:Raycast(state.position, ray, params)
				if hit and state.position.Y - hit.Position.Y < GameConfig.Flight.LandRayTrigger then
					if hit.Instance:FindFirstAncestor("GeneratedWorld") ~= nil and hit.Position.Y >= 40 then
						landOn(root, Vector3.new(state.position.X,
							hit.Position.Y + GameConfig.World.CharacterRootHeight,
							state.position.Z))
					elseif hit.Instance:FindFirstAncestor("GeneratedWorld") == nil then
						miss(root)
					end
				end
			end
		end
	end
	if root then
		local humanoid = humanoidOf(root)
		if humanoid then
			-- PlatformStand synced every frame: true while airborne (prevents normal
			-- walking physics from fighting flight), false every Grounded frame so the
			-- character can walk immediately without needing a separate landOn call.
			humanoid.PlatformStand = flying()
		end
		if correcting or flying() then
			root.AssemblyLinearVelocity = state.velocity
			local face = Vector3.new(state.velocity.X, 0, state.velocity.Z)
			if face.Magnitude > 0.01 then
				root.CFrame = CFrame.lookAt(state.position, state.position + face.Unit)
			else
				root.CFrame = CFrame.new(state.position)
			end
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
	local horizontal = Vector3.new(look.X, 0, look.Z)
	if horizontal.Magnitude < 0.25 then
		horizontal = Vector3.zAxis
	end
	state.velocity = horizontal.Unit * 90 + Vector3.new(0, -30, 0)
	launchedUntil = state.t + 1.2
end

local function launchHome()
	local root = characterRoot()
	if root == nil or flying() then
		return
	end
	-- Aim horizontally toward the world origin where Base sits (0, 0, 0).
	-- Positive ImpulseV overcomes the altitude deficit between island and Base.
	local flat = Vector3.new(state.position.X, 0, state.position.Z)
	local homeDir: Vector3 = if flat.Magnitude > 1 then -flat.Unit else -Vector3.zAxis
	state.mode = "Launched"
	state.position = root.Position
	-- ReturnImpulseH is a dedicated dial for island→Base reach; ImpulseH is
	-- reserved as a separate outbound-facing constant so the two can be tuned
	-- independently.  ImpulseV (hang height) is shared and still governs both.
	state.velocity = homeDir * GameConfig.World.HomePad.ReturnImpulseH
		+ Vector3.new(0, GameConfig.World.HomePad.ImpulseV, 0)
	launchedUntil = state.t + GameConfig.World.HomePad.LaunchSeconds
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
				if radial.Magnitude > 1 and pulled:Dot(radial.Unit) < 0 then
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

		-- Connect launch to every JumpPad strip in the ring.  ChildAdded handles
		-- parts that replicate after WaitForChild("Base") resolves.
		local function hookPad(child: Instance)
			if not child:IsA("BasePart") then return end
			local pad = child :: BasePart
			pad.Touched:Connect(function(hit)
				local character = Players.LocalPlayer.Character
				if character and hit:IsDescendantOf(character) then
					if os.clock() < spawnGraceUntil then return end
					launch()
				end
			end)
			local prompt = pad:FindFirstChild("LaunchPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Triggered:Connect(function()
					if os.clock() < spawnGraceUntil then return end
					launch()
				end)
			end
		end

		for _, child in base:GetChildren() do
			if child.Name == "JumpPad" then
				hookPad(child)
			end
		end
		base.ChildAdded:Connect(function(child)
			if child.Name == "JumpPad" then
				hookPad(child)
			end
		end)
		-- Wire the orange spring (HomePad) on every in-slice island so the player
		-- can return to Base after a grab regardless of which island they landed on.
		for _, islandDef in GameConfig.Islands do
			if islandDef.inSlice then
				local islandModel = world:WaitForChild(islandDef.id, 15)
				if islandModel then
					local homePad = islandModel:FindFirstChild("HomePad")
					if homePad and homePad:IsA("BasePart") then
						homePad.Touched:Connect(function(hit)
							local character = Players.LocalPlayer.Character
							if character and hit:IsDescendantOf(character) then
								launchHome()
							end
						end)
						local homePrompt = homePad:FindFirstChild("LaunchHomePrompt")
						if homePrompt and homePrompt:IsA("ProximityPrompt") then
							homePrompt.Triggered:Connect(launchHome)
						end
					end
				end
			end
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		step(dt)
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		state.mode = "Grounded"
		state.velocity = Vector3.zero
		timeOverIsland = 0
		timeOverBase = 0
		-- Grace window: ignore JumpPad touch immediately after spawn so the
		-- character cannot be auto-launched off Base before they are stable.
		spawnGraceUntil = os.clock() + GameConfig.World.SpawnGraceSeconds
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
			local generated = part:FindFirstAncestor("GeneratedWorld")
			if generated == nil or part.Position.Y < 40 then
				miss(root)
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
