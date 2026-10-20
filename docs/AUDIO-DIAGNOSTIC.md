# Audio diagnostic

Audio is accepted for release after hardware listening with the retuned filter.
The remaining high-note grit is an open accuracy question. The supplied Happy
Birthday capture predates that retune and has weak upper harmonics.
Periodic timing modulation is present before
filtering in the held-note capture; CPU/bus timing and analog response remain
separate accuracy targets. Regular test tones establish timing cleanliness,
not faithful original-machine filtering.

`System > Audio Test` selects a 500 Hz, 1 kHz, 2 kHz or 4 kHz square-wave
source ahead of the existing audio filter. It uses no CPU, ROM, keyboard or
interrupt timing. The computer continues running. Off selects normal audio.
This is an isolation test, not a sound correction. Filtering rounds its output.

The test tones sound steady on the user's core.
Low nonharmonic noise alone does not establish faithful sound.

Matched Happy Birthday recordings contain the same 25 notes. On the high C5,
relative harmonic levels agree near 2.6 kHz, but MiSTer is about 4.5 dB lower
near 5.8 kHz and 14 dB lower near 11 kHz. The reference's steep 12..13 kHz
cutoff is present in its compressed source video; its origin is unverified.
MiSTer's weak harmonics above that edge continue falling. C4 plateau decay
suggests effective time constants near 4.3 ms in the reference chain and
11 ms in MiSTer. These are recording-chain observations, not board component
values. Excess C5 sidebands near +/-60 Hz remain a separate timing concern.

Filter audit: `refs/seanriddle.com/videobrain4.jpg` shows a resistive DAC;
sheet 1 (`videobrain1.jpg`) shows the RF sound path: series choke, 150 pF
shunt, 0.01 uF coupling capacitor, 1 Mohm return and varactor-modulated
LM1889 sound oscillator. The DAC ladder's schematic source resistance is
`120k || (56k + (120k || 120k))`, about 59 kohms. The 150 pF alone therefore
suggests a pole near 18 kHz, excluding varactor loading. These are not the
four independent audio low-pass poles currently in the core. The workbook's
R51 connection conflicts with this schematic; it is not used for this estimate.
Receiver de-emphasis also matters: [TI AN-402](https://www.ti.com/lit/an/snoa678/snoa678.pdf)
describes the US 75 us response (about 2.1 kHz). The recording path is unknown.

At the C5 harmonics near 5.8/11 kHz, relative to the fundamental, the core's
two 8.9 kHz poles add 3.01/8.02 dB loss and its four reconstruction poles add
1.71/5.58 dB. Without compensation this accounts for most of the observed
excess suppression. The held FIR output adds another 0.04/0.14 dB loss.

`python3 verilator/tests/audio_response_audit.py` uses NumPy and FFmpeg to
check the saved OGGs and stage responses. It writes `verilator/out/audio_response_audit/`.
A two-pole magnitude fit to C5 gives approximately 1.50/6.89 kHz, with
0.24 dB RMS error across odd harmonics 3..21. Independent C4/D4/E4/G4/A4
windows give 0.14..0.28 dB RMS; F4 gives 1.41 dB. This is an effective
recording-response target, not identified component values or a complete
model. Droop changes are deferred.

The 225-tap FIR compensates the retained prefilter and reconstruction stages
for an effective 1.50/6.90 kHz two-pole magnitude response. Maximum numerical
error through 11.5 kHz is 0.22 dB. A steep transition centered at 13 kHz puts
14 kHz at -67.9 dB relative to DC; 14.5 kHz is below 16-bit output resolution
in the RTL tone check. This band limit is intentional alias protection, not
an attribution of the compressed reference's cutoff to board components.
Phase response is not calibrated to hardware.

A synthetic 524 Hz tone through the actual MiSTer I2S modules gives H5/H11/H21
at -20.0/-34.4/-48.7 dBc, versus -20.2/-34.5/-49.4 dBc in the hardware C5
reference. This checks the filter calibration, excluding normal ROM timing.

The FIR uses 113 products per 128-clock sample interval, retaining one shared
multiplier and both 256-word history arrays. Group delay increases by 0.286 ms.
Quarter gain within the FIR preserves headroom; gain is restored before
reconstruction. `make test-audio` passes pin/latch, DC, bounds, response,
decimation and exact FIR convolution/reset checks. Its 36-note, three-octave
sweep at 48/96 kHz keeps measured foldback below 0.5 output LSB RMS.
The coefficient table is larger; Quartus timing/resource validation is pending.

Run the short digital-path check from `verilator`:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tests/check_audio_path.py --run
```

It checks source pulse widths and decodes actual I2S words after the core
filter and MiSTer output modules at independent 14.318181/24.576 MHz clocks.
It tests 500/1000/2000/4000/8000 Hz at 48/96 kHz, with default MiSTer filter
coefficients, unity volume, no boost and no Linux audio.

Verilator 5.032 requires a simulation copy of `audio_out.sv`: five procedural
declaration initializers are removed and initialized with `--x-initial 0`.
No `sys` source is modified. Build diagnostics are in `out/audio_path_build.log`.
The test excludes analog circuitry, HDMI transport, metastability and FPGA
timing failures. It does not validate the original machine's analog response.

Measured on 2026-10-19: all ten cases pass. I2S nonharmonic RMS ranges from
-79.9 to -53.8 dBc; interpolated period spread is below 0.20 us over each
0.25-second capture. These figures describe controlled test inputs only.
The output third harmonic is -15.6 dBc at 1 kHz and -23.5 dBc at 4 kHz,
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
the halt-cost assertion remains failing. The completed full-ROM capture
reduces period RMS deviation from 20.315 to 8.875 us and the +/-60 Hz
sidebands by 9.5..9.7 dB in frames 330..342. IRQ-to-ack maximum falls from
94.705 to 62.438 us. RC17 hardware listening suggests improvement, but the
fundamental audio fault remains unresolved.

The RC17 recording's release tails decay in 10.6..10.8 ms, matching the
MiSTer DC blocker's 10.66 ms time constant. Opposite onset polarities can
follow different held idle DAC levels; they do not establish a latch fault.
Same-pitch notes with the same onset polarity still have different sideband
strengths. Sustained IRQ/DAC timing remains the investigation target.

Run the repeated-note phase capture from the root in WSL:

```sh
sh verilator/audio_note_phase_capture.sh
```

This long run uses unmodified ED01, four K presses with different sub-frame
key-down delays, and writes `verilator/out/audio_note_phase/`. It preserves
existing captures. `trace.csv` independently records key changes, physical
sound-clock/data checks, IRQ/ack edges and actual onset video phase;
`events.csv` retains the existing detailed latency fields. Pin inputs are
sampled before MCLK rising, latch/IRQ outputs after it. The checker verifies
physical rising clock edges, including any without a port-write strobe.

`comparison.txt` reports idle/first/final codes, pulse widths, duty cycle,
period variation, IRQ latency and +/-60/120 Hz sidebands. All spectra use
0.100..0.300 s after each note's first DAC write. The synthetic fixed-ack
comparison changes IRQ-to-ack latency only; it is not a proposed correction.
Keyboard scanning can collapse requested phases to similar actual onsets.
Missing notes, incomplete windows and mismatched latch/IRQ logs fail analysis.
Short analyzer checks:
`PYTHONDONTWRITEBYTECODE=1 python3 verilator/tests/test_audio_note_phase.py`.
