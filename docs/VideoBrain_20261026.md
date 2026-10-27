# VideoBrain 20261026

Changes since [20261020](VideoBrain_20261020.md), included in the [October 26 release candidate](../releases/VideoBrain_20261026.rbf).

## Core and controls

- F8 branch, interrupt, reset and bus sequencing corrections, supported by expanded instruction and timing regressions.
- F3853 feedback-register timer sequence, interrupt behavior and CPU PHI clock connection.
- CPU reset independent of clock enable, correcting APL/S cartridge reload failures.
- PC keyboard aliases for numbers, keypad, Enter, Backspace and function keys.
- Relative joystick movement with three speed settings for self-centering controllers.
- Optional reset on cartridge loading, reorganized OSD controls and keyboard-entry options.
- Independent printer capture to VBP images, including framing/storage error reporting and desktop export tools, alongside modem communication.
- Optional Information Manager printer ROM correction, with reconstructed operating instructions and command analysis.
- Music Teacher playback refinements, an optional static-staff ROM patch and additional examples.

## Documentation and verification

- Expanded CPU reference audits, logic-capture analysis and focused regressions.
- Updated user guides, tape examples and current accuracy status.
- Pre-review cleanup of disabled diagnostics, research documentation and regression entry points.
- User-supplied simulator/test ROM paths, regression provenance logs and required printer-output checks.

Daily MiSTer use and difficult software/peripheral paths have revealed no further known core bugs. Information Manager testing continues primarily to complete its manual and document prototype software behavior. Remaining accuracy work chiefly requires original-machine measurements, especially UV201, then UV202, audio and joystick timing. See [accuracy and remaining work](ACCURACY.md) for evidence limits and optional future work.

Simulation results do not replace Quartus timing checks or MiSTer hardware acceptance testing.

## Artifact

- File: `VideoBrain_20261026.rbf`
- Published: October 26, 2026
- Publication commit: `079511ab587970900c06f52de6b046b58f5b5ac9`
- Size: 3,052,848 bytes
- SHA-256: `b2312db5294154f9f84a6cd960ee64031505e6be602c4e0ad2577ebf72152195`

The publication commit identifies the tracked binary; its exact build-source revision was not recorded.
