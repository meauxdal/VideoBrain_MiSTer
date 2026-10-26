# VideoBrain 20261020

## Changes since 20261011

- APL/S execution and keyboard source entry, plus VBK2 input for other software and Music Teacher playback.
- Expander 1 digital tape SAVE/LOAD through separate playback and record images, with rewind controls and activity/error notifications.
- Information Manager tape entry, REVIEW and EDIT support, including independent source/output tape handling.
- Timeshare communication through MiSTer's HPS UART and a Linux network bridge. Interactive Telehack sessions were verified at 300 baud.
- Cartridge-selected linear joystick presets, joystick disconnect and automatic calibration.
- Optional 240p output alongside native interlacing.
- CPU clock-stop/restart, bus timing and audio filtering refinements.
- Manual BIOS/Expander firmware loading, optional notifications, software controls and keyboard/music examples.

These changes summarize the source history through the release publication commit. Original-machine timing and analog audio remained unverified; Expander 2 acoustic modem behavior was unsupported.

## Setup

Install [VideoBrain_20261020.rbf](../releases/VideoBrain_20261020.rbf) in the MiSTer Computers folder. Keep `boot0.rom` and add `boot1.rom` for Expander 1 operation. Tape images use the VBT format; mount separate files for source and output when editing databases.

Some OSD labels differ from current sources: keyboard-file controls were under **Input**. Printer capture images and the Information Manager printer correction were added after this release.

## Artifact

- File: `VideoBrain_20261020.rbf`
- Published: October 21, 2026
- Publication commit: `2a78622aac9ea9429632fdb0fa6938676b1e06e7`
- Size: 2,931,980 bytes
- SHA-256: `509006ce1b73251170104699366b95262db8b6d784eae8c3fc8101138ae60ef0`

The publication commit identifies the tracked binary; its exact build-source revision was not recorded.
