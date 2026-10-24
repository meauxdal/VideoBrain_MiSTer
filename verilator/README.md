# Verilator harness

Verilator reads Verilog only, so every build first runs the VHDL through `ghdl synth --out=verilog`. Module, instance and RAM names survive that step; intermediate combinational nodes become `nNNNN`.

    make            # graphical sim (SDL2 + ImGui)  -> ./obj_dir/Vtop
    make headless   # batch sim (no SDL)            -> ./obj_dir_headless/Vtop
    make netlist    # just the Verilog netlist      -> gen/videobrain.v
    make lint

Requires ghdl (VHDL-2008), verilator, zlib, and sdl2 for the graphical target. Run from this directory; the default ROM paths are relative to it.

`make test-cpu-branches` runs ROM-free GHDL checks for BR7 across all 64 ISAR values and every BT/BF mask across all 32 status-register values, including directly loaded zero/sign combinations. The 4,160 cases use signed displacement boundaries, check branch destinations and operand/fetch cycle lengths, and verify that ISAR or status flags remain unchanged.

`make test-cpu-ports` runs 1,280 cases through the full core using generated F8 programs. It checks every output value on both CPU ports, including port 1 readback with joystick fire and selected/unselected keyboard columns.

`make test-smi` checks external-interrupt rearming and the F3853 timer. Timer tests use all 255 seeds from the Mostek 1978 data book's Table 2 (printed p.170), checking initial delays and 255-count repeats with dividers 31 and 1. They also cover paused clock enables, masked expiries, acknowledge isolation, reload priority and `$FF` stopping. These are checks in timer input-clock periods.

`make test-smi-clock` runs a ROM through the full core and checks repeated timer IRQs at the DAC against 255 * 31 nominal 2 MHz PHI periods. Board records connect U16.2 to U17.1 (CPU PHI), and saved traces show this clock stopping during waits. The core derives one timer enable per two accepted CPU half-period enables. This regression checks the integrated rate without buffered-bus contention; it does not establish exact PHI edge phase or measured original-machine timer intervals.

    ./obj_dir/Vtop --run
    ./obj_dir_headless/Vtop --cart /path/to/cartridge.bin --frames 300 --shot-last
    ./obj_dir_headless/Vtop --help

Known cartridge ROMs are identified by CRC-32. `--cart-type` selects the slot profile only for unrecognized images.

`--expander1 <file>` loads the separate 2K Expander 1 firmware. See [Expander 1](../docs/EXPANDER1.md) for firmware and peripheral details. `make test-expander1` tests its ROM loading, host wiring, 3870 timer and interrupt execution. `make test-expander1-record` exercises original-ROM recording, decodes its digital capture and checks good/bad checksum status. It requires the firmware.

`make replay-apl-tape` boots APL/S and LOADs `refs/tape-observations/apls-test.vbt`, with a final screenshot and host signal trace in `out/expander1/apl-load`. Override `APL_TAPE` for another image. This is a long run. The headless `--playback FILE` option replays the VBT1 waveform directly at the Expander input, bypassing SD service; remote stops pause playback without rewinding. `--expander-trace FILE` logs host signals, interrupt acknowledgements and VideoBrain receive-register writes, including counters and interrupt sources.

## Keyboard input

User converters live in [tools](../tools/README.md#keyboard-files). `--source FILE@FRAME` accepts VBK1 and VBK2, including built-in Text without a cartridge. `make test-apl-source` runs the Python converter tests and RTL loader checks. `make test-music-input` checks the Music Teacher readiness hooks. `apl_next_sweep.py` generates timed probes for input diagnostics; see [NEXT timing sweeps](tests/APL-NEXT-SWEEP.md).

`make replay-clock-source` uses the bundled Price Clock keyboard file. `make capture-apl-save` and `make replay-apl-tape` generate keyboard files with `../tools/apl_source.py`.

### Keyboard file formats

VBK1 has an eight-byte header: magic `VBK1`, a little-endian 16-bit token count, and CRC-16/CCITT (polynomial 1021, initial FFFF) of the payload. Each byte contains a matrix key in bits 5:0 and desired symbol mode in bit 6. Bit 7 marks mode-independent SPACE (93 hex) or NEXT (9B hex). Raw SHIFT tokens are rejected. VBK1 is gated to the CRC-recognized Computational Language ROM.

The APL/S handshake observes bank D opcode fetches: $3C14 follows the all-keys-up loop at $3C0A; $3C20 follows acceptance at $3C14-$3C1E. Cursor drawing at $3C04 is not readiness.

VBK2 retains the eight-byte VBK1 header, with magic `VBK2`. Count is payload bytes, not event count; CRC is unchanged. Each three-byte event is matrix key 0..35 (or FF for WAIT), held fields 1..255, released fields 0..255. Limit: 4095 bytes / 1365 complete events. Raw SHIFT and function keys are valid in VBK2. APL-only VBK1 remains gated to the recognized Computational Language ROM.

VBK2 also accepts FE for the music Record/No-Record selector (inside shifted mode), and FD for Replay (inside lower mode). The menu setting is latched at download: Record maps FE to Z and FD to T; Playback maps FE to COMMA and FD to a silent wait with the encoded duration. Older cores reject these events. FA/FB/FC select Low/Middle/High with ROM acknowledgment. Their hold/gap bytes are placeholders (the converter emits 1/0); handshake state determines timing. These controls require lower SHIFT, as do physical octave keys. Keyboard > Music Repeat applies to both VBK1 and VBK2 and can be disabled during entry.

## Joystick diagnostics

Joystick pulse timing is runtime-configurable without rebuilding. Headless defaults to Linear, `--joy-timer-base 2580 --joy-timer-step 7`; MiSTer uses cartridge-selected linear presets. `--joy-timer-curve` retains the older shared curve for diagnostics. Values are MCLK ticks. With `--joy-trace`, `[joy-measure]` reports the selected axis, pot value, timer parameters, and measured pulse length. `bash joystick_sweep.sh [base:step ...]` cycles candidates independently on all eight axes in one Gladiator run, with neutral and each direction held in turn. The combined log is `out/joystick/sweep/gladiator_sweep.txt`.

## selftest.rom

A hand-assembled F8 program that sets up one 16x16 object and halts, so the CPU, bus, UV201 registers, fetcher, FIFO and renderer can be exercised without the BIOS. The 2K ROM is tracked; no regeneration script is provided.

    ./obj_dir_headless/Vtop --res1 selftest.rom --frames 8 --shot-last --ascii

`make test-render` checks UV201 background/object modifiers, zoom and blanking. `python3 tests/pinball_background.py out/pinball` checks matching before/after state dumps and collision captures from the Pinball regression run.

## Converting VHDL to Verilog one file at a time

The netlist is the reference. Write `rtl_v/<entity>.v`, add the entity name to `CONVERTED` in the Makefile, and rebuild: that module is stripped from the netlist and yours is compiled in its place. The VHDL stays in `VHD_SRC` so the rest of the hierarchy still elaborates.

Check equivalence by frame hash, before and after:

    ./obj_dir_headless/Vtop --res1 selftest.rom --frames 8 --frame-log
    ./obj_dir_headless/Vtop --frames 60 --frame-log

`CONVERTED` is currently empty. The F8 CPU and packages derive from the Channel F core; preserve attribution when changing them.

## Development utilities

Run these from `verilator/`. ROM-based captures need local BIOS and cartridge files under `software/0 BIOS` and `software/1 Cartridges`; ROMs are not bundled.

| Utilities | Purpose |
| --- | --- |
| `joystick_*_check.sh`, `joystick_calibration_check.py`, `joystick_gain_check.py` | Capture routing, calibration and BIOS scaling behavior. |
| `joystick_trace.sh`, `joystick_stability.sh`, `joystick_sweep.sh` | Capture joystick timing, stability and parameter sweeps. |
| `joystick_*_summary.py`, `joystick_scaling_model.py` | Summarize captures and model scaling. |
| `audio_*_capture.sh`, `audio_irq_diagnostic.sh` | Capture Music Teacher audio timing and interrupt behavior. |
| `music_audio_check.sh`, `music_bank_check.sh` | Check music playback and octave switching. |
| `patch_music_teacher.py` | Generate the experimental static-staff ED01 ROM for audio diagnostics. |
| `tests/*.py`, `tests/tb_*` | Analyze captures and run Python, VHDL, Verilog and C++ regressions. |
| `strip_modules.py` | Replace selected synthesized modules during Verilog conversion. |

`joystick_diag_check.sh` additionally requires `../../VideoBrain-Tests/JoystickDiag.bin`. The static-staff ROM is optional for normal core use. Create it for diagnostics with:

```sh
python3 patch_music_teacher.py /path/to/original-ed01.bin /path/to/static-staff.bin
```

Run all converter checks without building the simulator (Python 3.9 or newer, standard library only):

```sh
python3 -B tests/run_tools.py
```

The same checks are available as `make test-tools`, and are included in `make test-apl-source`. From the repository root, use `python3 -B verilator/tests/run_tools.py`. Use `python` if that is how Python is installed on your system. Optional tape-reference checks use local recordings under `refs/`; unavailable fixtures are skipped.
