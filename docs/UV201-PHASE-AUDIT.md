# UV201 access-phase correction

2026-10-24, following the initial [capture analysis](LOGIC-CAPTURE-ANALYSIS.md).
Baseline is `d4856b7` (`phase8`). The evidence supports correcting where a
data-counter access pauses within its bus cycle. It does not justify fitting
new arbiter wait constants to a captured median.

## Captured pause position

The Timeshare capture includes PHI, WRITE, ROMC and the data bus. Falling WRITE
edges delimit bus cycles. Count PHI falling edges from each boundary up to the
edge preceding the pause, including that edge. All these memory cycles contain
six PHI falling edges in total.

| Access | Captured cycles | PHI falls before pause | Old model | Corrected model |
| --- | ---: | ---: | ---: | ---: |
| UV201 read, ROMC 02 | 6,047 | 3 in every cycle | 1 | 3 |
| UV201 write, ROMC 05 | 13,543 | 4 in every cycle | 2 | 4 |
| RAM read, ROMC 02 | 418 | 3 in every cycle | 1 | 3 |
| RAM write, ROMC 05 | 38 | 4 in every cycle | 2 | 4 |

Every captured UV201 access has exactly one paused falling-edge interval. A
separate Python/decimal pass over the raw CSV independently confirms examples:

- WRITE cycle 0.007386375-0.007392625 s: six falling edges at offsets
  0.4375, 0.9375, 1.4375, 1.9375, 5.6875, 6.1875 us. The write pauses after
  edge four; the paused interval is 3.75 us.
- WRITE cycle 0.008074250-0.008080750 s: offsets 0.4375, 0.9375, 1.4375,
  5.4375, 5.9375, 6.4375 us. The read pauses after edge three; its gap is 4 us.

The UV201 read set consists of 6,009 current-Y reads (FB) and 38 field/freeze
status reads (FA). Writes cover 12,542 object-register accesses (00-8F), 76
command writes (F7), and 925 writes to other offsets. All have the same pause
position for their direction. Register addresses are reconstructed from DC0 bus
operations, not directly probed; all 76 available DC0 readbacks agree with that
reconstruction. DMA presence is unknown in this capture, but does not change
the observed pre-pause edge count.

## Manufacturer cross-check

Fairchild F3852/F3853 device documentation, preserved with the
[F8 programming manuals](https://orphanedgames.com/videobrain/):

- Figure 16, printed p. 3-70 / PDF page 16: the SMI's long read from DC0 has
  later address selection than a PC0 read. Its illustrated worst-case address
  settles about 1.25 us after WRITE falling, for 500 ns PHI.
- Figure 18, printed p. 3-71 / PDF page 17: write address selection precedes
  the /RAM WRITE pulse; the illustrated pulse starts no earlier than 1.85 us.
- Table 4, printed p. 3-73 / PDF page 19, distinguishes PC0 and DC0 address
  delays and specifies /RAM WRITE timing relative to PHI and WRITE.

These loaded worst-case timing diagrams are not fixed propagation constants
for this board. They corroborate the late DC0-address/write sequence, while
the captured PHI counts establish the tested cycle placement. The correction
uses the model's existing half-PHI phases; it does not reproduce analog delays
or claim electrical setup/hold equivalence.

## RTL changes

The F3853 addressing path is shared by UV201, RAM and other DC0 accesses, so
the fix belongs in ROMC 02/05 handling rather than a UV201-only delay:

- ROMC 02 selects the DC0 address and starts its request at half-phase 5,
  then latches returned data at phase 6 after any wait.
- The CPU consumes ROMC 02 data at phase 7 and commits its ALU result at
  phase 8. Leaving the old phase-3 consumption in place would use data from
  before the transfer completed.
- ROMC 05 selects and holds the DC0 address at phase 5, then starts its
  write request at phase 8. Holding the address preserves the target across
  the existing DC0 increment at phase 6. Write data remains held until grant.

No opcode ROMC order, short/long cycle length, CPU frequency, arbiter body
constant, DMA priority or gate-release rule is changed. PC0 fetch/operand
requests remain on their existing path. This corrects the measured DC0 pause
placement; it is not a complete electrical timing model of every bus state.

## Isolated phase sweep

The old sequential memory test reached UV201 writes only after several prior
buffered accesses. Those accesses can bias the available alignments. Its
2.51-2.79 us write range therefore was not the complete model range.

`make test-uv201-wait` resets the CPU separately at 256 offsets per direction.
It covers every modulo-four admission phase for each direction, with and
without a continuous DMA requester (1,024 cases total). Reads target FB and
writes target object register 50. The isolated same-polarity gap range is
32-47 MCLKs (2.235-3.283 us) for both directions, in both the original isolated
baseline and corrected no-DMA model. Range overlap alone did not expose the
early request phase.

The test checks the captured pre-pause edge count, unchanged active LM/ST
duration, phase-dependent setup/body accounting, both clock polarities, exact
write count/address/data, and returned-data validity. Read data is deliberately
poisoned until the CPU grant completes. An original CPU/bus build fails the
captured pause-position check. A build with only the bus phase moved and the
old CPU consumption phase fails the poisoned-data check. Thus both sides of
the correction are necessary.

The continuous-DMA test is one contention pattern, not exhaustive original
hardware equivalence. Broader DMA delays and the capture's longest UV201 gaps
still need matched request/service evidence. The existing sequential bus-wait
test still reports RAM/cart 6-7 lost half-clocks; its older documented-cost
assertion remains unchanged and is not a passing hardware-equivalence claim.

## Separate Expander 1 regression repair

Integration testing found the original-ROM cassette record test failing its
pulse count. An isolated build of the unchanged phase8 CPU/bus fails at exactly
the same timestamp, establishing that this was already present before the
DC0 phase correction.

The earlier F3853 acknowledgement correction moved `f8_busif.int_ack` from early
vector delivery to completion. Expander 1 had also used that output as the
3870's **vector selection** strobe. Its separate source-clear input occurs in
ROMC 13 phase 6, so a selection strobe arriving at phase 11 is too late.

`expander1.vhd` now derives its own `int_start` from ROMC 0F phase 1, before the
low vector byte is delivered. The existing 3870-specific phase-6 source clear
is preserved; the main-board F3853 still acknowledges at completion. Neither
timer's control semantics are generalized to the other device.

Original-firmware record tests again produce the expected 342 pulses for good
CRC and 343 for bad CRC. Firmware SAVE/LOAD through a remounted two-record SD
tape image and 300/110-baud serial tests also pass.

## Validation and remaining work

Passed: four extractor waveform/parser checks; 1,024 isolated/continuous-DMA
UV201 cases; all 968 opcode timing cases; 4,160 branch cases; 1,280 port cases;
CPU interrupt variants and the 320-phase ROM IRQ chain; both F3853 timer
dividers with all seeds and the 104 vector cases; full-core SMI clock;
clock-gate, arbiter and fetcher/DMA regressions; four fixed CPU-to-DAC programs;
Expander timer/interface, record, playback and serial firmware tests; CPU clock
test; and full-core GHDL synthesis.

Reproduce the new comparisons with:

```sh
make test-logic-csv test-uv201-wait
out/logic_captures/analyze_logic_csv /path/to/timeshare.logicdata.csv out/logic_captures/timeshare
python3 -B tests/summarize_logic_captures.py out/logic_captures
```

The extraction/summary also uses the other capture outputs from the initial
report. Detailed read/write CSVs are generated in `out/uv201_wait`; extracted
hardware measurements are written to `out/logic_captures`. The negative-control
results above used the baseline revision identified at the start of this audit.

MiSTer validation of these new DC0 and Expander-strobe changes is still needed.
Check APL/S entry/execution, cassette save/load, video updates and Music Teacher.
No claim is made yet about an audio improvement. Subsequent UV201 work should
compare the actual service/data-latch phase and DMA handoff, using matched
workloads or additional BRCLK/WACK observations, rather than change a wait
constant merely to move aggregate ranges.
