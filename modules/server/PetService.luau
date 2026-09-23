--!strict
-- Rarity is rolled here. Coin payouts go through EconomyService so the soft cap cannot be skipped.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PlayerData = require(script.Parent.PlayerData)
local EconomyService = require(script.Parent.EconomyService)

local PetService = {}
local started = false
local incomeAcc = 0

local function pickWeightedRarity(seed: number): Types.Rarity
	local rng = Random.new(seed)
	local roll = rng:NextNumber(0, GameConfig.RarityWeightTotal)
	local acc = 0
	for _, def in GameConfig.Rarities do
		acc += def.weight
		if roll <= acc then
			return def.rarity
		end
	end
	return "Common"
end

local function pickMutation(seed: number): Types.Mutation
	local rng = Random.new(seed + 17)
	local roll = rng:NextNumber(0, GameConfig.MutationWeightTotal)
	local acc = 0
	for _, def in GameConfig.Mutations do
		acc += def.weight
		if roll <= acc then
			return def.mutation
		end
	end
	return "None"
end

local function mutationMult(mutation: Types.Mutation): number
	for _, def in GameConfig.Mutations do
		if def.mutation == mutation then
			return def.incomeMult
		end
	end
	return 1
end

function PetService.totalLift(save: Types.PlayerSave): number
	local lift = 0
	for _, pet in save.pets do
		local rarity = GameConfig.getRarity(pet.rarity)
		if rarity then
			lift += rarity.lift
		end
	end
	return lift
end

function PetService.incomePerSecond(save: Types.PlayerSave): number
	local total = 0
	for _, pet in save.pets do
		local rarity = GameConfig.getRarity(pet.rarity)
		if rarity then
			total += GameConfig.Economy.PetBaseIncome * rarity.income * mutationMult(pet.mutation)
		end
	end
	return total
end

function PetService.rollAndGrant(player: Player, islandId: string, seed: number): Types.Pet?
	local save = PlayerData.get(player)
	if save == nil then
		return nil
	end
	local cap = GameConfig.perchSlotCount(save.upgrades.perchSlots, save.passes.skyCrew)
	if #save.pets >= cap then
		return nil
	end
	local pet: Types.Pet = {
		id = HttpService:GenerateGUID(false),
		species = islandId,
		rarity = pickWeightedRarity(seed),
		mutation = pickMutation(seed),
		slot = #save.pets + 1,
	}
	table.insert(save.pets, pet)
	return pet
end

function PetService.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(function(dt)
		incomeAcc += dt
		if incomeAcc < 1 then
			return
		end
		incomeAcc -= 1
		for _, player in Players:GetPlayers() do
			local save = PlayerData.get(player)
			if save and #save.pets > 0 then
				EconomyService.grantCoins(player, PetService.incomePerSecond(save), "pets")
			end
		end
	end)
end

return PetService
