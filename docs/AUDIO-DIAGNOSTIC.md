# Audio diagnostic

Normal audio remains faulty across software and pitch. Timing variation is
present before filtering. The current investigation targets core generation
and CPU/bus timing; MiSTer output, 240p and filter tuning are excluded.

`System > Audio Test` selects a 500 Hz, 1 kHz, 2 kHz or 4 kHz square-wave
source ahead of the existing audio filter. It uses no CPU, ROM, keyboard or
interrupt timing. The computer continues running. Off selects normal audio.
This is an isolation test, not a sound correction. Filtering rounds its output.

The test tones sound steady on the user's core. Normal audio remains faulty.
Low nonharmonic noise alone does not establish faithful sound.

Run the short digital-path check from `verilator`:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tests/check_audio_path.py --run
```

It checks source pulse widths and decodes actual I2S words after the core
filter and MiSTer output modules at independent 14.318181/24.576 MHz clocks.
It tests 500/1000/2000/4000 Hz at 48/96 kHz, with default MiSTer filter
coefficients, unity volume, no boost and no Linux audio.

Verilator 5.032 requires a simulation copy of `audio_out.sv`: five procedural
declaration initializers are removed and initialized with `--x-initial 0`.
No `sys` source is modified. Build diagnostics are in `out/audio_path_build.log`.
The test excludes analog circuitry, HDMI transport, metastability and FPGA
timing failures. It does not validate the original machine's analog response.

Measured on 2026-10-19: all eight cases pass. I2S nonharmonic RMS ranges from
-79.9 to -60.7 dBc; interpolated period spread is below 0.15 us over each
0.25-second capture. These figures describe controlled test inputs only.
The output third harmonic is -15.9 dBc at 1 kHz and -37.8 dBc at 4 kHz,
versus -9.54 dBc for an ideal square wave. The current filters therefore
produce substantial rounding even when timing is regular.

The saved post-fix held-note trace in `out/music_audio_b5/events.csv` has
DAC full periods of 932.241..1106.216 us, around a 1019.264 us median.
Corresponding IRQ full periods span 1017.448..1020.800 us. IRQ-to-ack delay
spans 5.029..93.867 us; ack-to-DAC spans 86.813..89.327 us. This localizes
most reproduced timing variation before acknowledgement, ahead of filtering.
It does not establish which implementation behavior differs from hardware.

The unmodified ED01 cartridge capture in `out/audio_timing_audit` reproduces
the variation. All 39 DAC updates covered by its detailed CPU trace match
the physical clock edge and data; none is missing. A 90.165 us request-to-ack
delay spans actual interrupt masking and privileged call/return instructions.
No missed permitted acceptance was found at the logged fetch boundaries.
The sparse trace does not prove CPU equivalence to original hardware.

`make test-cpu-audio` checks a fixed F8 program through the clock generator,
CPU, bus interface and DAC latch. Published instruction times give a half
period of `20 * delay_count + 82` CPU clocks. All four cases pass: 2002, 1002,
502 and 242 clocks, with only one MCLK tick of interval variation (69.84 ns).
This test uses RES1 without interrupts or buffered-bus waits. It validates
that path in simulation, not normal ROM interrupt timing or FPGA behavior.

UV202 corrections under evaluation, following the explicit bus-body and setup
rules in `refs/kevtris/videobrain_unwrapped.txt`:

- UV201 register bodies take 4..7 BRCLKs by phase, plus one setup BRCLK.
  The old body was fixed at five. Bus phase is three at HBLANK rising.
- Consecutive DMA bytes take three BRCLKs; the old arbiter took five.
  The fetcher keeps multi-byte requests asserted between bytes.
- CPU requests present before the last DMA cycle overlap setup; DMA after
  CPU completion retains one setup BRCLK.

`make test-arbiter test-fetcher-bus` passes phase, contention, priority,
dual-DMA, byte ordering, address wrap, copy mode and FIFO backpressure checks.
The old arbiter fails the UV201 duration and DMA burst-spacing checks.
Full-core VHDL analysis and elaboration, CPU interrupt, F3853 and fixed CPU
audio checks pass. Normal-ROM audio improvement is not yet measured.

Run `sh verilator/audio_bus_timing_capture.sh` from the repository root in WSL.
This longer run rebuilds the simulator, repeats the original ED01 capture,
preserves `out/audio_timing_audit` and compares frames 330..342. Results go to
`verilator/out/audio_bus_timing/comparison.txt`. Baseline full-period spread
is 171.460 us, RMS deviation 18.985 us and p95 deviation 60.769 us. Compare
those pre-filter metrics before requesting another FPGA build.
