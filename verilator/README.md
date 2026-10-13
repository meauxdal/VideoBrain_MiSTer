# Verilator harness

Verilator reads Verilog only, so every build first runs the VHDL through
`ghdl synth --out=verilog`. Module, instance and RAM names survive that step;
intermediate combinational nodes become `nNNNN`.

    make            # graphical sim (SDL2 + ImGui)  -> ./obj_dir/Vtop
    make headless   # batch sim (no SDL)            -> ./obj_dir_headless/Vtop
    make netlist    # just the Verilog netlist      -> gen/videobrain.v
    make lint

Requires ghdl (VHDL-2008), verilator, zlib, and sdl2 for the graphical target.
Run from this directory; the default ROM paths are relative to it.

    ./obj_dir/Vtop --run
    ./obj_dir_headless/Vtop --cart "../software/Gladiator ....bin" --frames 300 --shot-last
    ./obj_dir_headless/Vtop --help

Known cartridge ROMs are identified by CRC-32. `--cart-type` selects the slot
profile only for unrecognized images.

`--expander1 <file>` loads the separate 2K Expander 1 firmware. This support is
experimental; see [limits and hardware evidence](../docs/EXPANDER1.md).
`make test-expander1` tests its ROM loading, processor and host clock wiring.

## APL/S memory dumps

The `.bin` files in `software/21 games for apl_s` are 16K MAME CPU memory
dumps, not cartridge ROMs. Load the Computational Language cartridge first.
`--apl FILE@F` restores system RAM at 0C00-0FFF and cartridge RAM at
1C00-1FFF at frame F. Load while the interpreter is idle at its input prompt.
ROM, CPU registers, mapper bank and video registers are not restored.

```sh
mkdir -p out/apl
./obj_dir_headless/Vtop \
  --cart "../software/converted/The Computational Language (APL-S).bin" \
  --apl "../software/21 games for apl_s/guess.bin@300" \
  --frames 330 --shot-last --outdir out/apl
```

The loader checks dump size, system RAM mirrors, cartridge type and fixed ROM
contents. Use `--press` to enter the program name and NEXT after loading;
Guess's program name is `GUES`. APL/S uses RUN/STOP as Space and SHIFT as a
letter/symbol toggle. Guess completes a limit-1 game with the expected score
of `1 1`. Other programs and broader gameplay coverage remain pending.
`bash apl_guess_check.sh` captures startup, RAM loading and the submitted
`GUES` command, then enters a limit and guess of 1. Inspect its PNGs in
`out/apl/guess_check` for the completed score of `1 1`.

`bash apl_guess_check.sh rtl` repeats the schedule through the RTL loader
using core download index 4 (MiSTer OSD index 3). Captures go to
`out/apl/guess_check_rtl`. `--apl-rtl FILE@F` exercises staging, validation,
CPU pause, RAM copy and resume without resetting the interpreter. It checks
the 2048 copy writes, restored bytes, CPU pause and unchanged mapper bank
during the copy. Compare both runs before changing the restored RAM regions.

`python3 apl_check.py --all` captures the 23 numbered reference entries and
four variants. This is a long run. Use `--case 04-guess` for one case or
`--all --dry-run` to list the schedule without simulation. Captures, logs and
`summary.tsv` go to `out/apl/suite`. A completed capture is not a verified pass.
Cases without stored programs are entered from the reference listings.
For diagnostic retries, `--normalize` clears pending snapshot input. Add
`--leave-edit` only for snapshots in edit mode. `--settle N` extends the wait
after each line; `--trace-final N` traces N CPU memory cycles in the final
frame. Use `--outdir out/apl/retry` to keep the original captures.

Joystick pulse timing is runtime-configurable without rebuilding. Headless
defaults to Linear, `--joy-timer-base 2580 --joy-timer-step 7`; use
`--joy-timer-curve` to match MiSTer's default Curve setting. Values are MCLK
ticks. With `--joy-trace`, `[joy-measure]` reports the selected axis, pot value, timer
parameters, and measured pulse length. `bash joystick_sweep.sh [base:step ...]`
cycles candidates independently on all eight axes in one Gladiator run, with
neutral and each direction held in turn. The combined log is
`out/joystick/sweep/gladiator_sweep.txt`.

## selftest.rom

A hand-assembled F8 program that sets up one 16x16 object and halts, so the
CPU, bus, UV201 registers, fetcher, FIFO and renderer can be exercised without
the BIOS. The 2K ROM is tracked; no regeneration script is provided.

    ./obj_dir_headless/Vtop --res1 selftest.rom --frames 8 --shot-last --ascii

`make test-render` checks UV201 background/object modifiers, zoom and blanking.
`python3 tests/pinball_background.py out/pinball` checks matching before/after
state dumps and collision captures from the Pinball regression run.

## Converting VHDL to Verilog one file at a time

The netlist is the reference. Write `rtl_v/<entity>.v`, add the entity name to
`CONVERTED` in the Makefile, and rebuild: that module is stripped from the
netlist and yours is compiled in its place. The VHDL stays in `VHD_SRC` so the
rest of the hierarchy still elaborates.

Check equivalence by frame hash, before and after:

    ./obj_dir_headless/Vtop --res1 selftest.rom --frames 8 --frame-log
    ./obj_dir_headless/Vtop --frames 60 --frame-log

`CONVERTED` is currently empty. The F8 CPU and packages derive from the
Channel F core; preserve attribution when changing them.
