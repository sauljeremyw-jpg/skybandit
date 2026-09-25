# Status 2026-09-25 (morning, post-overnight polish)

Built in this chat on branch `cursor/perch-upgrade-hud-d8d6` / PR #1.
No Claude credits, no SkyBandit bots. Physics constants (LiftK / DragK / StallAirspeed) frozen throughout.

---

## Shipped (all green on review.py)

### Foundation
- Day-1 server loop: FlightController, HeistService, EconomyService, PetService, FlightService.
- Real MadStudio ProfileStore vendored. Session-lock + schema migration. AutosaveSeconds from config.
- FlightService rejects position claims beyond terminalSpeed or aircraft range; sends correction.
- Soft-cap economy: full payout at 0 coins, floor at `IncomeSoftCapFactor × grant` past tier-4 cost.

### HUD (phone-sized buttons)
- Grab / Deliver / Buy next aircraft / **Upgrade perch** — all fail-closed with status-label feedback.
- `save:snapshot` now carries `perchSlotsLevel`; info label shows level + next-upgrade cost.

### World
- Base platform doubled: `BasePlatformSize = 180×4×180` (was 90×4×90).
- Three walls removed (WallN / WallS / WallE). All four sides open for glide-in.
- JumpPad, SpawnLocation, seat() target, deliver zone all auto-adapt from config — no hard offsets.
- Orange HomePad spring on every in-slice island (Neon, named "HomePad", ProximityPrompt "Return to Base").

### Spawn / respawn (bulletproof)
- `Players.CharacterAutoLoads = false` at boot (service level). `LoadCharacter()` called after world + RespawnLocation armed. `Humanoid.Died → task.wait(RespawnDelaySeconds=3) → LoadCharacter()` for post-death respawn.
- `seat()`: `Spawning` attribute gates lava.Touched; invisible ForceField before `WaitForChild` yield; `root.Anchored + PivotTo(Platform top + 5)` + hold for 0.35 s; server raycast confirms `hit.Instance.Name == "Platform"` for ≥ 0.5 s before clearing Spawning + FF. Re-homes if drift detected. 6 s hard cap.
- `lava.Touched` uses `TakeDamage` (not direct Health) so ForceField blocks it. `SpawnLocation.Duration = 5`.
- JumpPad grace window: `SpawnGraceSeconds = 3` — Touched and ProximityPrompt both gated for 3 s after spawn.
- Server prints `[seat] name  after_y=N  target_y=N  pad_y=N` on every seat() call.

### Flight feel
- **Dive look-down**: `DiveLookDownY = -0.35`. When looking ≤ −0.35 Y, DiveExchangeRate horizontal push is skipped (player sinks onto target) and steer alpha doubles (`DiveLookDownSteerMult = 2`).
- **Island force-land**: `islandUnder(dt)` always applies vy ≤ −45 sink assist + horizontal damp when in flat radius; force-lands after `IslandLandSeconds = 1.5 s` or when `Y ≤ groundTop + IslandLandRadius`. Resets on landOn / CharacterAdded.
- **Base force-land**: `baseUnder(dt)` mirrors island logic for the Base footprint; force-lands after `BaseLandSeconds = 2 s` or within 12 studs of platformTop. Fixes RMB-look hover-stuck above Platform.
- **Raycast landing fixed**: removed `basePiece` gate that was silently skipping `landOn` for Platform. Any GeneratedWorld surface at Y ≥ 40 now calls `landOn`. `LandRayLength = 12`, `LandRayTrigger = 8` from config.
- **HomePad spring**: `launchHome()` fires homeDir × ImpulseH=90 + upward ImpulseV=60. Camera-steer suppressed while `carrying and t < launchedUntil` (prevents RMB look fighting return flight). Tier-1 outbound magnet gated on `not carrying`.
- `PlatformStand = flying()` every frame — cleared unconditionally when Grounded.

### Data persist
- Studio: `PlayerData` tries live DataStore (pcall), falls back to Mock with a one-time warn.
- `profile:Save()` before `EndSession()` in PlayerRemoving. `game:BindToClose` saves all on shutdown.
- **Requires**: Game Settings → Security → Studio Access to API Services = ON.

---

## Morning playtest checklist (Jeremy — DESKTOP-D8JUR0U)

Rebuild: `rojo serve` → Studio Rojo plugin → **File → Save As → skybandit.rbxlx** → **Play**.

| # | Step | Expected |
|---|------|----------|
| 1 | Watch Output on Play | `[seat] Jeremy  after_y=127  target_y=127  pad_y=122` (no errors) |
| 2 | Walk on 180-stud grey Base | No walls on any side; walk freely to all edges |
| 3 | Wait 3 s then step on green JumpPad | Launches into glide |
| 4 | Glide toward Meadowrock; stay above it without diving | Should land within 1.5 s of entering flat radius |
| 5 | Tap **Grab egg** | Status "ok"; orange HomePad visible on island |
| 6 | Step on orange **Spring Pad** (HomePad) | Launches toward Base |
| 7 | While returning, right-click look sideways above Base | Should land on Base within 2 s; no permanent hover |
| 8 | While gliding, look steeply downward at target | Should sink straight onto it instead of being pushed flat |
| 9 | Tap **Deliver** | Coins increment; "too_fast" if under MinRunSeconds |
| 10 | Die intentionally (walk off lava edge) | Respawn on grey Base ~3 s later; `[seat]` in Output |
| 11 | Tap **Buy next aircraft** | Coins deduct, tier label advances |
| 12 | Tap **Upgrade perch** | Perch level increments; "poor" / "max_level" on failure |
| 13 | Stop → Play again (API Services ON) | Coins + pets persist |

---

## Still not launch

- No full Studio playtest end-to-end with multiple players yet.
- Game-pass and developer-product IDs are still 0. Nothing is for sale.
- Islands past the first four not built (`inSlice = false`).
- No intercept combat, no hatch/upgrade UI.
- Dive and launch feel physically untested in Roblox. Do **not** retune `LiftK` / `DragK` until a Studio run shows the Meadowrock margin is off.

## Assumption

Soft-cap scale is the tier-4 aircraft cost in GameConfig (600,000). No new economy number invented.
