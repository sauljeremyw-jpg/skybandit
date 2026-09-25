--!strict
-- Phone-sized buttons. The server still decides whether a grab, deliver, or purchase is legal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local Hud = {}
local statusLabel: TextLabel? = nil

local function flight()
	return require(script.Parent.FlightController)
end

local function nearestIsland(): string?
	local pos = flight().getState().position
	local bestId: string? = nil
	local best = math.huge
	for _, island in GameConfig.Islands do
		if island.inSlice then
			local origin = GameConfig.islandWorldPosition(island.id)
			if origin then
				local nest = origin + Vector3.new(0, 4, 0)
				local distance = (pos - nest).Magnitude
				if distance < best then
					best = distance
					bestId = island.id
				end
			end
		end
	end
	return bestId
end

local function button(parent: Instance, name: string, text: string, order: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.new(1, -24, 0, 56)
	b.Position = UDim2.new(0, 12, 1, -12 - order * 64)
	b.Text = text
	b.TextSize = 22
	b.AutoButtonColor = true
	b.Parent = parent
	return b
end

function Hud.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkyBanditHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "Snapshot"
	label.Size = UDim2.new(1, -24, 0, 88)
	label.Position = UDim2.fromOffset(12, 12)
	label.BackgroundTransparency = 0.3
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextSize = 20
	label.TextWrapped = true
	label.Text = "SkyBandit"
	label.Parent = gui

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, -24, 0, 36)
	status.Position = UDim2.fromOffset(12, 104)
	status.BackgroundTransparency = 0.3
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextSize = 18
	status.Text = ""
	status.Parent = gui
	statusLabel = status

	local coins = "?"
	local tier = "?"
	local pets = "?"
	local carry = "empty"
	local perchLevel = 0
	local tierNum = 1

	local function redraw()
		local def = GameConfig.Upgrades.perchSlots
		local nextPerch = if perchLevel < def.maxLevel
			then tostring(GameConfig.upgradeCost(def.costBase, def.costMult, perchLevel))
			else "MAX"
		local nextAircraftDef = GameConfig.getAircraft(tierNum + 1)
		local nextPlane = if nextAircraftDef ~= nil
			then nextAircraftDef.name .. "  " .. tostring(nextAircraftDef.cost)
			else "MAX tier"
		label.Text = string.format(
			"coins %s\ntier %s   pets %s   perch lv%d  next:%s\nnext plane: %s\ncarry %s",
			coins, tier, pets, perchLevel, nextPerch, nextPlane, carry
		)
	end

	Net.on("save:snapshot", function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		coins = tostring(payload.coins)
		if typeof(payload.aircraftTier) == "number" then
			tierNum = payload.aircraftTier
		end
		tier = tostring(payload.aircraftTier)
		pets = tostring(payload.petCount)
		if typeof(payload.perchSlotsLevel) == "number" then
			perchLevel = payload.perchSlotsLevel
		end
		redraw()
	end)

	Net.on("replica:carry", function(payload)
		if typeof(payload) == "table" then
			carry = string.format("%s  (%s)", tostring(payload.islandId), tostring(payload.bounty))
			flight().setCarrying(true)
		else
			carry = "empty"
			flight().setCarrying(false)
		end
		redraw()
	end)

	local function show(result: any)
		if typeof(result) ~= "table" then
			status.Text = "no reply"
			return
		end
		if result.ok then
			status.Text = "ok"
		else
			status.Text = tostring(result.err)
		end
	end

	button(gui, "Grab", "Grab egg", 3).MouseButton1Click:Connect(function()
		local islandId = nearestIsland()
		if islandId == nil then
			status.Text = "no island"
			return
		end
		show(Net.invoke("heist:grab", { islandId = islandId }))
	end)

	button(gui, "Deliver", "Deliver", 2).MouseButton1Click:Connect(function()
		show(Net.invoke("heist:deliver", {}))
	end)

	button(gui, "Aircraft", "Buy next aircraft", 1).MouseButton1Click:Connect(function()
		show(Net.invoke("shop:aircraft", {}))
	end)

	button(gui, "Perch", "Upgrade perch", 0).MouseButton1Click:Connect(function()
		show(Net.invoke("shop:upgrade", { name = "perchSlots" }))
	end)
end

function Hud.fail(message: string)
	if statusLabel then
		statusLabel.Text = message
		statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	end
end

return Hud
