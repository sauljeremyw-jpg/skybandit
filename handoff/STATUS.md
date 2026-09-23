# Status 2026-09-22

Built in this chat. No Claude credits and no SkyBandit bots used.

## Landed

- Day-1 foundation, FlightController, HeistService, static review gate (green)
- Real MadStudio ProfileStore vendored. PlayerData uses `ProfileStore.New` and session lock. Saves persist.
- FlightService rejects claims that outrun `terminalSpeed` or the aircraft range, and sends a position correction.
- Touching JumpPad launches. Glide uses the config lift, drag, and dive exchange. Carrying no longer multiplies speed every frame.
- EconomyService soft-caps grants toward `IncomeSoftCapFactor` (full payout at 0 coins, approaching 0.35 as coins pass the tier-4 aircraft cost). x2 Coins applies before the cap.
- PetService rolls rarity, respects perch cap, and pays `PetBaseIncome` each second through EconomyService.
- Phone-sized Grab, Deliver, and Buy-next-aircraft buttons. Server still rejects a bad grab or a short run.
- Aircraft purchases spend coins and raise range. Perch upgrades exist on the server; the button is not on the HUD yet.

## Still not launch

- No Studio playtest. The 7 Day-1 checks and the two flight/heist tests have not been run in Roblox.
- Game-pass and developer-product ids are still 0. Nothing is for sale.
- Islands past the first four are not built (`inSlice = false`).
- No intercept combat, no hatch/upgrade UI, no aircraft purchase.
- Dive and launch feel are untested. Do not retune `LiftK` / `DragK` until a Studio run shows the meadowrock margin is off.

## Assumption

Soft-cap scale is the tier-4 aircraft cost already in GameConfig (600,000). No new economy number was invented.
