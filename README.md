# SkyBandit — Claude Code Handoff Pack

Roblox experience built in **Luau** with a **Rojo** file layout. Server-authoritative economy. This repo is the complete context dump so Claude Code can pick up the project without any Grok bot context.

## Folder map

| Path | Contents |
|---|---|
| `architecture/` | Architecture rules, data contracts, module boundaries, Rojo layout spec |
| `modules/` | Source files: Types, GameConfig, Net, PlayerData, WorldBuilder, FlightController, HeistService, boot scripts |
| `briefs/` | The exact prompts given to each builder agent (Foundation, FlightController, HeistService) plus the Reviewer spec |
| `tests/` | Acceptance tests and module tests as written in the briefs |
| `config/` | Tooling config: `default.project.json`, `.gitignore`, `selene.toml` |
| `handoff/` | Kickoff prompt and token-diet notes |

## What exists today (Day-1 foundation)

- `modules/shared/Types.luau` — single schema for all shared shapes
- `modules/shared/GameConfig.luau` — every tunable number, corrected version
- `modules/shared/Net.luau` — typed remote wrapper with rate limits + entry-count cap
- `modules/server/PlayerData.luau` — ProfileStore session, migration, reconcile
- `modules/server/WorldBuilder.luau` — grey-box world from GameConfig
- `modules/server/init.server.luau` — boot
- `modules/client/init.client.luau` — HUD + debug ping
- `config/default.project.json`, `config/.gitignore`, `config/selene.toml`

## Next modules (briefs ready, not yet built)

- `FlightController.luau` (client) — velocity glide model, 10Hz snapshots, server corrections
- `HeistService.luau` (server) — egg grab/deliver, nest locks, teleport-exploit guards
- `FlightService.luau` (server) — authoritative position, range entitlement
- `EconomyService.luau` (server) — coin grants, soft cap
- `PetService.luau` (server) — rarity rolls, mutations, income

## Hard rules (do not violate)

1. `--!strict` on every file. No `any` except validated remote boundaries.
2. Server is source of truth for coins, pets, egg carry, rarity, purchases. Client predicts flight and displays only.
3. Every number in `GameConfig`. Every shape in `Types`. No magic numbers.
4. All client→server traffic through `Net`. No raw RemoteEvents in services.
5. A module may require only Types, GameConfig, Net, and its named dependencies.
6. Rojo on disk, not Studio objects. No third-party deps beyond named ones.
7. Explicit error returns over `error()` on anything reachable from a remote.
8. Comment WHY, not WHAT.

## How to use this with Claude Code

1. Clone this repo into your workspace.
2. Paste the contents of `handoff/CLAUDE_CODE_KICKOFF.md` as the first message.
3. Point Claude at `architecture/ARCHITECTURE.md` and `modules/` as the source of truth.
4. Run the Reviewer checklist in `briefs/REVIEWER.md` on every new module before merging.

## Token diet note

This pack exists because the Grok bot roster was burning through its 48-hour token budget on tasks Claude Code handles better and cheaper. Grok stays only for FlightController physics tuning and HeistService exploit-guard judgment. Everything else — prose, prompts, code review, scheduling — goes to Claude.
