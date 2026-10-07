# Joystick timing

## Release result

On October 7, 2026, the user confirmed that the joystick fixes work on
MiSTer and that Stick timing=Curve is the fix. The release uses the tested
VideoBrain_26_20261007.rbf, from source revision
c24e29a5ed053d04da9a91f4cea300535a918994.

The final report does not enumerate games, controller models or controller
count. The measurements below are retained simulator evidence.

## Use

Set Joystick=On and Stick timing=Curve in the OSD. Curve is the default.
For Gladiator, push fully forward, then move through a full circle at the
start of the first game. Reach the extremes on each controller in use.
Judge neutral after calibration; startup drift alone is inconclusive.
Repeat calibration after a reset or a new game where required by the software.

Analog inputs have a -8..8 center deadband. Digital directions override
analog: up/left select pot 0, down/right select 255. The channel order is
V1,H1,V2,H2,V3,H3,V4,H4. The wrapper supports four controllers.

## Why the linear settings conflicted

The emulated 555 pulse expires and freezes UV201 X/Y. The BIOS and Tennis
both normally measure lines*228 + frozenX - 38, but scale the result
differently. The BIOS expands per-axis bounds and chooses a gain from the
span. Tennis starts with bounds 640..1792 and uses fixed absolute scaling:
70 + 3*(delta >> 5), capped at 214 in the normal path.

| Linear timer, MCLK ticks | Observed result |
| --- | --- |
| 2580 + 18*pot | Wider Tennis travel, 70..175 with neutral 124; calibrated Gladiator neutral saturates at 199 and drifts. |
| 2580 + 6*pot | Gladiator neutral is stationary after calibration, but analog down-right fails in the hardware report; Tennis travel is 70..103. |
| 2580 + 7*pot | Hardware Gladiator neutral and all eight analog/D-pad directions pass after calibration; Tennis travel remains compressed, 70..109 in simulation and upper-arena-only on hardware. |

The step 18 Gladiator trace selects gain 8, multiplies neutral delta 576 to
4608, and clamps to 199. This is expected BIOS arithmetic. An isolated
diagnostic passes all 19 threshold, carry, product and clamp cases.
The step 7 Tennis trace measures pot 0 raw 640 with zero delta and returns 70;
timer expiry and paired capture agree. These checks did not show a CPU
arithmetic or capture error explaining the shared scaling conflict.

The offline affine search found no stationary Gladiator vertical neutral
among 60,544 pairs giving Tennis neutral 124..154 under its assumptions.
It omits phase changes, rejected measurements and byte wrap; it is a model
result, not a proof over all possible RTL behavior.

## Final mapping

One mapping serves all games; there is no cartridge-specific timing switch.
For pot p in 0..255, the programmed delay in 14.318181 MHz MCLK ticks is:

```text
p <= 128: 1620 + 23*p
p >  128: 4564 + 53*(p - 128)
```

Pots 0/128/255 give 1620/4564/11295 ticks. The mapping is continuous at 128.
The timer adds one expiry tick to the observed pulse. Lowering the minimum
and extending the upper span lets BIOS select gain 2 while keeping Tennis
neutral near its initialized 138. Linear retains 2580 + 7*p in the OSD.

The timer follows EJOY/HBLANK reset and release. Falling joystick interrupt
edges latch X and Y together; a registered strobe delivers that pair to the
UV201 freeze registers when FRZ is set. Preserve this with the curve.
The fractional CPU clock produces 2 MHz on average and is also retained.
No CPU arithmetic change was needed for the final mapping.

## Retained verification

| Curve run | Result after forward/full-circle calibration |
| --- | --- |
| Gladiator, 461 frames | All four sampled axes reach bounds 2819/400, span 2419, gain 2. Neutral delta 736 produces 1472 and returns 92. Pots 112/128/144 return 80/92/118. |
| Tennis, 551 frames | Both vertical channels span 70..214; neutral 139. Pots 112/128/144 return 130/139/157. Lower bounds expand to 400; high inputs reach the rejection cap. |

Every planned state sample is present. Settled holds have 24 fixed position
samples each. Gladiator returns 92 on all four axes at the first and final
neutral holds; Tennis returns 139 on both vertical channels. Gladiator's
P1 vertical position is near a boundary, which limits that simulation's
neutral evidence. Simulator pots bypass MiSTer analog reports and deadband.

Completed runs are local, ignored artifacts under
verilator/out/joystick/gladiator_shared_curve and tennis_shared_curve.
The isolated arithmetic evidence is under gain_check. Preserve the raw runs.
To reproduce from WSL in verilator/:

```sh
python3 joystick_gain_check.py --run
python3 joystick_calibration_check.py gladiator --curve --focus 342 --out out/joystick/gladiator_shared_curve_repeat
python3 joystick_calibration_check.py tennis --curve --focus 432 --out out/joystick/tennis_shared_curve_repeat
```

The calibration commands rebuild headless and write plans, traces, state,
screenshots and summary.json. Use new output directories to keep originals.
GHDL synthesis, Verilator lint and C++ syntax checks were completed during
development; the final hardware success report closes the Curve trial.

The curve is a validated gameplay mapping, not a measured physical pot
resistance curve. Original UV201 counter phase and mechanical pot limits
remain unmeasured. See [investigation notes](../verilator/joystick_verification.md)
for trace details, source references and earlier settings.
