# Day-1 Acceptance Tests

From the Foundation brief. All must pass before Day-1 is declared done.

1. **Types compile** — every exported type is referenced by at least one module; no orphan shapes.
2. **GameConfig numbers intact** — the corrected GameConfig.luau is byte-identical to the spec; no numbers altered.
3. **Net entry cap** — sending a table with >200 keys is dropped and recorded as `too_many_entries`; under the cap it passes.
4. **Net rate limit** — exceeding DefaultLimitPerMinute (60) drops subsequent calls within the window; DropStrikeThreshold (10) in DropStrikeWindowSeconds (10) triggers a strike.
5. **PlayerData migration** — a save with no schemaVersion migrates to 1; a save with version > CURRENT is rejected and the player kicked; version == CURRENT reconciles cleanly.
6. **WorldBuilder idempotent** — calling build() twice destroys and rebuilds; no duplicate roots. Every BasePart Anchored. Every nest's flat distance from base ≤ its island's rangeNeeded.
7. **Boot + HUD** — server boots WorldBuilder then PlayerData; client receives save:snapshot and can invoke debug:ping, which echoes `{ok=true, serverTime}`.

## Module tests (per brief)

- FlightController: tier-1 reaches meadowrock not thornspire; tier-2 reaches thornspire with ~10% margin.
- HeistService: spoofed instant deliver → 0 coins + logged rejection; legitimate 40s deliver → BASE_EGG_BOUNTY coins + 1 pet.
