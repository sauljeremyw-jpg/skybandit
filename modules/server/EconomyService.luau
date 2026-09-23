--!strict
-- Clients never add coins. Grants shrink toward IncomeSoftCapFactor as the balance grows, and never below it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)

local EconomyService = {}
local remainder: { [Player]: number } = {}

local function softMultiplier(coins: number): number
	local aircraft = GameConfig.getAircraft(4)
	local scale = if aircraft then aircraft.cost else GameConfig.Economy.BaseEggBounty
	if scale <= 0 then
		return 1
	end
	local t = coins / (coins + scale)
	local floorFactor = GameConfig.Economy.IncomeSoftCapFactor
	return 1 - (1 - floorFactor) * t
end

local function push(player: Player, save: Types.PlayerSave)
	Net.fireClient("save:snapshot", player, {
		coins = save.coins,
		aircraftTier = save.aircraftTier,
		petCount = #save.pets,
	})
end

function EconomyService.grantCoins(player: Player, amount: number, _reason: string): (boolean, string?)
	if amount <= 0 then
		return false, "non_positive"
	end
	local save = PlayerData.get(player)
	if save == nil then
		return false, "no_save"
	end
	local granted = amount
	if save.passes.x2Coins then
		granted *= 2
	end
	granted *= softMultiplier(save.coins)
	local pending = (remainder[player] or 0) + granted
	local whole = math.floor(pending)
	remainder[player] = pending - whole
	if whole > 0 then
		save.coins = math.min(save.coins + whole, GameConfig.Economy.MaxCoins)
		push(player, save)
	end
	return true, nil
end

function EconomyService.trySpend(player: Player, amount: number, _reason: string): (boolean, string?)
	if amount < 0 then
		return false, "negative"
	end
	local save = PlayerData.get(player)
	if save == nil then
		return false, "no_save"
	end
	if save.coins < amount then
		return false, "poor"
	end
	save.coins -= amount
	push(player, save)
	return true, nil
end

function EconomyService.buyNextAircraft(player: Player): (boolean, string?)
	local save = PlayerData.get(player)
	if save == nil then
		return false, "no_save"
	end
	local nextTier = save.aircraftTier + 1
	if nextTier > GameConfig.MaxTier then
		return false, "max_tier"
	end
	local aircraft = GameConfig.getAircraft(nextTier)
	if aircraft == nil then
		return false, "no_aircraft"
	end
	local ok, err = EconomyService.trySpend(player, aircraft.cost, "aircraft")
	if not ok then
		return false, err
	end
	save.aircraftTier = nextTier
	push(player, save)
	return true, nil
end

local function upgradeLevel(save: Types.PlayerSave, name: string): number?
	if name == "perchSlots" then
		return save.upgrades.perchSlots
	elseif name == "incubator" then
		return save.upgrades.incubator
	elseif name == "launchPad" then
		return save.upgrades.launchPad
	elseif name == "vault" then
		return save.upgrades.vault
	end
	return nil
end

local function setUpgradeLevel(save: Types.PlayerSave, name: string, level: number)
	if name == "perchSlots" then
		save.upgrades.perchSlots = level
	elseif name == "incubator" then
		save.upgrades.incubator = level
	elseif name == "launchPad" then
		save.upgrades.launchPad = level
	elseif name == "vault" then
		save.upgrades.vault = level
	end
end

function EconomyService.buyUpgrade(player: Player, name: any): (boolean, string?)
	if typeof(name) ~= "string" then
		return false, "bad_name"
	end
	local def = GameConfig.Upgrades[name]
	if def == nil then
		return false, "unknown"
	end
	local save = PlayerData.get(player)
	if save == nil then
		return false, "no_save"
	end
	local level = upgradeLevel(save, name)
	if level == nil then
		return false, "unknown"
	end
	if level >= def.maxLevel then
		return false, "max_level"
	end
	local cost = GameConfig.upgradeCost(def.costBase, def.costMult, level)
	local ok, err = EconomyService.trySpend(player, cost, name)
	if not ok then
		return false, err
	end
	setUpgradeLevel(save, name, level + 1)
	push(player, save)
	return true, nil
end

function EconomyService.start()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		remainder[player] = nil
	end)
end

return EconomyService
