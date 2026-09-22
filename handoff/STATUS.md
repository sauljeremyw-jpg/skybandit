# Status 2026-09-22

Started from this Grok chat (not the SkyBandit bot roster) so the 48-hour bot budget stays untouched. Claude tokens can iterate from the files now on `main`.

## Landed on main

- Day-1 foundation: Types, GameConfig, Net, PlayerData, WorldBuilder, boot scripts, Rojo/selene/gitignore
- FlightController (client predict + 10Hz claim snapshots + lerp corrections)
- HeistService (server grab/deliver, nest locks, MinRunSeconds anti-teleport)
- Thin FlightService / EconomyService / PetService so Heist compiles without waiting on full economy

## GameConfig additions (needed by Heist, not in original paste)

- `World.NestGrabRadius = 20`
- `World.NestRespawnSeconds = 15`
- `islandWorldPosition(id)` helper so Heist does not require WorldBuilder

## Not done

- Full FlightService (authoritative integration, range entitlement from pets)
- Soft-cap EconomyService
- Real ProfileStore vendor (stub in Packages/)
- Studio playtest of the 7 Day-1 checks and the two module tests
- Reviewer pass against live Studio output

## How to continue in Claude Code

Clone `sauljeremyw-jpg/skybandit`, paste `briefs/CLAUDE_CODE_KICKOFF.md`, treat `modules/` as source of truth. Do not re-prompt the Grok SkyBandit bots unless a physics/exploit judgment is blocked.
