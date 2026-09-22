# Claude Code Kickoff Prompt

Paste this as the first message to Claude Code after cloning this repo.

---

You are continuing **SkyBandit**, a Roblox experience written in Luau with a Rojo layout. The Day-1 foundation is already built and sitting in `modules/`. Read `architecture/ARCHITECTURE.md` and the files in `modules/` before writing anything.

## Your job right now

Build the next two modules, in order:

1. `modules/client/FlightController.luau` — see brief `briefs/FLIGHTCONTROLLER.md`
2. `modules/server/HeistService.luau` — see brief `briefs/HEISTSERVICE.md`

Do not write FlightService, EconomyService, or PetService yet. Those come after these two compile and pass review.

## Rules (non-negotiable)

- `--!strict`, no `any` except validated remote boundaries.
- Server is source of truth for coins, pets, egg carry, rarity, purchases.
- Every number in GameConfig, every shape in Types. No magic numbers.
- All client→server traffic through Net. No raw RemoteEvents.
- A module requires only Types, GameConfig, Net, and its named dependencies.
- Explicit error returns on anything reachable from a remote.
- Comment WHY, not WHAT.

## Output per module

1. The complete file in a fenced block headed by its path.
2. Assumptions list.
3. The test from the brief.

## After both modules

Run the Reviewer checklist from `briefs/REVIEWER.md` on each. Fix any BLOCKER before declaring done. Then stop and report status.

## Token discipline

This project moved off a Grok bot roster that was exhausting its 48-hour budget. Do not re-litigate decisions already in the architecture doc. If something is ambiguous, make the cheapest safe assumption, list it, and move on.
