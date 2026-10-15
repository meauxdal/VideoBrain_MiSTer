# Joystick timing

## Use

Set Joystick=On and Stick Timing=Linear in the OSD. Linear is the default;
cartridge CRC-32 and size select its preset. Check the setting when loading
an older saved configuration: the Linear and Curve option order has changed.
For Gladiator, push fully forward, then make a full-extreme circle on each
controller at first-game start. Repeat after a reset or a new game where
required by the software. Automatic trim does not replace software calibration.

Analog inputs have a -8..8 center deadband. Digital directions override
analog: up/left select pot 0, down/right select 255. The channel order is
V1,H1,V2,H2,V3,H3,V4,H4. The wrapper supports four controllers.

## Per-game adjustment

[VideoBrain Transfers, Set 1, Image (33)](../refs/VideoBrain%20Transfers/Set%201/Image%20%2833%29.jpg)
labels added X/Y trim pots for preventing motion with centered sticks. Its
note says each game requires trim readjustment for correct centering, so the
pots must remain accessible. This documents a hardware adjustment practice;
it does not establish factory-installed trims or their resistance settings.

The FPGA can select a linear range and offset for each recognized cartridge,
providing that adjustment automatically. For pot p in 0..255, the delay in
14.318181 MHz MCLK ticks is base + step*p. The timer adds one expiry tick.

| Cartridge | Base | Step | Status |
| --- | --- | --- | --- |
| Tennis, CRC 1942F852, 4096 bytes | 2644 | 24 | Initial preset; full-court gameplay verification pending. |
| Other cartridges, including unknown images | 2580 | 7 | Gladiator movement tested on MiSTer; aiming refinement pending. |

Tennis uses fixed absolute scaling; the BIOS selects gain from measured axis
bounds. Tennis's wider linear range and +64-tick offset predict positions
70..214 and neutral 142, the court's midpoint, in the retained scaling model.
Full vertical court travel is required for playability. These are predictions,
not simulator or hardware results; its initialized position is 138.
Checkers and Vice Versa use the BIOS path, but their current linear gameplay
coverage remains pending.

Presets persist through machine reset and are cleared when a new cartridge
starts loading. Mapper fallback settings do not select joystick presets.
Physical pot resistance and UV201 counter phase remain unmeasured.

## Curve

Curve remains available as a shared gameplay mapping:

```text
p <= 128: 1620 + 23*p
p >  128: 4564 + 53*(p - 128)
```

Pots 0/128/255 give 1620/4564/11295 ticks, plus one expiry tick.
Curve was chosen to reconcile BIOS gain selection with Tennis travel while
using one mapping for every cartridge. It lets the BIOS select gain 2 while
keeping Tennis neutral near its initialized position. The Transfers note
removes the need to impose a shared center on the linear presets.

The timer follows EJOY/HBLANK reset and release. Falling joystick interrupt
edges latch X/Y together; a registered strobe delivers the pair to the UV201
freeze registers when FRZ is set.

## Verification

Curve was tested on MiSTer on October 7, 2026. See the
[release notes](VideoBrain_20261007.md) for the artifact hash.

| Simulator run | Result after forward/full-circle calibration |
| --- | --- |
| Gladiator, 461 frames, Curve | All four axes reach bounds 2819/400, span 2419, gain 2. Neutral returns 92; pots 112/128/144 return 80/92/118. |
| Tennis, 551 frames, Curve | Both vertical channels span 70..214; neutral 139. Pots 112/128/144 return 130/139/157. |

Settled holds have 24 fixed position samples each. First and final neutral
holds agree. Gladiator P1 is near a vertical boundary, limiting that axis's
stability evidence. Simulator pots bypass MiSTer analog reports and deadband.

Hardware feedback reports that Gladiator needs slight upward analog input
for a horizontal shot with both Linear and Curve. In game mode 1, pure left
and right should hold the bow vertically and fire horizontally. This is a
separate acceptance check from stationary neutral; no aiming fix is yet verified.

Run the short preset-selection regression from WSL in verilator/:

```sh
make test-cartridges
```

The following longer checks rebuild headless and write new evidence:

```sh
python3 joystick_calibration_check.py gladiator --auto --aim --out out/joystick/gladiator_linear_aim
python3 joystick_calibration_check.py tennis --auto --out out/joystick/tennis_linear_preset
python3 joystick_calibration_check.py checkers --auto --out out/joystick/checkers_linear_preset
```

Verify Tennis reaches both vertical court limits on both controllers.
Inspect Gladiator's aim_left and aim_right captures for bow position and shot
direction. Use --curve instead of --auto to compare Curve. The headless
simulator defaults to cartridge presets; explicit --joy-timer-base or
--joy-timer-step options select manual linear timing.
See [measurement notes](../verilator/joystick_verification.md) for arithmetic,
timing constraints and earlier linear results.
