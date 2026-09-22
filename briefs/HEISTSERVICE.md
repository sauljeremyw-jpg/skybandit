# HeistService Brief

Source: SkyBandit HeistService agent, 2026-09-22.

## Module

`ServerScriptService/Server/HeistService.luau`
Depends on: Types, GameConfig, Net, PlayerData, FlightService, EconomyService, PetService.

## Public API

- `start(): ()`
- `getCarried(player: Player): Types.CarriedEgg?`
- `forceDrop(player: Player, reason: string): ()`

## Data contract

Owns egg carry state. Exactly one carried egg per player, server-side. Client gets a replicated read-only copy for visuals. An egg has: islandId, rarityRollSeed (server-only), grabbedAt. Delivery converts carry → coins via EconomyService and an egg → PetService.rollAndGrant.

## Must validate

On grab:
- player's authoritative position is within N studs of the nest (FlightService, not the client)
- player's effective range actually covers that island
- player is not already carrying
- per-player grab cooldown ≥ the island's respawn timer

On deliver:
- player is at their own base, authoritative position
- carry state exists and grabbedAt is at least MIN_RUN_SECONDS ago (instant deliver = teleport exploit)

## Failure modes

- Player disconnects carrying: egg is lost. Do not refund. Log it.
- Player is intercepted: carry transfers atomically; both players cannot hold it for one frame.
- Guardian kills the carrier: forceDrop with reason "guardian", victim keeps nothing.
- Two players grab the same nest in the same frame: first-write-wins under a per-nest lock.

## Test

Simulate: grab at Meadowrock, deliver immediately via a spoofed position packet. Expect zero coins granted and a logged rejection. Then grab and deliver legitimately after 40 seconds: expect exactly BASE_EGG_BOUNTY coins and exactly one pet rolled.
