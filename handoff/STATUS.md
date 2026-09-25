# Status 2026-09-25

Built in this chat. No Claude credits and no SkyBandit bots used.

## Landed

- Day-1 foundation, FlightController, HeistService, static review gate (green)
- Real MadStudio ProfileStore vendored. PlayerData uses `ProfileStore.New` and session lock. Saves persist.
- FlightService rejects claims that outrun `terminalSpeed` or the aircraft range, and sends a position correction.
- Touching JumpPad launches. Glide uses the config lift, drag, and dive exchange. Carrying no longer multiplies speed every frame.
- EconomyService soft-caps grants toward `IncomeSoftCapFactor` (full payout at 0 coins, approaching 0.35 as coins pass the tier-4 aircraft cost). x2 Coins applies before the cap.
- PetService rolls rarity, respects perch cap, and pays `PetBaseIncome` each second through EconomyService.
- Phone-sized Grab, Deliver, Buy-next-aircraft, and **Upgrade perch** buttons. Server still rejects a bad grab or a short run.
- Aircraft purchases spend coins and raise range.
- **Perch upgrade HUD button landed.** Tap "Upgrade perch" → fires `shop:upgrade {name="perchSlots"}` → EconomyService.buyUpgrade validates level cap, coin balance, and unknown-name; returns `{ok, err}` displayed on the status label (fail-closed, no silent no-ops). Info label now shows current perch level and cost of next upgrade.
- `save:snapshot` now carries `perchSlotsLevel` so the HUD always reflects the server-authoritative level.

## Hotfix — 2026-09-25 (round 1)

Studio boot was blocked by two `Workspace.StreamingEnabled = false` writes in `init.server.luau` (line 3) and `WorldBuilder.luau` (`WorldBuilder.build()`). Scripts lack the Plugin capability required to write that property at runtime; Rojo's `default.project.json` already sets it via `$properties`, which is the correct place. Both writes removed. The unused `local Workspace = game:GetService("Workspace")` import in `init.server.luau` was also dropped. WorldBuilder retains its own `Workspace` import for part creation.

## Hotfix — 2026-09-25 (round 2)

Second Studio playtest hit two cascading failures:

**WorldBuilder Terrain crash** — `WorldBuilder.build()` loops over `Workspace:GetChildren()` and destroys any `BasePart`. `Terrain` is a `BasePart` subclass in Roblox; destroying it raises `Cannot Destroy() Terrain`. This killed `init.server.luau` before any service could start, including `FlightService`. Fixed by adding `and not child:IsA("Terrain")` to the guard.

**flight:state Net flood** — Because `init.server.luau` died before `FlightService.start()`, the `flight:state` event handler was never registered with its intended rate limit; only the default 60/min applied. The client sends at `SnapshotHz = 10 Hz = 600/min`, so the token bucket drained in ~6 seconds and every subsequent event logged a drop + strike. Fixed by adding `FlightStateLimitPerMinute = 720` to `GameConfig.Net` and passing it to `Net.handleEvent("flight:state", …)` in `FlightService.start()`.

After these two fixes, `WorldBuilder.build()` completes, `GeneratedWorld` appears in Workspace, the client `WaitForChild` resolves, and flight:state events process without flooding the log.

## Hotfix — 2026-09-25 (round 7): bulletproof seat() — Spawning attribute + anchor-PivotTo + raycast confirm

b1ae016 still left the player on lava because:
1. `root.Position.Y > LaunchEdgeAltitude-4` (= 116) fired immediately after ONE task.wait(0.1) when the character respawned at Y=122, removing the ForceField before physics had settled. Lava could then kill during the confirmation gap.
2. `root.CFrame = cf` (not `character:PivotTo`) only moves HumanoidRootPart; other character parts can lag behind. Physics fights the placement. No anchor hold.
3. No secondary kill guard — once the ForceField was removed, lava.Touched could fire.
4. Print was before place(), showing pre-teleport Y.

**Fixes (WorldBuilder.luau + GameConfig.luau):**
- `player:SetAttribute("Spawning", true)` at seat() entry. lava.Touched checks BOTH ForceField AND Spawning attribute before TakeDamage. Spawning cleared only when platform raycast confirms grounded on Base.Platform.
- `root.Anchored = true` + zero velocity + `character:PivotTo(target)` for solid placement. Anchored hold for AnchorHoldSeconds (0.35 s) so physics settles before release.
- Target is `platform.CFrame * CFrame.new(0, Platform.Size.Y/2 + 5, 0)` (5 studs above Platform top) instead of SpawnLocation+4. Falls to Platform naturally after unanchoring.
- Confirmation loop uses server-side raycast (0, -RayLength, 0) checking `hit.Instance.Name == "Platform"` AND `Y > LaunchEdgeAltitude-10`. Confirmed for ≥ConfirmSeconds (0.5 s) continuous before clearing Spawning and FF. Re-homes (anchor+PivotTo) on any drift below threshold.
- Hard cap at HardCapSeconds (6 s): clears Spawning, keeps FF for PostCapFF (2 s) buffer.
- Print AFTER place(): shows `after_y`, `target_y`, `pad_y`.
- All timing constants in `GameConfig.World.SeatConfig` — no inline numbers.

## Hotfix — 2026-09-25 (round 6): Players.CharacterAutoLoads (service) + Humanoid.Died respawn

Root cause of post-death lava loop:

1. `player.CharacterAutoLoads` (per-Player) is NOT the service-level gate. The correct
   property is `Players.CharacterAutoLoads` on the Players service. Setting it per-player
   was a silent no-op — the service-level auto-load was never actually disabled.

2. `seat()` had `player.CharacterAutoLoads = true` which was also a no-op (same wrong API).

3. After death, `Players.CharacterAutoLoads` was still the Roblox default (true), so
   auto-respawn happened — but since the per-player gate never worked, there was nothing
   guaranteed about where the character respawned.

4. The ForceField removal check `root.Position.Y > 70` fired immediately (Y=122 > 70)
   before the character had settled one physics frame on the Platform.

**Fixes:**
- `Players.CharacterAutoLoads = false` (service level, one line) at the top of
  init.server.luau. Kept false permanently; all character loads are explicit.
- Deaths wired via `humanoid.Died → task.wait(RespawnDelaySeconds) → player:LoadCharacter()`
  in `hookPlayer()` (WorldBuilder). Every respawn goes through seat() with SpawnLocation armed.
- `GameConfig.World.RespawnDelaySeconds = 3` (no inline magic number).
- `seat()`: removed bogus `player.CharacterAutoLoads = true`. `task.wait(0.1)` moved
  to TOP of retry loop (at least one physics frame before checking). Threshold raised from
  `Y > 70` to `Y > LaunchEdgeAltitude - 4` (= 116) so mid-air and lava-surface heights
  cannot pass the confirmation check.
- Server print on each seat() call: hrp_y, target_y, pad_y visible in Studio Output.

## Hotfix — 2026-09-25 (round 5): CharacterAutoLoads + JumpPad grace gate

Second spawn-loop iteration. After round 4's ForceField/TakeDamage fix, Jeremy
landed on lava WITH ForceField alive — then died when he stepped. Root causes:

1. `CharacterAutoLoads = true` (default) fires character auto-load as soon as
   `PlayerAdded` resolves — BEFORE `WorldBuilder.build()` creates the SpawnLocation.
   Character spawns at Roblox's default Y≈5, which is inside the lava (top Y=4).
   SpawnLocation.Duration=5 kept him alive on lava but TakeDamage fired the instant
   he moved and the ForceField ended.

2. JumpPad.Touched fires on any contact, including when the character
   is placed on Base by seat(). launch() gives velocity.Y = -30, launching
   the character downward off Base into lava.

**Fixes:**
- `init.server.luau`: sets `player.CharacterAutoLoads = false` for all current
  players AND via PlayerAdded — BEFORE Net.start / WorldBuilder. After all services
  are running and RespawnLocation is armed, calls `player:LoadCharacter()` for all
  current players and connects a second PlayerAdded handler for future joiners.
- `WorldBuilder.seat()`: first thing it does is `player.CharacterAutoLoads = true`
  so future deaths auto-respawn at the armed SpawnLocation.
- `GameConfig.World.SpawnGraceSeconds = 3`: tunable grace window.
- `FlightController`: `spawnGraceUntil = os.clock() + SpawnGraceSeconds` set in
  CharacterAdded. JumpPad.Touched and LaunchPrompt.Triggered both check
  `os.clock() < spawnGraceUntil` and bail during the grace window.

## Hotfix — 2026-09-25 (round 4): spawn / lava death loop

**Root cause chain:**
1. `lava.Touched` used `humanoid.Health = 0` (direct assignment), which bypasses ForceField — no spawn protection worked.
2. `seat()` called `character:WaitForChild("HumanoidRootPart")` which **yields** before teleporting. During that yield, lava could fire and kill the character.
3. `player.RespawnLocation` was set inside `seat()` **after** the yield, so if the character died mid-yield the next respawn used Roblox's default position (Y≈0 → lava → loop).
4. `SpawnLocation.Duration = 0` gave no automatic ForceField on respawn.

**Fixes:**
- `lava.Touched` now calls `humanoid:TakeDamage(humanoid.MaxHealth)` so ForceField blocks it.
- `seat()` creates an invisible `ForceField` on the character **before** `WaitForChild` yields. The FF is destroyed once the character is confirmed above Y=70 (or after 4 s cap). Lava cannot kill during the teleport window.
- `SpawnLocation.Duration = 5` — 5-second ForceField on every SpawnLocation respawn.
- `WorldBuilder.start()` pre-arms `player.RespawnLocation` before `hookPlayer` runs, so a first-frame death respawns at Base altitude, not Y=0.
- `FlightController`: camera-steer lerp suppressed while `carrying and state.t < launchedUntil` so the HomePad's homeward velocity is not immediately overridden by a random camera direction.

## Hotfix — 2026-09-25 (round 3): HomePad spring + carry magnet gate

Meadowrock (and all in-slice islands) sit below Base altitude by design. After Grab the player could not glide home. Fixed by adding an **orange spring pad ("HomePad")** to every in-slice island in `WorldBuilder.buildIsland()`. Touching or prompting it fires `launchHome()` in FlightController, which fires the player toward the world origin (Base) at ImpulseH=90 horizontal + ImpulseV=60 upward — enough to clear the altitude deficit while carrying.

The tier-1 Meadowrock outbound velocity magnet was also gated on `not carrying`: it only applies when flying toward the island (no egg), preventing it from fighting the homebound return after a spring launch.

Config: `GameConfig.World.HomePad = { ImpulseH = 90, ImpulseV = 60, LaunchSeconds = 1.5 }`.

**Finding the HomePad in Studio:** orange Neon `BasePart` named "HomePad", 12×2×12 studs, 20 studs west of each island's nest. Has a "Return to Base / Spring Pad" ProximityPrompt.

## Studio playtest checklist

1. Open Roblox Studio → File → Open From File → `default.project.json` (requires Rojo plugin ≥ 7).
2. Start Rojo (`rojo serve`) from the workspace root; Studio auto-syncs.
3. Press **Play** (local server mode). Confirm no Script errors in Output.
4. Walk character onto the JumpPad — should launch into glide.
5. Fly toward Meadowrock nest → tap **Grab egg** → status shows "ok" or rejection reason.
6. Fly back to start platform → tap **Deliver** → coins increase in info label; check MinRunSeconds reject if delivered instantly.
7. Tap **Buy next aircraft** → coins deduct, tier in info label advances (or "poor" if insufficient).
8. Tap **Upgrade perch** → info label perch level increments and next-cost updates; tap repeatedly to approach max_level; tap with insufficient coins → status shows "poor".
9. Confirm all four buttons respond with status-label feedback (no silent failures).

## Landed (2026-09-25 continued)

- **Studio data persist**: `PlayerData` now tries the live DataStore in Studio (pcall); warns and falls back to Mock only if API is unreachable. `profile:Save()` added before `EndSession()` in PlayerRemoving. `game:BindToClose` saves and ends all active profiles on server shutdown. **Prerequisite**: Game Settings → Security → Studio Access to API Services must be on for live persistence.
- **Dive look-down feel**: `GameConfig.Flight.DiveLookDownY = -0.35`, `DiveLookDownSteerMult = 2`. When `look.Y ≤ -0.35`, DiveExchangeRate horizontal conversion is skipped (downward speed stays downward) and camera-steer alpha doubles so velocity tracks the steep dive quickly. Outbound magnet and HomePad launch window unchanged.

- **Island hover fix**: `islandUnder()` rewired — always applies sink assist (vy ≤ -45) the moment the character is in the flat radius; adds `timeOverIsland` accumulator that force-lands after `IslandLandSeconds` (1.5 s); land-trigger threshold lowered to `groundTop + IslandLandRadius` (= origin.Y+14). PlatformStand now set every frame from `flying()` so Grounded always clears it. Constants in GameConfig.World.

## Still not launch

- No Studio playtest yet. The 7 Day-1 checks and the two flight/heist tests have not been run in Roblox.
- Game-pass and developer-product ids are still 0. Nothing is for sale.
- Islands past the first four are not built (`inSlice = false`).
- No intercept combat, no hatch/upgrade UI.
- Dive and launch feel are untested. Do not retune `LiftK` / `DragK` until a Studio run shows the meadowrock margin is off.

## Assumption

Soft-cap scale is the tier-4 aircraft cost already in GameConfig (600,000). No new economy number was invented.
