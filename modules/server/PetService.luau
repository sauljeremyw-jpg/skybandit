--!strict
-- Thin roll+grant used by HeistService. Rarity is rolled server-side only.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PlayerData = require(script.Parent.PlayerData)

local PetService = {}

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

function PetService.rollAndGrant(player: Player, islandId: string, seed: number): Types.Pet?
	local save = PlayerData.get(player)
	if save == nil then
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

function PetService.start() end

return PetService
