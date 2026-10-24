# Timing sources and remaining work

CPU active cycles and board elapsed times need separate checks. Correct opcodes
can still finish too early if buffered accesses pause the clock too briefly.

## Source roles

| Source | Establishes | Limits |
| --- | --- | --- |
| Fairchild F3850 Table 3, printed pp. 3-21 through 3-25 (`refs/orphanedgames.com/fairchild-3850.pdf`, PDF pages 15-19) | Instruction ROMC order, short/long cycles, data-bus timing classes, interrupt restrictions | Does not specify VideoBrain arbitration or external clock stopping |
| Fairchild 1975 F8 brochure (`refs/Fairchild_Semiconductor_-_F8_Microprocessor_brochure_-_1975.pdf`), printed pp. 9-11 (PDF pages 11-13) | Manufacturer summary corroborating BR7 totals, branch masks, IN timing and CPU-port timing exceptions | Summary totals do not specify bus phases or VideoBrain waits |
| Osborne, *An Introduction to Microcomputers*, Vol. 2, September 1978 (`refs/Osborne_An_Introduction_to_Microcomputers_Volume_2_Sep78.pdf`), Chapter 2 | Detailed explanation of cycle overlap, WRITE/ROMC boundaries, F8 I/O and timer behavior | Covers both 3870 and F8 devices; some tables disagree internally; device manuals take precedence |
| Fairchild F3852/F3853 manual and Mostek 1978 data book | Timer sequence, division, reload and interrupts | Input frequency and gating depend on the board |
| Fairchild F8 User's Guide, May 1976 (`refs/67095665B_F8_Users_Guide_May76.pdf`) | ROMC 13 resets interrupt circuitry; event G and the explicit 3851-to-3853 interrupt-logic link corroborate the completion boundary | PSU sections need the SMI differences in section 5.1.2 applied |
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

## Additional corroboration: 1975 brochure and Osborne

The 1975 Fairchild brochure's printed p. 9 (PDF page 11) explicitly lists BR7
as 2.5 cycles when taken and 2.0 when not taken. It also shows BT selecting
Z/C/S, BF selecting O/Z/C/S, with any selected true flag sufficient for BT and
all selected flags false required for BF. Printed p. 11 (PDF page 13) gives IN
as four cycles and footnotes INS/OUTS as two cycles for CPU ports. These agree
with the fixes and timing expectations already implemented.

Osborne adds useful detail at these locations:

| Printed page | PDF page | Evidence and consequence |
| --- | --- | --- |
| 2-27, Table 2-2 | 96 | BR7 has short 03 + short 00 when not taken, long 01 + short 00 when taken; no BT/BF-style idle cycle |
| 2-29, Table 2-3 | 98 | The summary contradicts Table 2-2 by giving BR7 3/3.5; this matches Turner's incorrect entry, but does not prove the web table's provenance |
| 2-35 | 104 | Short cycles are four PHI periods, long cycles six; the trailing edge of WRITE defines the cycle boundary |
| 2-36 | 105 | WRITE's trailing edge triggers the next ROMC state; execution overlaps the next opcode fetch, including the final cycle of external-memory/I/O instructions |
| 2-37 | 106 | F8 I/O is inverted and externally low-driven pins combine with output-latch state; reset/power-up pin states are indeterminate, unlike some 3870 ports |
| 2-43 | 112 | The interrupt ROMC sequence is 10, 1C, 0F, 13, 00; timer and external sources cannot both be enabled by the two-bit F8 control code |
| 2-44, Table 2-5 | 113 | Polynomial timer conversion table, including FE=254, C4=100, 28=164 and 7F=0; these are effective count labels, not literal binary counter contents |
| 2-45 | 114 | Timer runs unless FF is loaded, advances once per 31 clocks, and repeats from FE after timeout |
| 2-54 | 123 | Explicitly applies the preceding PSU timer/interrupt description to the 3853, distinguishing its programmable vector and lack of priority output |

The fetch overlap matters when interpreting captures: do not add a separate
fetch cycle to each instruction's published total. Table 2-2 corroborates the
existing timing audit; Table 2-3 must not override its detailed sequence.
Table 2-2 itself has an interrupt-row discrepancy (08 rather than 0F) and lists
INS/OUTS ports 2-15, whereas the Fairchild CPU table documents external short
I/O ports 4-15. Keep those exceptions visible rather than adopting the entire
table as an independent test oracle.

Osborne's initial chapter discussion describes the 3870's different timer/counter
and interrupt controls. It must not be applied to the main-board 3853 timer.
The F8-specific explanation on pp. 2-43 through 2-45, together with the explicit
3853 link on p. 2-54, is the relevant corroboration. The initial two-input-period
timer delay remains established by the F3852/F3853 manual, not this summary.

## F3853 acknowledgement during vector delivery

The Mostek 1978 data book resolves Osborne's ROMC 13 observation with a
device-specific description: printed pp. 171-174 (PDF pages 174-177), Figure 4
and events E-G/Figures 6-7. Event E freezes priority selection in ROMC 10. Event
F supplies vector low in 0F and vector high in 13. Event G clears SERVICE
REQUEST and the appropriate source latch at the 13-to-00 boundary, as the
first ISR instruction fetch begins. Both timer and external timing diagrams
retain their request through vector delivery. This is stronger evidence than
the secondary source's description of a reset somewhere during ROMC 13.

The newly added Fairchild May 1976 User's Guide independently corroborates
this: Table 2-5, printed p. 2-13 (PDF page 54), assigns the interrupt-circuit
reset to ROMC 13; section 3.6.2, printed p. 3-21 (PDF page 90), places event G
at the first ISR fetch. Section 5.1.2, printed p. 5-2 (PDF page 121), explicitly
links the 3853 timer/interrupt handling to the PSU logic, with differences in
priority output and programmable vector. The February 1976 guide makes the
same device link in section 5.1.2 (printed p. 5-5, PDF page 227). The November
1977 compilation retains the May 1976 revision marking on its SMI description
(printed p. 5-1, PDF page 119); its filename does not make that device section
a newer revision. These guides corroborate rather than contradict Mostek's
device-specific sequence.

The former `f8_busif` acknowledgement in ROMC 0F phase 1 cleared the source
early. A further event latched after that clear but before completion could
leave an extra interrupt pending, whereas the documented single request latch
is still set until event G. The bus interface now emits its one-MCLK pulse at
ROMC 13 phase 11; the F3853 consumes it on the following MCLK, at the beginning
of the ISR fetch. The CPU's vector/return-address updates and cycle lengths
are unchanged. This moves the acknowledgement telemetry endpoint by 11 PHI
periods; old IRQ-to-ack measurements must retain their original endpoint.
`audit_audio_irq.py` uses the corrected completion endpoint by default; use
`--legacy-early-ack` only for captures from the old ROMC 0F implementation.

Printed p. 172 specifies separate clears: timer load or timer acknowledgement
clears TIMER INTERRUPT; a control write or external acknowledgement clears
EXTERNAL INTERRUPT. Masked timer timeouts remain latched. Figure 4 shows the
source-clear inputs taking precedence over their set/feedback paths. Existing
F3853 source-specific clear, simultaneous acknowledge/expiry, and reload
priority therefore remain unchanged.

No vector latch is needed for new pending events in this single-SMI system:
bit 7 follows the interrupt control mode, not pending-source arbitration.
The CPU executes no I/O writes during 10, 1C, 0F, 13, so neither the mode nor
the programmable vector can change between byte deliveries. A masked timer
expiry during external entry cannot switch the vector or be cleared by the
external acknowledgement. This does not implement multi-device daisy chaining
or guarantee behavior under artificial concurrent register writes.

`make test-smi` includes 104 source/event/half-phase cases across both vector
states and the clearing boundary, checking pending requests, vector bytes,
saved PC, acknowledgement pulse width and enable gating. It also checks
acknowledge/expiry and acknowledge/expiry/reload collisions at dividers 31 and
1. Event offsets refer to the existing RTL's latch inputs: Mostek's two WRITE
synchronizers on each physical interrupt input are not reproduced by this
model, so these tests do not establish pin-edge setup/hold or exact latency
for a physical request arriving immediately around event G. The corrected
acknowledgement and the earlier gated-PHI timer-input change still require
hardware confirmation.

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

No bus-wait constants were changed. The acknowledgement correction above is
separate from the unresolved wait-duration investigation.
