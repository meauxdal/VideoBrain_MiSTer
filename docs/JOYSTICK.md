# Joystick timing

## Use

Joysticks default to Connected. **Joysticks > Stick Preset > Auto** selects linear timing by cartridge CRC-32 and size. Tennis and Gladiator can be selected manually; Gladiator is also Auto's fallback for other cartridges. The release core uses linear timing throughout. At first-game start, use Joysticks > Calibrate Sticks to virtually supply exact full Up, Down, Left, Right, then center to all four emulated joysticks, including paired sticks. Each position lasts 30 video frames. Use it while the software is actively reading those channels; repeat after a reset or new game when required by the software. Joystick must be Connected. Reset or disconnect cancels the sequence; live axes resume afterward when connected. Fire buttons remain live during calibration. Automatic trim does not replace software calibration.

Analog inputs have a -8..8 center deadband. Digital directions override analog: up/left select pot 0, down/right select 255. The channel order is V1,H1,V2,H2,V3,H3,V4,H4. The wrapper supports four controllers.

## Paired controllers

Paired Sticks defaults to Off, preserving four independent controllers. Each left stick/D-pad and Fire still control its own joystick. The right stick and Fire 2 control the paired joystick selected by the mode:

- 1+2 / 3+4: 1 <-> 2 and 3 <-> 4.
- Doubles: 1 <-> 3 and 2 <-> 4.

Map Fire and Fire 2 separately in MiSTer's button definitions (defaults A/B). MiSTer's upstream interface provides both analog sticks and button reports.

If either own axis is outside the center deadband, the own stick controls both axes; otherwise the paired right stick takes over. Digital directions retain priority over the own analog axis. Own Fire and paired Fire 2 are ORed, independently of movement. Joystick=Disconnected releases fire and opens all pot charging paths, preventing timer expiry while preserving EJOY/reset behavior.

The Pinball manual (printed p. 5) assigns joystick 1's button to the left flipper and joystick 2's to the right. Controller 1's Fire/Fire 2 can therefore operate both flippers. Tennis's manual (printed p. 4) confirms four joysticks: 1/2 are left/right backcourt, 3/4 left/right forecourt. Doubles teams use 1+3 and 2+4. Select Doubles to control teammates, or 1+2 / 3+4 for opposite sides. There is no automatic game-specific routing.

## Per-game adjustment

The VideoBrain Transfers board photograph (Set 1, Image 33) labels added X/Y trim pots for preventing motion with centered sticks. Its note says each game requires trim readjustment for correct centering, so the pots must remain accessible. This documents a hardware adjustment practice; it does not establish factory-installed trims or their resistance settings.

The FPGA can select a linear range and offset for each recognized cartridge, providing that adjustment automatically. For pot p in 0..255, the delay in 14.318181 MHz MCLK ticks is base + step*p. The timer adds one expiry tick.

| Cartridge | Base | Step | Status |
| --- | --- | --- | --- |
| Tennis, CRC 1942F852, 4096 bytes | 2644 | 24 | Positive hardware gameplay feedback; measured full-court verification pending. |
| Other cartridges, including unknown images | 2580 | 7 | Positive hardware gameplay feedback; Gladiator aiming acceptance pending. |

Auto's detected preset persists through machine reset and is cleared when a new cartridge starts loading or is unloaded. Manual preset selection stays in the OSD. System > Mapper Fallback does not select joystick presets. Physical pot resistance and UV201 counter phase remain unmeasured.

The timer follows EJOY/HBLANK reset and release. Falling joystick interrupt edges latch X/Y together; a registered strobe delivers the pair to the UV201 freeze registers when FRZ is set.

## Verification

Run the input-routing, preset-selection and calibration regressions from WSL in `verilator/`:

```sh
make test-joystick test-cartridges
```

The checks cover routing, presets, calibration duration, reset/disconnect cancellation and live input restoration. On MiSTer, verify Tennis court travel, Gladiator horizontal aim, both Pinball flippers and four-controller routing. Detailed timing measurements and diagnostic simulator options are in [measurement notes](../verilator/joystick_verification.md).
