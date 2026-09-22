# FlightController Brief

Source: SkyBandit FlightController agent, 2026-09-22.

## Module

`StarterPlayerScripts/Client/FlightController.luau`
Depends on: Types, GameConfig, Net.

## Public API

- `start(): ()`
- `getState(): Types.FlightState`
- `setAircraft(tier: number): ()`
- `setCarrying(carrying: boolean): ()`
- `setLift(lift: number): ()` — from server replica, not computed locally

## Data contract

Owns the local character's flight simulation. Publishes `Types.FlightState` at 10Hz via `Net.send("flight:state", state)`. Reads aircraft tier and lift from the server replica (`Net.on "replica:flight"`); never computes its own range entitlement. The server's FlightService is authoritative on position.

Flight model (constants in GameConfig.Flight):
- liftForce = LIFT_K * speed^2, capped at LIFT_CAP
- dragForce = DRAG_K * speed^2, opposite velocity
- gravity = 60
- diveExchange = DIVE_EXCHANGE_RATE (1.2)
- stallSpeed = STALL_AIRSPEED (40)
- carryPenalty = CARRY_SPEED_PENALTY (0.85) on max speed when carrying

Correction: on server correction packet, lerp position over CORRECTION_LERP_SECONDS (0.2), never snap. During lerp, suppress input that fights the correction.

## Must validate

Nothing — it is the client. But it must ASSUME the server will reject. The 10Hz snapshot is a claim, not truth.

## Failure modes

- Frame spike: clamp dt to MAX_DT (0.05s).
- Server correction: lerp 0.2s, suppress input during lerp.
- Carrying flag changes mid-flight: apply penalty immediately, no ramp.
- Mobile: one Heartbeat connection, no per-frame allocation, 60fps budget on low-end phone.
- Lift changes: update from replica, don't recompute from local pet list.

## Test

From the base launch pad at tier 1 (range 400), zero lift, flying optimally: player reaches meadowrock (400) and NOT thornspire (900). At tier 2 (range 900) reaches thornspire with roughly 10% margin. If margin under 5% or over 20%, retune LIFT_K and DRAG_K before day 5.
