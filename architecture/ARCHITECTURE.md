# Architecture Rules

Violations are rejected without review.

1. **Luau strict mode.** Every file starts with `--!strict`. No `any` except at validated remote boundaries.
2. **Server-authoritative economy.** The client may PREDICT flight and DISPLAY values. It may never be the source of truth for coins, pets, egg carry state, rarity rolls, or purchases.
3. **Every tunable number lives in `ReplicatedStorage/Shared/GameConfig.luau`.** If you need a number that is not there, ADD IT THERE and reference it. Never inline a magic number in a service.
4. **Every shared shape lives in `ReplicatedStorage/Shared/Types.luau`.** One schema, one place.
5. **All client→server traffic goes through the Net wrapper.** Never create a RemoteEvent directly in a service. The wrapper is where rate limits and validation live.
6. **Hard module boundaries.** A module may require only: Types, GameConfig, Net, and the modules explicitly named in its brief's dependency list. If you think you need another, stop and say so instead of requiring it.
7. **Rojo file layout.** Writing files on disk, not Studio objects.
8. **No third-party dependency** beyond the ones named in the brief.

## Style

- Pure functions where possible; side effects concentrated at the module's edges.
- Explicit error returns (`ok: boolean, err: string?`) over `error()` in anything reachable from a remote.
- Comment WHY, not WHAT.
- No placeholder TODOs in accepted code. If something is out of scope, it is simply absent.

## Output format (for any builder)

1. Complete files, each in its own fenced block headed by its full path.
2. A short list of every assumption made that the brief did not specify.
3. The module's test, written as described in the brief.

## Judgment order

1. Can a client cheat it?
2. Does it match the data contract exactly?
3. Does it handle the failure modes listed?
4. Does the test actually test the thing?
5. Is it readable?

## Rojo layout

```
src/
  shared/          → ReplicatedStorage/Shared
    Types.luau
    GameConfig.luau
    Net.luau
  server/          → ServerScriptService/Server
    PlayerData.luau
    WorldBuilder.luau
    HeistService.luau
    FlightService.luau
    EconomyService.luau
    PetService.luau
    init.server.luau
    Packages/
      ProfileStore.luau
  client/          → StarterPlayerScripts/Client
    FlightController.luau
    init.client.luau
```

## Data contract summary

- `PlayerSave`: schemaVersion, coins, aircraftTier, pets[], upgrades, passes, stats, meta
- `FlightState`: position, velocity, altitude, mode, t — published at 10Hz, server-authoritative on position
- `CarriedEgg`: islandId, bounty, grabbedAtUnix (server); rarityRollSeed is server-only
- Economy: BaseEggBounty 250, soft cap, intercept consolation rarity-down by 1
- Intercept: radius 25, pair cooldown 30s, new-player immunity 30min
