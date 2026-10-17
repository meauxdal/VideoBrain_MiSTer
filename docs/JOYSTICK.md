# Joystick timing

## Use

Set Input > Joystick=Connected and Stick Timing=Linear in the OSD. Linear is the default.
Linear Preset=Auto selects by cartridge CRC-32 and size. Tennis and Gladiator
force the corresponding linear timing; Gladiator is also Auto's fallback for
other cartridges. Curve ignores Linear Preset, which is grayed out in that mode.
Check older saved configurations: releases before the linear presets used the
opposite Linear/Curve option order.
At first-game start, use Input > Calibrate Sticks to send full Up, Down,
Left, Right, then center to all four emulated joysticks, including paired
sticks. Each position lasts 30 video frames. Use it while the game is reading
joysticks; repeat after a reset or new game when required by the software.
Joystick must be Connected. Automatic trim does not replace software calibration.

Analog inputs have a -8..8 center deadband. Digital directions override
analog: up/left select pot 0, down/right select 255. The channel order is
V1,H1,V2,H2,V3,H3,V4,H4. The wrapper supports four controllers.

## Paired controllers

Paired Sticks defaults to Off, preserving four independent controllers.
Each left stick/D-pad and Fire still control its own joystick. The right stick
and Fire 2 control the paired joystick selected by the mode:

- 1+2 / 3+4: 1 <-> 2 and 3 <-> 4.
- Doubles: 1 <-> 3 and 2 <-> 4.

Map Fire and Fire 2 separately in MiSTer's button definitions (defaults A/B).
MiSTer's upstream interface provides both analog sticks and button reports.

If either own axis is outside the center deadband, the own stick controls both
axes; otherwise the paired right stick takes over. Digital directions retain
priority over the own analog axis. Own Fire and paired Fire 2 are ORed,
independently of movement. Joystick=Disconnected releases fire and opens all
pot charging paths, preventing timer expiry while preserving EJOY/reset behavior.

The Pinball manual (printed p. 5) assigns joystick 1's button to the left
flipper and joystick 2's to the right. Controller 1's Fire/Fire 2 can therefore
operate both flippers. Tennis's manual (printed p. 4) confirms four joysticks:
1/2 are left/right backcourt, 3/4 left/right forecourt. Doubles teams use 1+3
and 2+4. Select Doubles to control teammates, or 1+2 / 3+4 for opposite sides.
There is no automatic game-specific routing.

OSD regrouping retains existing status bits and option order. New fields are
status[15:14] (Auto=0, Tennis=1, Gladiator=2; reserved 3 uses Auto) and
status[17:16] (Off=0, 1+2 / 3+4=1, Doubles=2; reserved 3 uses Off).
The earlier paired On setting retains its 1+2 / 3+4 routing. Older saved
settings leave these unused bits at zero.

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
| Tennis, CRC 1942F852, 4096 bytes | 2644 | 24 | Positive hardware gameplay feedback; measured full-court verification pending. |
| Other cartridges, including unknown images | 2580 | 7 | Positive hardware gameplay feedback; Gladiator aiming acceptance pending. |

Tennis uses fixed absolute scaling; the BIOS selects gain from measured axis
bounds. Tennis's wider linear range and +64-tick offset predict positions
70..214 and neutral 142, the court's midpoint, in the retained scaling model.
Full vertical court travel is required for playability. These are predictions,
not simulator or hardware results; its initialized position is 138.
Checkers and Vice Versa use the BIOS path, but their current linear gameplay
coverage remains pending.

Auto's detected preset persists through machine reset and is cleared when a
new cartridge starts loading. Manual preset selection stays in the OSD.
Mapper fallback settings do not select joystick presets.
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

Recent hardware feedback reports that the linear presets feel correct across
games. This is encouraging gameplay evidence, not exhaustive verification.
Earlier feedback reported slight upward input was needed for a horizontal
Gladiator shot with both Linear and Curve. In game mode 1, pure left/right
should hold the bow vertically in hand and fire horizontally. This specific
check remains unverified; no aiming-specific fix has been established.

Run the short input-routing and preset-selection regressions from WSL in verilator/:

```sh
make test-joystick test-cartridges
```

The following longer checks rebuild headless and write new evidence:

```sh
python3 joystick_calibration_check.py gladiator --auto --aim --out out/joystick/gladiator_linear_aim
python3 joystick_calibration_check.py tennis --auto --out out/joystick/tennis_linear_preset
python3 joystick_calibration_check.py checkers --auto --out out/joystick/checkers_linear_preset
```

Verify Tennis reaches both vertical court limits on both controllers.
On MiSTer, check right-stick reports, Fire 2 mapping, simultaneous input priority,
both Pinball flippers, and all four ordinary controllers with pairing Off.
Inspect Gladiator's aim_left and aim_right captures for bow position and shot
direction. Use --curve instead of --auto to compare Curve. The headless
simulator defaults to cartridge presets; explicit --joy-timer-base or
--joy-timer-step options select manual linear timing.
See [measurement notes](../verilator/joystick_verification.md) for arithmetic,
timing constraints and earlier linear results.
