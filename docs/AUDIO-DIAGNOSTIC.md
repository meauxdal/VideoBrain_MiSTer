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

Full-ROM follow-up on 2026-10-19:

```sh
cd verilator
PYTHONDONTWRITEBYTECODE=1 python3 tests/audit_audio_irq.py
make test-cpu-bus-wait
```

The offline audit verifies 4175 opcode fetches against the unmodified RES1
and ED01 images. The detailed trace covers MCLK 81163982..81450016: 39
requests, including three delays over 40 us. The 94.705 us maximum is outside
that coverage. Table 3 timings account for the covered long paths:

| Request MCLK | Live PC at request | IRQ-to-ack us | DI-entry-to-accept active clocks | Lost half clocks | Buffered reads |
| --- | --- | --- | --- | --- | --- |
| 81200432 | 43AC | 87.371 | 168 | 25 | 5 |
| 81207728 | 15A9 | 78.292 | 130 | 14 | 3 |
| 81441200 | 1589 | 68.025 | 168 | 25 | 5 |

Active/lost totals start at DI, not at the request. Lost half clocks are
timing residuals, not independent validation of the arbiter. CSV masked and
stalled wall ticks overlap and must not be added. ROMC 10 to ROMC 0F entry
takes 10 CPU clocks; CSV acknowledgement is one MCLK after logged 0F entry.

Trace PCs are live counters, not opcode addresses. Opcode 43AA is DI; 43AB
is LM; 43AC is OUTS 1. LR W,J at 43AD restores the enable flag, but PK at
43AE and PI at 1588 exclude acceptance. The callee at 40BC masks again,
restores W at 40CE and returns through privileged POP at 40CF. Acceptance
occurs during LIS 0 at 158B, with live PC 158C. The second path enters DI at
40A9 (live PC 40AA), restores W at 40BA, then crosses POP at 40BB and PI at
1582. The first permitted fetch belongs to LR K,P at 41C8, after its two
long body cycles. No skipped permitted fetch was found in these three paths.

Foreground scheduling is tied to video: BIOS 4501 loads a target from 0FE5,
polls current Y at 08FB and branches at 450A before PK. The captured target
is F9. ED01's routine at 157E calls 40A9, 41C8, 4361 and 40BC in sequence;
41C8 itself calls the Y wait at 4501. Thus buffered-access timing can shift
these masked sections relative to the periodic audio request. Across frames
330..342, all 18 delays over 40 us precede DAC updates at Y=29..60. This is
consistent with periodic foreground work, not proof that its timing is correct.

Before the external circuit correction below, `test-cpu-bus-wait` measured the production CPU,
bus interface and UV202 top, including its clock gate, without DMA. It sweeps
128 reset offsets and verifies LM/ST take 10 active CPU clocks. RES1 adds
zero lost half clocks. RAM/cart/RES2 reads add 4..5 half clocks (1..1.25 us);
RAM writes add 5 (1.25 us). UV201 reads add 5..10 and writes 6..10.
These CPU halt costs are distinct from the arbiter's BRCLK service lengths.

`refs/kevtris/videobrain_unwrapped.txt`, Wait States, lines 739..778, reports
RAM/cart sunk cost of 4 CPU clocks (about 2 us), with approximately half-clock
variation, and UV201 costs of 4.5..7 CPU clocks. The test's default assertions
allow half a clock of tolerance and currently fail the RAM/cart lower bound.
RES2 is measured but excluded from that assertion because the explicit
4-CPU-clock statement names RAM/cart. Measurement-only mode is
`make test-cpu-bus-wait BUS_WAIT_ARGS=-gcheck_documented=false`.

Clock-edge accounting agrees with instruction overhead for every buffered
access at all 128 offsets. Reconstructing one CPU edge polarity from phase
parity and subtracting one normal CPU period gives the same lost half clocks.
There is no hidden overlap between the two measurements.

Before correction, offset-zero RAM read MCLK edges are: request asserted 633, arbiter
admission 636, grant/WACK falling 652, CPU resumes at phase 2 on 655. The
request-to-resume interval is 3 alignment + 16 service + 3 restart-phase
MCLKs. Same-polarity CPU edges are 633 and 658; their 25-MCLK gap minus one
normal CPU period is 1.246 us, agreeing with five lost half clocks. Registered
signal changes first appear in the pre-edge trace one tick after their edge.
Enable `-gtrace_bus=true` in BUS_WAIT_ARGS for this trace.

The previous RTL runs its CPU phase accumulator continuously during a stall. The
arbiter releases the stall at grant; `cpu_ce = cpu_ena_raw AND NOT cpu_stall`
then resumes at the next raw enable. No separate clock-stop/restart state
machine adds another interval. The replica's halt is fully accounted for;
whether it matches the documented external circuit remains to be resolved.

The [external circuit audit](CPU-CLOCK-GATE.md) identifies missing U30A
request-latch, U31A opposite-edge WACK sample and U41 request-sampling
transitions. The corrected
gate passes the circuit-derived edge regression and CPU/interrupt tests,
retaining zero RES1 waits and the existing BRCLK service lengths. RAM/cart
halt cost becomes 6..7 lost half-clocks, still below the documented range;
the halt-cost assertion remains failing. Full-ROM IRQ latency and audio
sideband effects await `sh verilator/audio_cpu_gate_capture.sh`. The
fundamental audio fault remains unresolved.
