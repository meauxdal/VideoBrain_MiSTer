# Timing sources and remaining work

CPU active cycles and board elapsed times need separate checks. Correct opcodes
can still finish too early if buffered accesses pause the clock too briefly.

## Source roles

| Source | Establishes | Limits |
| --- | --- | --- |
| Fairchild F3850 Table 3, printed pp. 3-21 through 3-25 (`refs/orphanedgames.com/fairchild-3850.pdf`, PDF pages 15-19) | Instruction ROMC order, short/long cycles, data-bus timing classes, interrupt restrictions | Does not specify VideoBrain arbitration or external clock stopping |
| Fairchild F3852/F3853 manual and Mostek 1978 data book | Timer sequence, division, reload and interrupts | Input frequency and gating depend on the board |
| Sean Riddle's connection records and photographs | Net connections and external gate topology | Do not establish propagation delays or internal ASIC behavior |
| Sean's original-machine captures | Observed clocks and requests | Depend on recorded channels, sample resolution, reset and software state |
| Kevtris, *VideoBrain Unwrapped*, Wait States section | UV202 service timing and full-speed CPU halt measurements | Separates a slowed, clock-modified machine from full-speed operation; interval endpoints differ |
| Turner's [overview](https://www.nyx.net/~lturner/public_html/Fairchild_F8.html), [instruction details](https://www.nyx.net/~lturner/public_html/F8_ins.html) and [opcode summary](https://www.nyx.net/~lturner/public_html/F8_opcodes.html) | Instruction index and timing cross-check | Contains discrepancies; resolve them with the device manuals |
| MAME and our regressions | Executable models and checks of explicit expectations | Agreement between models is not a hardware timing measurement |

Use manufacturer tables for instruction expectations and board measurements for
VideoBrain waits. Preserve conflicting observations and their endpoints rather
than adjusting constants to average them together.

## Opcode audit

`make test-cpu-opcode-timing` executes the CPU and bus interface against an
independent transcription of Fairchild Table 3. It checks ROMC order and each
cycle's duration, including the terminating fetch. Expectations do not come from
the implementation's `MICROCODE` table.

It covers 242 documented opcodes in four configurations: low W flags all clear
or all set, and ISAR low bits 3 or 7. Each case initializes the scratchpad through
instructions. Undefined encodings, including reserved INS/OUTS ports 2 and 3,
are excluded. External waits are absent. Existing tests cover the larger branch
mask/flag/displacement space and interrupt entry.

On 2026-10-24 all 968 cases passed. This verifies active cycle lengths and ROMC
order for those cases, not electrical setup/hold or exhaustive semantics.

Fairchild resolves these discrepancies in the web tables:

| Instruction | Fairchild ROMC sequence | PHI clocks | Time at 2 MHz without waits |
| --- | --- | --- | --- |
| BR7, ISAR low bits = 7 | short 03, short 00 | 8 | 4 us |
| BR7, ISAR low bits != 7 | long 01, short 00 | 10 | 5 us |
| IN, immediate port address | long 03, long 1B, short 00 | 16 | 8 us |
| INS/OUTS, ports 0 or 1 | short 1C, short 00 | 8 | 4 us |
| INS/OUTS, ports 4 through 15 | long 1C, long 1B/1A, short 00 | 16 | 8 us |

Turner's machine-cycle unit is four PHI periods. His tables are related secondary
sources, not independent corroboration of BR7's 3/3.5 entry. Fairchild specifies
two cycles for BR7 rather than BT/BF's three.

## Saved capture inventory

Metadata in all three `refs/seanriddle.com/*wreset.sal` archives records 12.5 MHz
digital sampling (80 ns samples) and these channel labels:

| Channel | Label | Use |
| --- | --- | --- |
| 0 | 202-7 clock | Unused UV202 CPU-clock output; this is not BRCLK |
| 1 | 3850-38 xtal | Gated external CPU clock |
| 2 | 3850-1 phi | CPU PHI |
| 3 | 3850-37 /reset | Exclude reset and identify restart |
| 4 | 202-2 umi rq0 | UV201 DMA requests |
| 5 | 202-3 cpu rq0 | CPU request 0 |
| 6 | 202-39 cpu rq1 | CPU request 1 |
| 7 | 3850-28 IO16 | Auxiliary I/O activity |

Metadata durations are approximately 11.186 s (`vbnormalwreset.sal`), 10.491 s
(`vbdiagwreset.sal`) and 10.293 s (`vbnobios1wreset.sal`). Names alone do not prove
the ROM bytes or software state. None records BRCLK, WACK, WRITE, ROMC or data.

The older `vbclocksandromcx.jpg` screenshot shows WRITE/ROMC but is a separate
session. `vbxtalyphicrystal.jpg` includes the continuous crystal oscillator,
which is absent from these .sal sessions. Do not combine their sampling rates
or infer a complete opcode stream from the request-only sessions.

The archives contain Saleae's internal format, not its public binary export
format. [Saleae recommends exporting with Logic 2](https://www.saleae.com/support/logic-software/saving-and-exporting-data/sal-file-format).
Metadata inspection is complete; transition measurements from these archives
are not. Logic 2 was not found in the checked standard installation locations
or running processes during this audit.

## Next timing comparison

The gate regression matches an independent ideal U30/U31/U41 model over 76,742
edge decisions. It checks the response to supplied requests and WACK, not the
CPU request-generation phase, UV202 WACK duration, DMA handoffs or propagation.

The 128-offset diagnostic still reports 6-7 lost half-clocks for RAM/cart/RES2
reads and RAM writes, 7-11 for UV201 reads, and 8-9 for UV201 writes, without DMA.
The documented RAM/cart expectation remains 7-9; it has not been weakened.
See [the gate investigation](CPU-CLOCK-GATE.md).

Kevtris's full-speed sunk cost is the last CPU falling edge to the first resumed
falling edge, minus one CPU period. His ASIC service description starts at UV202
request pins, after external synchronizers. It also quotes both 6-9 and 5-8
BRCLK totals for UV201 accesses. Resolve these endpoints before interpreting a
one-BRCLK discrepancy as a missing RTL stage. Full-speed results include
propagation effects absent from the slowed experiments and ideal gate model.

Export the saved sessions and measure same-polarity PHI gaps alongside both CPU
request lines and DMA requests, excluding reset. Start with isolated accesses,
then DMA contention. Compare distributions and phase dependence with an 80 ns
sampling error budget; do not impose the screenshot's 48-clock/3-us pattern on
all workloads. BRCLK/WACK captures would separate admission, service and restart
costs; the existing channels cannot uniquely determine all three.

No bus-wait constants or CPU timing RTL were changed by this audit.
