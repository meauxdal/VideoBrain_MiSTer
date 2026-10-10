# Joystick timing

## Use

Set Joystick=On and Stick timing=Curve in the OSD. Curve is the default.
For Gladiator, push fully forward, then make a full-extreme circle on each
controller at first-game start. Judge neutral after calibration. Repeat after
a reset or a new game where required by the software.

Analog inputs have a -8..8 center deadband. Digital directions override
analog: up/left select pot 0, down/right select 255. The channel order is
V1,H1,V2,H2,V3,H3,V4,H4. The wrapper supports four controllers.

## Mapping

For pot p in 0..255, the delay in 14.318181 MHz MCLK ticks is:

```text
p <= 128: 1620 + 23*p
p >  128: 4564 + 53*(p - 128)
```

Pots 0/128/255 give 1620/4564/11295 ticks. The timer adds one expiry tick.
Linear uses 2580 + 7*p. One mapping serves all games.

The BIOS selects gain from measured axis bounds; Tennis uses fixed absolute
scaling. The curve lets BIOS select gain 2 while keeping Tennis neutral near
its initialized 138. It is a gameplay mapping; physical pot resistance and
UV201 counter phase remain unmeasured.

The timer follows EJOY/HBLANK reset and release. Falling joystick interrupt
edges latch X/Y together; a registered strobe delivers the pair to the UV201
freeze registers when FRZ is set. Preserve this capture behavior with the curve.

## Verification

Curve was confirmed working on MiSTer on October 7, 2026. The hardware report
did not enumerate games, controller models or controller count. See the
[release notes](VideoBrain_20261007.md) for the artifact hash.

| Simulator run | Result after forward/full-circle calibration |
| --- | --- |
| Gladiator, 461 frames | All four axes reach bounds 2819/400, span 2419, gain 2. Neutral returns 92; pots 112/128/144 return 80/92/118. |
| Tennis, 551 frames | Both vertical channels span 70..214; neutral 139. Pots 112/128/144 return 130/139/157. |

All planned state samples are present. Settled holds have 24 fixed position
samples each. First and final neutral holds agree. Gladiator P1 is near a
vertical boundary, limiting that axis's stability evidence. Simulator pots
bypass MiSTer analog reports and deadband.

Run from WSL in verilator/, using new output directories to preserve evidence:

```sh
python3 joystick_gain_check.py --run
python3 joystick_calibration_check.py gladiator --curve --focus 342 --out out/joystick/gladiator_shared_curve_repeat
python3 joystick_calibration_check.py tennis --curve --focus 432 --out out/joystick/tennis_shared_curve_repeat
```

Calibration commands rebuild headless and write plans, traces, state,
screenshots and summary.json. Original runs remain ignored under
verilator/out/joystick/. See [measurement notes](../verilator/joystick_verification.md)
for arithmetic, timing constraints and earlier linear results.
