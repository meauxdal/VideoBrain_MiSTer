# Original-machine logic capture analysis

Measured 2026-10-24 against the `phase8` checkout (`d4856b7`). The initial
extraction/comparison pass made no production RTL or wait-constant changes.
The subsequent [UV201 phase audit](UV201-PHASE-AUDIT.md) records a supported
request-phase correction and a separate Expander vector-selection repair.
Results below describe the initial baseline and sampled signals from Sean
Riddle's captures, with the provenance limits below.

## Inputs and measurement definitions

| CSV | Rows / transitions | Final timestamp / observed span | Time grid | Recorded signals |
| --- | ---: | ---: | ---: | --- |
| `vbnormalwreset.csv` | 64,608,939 rows | 11.186339840 s | 80 ns | UV202 unused clock output, gated XTAL, PHI, reset, DMA request 0, CPU requests 0/1, IO16 |
| `vbdiagwreset.csv` | 66,024,736 rows | 10.491330560 s | 80 ns | Same eight channels |
| `vbnobios1wreset.csv` | 243,118 rows | 10.292756480 s | 80 ns | Same eight channels |
| `timeshare.logicdata.csv` | 5,756,498 rows | 0.632319875 s | 62.5 ns | xtl, PHI, WRITE, ROMC0-4, D0-7 |
| `moneymindersave.csv` | 57,985 transitions | 55.345839 s between first/last transitions | 0.5 us | Cassette output, sample indices at 2 MHz |

The first four inputs total 136,633,291 rows. Their timestamps are strictly
increasing and lie on the stated grids. Startup, reset and inactive tails mean
the final timestamp is not a duration of uninterrupted CPU operation.

For the eight-channel files, exclude reset-low intervals and guard 100 us at
both ends of each reset-high segment. Measure the interval between consecutive
PHI falling edges; flag gaps over 0.8 us. An ordinary PHI period is approximately
0.500 us. Define **sunk time = same-polarity gap minus one ordinary period**.
This is the same endpoint definition used by `tb_cpu_bus_wait`; neither a
request-pulse width nor an instruction's full elapsed time is that clock gap.

CPU request decoding follows Kevtris's pin table: rq0/rq1 = 11 identifies
RAM/cart-style reads, 01 identifies UV201 reads, and 10 identifies writes whose
destination cannot be distinguished without /800-BFF or addresses. The extractor
stores bit sets of *all* codes observed inside a gap. The clean classes below
allow idle 00 and exactly one nonzero code; mixed/skewed codes are retained
separately. In addition, require DMA request 0 to remain low from 2 us before
the gap until its end. This is a conservative **DMA-request-quiet** screen,
not direct observation of DMA grants or WACK.

Each 80 ns grid gives roughly +/-80 ns interval quantization; the Timeshare
grid gives roughly +/-62.5 ns. Threshold/probe delays and missed narrow pulses
are additional uncertainties. Do not infer nanosecond electrical precision
from averages over many sampled events.

## Normal capture: measured waits versus the current model

| Class / dataset | Samples | Same-polarity PHI gap | Main modes / median |
| --- | ---: | --- | --- |
| RAM/cart-style read, DMA-request-quiet | 18,080 | 1.68-2.08 us | Modes 1.76 and 2.00 us; median 1.76 us |
| UV201 read, DMA-request-quiet | 199,025 | Central 98%: 2.72-3.52 us | Median 3.28 us |
| Writes, destination unknown, DMA-request-quiet | 17,626 | 1.68-4.00 us | Modes include 2.00 and 3.76 us; mixed destinations |
| Any gap with DMA request seen during it | 41,547 | 1.68-4.32 us | Mixed CPU access classes; median 3.20 us |
| Simulated RAM/cart reads, no DMA | 128 offsets each | 1.9556-2.3048 us | RAM median 2.0254 us; cart median 2.2349 us |
| Simulated UV201 reads, no DMA | 128 offsets | 2.2349-3.2825 us | Median 2.7937 us |
| Simulated UV201 writes, no DMA | 128 offsets | 2.5143-2.7937 us | Median 2.5143 us |

The clean hardware read-code modes imply approximately 2.5 or 3.0 sunk CPU
periods, rather than a universal 4.0. The model still reports 6-7 lost half
clocks (nominally 3.0-3.5 periods) for its RAM/cart test. **These captures do not
justify adding a blanket wait to meet the older approximate 4-clock account.**
They suggest the read distribution may already be somewhat too long, while
UV201 service timing needs its own comparison. Different programs and relative
clock/video phases make medians unsuitable as direct constants to fit.

Two raw pairs were independently verified using Python's decimal CSV parser,
separately from the C++ extractor: 1.825328720 to 1.825330480 s (1.760 us) and
1.844185520 to 1.844187520 s (2.000 us).

Do not treat raw maxima as stable operating limits. Near the normal capture's
tail, one UV201-coded gap is 7.44 us, followed by an 8.58408 ms gap without a
CPU request. Both occur around 9.509 s, before reset goes low at 9.520142640 s.
The 100 us reset guard alone cannot remove such anomalies. They remain in the
extracted data. The first uninterrupted reset-high segment has no such outlier:
its no-DMA-observed UV201-read gaps range from 2.72 to 3.76 us. The no-BIOS file
supplies 512 clean UV201-coded gaps, mainly 2.96/3.04 us, but no clean read-code
11 sample. The diagnostic file is not a representative bus-wait workload.

## Timeshare: direct CPU cycle evidence

Use falling WRITE edges as cycle boundaries. Take the stable ROMC and bus byte
immediately before the following boundary; retain an independent bus sample
at WRITE rising. The capture starts mid-execution, so discard the initial
partial cycle and leave initial CPU address registers unknown.

- 242,911 completed cycles contain exactly four or six PHI falling edges:
  159,534 short cycles and 83,377 long cycles.
- 110,527 complete instruction intervals, spanning 66 distinct opcodes, match
  the independently transcribed Fairchild Table 3 ROMC orders and active cycle
  lengths. Branch taken/untaken alternatives are allowed; flags are not captured.
- No undefined opcode fetch or sequence mismatch was found. Fetch bytes agree
  at WRITE rising and just before the next falling boundary in all 110,528
  captured fetch cycles.
- No 10/0F/13 interrupt-entry sequence occurs here. This capture does not measure
  F3853 acknowledgement or timer behavior.

This corroborates the CPU cycle model for the observed program. It does not
check all opcodes, arithmetic results, branch flag semantics, or internal edges.

DC0 can be reconstructed after its bytes have been supplied by recorded ROMC
loads. Track increments, signed adds and XDC swaps; never invent reset values.
All 76 available DC0 byte readbacks agree with that reconstruction. Applying
the documented address map gives:

| Inferred access | Cycles | Observed paused PHI gap | Median gap |
| --- | ---: | --- | ---: |
| RES1 LM | 12,897 | No gap over 0.8 us | Ordinary clocks |
| RAM LM | 418 | 1.75-2.75 us | 2.00 us |
| RAM ST | 38 | 1.75-2.5625 us | 2.00 us |
| UV201 LM | 6,047 | 2.75-4.5625 us | 3.25 us |
| UV201 ST | 13,543 | 2.75-4.75 us | 3.75 us |

Addresses in this table are inferred from bus operations, not probed address
pins. Another 229 LM and 229 ST cycles precede known DC0 values; 570 LM cycles
address the expansion region and are kept separately. There is no DMA channel
in this recording, so its paused samples cannot be labeled contention-free.

The user identifies the source as `https://www.seanriddle.com/vb/timeshare/`.
Its machine/clock modifications and the physical `xtl` probe point remain
unknown. The dominant `xtl` same-edge interval is 250 ns, versus 500 ns on the
reset captures' channel labeled `3850-38 xtal`. Do not equate those nets or infer
clock-gate edge behavior across the two recordings from their labels alone.
The PHI/WRITE/ROMC measurements above do not require that equivalence.

## Paired diagnostic ROM

The user confirms `vbdiag.bin` and `vbdiagwreset.sal` are paired source files.
MAME unidasm's F8 backend produces the disassembly; a DASM source is saved
locally as `refs/seanriddle.com/vbdiag.asm`. Its rebuilt raw 1,024-byte image is
byte-identical, SHA256:

`db263679a219f0b8bb3051a478c08de81e4a79ad96e726d3592b2646c27eda83`

Only the first 35 bytes are code; the rest is FF padding. The program disables
interrupts, toggles port 1 bit 6, executes nested R5=40/R6=FF decrement loops,
then jumps to the RES1 mirror at 4000. It performs no normal buffered-memory
accesses and never enables the SMI timer or video DMA. This explains the sparse
CPU request activity without assuming its waveform should resemble normal ROMs.

The exact program bytes run in `make test-sean-diag`. Published instruction
totals and the model give a full two-level loop of 787,540 PHI periods. The
steady hardware full period is 0.39380920/0.39380928 s, consistent with about
1.999801 MHz PHI. Twenty-eight adjacent steady interval pairs count 787,540 PHI
falling edges; three count one edge less/more, consistent with sampling/pin
boundary ambiguity.

Individual physical IO16 intervals split near 393,754 and 393,786 periods
(some counts differ by one), while the digital model splits at 393,752 and
393,788. Their sum agrees. This roughly one-microsecond rising/falling boundary
displacement could include unequal electrical pin delays and cannot be assigned
to instruction execution from this recording. WRITE and IO16 in the same
capture, with known probe/load conditions, would separate latch timing from
electrical rise/fall delay. Do not change CPU instruction lengths to fit it.

## Money Minder digital tape reference

Interpret `Sample` as a 2 MHz sample index, not seconds. Its first/last recorded
indices are 25,065,357 and 135,757,035. All 57,985 transitions alternate levels.
Low pulses are 156.5/157.0 us; high intervals form the approximate 1 kHz/500 Hz
tone timing. There are six inter-block idle gaps around 2.04-2.30 s, plus an
initial observed 0.326026 s high interval. No duration before the first recorded
transition or after the last one is assumed.

Removing high intervals >=100 ms and classifying the remaining high intervals
at 1.35 ms gives seven groups of 2,627/2,627/2,627/6,929/6,929/6,929/317 symbols.
The first three groups match each other, as do the next three. All 28,985 tone
symbols match `refs/tape-observations/moneymindersave.vbt`, with zero length or
symbol differences. This confirms a digital counterpart to that tested data;
it is not a fresh record/checksum decode or proof that pulse timings match.
The original CSV timing is retained without rescaling or polarity changes.

## Reproduction and next work

From `verilator`, build and self-check the streaming extractor:

```sh
make test-logic-csv
out/logic_captures/analyze_logic_csv ../refs/seanriddle.com/vbnormalwreset.csv out/logic_captures/vbnormalwreset
out/logic_captures/analyze_logic_csv ../refs/seanriddle.com/vbdiagwreset.csv out/logic_captures/vbdiagwreset
out/logic_captures/analyze_logic_csv ../refs/seanriddle.com/vbnobios1wreset.csv out/logic_captures/vbnobios1wreset
out/logic_captures/analyze_logic_csv ../refs/seanriddle.com/timeshare.logicdata.csv out/logic_captures/timeshare
make test-cpu-bus-wait BUS_WAIT_ARGS="-gcheck_documented=false -ggap_csv=out/logic_captures/simulation.csv"
make test-sean-diag
python3 -B tests/summarize_logic_captures.py out/logic_captures
python3 -B tests/analyze_tape_capture.py ../refs/seanriddle.com/moneymindersave.csv ../refs/tape-observations/moneymindersave.vbt out/logic_captures/moneyminder-summary.json
```

The summary script needs NumPy/pandas. The extractor tests need only C++17 and
Python's standard library. They check exact fractional timestamps, reset gap
exclusion, known request classification, cycle edge counting and invalid time
order. Large intermediate tables stay in ignored `verilator/out/logic_captures`;
raw CSVs stay in ignored `refs`. The normal default bus-wait assertion remains
unchanged; `check_documented=false` above is explicitly measurement-only mode.

Next investigate UV201 read/write service and CPU request-generation phase
separately, using the measured access classes and both clock polarities. Prefer
a matched program/phase replay to fitting aggregate medians. BRCLK/WACK, /800-BFF,
WRITE, PHI and CPU/DMA requests captured together would distinguish admission,
service and restart costs. Until that decomposition or equivalent evidence is
available, these measurements justify targeted investigation, not a new blanket
wait constant.

Follow-up: independent per-access sweeps establish a wider original-model
UV201-write range of 2.235-3.283 us than the sequential test above. Direct PHI
edge counting also finds an early DC0 request phase in the model, despite
overlapping gap ranges. See the UV201 phase audit for the evidence, fix and
validation; the baseline table above has not been silently replaced.
