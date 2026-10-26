# Documentation

Start with [installation and core controls](../README.md).

## User guides

| Guide | Contents |
| --- | --- |
| [Software controls](HOW-TO-PLAY.md) | Cartridge instructions, overlays and key mappings. |
| [Cartridges](CARTRIDGES.md) | ROM assembly and supported memory layouts. |
| [Joysticks](JOYSTICK.md) | Calibration, pairing and timing options. |
| [Keyboard files](KEYBOARD-INPUT.md) | Text, physical key scripts and Music Teacher playback. |
| [APL/S source entry](APL-SOURCE.md) | Loading listings and launching programs. |
| [Tape images](TAPE.md) | Mounting, recording and image format. |
| [Expander 1](EXPANDER1.md) | Firmware, Timeshare UART and printer routing. |
| [Printer images](PRINTER.md) | Capture, export, storage errors and validation limits. |
| [Information Manager manual](INFOMAN-MANUAL.md) | Database creation, review and editing. |
| [Examples](../examples/README.md) | Keyboard files, music and saved tapes. |
| [Tools](../tools/README.md) | Desktop conversion and image utilities. |

## Implementation and evidence

Reports describe the revisions and evidence identified within each document.
See [accuracy and remaining work](ACCURACY.md) for the current pre-1.0 status, hardware measurement priorities and optional future work, and the
[simulation harness](../verilator/README.md) for regression commands.

| Area | Reports |
| --- | --- |
| CPU and bus | [Clock gating](CPU-CLOCK-GATE.md), [reset](CPU-RESET-AUDIT.md), [timing sources](TIMING-SOURCES.md), [logic captures](LOGIC-CAPTURE-ANALYSIS.md). |
| CPU references | [F8 reference card](F8-REFERENCE-CARD-AUDIT.md), [Mostek 1979](MOSTEK-1979-AUDIT.md), [Mostek 1981](MOSTEK-1981-AUDIT.md), [VESWiki opcodes](VESWIKI-OPCODE-AUDIT.md). |
| Video and audio | [UV201 access phase](UV201-PHASE-AUDIT.md), [audio diagnostics](AUDIO-DIAGNOSTIC.md). |
| Software | [APL/S dump comparison](APL-DUMP-AUDIT.md), [Information Manager analysis](INFOMAN.md), [experimental Music Teacher patch](MUSIC-TEACHER-PATCH.md). |

## Release notes

- [Unreleased source changes](VideoBrain_UNRELEASED.md)
- [October 20, 2026](VideoBrain_20261020.md)
- [October 11, 2026](VideoBrain_20261011.md)
- [October 7, 2026](VideoBrain_20261007.md)
- [Release binaries](../releases)
