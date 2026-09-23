# SkyBandit — Claude Code standing orders

Read `architecture/ARCHITECTURE.md` before writing anything.

## Loop (do not skip)

1. Change one module or one thin service.
2. Run `python tools/review.py`. Zero BLOCKERs required.
3. If BLOCKER, fix in the same turn. Do not commit a reject.
4. Stop after the current brief. Do not start FlightService-full, ads, UI polish, or new systems.

## Current queue

1. Confirm all files under `modules/` exist on disk (review.py fails if any are missing).
2. Vendor real ProfileStore over the stub when you have the file; keep the same require path.
3. Full FlightService only after FlightController + Heist pass review.py.
4. Soft-cap EconomyService after FlightService.

## Never

- Prompt Grok SkyBandit bots for code.
- Inline magic numbers.
- Trust client position for coins, pets, carry, rarity, or purchases.
- Create remotes outside `Net.luau`.
- Leave TODO in accepted files.

## Notify Jeremy only

COMPLETE+path, hard blocker, or a yes-no that unblocks the next module.
