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

## Still not launch

- No Studio playtest yet. The 7 Day-1 checks and the two flight/heist tests have not been run in Roblox.
- Game-pass and developer-product ids are still 0. Nothing is for sale.
- Islands past the first four are not built (`inSlice = false`).
- No intercept combat, no hatch/upgrade UI.
- Dive and launch feel are untested. Do not retune `LiftK` / `DragK` until a Studio run shows the meadowrock margin is off.

## Assumption

Soft-cap scale is the tier-4 aircraft cost already in GameConfig (600,000). No new economy number was invented.
