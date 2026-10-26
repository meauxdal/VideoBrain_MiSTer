# Timing sources and remaining work

CPU active cycles and board elapsed times need separate checks. Correct opcodes
can still finish too early if buffered accesses pause the clock too briefly.

## Source roles

| Source | Establishes | Limits |
| --- | --- | --- |
| [Fairchild F3850](https://datasheets.chipdb.org/Fairchild/F8/fairchild-3850.pdf), Table 3, printed pp. 3-21 through 3-25 (PDF pages 15-19) | Instruction ROMC order, short/long cycles, data-bus timing classes, interrupt restrictions | Does not specify VideoBrain arbitration or external clock stopping |
| Fairchild F8/F3870 User Reference Card, `2033-249-A-75-020` | Manufacturer summary corroborates PK=4, DI/EI=2, BR7=2/2.5, register mappings and arithmetic flag effects | Internal BR7/DC-update errors and F387X scope conflicts; no ROMC phases; see the [card comparison](F8-REFERENCE-CARD-AUDIT.md) |
| [Fairchild 1975 F8 brochure](https://bitsavers.trailing-edge.com/components/fairchild/f8/Fairchild_Semiconductor_-_F8_Microprocessor_brochure_-_1975.pdf), printed pp. 9-11 (PDF pages 11-13) | Manufacturer summary corroborating BR7 totals, branch masks, IN timing and CPU-port timing exceptions | Summary totals do not specify bus phases or VideoBrain waits |
| Osborne, [*An Introduction to Microcomputers*, Vol. 2, September 1978](https://bitsavers.computerhistory.org/pdf/osborne/books/Osborne_An_Introduction_to_Microcomputers_Volume_2_Sep78.pdf), Chapter 2 | Detailed explanation of cycle overlap, WRITE/ROMC boundaries, F8 I/O and timer behavior | Covers both 3870 and F8 devices; some tables disagree internally; device manuals take precedence |
| Terry Dollhoff, 1979 F8 chapter, [Sean Riddle's scan](https://www.seanriddle.com/f8_info.pdf), printed pp. 70-79 | Separately authored explanation and instruction byte lengths/totals; explicitly defines a short cycle as four clock periods | PK and DI/EI totals conflict with detailed MK3850 sequences; excerpt does not establish table derivation or independent timing measurements |
| Fairchild F3852/F3853 manual and Mostek 1978 data book | Timer sequence, division, reload and interrupts | Input frequency and gating depend on the board |
| [Mostek June 1979 Microcomputer Products Data Book](https://bitsavers.trailing-edge.com/components/mostek/_dataBooks/1979_Mostek_Microcomputer_Products_Data_Book.pdf) | Detailed MK3850/MK3853 timing chapters corroborate the 1978 sequences and completion boundary | Repeated material is not a new hardware measurement; 3870 summary conflicts and decimal-flag annotations remain visible in the [1979 comparison](MOSTEK-1979-AUDIT.md) |
| [Mostek 1981 3870/F8 data book](https://bitsavers.trailing-edge.com/components/mostek/f8/1981_3870_F8_Microcomputer_Data_Book.pdf) | Later 3870 technical manual, instruction tables and timer/interrupt timing bounds | F8 device pages are brief summaries; inherited conflicts and 3870 distinctions need separate treatment; see the [1981 audit](MOSTEK-1981-AUDIT.md) |
| [Fairchild F8 User's Guide, May 1976](https://bitsavers.trailing-edge.com/components/fairchild/f8/67095665B_F8_Users_Guide_May76.pdf) | ROMC 13 resets interrupt circuitry; event G and the explicit 3851-to-3853 interrupt-logic link corroborate the completion boundary | PSU sections need the SMI differences in section 5.1.2 applied |
| Sean Riddle's connection records and photographs | Net connections and external gate topology | Do not establish propagation delays or internal ASIC behavior |
| Sean's original-machine captures | Observed clocks and requests | Depend on recorded channels, sample resolution, reset and software state |
| Kevtris, *VideoBrain Unwrapped*, Wait States section | UV202 service timing and full-speed CPU halt measurements | Separates a slowed, clock-modified machine from full-speed operation; interval endpoints differ |
| Turner's [overview](https://www.nyx.net/~lturner/public_html/Fairchild_F8.html), [instruction details](https://www.nyx.net/~lturner/public_html/F8_ins.html) and [opcode summary](https://www.nyx.net/~lturner/public_html/F8_opcodes.html) | Instruction index and timing cross-check | Contains discrepancies; resolve them with the device manuals |
| Tobias V. Langhoff's [F8 Optable](https://tobiasvl.github.io/optable/f8/) and [opcode data](https://github.com/tobiasvl/optable/blob/master/_data/f8/opcodes.json), checked 2026-10-24 | Searchable opcode index and instruction-total cross-check; the page credits Pastraiser | Six documented opcode totals disagree with Fairchild Table 3; no ROMC phases or VideoBrain waits; its linked errata page returns 404 |
| E5frog's [Veswiki Opcode page, revision 786](https://channelf.se/veswiki/index.php?title=Opcode&oldid=786), edited 2026-08-07 | Detailed S/L and ROMC columns corroborate the manufacturer sequences, including BR7 | Credits Dollhoff, Turner and the 1976 guide; five totals contradict its own S/L sequences; see the [revision audit](VESWIKI-OPCODE-AUDIT.md) |
| MAME and our regressions | Executable models and checks of explicit expectations | Agreement between models is not a hardware timing measurement |

Use manufacturer tables for instruction expectations and board measurements for
VideoBrain waits. Preserve conflicting observations and their endpoints rather
than adjusting constants to average them together.

## Excluded namesake: Krause's 2024 `f8 Manual`

The *f8 Manual* is a 23-page draft by Philipp Klaus Krause dated July 29, 2024. Reviewed on 2026-10-24;
its `f8` describes a different instruction-set architecture. Pages 3-4 specify
reset PC=4000, a memory stack with SP, register pairs X/Y/Z, an H/C/N/Z/O flag
layout and prefix bytes. Page 21 assigns opcode 00 to a trap. These are not
the Fairchild F8's accumulator/scratchpad/ISAR architecture, IOZCS register or
opcode 00 (`LR A,KU`). The draft's incomplete opcode-map chapter on page 23
does not supply historical F8 timing evidence. Retain this exclusion to avoid
importing namesake instruction, flag, reset or stack semantics into the core.
No RTL or test expectation changes follow from this document.

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

## F8 Optable comparison, 2026-10-24

Compared the published opcode JSON's totals with the Fairchild Table 3
expectations used by `tb_cpu_opcode_timing.vhd`, excluding the same 14
undocumented/reserved encodings. Of 242 documented opcodes, 236 agree and six
disagree. For conditional instructions this compares the possible taken and
not-taken totals; it does not validate branch conditions or instruction semantics.

The units below are four PHI periods, including the overlapping terminating
fetch. A short cycle contributes 1 and a long cycle 1.5. These are active-clock
totals, so external clock stops can increase elapsed time.

| Opcode | Instruction | Optable total | Fairchild Table 3 / current core | Fairchild ROMC sequence |
| --- | --- | --- | --- | --- |
| 0C | PK | 2.5 | 4 | long 12, long 14, short 00 |
| 1A | DI | 1 | 2 | short 1C, short 00 |
| 1B | EI | 1 | 2 | short 1C, short 00 |
| 1D | LR W,J | 1 | 2 | short 1C, short 00 |
| 1E | LR J,W | 2 | 1 | short 00 |
| 8F | BR7 | 3 / 3.5 | 2 / 2.5 | short 03 / long 01, then short 00 |

BR7 totals are not-taken / taken. Its Optable entry repeats the discrepancy
already identified in other summary tables; it supplies no new bus-sequence
evidence to overturn the manufacturer sequence. PK's 4-unit total is 16 PHI
periods, not the 10 implied by 2.5. DI, EI and LR W,J each require eight PHI
periods, while LR J,W requires four. The existing execution regression was rerun
for this comparison: all 968 cases passed, including these six opcodes.

Optable correctly gives IN as 4 and distinguishes INS/OUTS ports 0/1 (2)
from the documented external short-address ports 4-15 (4). It also assigns
external-port behavior to reserved encodings A2/A3/B2/B3; those remain outside
our documented-opcode audit. Its JSON labels both 1D and 1E as LR W,J, although
1E transfers in the opposite direction. The combined F3850/MK3870 title and
instruction totals do not establish VideoBrain-specific bus phases, interrupt
acknowledgement timing or UV202 wait durations.

This comparison changes no RTL or timing expectations. Treat the page as a
convenient index with recorded exceptions, rather than another independent
hardware timing measurement. The page explicitly credits Pastraiser; matching
entries across those two sites therefore do not establish independent provenance.

### Upstream corrections: issue 12

In [Optable issue 12](https://github.com/tobiasvl/optable/issues/12), opened
2026-07-01, e5frog reports corrections to the register mappings, AMD/CM flags
and BR7 timing. Checked on 2026-10-24 against the local 1976 Fairchild manuals:

| Correction | Manufacturer evidence | Current core |
| --- | --- | --- |
| 0E = LR Q,DC; 0F = LR DC,Q; 10 = LR DC,H | May 1976 User's Guide, Table 2-7, printed p. 2-18 (PDF page 59); 1976 Guide to Programming, Appendix D, printed p. D-2 (PDF page 113) | Already matches; 11 is LR H,DC |
| 1E = LR J,W | Same manufacturer tables | Already matches; 1D is LR W,J |
| 89 AMD modifies O/Z/C/S, preserves I | User's Guide, Table 2-7, printed p. 2-19 (PDF page 60); Guide to Programming, section 6.4, printed pp. 6-3/6-4 (PDF pages 40/41), and p. D-2 | Uses OP_ADDD, which updates all four arithmetic flags and preserves I |
| 8D CM modifies O/Z/C/S, preserves I | User's Guide, Table 2-7, printed p. 2-20 (PDF page 61); Guide to Programming, sections 6.8/6.10, printed p. 6-7 (PDF page 44), and p. D-2 | Uses OP_CMP, which updates flags without writing the accumulator |
| 8F BR7 = 2 / 2.5 | User's Guide, Table 2-7, printed p. 2-20 (PDF page 61); the earlier manufacturer sequence/brochure audit above | Already matches |

The programming guide calls AMD's overflow/sign statuses not significant and
explicitly says other status indicators are modified. This is not an instruction
to preserve them or force them to zero. The summary in Appendix D marks all
four arithmetic flags as affected for both AMD and CM. In the current RTL,
AMD computes those flags from the binary sum before applying decimal correction;
that observation describes the implementation, not an exhaustive flag-value
validation from these summary tables.

The issue provides a useful correction trail for the published table. Its
claims above are supported by the manufacturer documents cited above;
the cited Dollhoff book and veswiki were not needed to establish them here.
No RTL change follows from these corrections. The 968-case timing test checks
cycle sequences and durations, not AMD/CM flag semantics; the flag statements
above were checked against the RTL and manuals rather than inferred from that
test's pass result.

## Dollhoff instruction lengths and totals (`f8_info.pdf`)

Reviewed all five scanned spreads on 2026-10-24. The handwritten attribution
on PDF page 1 identifies Terry Dollhoff, *16 bit Microprocessor Architecture*,
1979; this matches the book reference in Optable issue 12. The excerpt contains
printed pp. 70-79, with the length/timing table on pp. 78-79 (PDF page 5).
It is a separately authored secondary reference, rather than another manufacturer
databook printing. Its derivation and any underlying timing measurements are
not stated in the excerpt, so independence of authorship should not be confused
with independent hardware measurement.

Printed p. 77 (PDF page 4) explicitly defines a short cycle as four basic
clock periods: at 2 MHz it is 2 us. The timing column is in these short-cycle
units, and the larger conditional-branch total applies when taken. The `Len`
column gives bytes, not machine cycles. Its listed instruction byte lengths
agree with our decode: three bytes for JMP/PI/DCI, two for immediate ALU,
long-address IN/OUT and relative branches, and one for the remaining rows.
This does not check program-counter sequencing at every intermediate ROMC phase.

| Entry on pp. 78-79 | Dollhoff total | Detailed MK3850 / current core | Assessment |
| --- | --- | --- | --- |
| BR7, not taken / taken | 2 / 2.5 | 2 / 2.5 | Corroborates the corrected two-cycle sequence |
| IN and OUT with immediate port address | 4 | 4 | Corroborates long-address I/O totals |
| INS/OUTS ports 0/1; ports 4-7 | 2; 4 | 2; 4 | Corroborates CPU-port exception; table does not enumerate ports 8-15 |
| LR J,W; LR W,J | 1; 2 | 1; 2 | Correct direction and distinct totals |
| PK | 2.5 | 4 | Conflicts with long 12 + long 14 + short 00 |
| DI and EI | 1 each | 2 each | Matches the shorter Mostek 3870 summary, but not the detailed MK3850 sequence |

Other table totals agree with the current documented instruction families,
including DS 1.5, ASD 2, PI 6.5, JMP 5.5 and DCI 6. The three conflicting
instruction totals above do not justify changing the main-board F8. The DI/EI
entries also do not independently settle the 3870-specific conflict: the
chapter discusses both single-chip and multichip F8s without assigning separate
DI/EI timings to each. POP is described as `PO=P`, not an exchange, but that
generic summary likewise does not resolve the specific 3870 exchange claim.

The prose supplies useful semantic cross-checks: printed p. 75 states S=1
for a plus result and warns that JMP/PI modify A; p. 76 describes compare as
operand minus A and the required H'66' preparation for decimal addition.
Printed p. 74 correctly confines indirect post-increment/decrement to ISAR's
low three bits, despite the table shorthand `ISAR=ISAR+1/-1` on pp. 77-78.
The p. 77 statement that timer and external interrupts cannot both be enabled
fits the older multichip peripheral control, not the 3870's separate enables.

This adds corroboration for instruction lengths and selected totals, especially
BR7, but no bus-phase, SMI synchronization or VideoBrain wait measurement.
No RTL or test expectations changed, and simulations were not rerun for this
documentation-only comparison.

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
Comparisons of old ROMC 0F captures with current traces must account for that
endpoint change.

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

Metadata in Sean Riddle's three reset-capture archives listed below records 12.5 MHz
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
The CSV exports were analyzed on 2026-10-24, together with a separate Timeshare
Logic 1 bus capture, the paired diagnostic ROM and the Money Minder cassette
transition CSV. See [the measured capture report](LOGIC-CAPTURE-ANALYSIS.md) for
methods, counts, original-machine versus simulation comparisons and limits.

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

The exported sessions now provide same-polarity PHI gap distributions alongside
CPU/DMA requests, with reset exclusion and an 80 ns sampling grid. Clean read
code 11 gaps in the normal capture cluster around 1.76/2.00 us, so adding delay
solely to meet the older approximate sunk-cost account is not justified. See
the capture report before interpreting the previous regression bounds as
original-machine measurements. Next resolve access-specific service and request
phase using a matched workload. BRCLK/WACK captures would separate admission,
service and restart costs; the existing channels cannot uniquely determine all
three. Do not impose one screenshot's pattern on every workload.

No bus-wait constants were changed. The acknowledgement correction above is
separate from the unresolved wait-duration investigation.

The follow-up [UV201 phase audit](UV201-PHASE-AUDIT.md) compares the position of
the pause within each long memory cycle, not just its duration. Captured DC0
reads pause after the third PHI falling edge and writes after the fourth; the
former bus interface paused after the first/second. ROMC 02/05 request placement
and the corresponding CPU read-data consumption have been corrected without
altering the active cycle totals or arbiter wait constants. The same audit
records the necessary separation of the Expander 3870 vector-selection strobe
from the main-board F3853's completion acknowledgement.
