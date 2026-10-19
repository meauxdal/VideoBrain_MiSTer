# Audio diagnostic

Normal audio remains faulty across software and pitch. Periodic timing
modulation is present before filtering in the held-note capture. The
investigation targets core generation and CPU/bus timing; MiSTer output,
240p and filter tuning are excluded.

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
audio checks pass.

Hardware listening after these corrections on 2026-10-19 suggests a modest
improvement: smoother, more periodic sound, with the remaining ringing sounding
more like an overtone than distortion. The fundamental audio fault persists.
Brief gameplay showed no observed graphics discrepancies.
The remaining sound is described as pitch-related beating or nonharmonic
ringing; the fundamental fault remains unfixed.

Run `sh verilator/audio_bus_timing_capture.sh` from the repository root in WSL.
This longer run rebuilds the simulator, repeats the original ED01 capture,
preserves `out/audio_timing_audit` and compares frames 330..342. Results go to
`verilator/out/audio_bus_timing/comparison.txt`.

Measured on 2026-10-19: DAC period spread increased from 171.460 to 174.254 us,
RMS deviation from 18.985 to 20.315 us and p95 deviation from 60.769 to
66.503 us. This capture does not support reduced DAC timing variation.
Of 425 IRQ full periods, 423 are 14592 MCLKs; the other two are 14568 and
14616 MCLKs around the frame-340 boundary. IRQ-to-ack reaches 94.705 us;
ack-to-DAC spread is 1.816 us. Long waits include interrupt masking at BIOS
PCs 43AB/43AC and 40AA. CPU instruction timing and interrupt acceptance
through these paths remain investigation targets, not established defects.

Exact held-DAC integration over 0.005..0.200 s of this capture shows sidebands
near 981.24 +/- 59.94/119.88 Hz at approximately -35 dBc, similar to baseline.
IRQ-to-ack delays have modulation near 60 Hz and its multiples. Replacing only
IRQ-to-ack latency with a constant reduces the +/-60 Hz sidebands to roughly
-72/-75 dBc. This timestamp sensitivity check links the simulated sidebands
to acknowledgement latency; it is not a hardware correction or proof that
the CPU's interrupt acceptance rules are wrong. Pitch dependence is unmeasured.

Run `sh verilator/audio_irq_diagnostic.sh` in WSL for the short follow-up.
It reuses the saved capture and writes `verilator/out/audio_irq_diagnostic/`:

- `cpu.txt`: ROM instruction-chain timing and acceptance at 320 request phases.
- `comparison.txt`: pre-filter sideband levels and listening instructions.
- `a_recorded.wav`: recorded DAC timing.
- `b_fixed_ack.wav`: constant IRQ-to-ack latency, recorded ack-to-DAC latency.
- `c_fixed_irq_to_dac.wav`: constant IRQ-to-DAC latency, recorded IRQ timing.

All WAVs use the same reconstruction and gain, excluding core/MiSTer/analog
filters. Each repeats the short captured burst with silence between repeats.
User listening on 2026-10-19: A is bad; B and C are good. Removing IRQ-to-ack
variation is sufficient to remove the reported ringing in this capture.
This identifies a sufficient timing intervention, not an accuracy correction.

The isolated ROM chain passes the Fairchild F3850 Table 3 instruction timings
and interrupt exclusions (printed pp. 3-22..3-24 in
`refs/orphanedgames.com/fairchild-3850.pdf`). A request at LM entry takes
85.25 us to acknowledge at 2 MHz, without bus waits. This checks a controlled
ROM slice, not full-machine execution or the original hardware's audio.
