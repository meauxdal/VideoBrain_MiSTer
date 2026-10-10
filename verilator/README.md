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
