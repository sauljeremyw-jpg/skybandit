--!strict
local Types = require(script.Parent.Types)
export type AircraftDef = { tier: number, name: string, range: number, cost: number }
export type IslandDef = { id: string, name: string, rangeNeeded: number, guardian: string, bountyMultiplier: number, hazard: string, safeZone: boolean, inSlice: boolean }
export type RarityDef = { rarity: Types.Rarity, weight: number, lift: number, income: number }
export type MutationDef = { mutation: Types.Mutation, weight: number, incomeMult: number }
export type UpgradeDef = { baseCount: number?, baseSeconds: number?, baseAltitude: number?, minSeconds: number?, maxSeconds: number?, maxLevel: number, costBase: number, costMult: number, perLevel: number? }
local GameConfig = {}
GameConfig.Data = { StoreName = "PlayerData_v1", SchemaVersion = 1, AutosaveSeconds = 60 }
GameConfig.Economy = { BaseEggBounty = 250, PetBaseIncome = 0.15, LiftToStuds = 1.5, CarrySpeedPenalty = 0.85, InterceptBountyPct = 0.25, IncomeSoftCapFactor = 0.35, InterceptConsolationRarityDown = 1, MinRunSeconds = 8, MaxCoins = 2 ^ 53 }
GameConfig.Aircraft = {
	{ tier = 1, name = "Bedsheet Chute", range = 400, cost = 0 },
	{ tier = 2, name = "Patched Kite", range = 900, cost = 2_500 },
	{ tier = 3, name = "Hang Glider", range = 2_000, cost = 40_000 },
	{ tier = 4, name = "Powered Paraglider", range = 4_500, cost = 600_000 },
	{ tier = 5, name = "Ultralight", range = 10_000, cost = 3_000_000 },
	{ tier = 6, name = "Prop Plane", range = 22_000, cost = 15_000_000 },
	{ tier = 7, name = "Turboprop", range = 50_000, cost = 75_000_000 },
	{ tier = 8, name = "Jet", range = 120_000, cost = 400_000_000 },
} :: { AircraftDef }
GameConfig.MaxTier = 8
GameConfig.Islands = {
	{ id = "meadowrock", name = "Meadowrock", rangeNeeded = 400, guardian = "Sleepy Roc", bountyMultiplier = 1, hazard = "none", safeZone = true, inSlice = true },
	{ id = "thornspire", name = "Thornspire", rangeNeeded = 900, guardian = "Thorn Wyrm", bountyMultiplier = 8, hazard = "wind_shear", safeZone = true, inSlice = true },
	{ id = "cloudforge", name = "Cloudforge", rangeNeeded = 2_000, guardian = "Forge Golem", bountyMultiplier = 60, hazard = "updrafts", safeZone = false, inSlice = true },
	{ id = "stormgate", name = "Stormgate", rangeNeeded = 3_000, guardian = "Storm Roc", bountyMultiplier = 200, hazard = "wind_shear", safeZone = false, inSlice = true },
	{ id = "stormcrown", name = "Stormcrown", rangeNeeded = 4_500, guardian = "Tempest Drake", bountyMultiplier = 500, hazard = "lightning", safeZone = false, inSlice = false },
	{ id = "ring", name = "The Shattered Ring", rangeNeeded = 10_000, guardian = "Ring Sentinel", bountyMultiplier = 4_000, hazard = "debris", safeZone = false, inSlice = false },
	{ id = "emberfall", name = "Emberfall", rangeNeeded = 22_000, guardian = "Ash Phoenix", bountyMultiplier = 40_000, hazard = "falling_ash", safeZone = false, inSlice = false },
	{ id = "voidshelf", name = "The Void Shelf", rangeNeeded = 50_000, guardian = "Void Leviathan", bountyMultiplier = 500_000, hazard = "no_glide", safeZone = false, inSlice = false },
	{ id = "apex", name = "Apex", rangeNeeded = 120_000, guardian = "The Apex", bountyMultiplier = 8_000_000, hazard = "all", safeZone = false, inSlice = false },
} :: { IslandDef }
GameConfig.RarityWeightTotal = 10_000
GameConfig.Rarities = {
	{ rarity = "Common", weight = 6_000, lift = 1, income = 1 },
	{ rarity = "Uncommon", weight = 2_500, lift = 3, income = 4 },
	{ rarity = "Rare", weight = 1_000, lift = 10, income = 20 },
	{ rarity = "Epic", weight = 400, lift = 35, income = 120 },
	{ rarity = "Legendary", weight = 90, lift = 120, income = 900 },
	{ rarity = "Mythic", weight = 9, lift = 500, income = 8_000 },
	{ rarity = "Secret", weight = 1, lift = 2_500, income = 100_000 },
} :: { RarityDef }
GameConfig.Mutations = {
	{ mutation = "None", weight = 9_000, incomeMult = 1 },
	{ mutation = "Gold", weight = 800, incomeMult = 3 },
	{ mutation = "Storm", weight = 180, incomeMult = 10 },
	{ mutation = "Void", weight = 20, incomeMult = 40 },
} :: { MutationDef }
GameConfig.MutationWeightTotal = 10_000
GameConfig.Upgrades = {
	perchSlots = { baseCount = 10, maxLevel = 90, costBase = 500, costMult = 3.2 },
	incubator = { baseSeconds = 10, minSeconds = 2, maxLevel = 5, costBase = 2_000, costMult = 8 },
	launchPad = { baseAltitude = 120, perLevel = 40, maxLevel = 8, costBase = 1_000, costMult = 5 },
	vault = { baseSeconds = 7_200, maxSeconds = 86_400, maxLevel = 6, costBase = 3_000, costMult = 6 },
} :: { [string]: UpgradeDef }
GameConfig.Store = {
	passes = { x2Coins = { id = 0, price = 399, label = "x2 Coins" }, fastHatch = { id = 0, price = 349, label = "Fast Hatch" }, bigVault = { id = 0, price = 299, label = "Big Vault" }, skyCrew = { id = 0, price = 599, label = "Sky Crew" } },
	products = { luckyFeather = { id = 0, price = 99, label = "Lucky Feather", hours = 24, luckMult = 2 }, coinsSmall = { id = 0, price = 99, label = "Pouch of Coins" }, coinsMedium = { id = 0, price = 399, label = "Sack of Coins" }, coinsLarge = { id = 0, price = 999, label = "Vault of Coins" } },
}
GameConfig.Net = { MaxPayloadBytes = 4_096, MaxPayloadEntries = 200, DefaultLimitPerMinute = 60, DropStrikeWindowSeconds = 10, DropStrikeThreshold = 10, FlightStateLimitPerMinute = 720 }
GameConfig.Flight = { LiftK = 0.012, LiftCap = 200, DragK = 0.004, DiveExchangeRate = 1.2, StallAirspeed = 40, CorrectionLerpSeconds = 0.2, MaxDt = 0.05, SnapshotHz = 10, DiveLookDownY = -0.35, DiveLookDownSteerMult = 2, LandRayLength = 12, LandRayTrigger = 8 }
GameConfig.Intercept = { Radius = 25, PairCooldownSeconds = 30, NewPlayerImmunitySeconds = 30 * 60 }
GameConfig.World = { BaseSpacing = 600, BasePlatformSize = Vector3.new(180, 4, 180), LaunchEdgeAltitude = 160, IslandRadius = 80, IslandDistanceFactor = 0.6, IslandAngleStepDegrees = 65, NestGrabRadius = 80, NestRespawnSeconds = 15, SpawnGraceSeconds = 3, RespawnDelaySeconds = 3, IslandGroundHeight = 4, IslandLandRadius = 12, IslandLandSeconds = 2.5, IslandLandSpeedThreshold = 50, BaseLandSeconds = 2, LaunchRingWidth = 8, CharacterRootHeight = 3, HomePad = { ImpulseH = 80, ImpulseV = 45, LaunchSeconds = 1.5 }, SeatConfig = { AnchorHoldSeconds = 0.35, ConfirmSeconds = 0.5, HardCapSeconds = 6, PostCapFF = 2, CheckInterval = 0.1, RayLength = 6 } }
function GameConfig.terminalSpeed(carrying: boolean): number
	local speed = math.sqrt(GameConfig.Flight.LiftCap / GameConfig.Flight.DragK)
	if carrying then
		speed *= GameConfig.Economy.CarrySpeedPenalty
	end
	return speed
end
function GameConfig.getAircraft(tier)
	for _, a in GameConfig.Aircraft do
		if a.tier == tier then
			return a
		end
	end
	return nil
end
function GameConfig.getIsland(id)
	for _, i in GameConfig.Islands do
		if i.id == id then
			return i
		end
	end
	return nil
end
function GameConfig.islandWorldPosition(id: string, sliceIndex: number?): Vector3?
	local island = GameConfig.getIsland(id)
	if island == nil then
		return nil
	end
	local index = sliceIndex
	if index == nil then
		local n = 0
		for _, other in GameConfig.Islands do
			if other.inSlice then
				n += 1
				if other.id == id then
					index = n
					break
				end
			end
		end
	end
	if index == nil then
		return nil
	end
	local distance = if index == 1 then 180 else island.rangeNeeded * GameConfig.World.IslandDistanceFactor
	local angle = if index == 1 then math.rad(90) else math.rad(GameConfig.World.IslandAngleStepDegrees * index)
	local drop = math.min(distance * 0.18, GameConfig.World.LaunchEdgeAltitude * 0.6)
	local altitude = GameConfig.World.LaunchEdgeAltitude - drop
	return Vector3.new(math.cos(angle) * distance, altitude, math.sin(angle) * distance)
end
function GameConfig.getRarity(rarity)
	for _, r in GameConfig.Rarities do
		if r.rarity == rarity then
			return r
		end
	end
	return nil
end
function GameConfig.getRarityIndex(rarity)
	for i, r in GameConfig.Rarities do
		if r.rarity == rarity then
			return i
		end
	end
	return 1
end
function GameConfig.consolationRarity(stolen)
	local idx = GameConfig.getRarityIndex(stolen)
	local down = math.max(1, idx - GameConfig.Economy.InterceptConsolationRarityDown)
	return GameConfig.Rarities[down].rarity
end
function GameConfig.upgradeCost(costBase, costMult, level)
	return math.floor(costBase * costMult ^ level)
end
function GameConfig.perchSlotCount(level, hasSkyCrew)
	local n = GameConfig.Upgrades.perchSlots.baseCount + level
	if hasSkyCrew then
		n += 20
	end
	return n
end
function GameConfig.vaultCapSeconds(level, hasBigVault)
	local u = GameConfig.Upgrades.vault
	local span = u.maxSeconds - u.baseSeconds
	local byLevel = u.baseSeconds + span * (level / u.maxLevel)
	if hasBigVault then
		byLevel = math.max(byLevel, 12 * 3_600)
	end
	return math.floor(math.min(byLevel, u.maxSeconds))
end
function GameConfig.hatchSeconds(level, hasFastHatch)
	local u = GameConfig.Upgrades.incubator
	local span = u.baseSeconds - u.minSeconds
	local s = u.baseSeconds - span * (level / u.maxLevel)
	if hasFastHatch then
		s /= 2
	end
	return math.max(s, 0.5)
end
return GameConfig
