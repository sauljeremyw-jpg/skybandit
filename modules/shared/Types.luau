--!strict
-- Single shared schema. Every service imports shapes from here; none invent their own.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"
export type Mutation = "None" | "Gold" | "Storm" | "Void"

export type Pet = {
	id: string,
	species: string,
	rarity: Rarity,
	mutation: Mutation,
	slot: number?,
}

export type Upgrades = {
	perchSlots: number,
	incubator: number,
	launchPad: number,
	vault: number,
}

export type Passes = {
	x2Coins: boolean,
	fastHatch: boolean,
	bigVault: boolean,
	skyCrew: boolean,
}

export type Stats = {
	runs: number,
	eggsDelivered: number,
	eggsLost: number,
	eggsStolen: number,
	eggsStolenFromMe: number,
}

export type Meta = {
	firstJoinUnix: number,
	lastSeenUnix: number,
	streakDays: number,
	ascensions: number,
	lastPurchaseId: string?,
	luckyFeatherUntilUnix: number,
}

export type PlayerSave = {
	schemaVersion: number,
	coins: number,
	aircraftTier: number,
	pets: { Pet },
	upgrades: Upgrades,
	passes: Passes,
	stats: Stats,
	meta: Meta,
}

export type FlightMode = "Grounded" | "Gliding" | "Stalled" | "Launched"

export type FlightState = {
	position: Vector3,
	velocity: Vector3,
	altitude: number,
	mode: FlightMode,
	t: number,
}

export type CarriedEgg = {
	islandId: string,
	bounty: number,
	grabbedAtUnix: number,
}

return {}
