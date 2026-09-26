# Status 2026-09-25 (overnight, post Jeremy session)

Branch `cursor/perch-upgrade-hud-d8d6` / PR #1 — tip `d107055`.
No Claude credits, no SkyBandit bots. All commits on this branch.

---

## Locked constants — do NOT change without explicit Jeremy PASS

| Constant | Value | Reason |
|----------|-------|--------|
| `GameConfig.World.HomePad.ImpulseH` | 70 | outbound-reserved; locked |
| `GameConfig.World.HomePad.ImpulseV` | 45 | hang-time PASS |
| `GameConfig.World.HomePad.ReturnImpulseH` | 90 | island→Base horizontal reach |
| `GameConfig.World.HomePad.ReturnImpulseV` | 60 | island→Base vertical height — FAIL 2026-09-26: ReturnImpulseH=90+ImpulseV=45 fell short vertically; added ReturnImpulseV=60 |
| `GameConfig.Flight.LiftK` | 0.012 | frozen |
| `GameConfig.Flight.DragK` | 0.004 | frozen |
| `GameConfig.Flight.StallAirspeed` | 40 | frozen |
| `GameConfig.World.LaunchEdgeAltitude` | 160 | frozen |
| `GameConfig.World.IslandAngleStepDegrees` | 65 | frozen |
| `GameConfig.Economy.MinRunSeconds` | 8 | **PARKED** — see open items |

---

## Open items (Jeremy to confirm)

### (a) Thornspire→Base return — pending first PASS
`HomePad.ReturnImpulseH` was raised 70→90 in `d107055` to restore Thornspire→Base reach after ImpulseV 60→45 (hang fix) cut the lift. Playtest checklist step 6 below confirms.

### (b) Data persist — Studio API Services
With API Services OFF (Jeremy's current Studio) data resets each session. Turning on **Game Settings → Security → Studio Access to API Services** will persist coins/pets between Stop→Play. Code is correct for both modes — warn fires once if unavailable, falls back to Mock.

### (c) MinRunSeconds 8→3 — PARKED
`[Heist] reject instant deliver` hit with HomePad return timing. Changing MinRunSeconds from 8→3 would fix the instant-deliver gate. **This was NOT pushed** — Jeremy must decide whether 3s is acceptable anti-cheat before applying. The change is a one-liner in GameConfig and review.py needs its required-number updated to match.

### (d) Day-1 acceptance checklist — pending full Studio run
Checklist is in the next section. No full end-to-end run has been done with two players or with API Services on.

---

## Day-1 acceptance checklist

Tony rebuilds `skybandit.rbxlx` with `rojo serve` → Studio Rojo plugin → **File → Save As → skybandit.rbxlx** → share with Jeremy. Enable **Game Settings → Security → Studio Access to API Services** for data persistence.

| # | Action | Expected |
|---|--------|----------|
| 1 | Press **Play** | No errors in Output. `[seat] JeremyName after_y=127 target_y=127 pad_y=122` visible. Character stands on grey Base. |
| 2 | Stand on Base for 3 s | ForceField drops. No lava death. |
| 3 | Step on green launch ring (any side) | Launches into glide. No lock. |
| 4 | Aim **west** (toward Thornspire, 130° bearing) and launch | Path clears Meadowrock. No force-land on Meadowrock. |
| 5 | Land on **Meadowrock** → **Grab egg** | Status "ok". |
| 6 | Step on orange **Spring Pad** on Meadowrock | Launches toward Base. Reaches Base (does not fall short). No excessive bounce above Base. |
| 7 | Land on Base → **Deliver** | Coins increment. If "too_fast" appears, MinRunSeconds=8 gate hit — consider applying the parked 8→3 cut. |
| 8 | With tier-2 aircraft (Patched Kite), launch toward **Thornspire** (west edge of ring) | Arrives at Thornspire without force-landing on Meadowrock en route. |
| 9 | Grab on Thornspire → **Spring Pad** → Base | Returns to Base (does not fall short). No excessive hang. |
| 10 | Die intentionally (walk off into lava) | Respawn on Base after ~3 s. `[seat]` in Output. No lava loop. |
| 11 | Tap **Buy next aircraft** | Tier label advances, HUD `tier N → NextPlane COST` updates. |
| 12 | Tap **Upgrade perch** | Perch level increments, `upg:N` cost advances. No "poor" when coins ≥ cost. |
| 13 | Stop Studio → Play again (API Services ON) | Coins, tier, pets persist. |

---

## Shipped (all green on review.py)

### Foundation + economy
- Day-1 server loop: FlightController, HeistService, EconomyService, PetService, FlightService.
- ProfileStore real (API Services ON) or Mock (OFF); session-lock + schema migration.
- Soft-cap economy; x2 Coins pass; FlightService position-claim validation.

### HUD
- Grab / Deliver / Buy next aircraft / **Upgrade perch** buttons — fail-closed, status-label feedback.
- `save:snapshot` carries `perchSlotsLevel`; `shop:requestSnapshot` also calls `pushFlight` to sync `aircraftTier` (fixes tier-1 magnet staying active for tier-2 players).
- HUD label: `tier N → NextPlane COST` on tier line; `upg:N` for perch upgrade cost (no "next:" ambiguity).

### World
- Base: 180×180 platform, full-perimeter green launch ring (4 strips named "JumpPad"), no walls.
- Islands: floating name labels (BillboardGui on Beacon), orange HomePad spring on every in-slice island.
- IslandAngleStepDegrees=65 — Thornspire path clears Meadowrock flat radius by 93 studs.

### Spawn / respawn (bulletproof)
- `Players.CharacterAutoLoads=false` at boot; `LoadCharacter()` after RespawnLocation armed.
- `Humanoid.Died → task.wait(3) → LoadCharacter()` for post-death respawn.
- `seat()`: Spawning attribute + invisible ForceField + anchor+PivotTo + raycast confirm.
- `lava.Touched` uses `TakeDamage`; `SpawnLocation.Duration=5`.
- JumpPad SpawnGraceSeconds=3 gate.

### Flight / landing
- Island hover: time-only force-land (`IslandLandSeconds=2.5`), speed-gated (`IslandLandSpeedThreshold=50`), altitude trigger removed.
- Base hover: `baseUnder()` — speed-gated time-only + sub-deck snap (`Y < platformTop-2` → snap back to surface).
- Raycast landing: Platform hits now call `landOn` (basePiece gate removed). `LandRayTrigger=8`.
- PlatformStand synced every frame from `flying()`.
- Dive look-down: `DiveLookDownY=-0.35`, `DiveLookDownSteerMult=2`.
- HomePad return: `ReturnImpulseH=90`, `ImpulseV=45`; camera-steer suppressed while carrying in launch window.

### Data persist
- Studio: tries live DataStore (pcall), falls back to Mock with one-time warn.
- `profile:Save()` before `EndSession()`; `game:BindToClose` saves all.

---

## Still not launch

- No full end-to-end multi-player test.
- Game-pass and developer-product IDs still 0.
- Islands past the first four not built (`inSlice=false`).
- No intercept combat, no hatch/upgrade UI.
- MinRunSeconds 8→3 parked (Jeremy decision).
- Dive/launch feel untested with two concurrent players.
- `LiftK`/`DragK` not tuned — do not retune until Studio shows Meadowrock margin wrong.
