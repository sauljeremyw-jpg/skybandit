--!strict
-- Thin coin grants used by HeistService. Soft-cap lives here so clients never add coins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local PlayerData = require(script.Parent.PlayerData)

local EconomyService = {}

function EconomyService.grantCoins(player: Player, amount: number, _reason: string): (boolean, string?)
	if amount <= 0 then
		return false, "non_positive"
	end
	local save = PlayerData.get(player)
	if save == nil then
		return false, "no_save"
	end
	save.coins = math.min(save.coins + amount, GameConfig.Economy.MaxCoins)
	return true, nil
end

function EconomyService.start() end

return EconomyService
