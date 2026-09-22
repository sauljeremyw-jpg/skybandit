# Foundation Brief (Day-1)

Source: SkyBandit Foundation agent, 2026-09-22.

## Task

Build the Day-1 foundation. Seven files. No flight, no economy, no pets yet.

## Files

1. `modules/shared/Types.luau` — the one schema. Exports: Rarity, Mutation, Pet, Upgrades, Passes, Stats, Meta, PlayerSave, FlightMode, FlightState, CarriedEgg.
2. `modules/shared/GameConfig.luau` — paste the corrected version exactly. Data, Economy, Aircraft (8 tiers), Islands (9), Rarities, Mutations, Upgrades, Store, Net, Flight, Intercept, World. Plus getter helpers.
3. `modules/shared/Net.luau` — typed remote wrapper. One RemoteEvent "E", one RemoteFunction "F", multiplexed by string name. Token bucket per-player-per-name. Entry-count cap at MaxPayloadEntries (200). pcall handlers. PlayerRemoving clears buckets.
4. `modules/server/PlayerData.luau` — ProfileStore session. StartSessionAsync, migrate before Reconcile, reject version > CURRENT. onLoaded, saveNow, OnSessionEnd.
5. `modules/server/WorldBuilder.luau` — grey-box world. buildBase (platform, walls, JumpPad, SpawnLocation), buildIsland per inSlice island. Self-assertions: all Anchored, nest distance <= rangeNeeded.
6. `modules/server/init.server.luau` — boot: WorldBuilder.build() then PlayerData.start(). debug:ping handler.
7. `modules/client/init.client.luau` — HUD from save:snapshot, invoke debug:ping on start.

Plus: `config/default.project.json` (StreamingEnabled, Gravity 60, Future lighting), `config/.gitignore`, `config/selene.toml` (std=roblox, mixed_table=allow).

## Assumption

ProfileStore vendored at `modules/server/Packages/ProfileStore.luau` — do not fetch, just require.

## Acceptance (7 tests)

See `tests/DAY1_ACCEPTANCE.md`.
