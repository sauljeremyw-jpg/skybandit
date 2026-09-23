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

function EconomyService.start()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		remainder[player] = nil
	end)
end

return EconomyService
