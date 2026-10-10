# VideoBrain 20261007

Joystick control now works with the default Stick timing=Curve setting.

## Changes since 20260921

- Analog axes, D-pad overrides and fire inputs for four controller ports.
- Shared joystick timing curve resolves the Gladiator neutral/Tennis travel
  conflict. Linear timing remains available in the OSD.
- Paired UV201 X/Y freeze capture on falling joystick interrupt edges.
- Fractional CPU clock for 2 MHz average operation.
- Known cartridges select their slot behavior by CRC-32; Fallback applies
  to unrecognized images.
- Interlaced field output, rendering fixes, ESC as MASTER CONTROL, and
  revised audio latching/output. Imperfect audio remains a known issue.

## Setup

Install VideoBrain_20261007.rbf in the MiSTer Computers folder. Keep the
existing boot.rom setup. Set Joystick=On and Stick timing=Curve in the OSD.
In Gladiator, push fully forward and make a full-extreme circle on each
controller at first-game start.

## Artifact

- File: VideoBrain_20261007.rbf
- Recorded source baseline: `c24e29a5ed053d04da9a91f4cea300535a918994`
- Size: 3,090,592 bytes
- SHA-256: `8a750e791493e3117374b50dd719adf87e66d69c2807121feecf7423defe3dac`
