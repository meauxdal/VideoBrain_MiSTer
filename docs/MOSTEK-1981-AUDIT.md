# Mostek 1981 F8/3870 source audit

Checked 2026-10-24 against
`refs/datasheets-databooks-fairchild-mostek-manuals/1981_3870_F8_Microcomputer_Data_Book.pdf`
(586 PDF pages), the corresponding 1978 volume and current RTL. Printed page
numbers below are followed by one-based PDF page numbers.

The new volume is useful corroboration and exposes unresolved 3870 questions.
It is not a blanket replacement for the earlier device manuals. No separately
labelled errata section was found in the contents or searchable text. Relevant
instruction tables and interrupt diagrams were also visually inspected; OCR
alone loses table alignment, overbars and symbols.

## Which material is actually newer evidence?

The 1981 F8 device section, IV-1 through IV-14 (PDF 274-287), contains brief
descriptions and pinouts. The MK3850 entry is IV-1 (PDF 274), and the MK3853
entry is IV-7 (PDF 280). The latter is visibly marked **NOT FOR NEW DESIGNS**.
Its facing page is blank. There is no replacement detailed SMI timing chapter,
polynomial timer table or acknowledgement diagram here. Keep the 1978 SMI
chapter and Fairchild F3852/F3853 manual as the detailed device references.
The book's 1981 publication date does not establish a later silicon revision
or an erratum to every reprinted device description.

The subsequent [1979-volume comparison](MOSTEK-1979-AUDIT.md) locates the
intervening detailed F8 chapters. They retain the SMI completion boundary and
main-board opcode sequences; the same volume contains both the 3870/F3850
DI/EI discrepancy and the differing POP descriptions. It also records changed
decimal-flag annotations and a reversed LISL/LISU entry in the 3870 summary.

The [Fairchild F8/F3870 reference card comparison](F8-REFERENCE-CARD-AUDIT.md)
adds manufacturer evidence listing two-cycle DI/EI and POP as a copy under a
shared F8/F3870 title, while excluding XDC for F387X. These disagree with the
Mostek 3870 descriptions in different ways; vendor/device identity remains
part of the unresolved audit rather than treating all 3870-labelled sources
as interchangeable.

The substantial technical manual in section III describes the single-chip
**3870 family**. This is relevant to Expander 1, but its internal binary timer
and internal interrupt diagrams must not be applied to the main-board 3853.
The new part-number cross-reference, III-10 (PDF 35), identifies the original
MK3870 as MK3870/20; the family also includes parts with executable RAM and
serial hardware absent from the original MK3870.

## Corroboration

| Evidence | Location in 1981 volume | Consequence |
| --- | --- | --- |
| Sign is the complement of result bit 7; overflow is carry out of bit 6 XOR carry out of bit 7 | III-16/17 (PDF 41/42), sections 4.5.1 and 4.5.4 | Supports current ALU conventions; contradicts Optable's prose definitions |
| AMD and CM affect all four arithmetic flags | III-60/61 (PDF 85/86), Table 8-4 | Supports the issue-12 correction; not an exhaustive definition of decimal flag values |
| PK is long + long + short, 8 us at 2 MHz PHI | III-62 (PDF 87), Table 8-4 | Supports the current F8 total of four four-PHI units |
| Q/DC/H register mappings and LR J,W direction | III-63/64 (PDF 88/89), Table 8-4 | Agrees with the mappings already used in the core |
| 3870 timer uses half the external time-base frequency, with prescales 2/5/10/20/40/100/200 | III-25 (PDF 50), section 5.2 | Supports Expander clock and timer division |
| Timer reload is 01-to-N; N=00 means 256 counts; timer requests survive masking; load or acknowledgement clears them | III-26 (PDF 51), section 5.3 | Supports current 3870 timer's functional model |
| External requests require local enable; disabling clears them; pulse-width mode uses the trailing edge, other modes the leading edge | III-29/30 (PDF 54/55), sections 5.4-5.6 | Supports current mode/edge/latch rules |
| Timer wins simultaneous requests; vectors are 0020 and 00A0 | III-30/31 (PDF 55/56), section 5.7 | Supports the functional priority and vector values |

These timer, interrupt and error-budget descriptions substantially repeat the
1978 MK3870 material, printed pp. 10-15 and 24 (PDF 13-18 and 27). Repetition
is corroboration of the documented specification, not independent hardware
measurement or evidence that a behavior changed between 1978 and 1981.

## Conflicts and limits to preserve

| Question | Source evidence | Current implementation / disposition |
| --- | --- | --- |
| DI/EI duration on a 3870 | III-64 (PDF 89) lists one short cycle, 2 us each at 2 MHz PHI. The 1978 MK3870 table, printed p. 21 (PDF 24), already gives the same totals. Fairchild's F3850 table specifies two short cycles. | Expander uses the shared F3850 CPU's two-short-cycle sequence. This is an inherited device/source conflict to resolve with 3870-specific evidence, not a demonstrated 1981 change or grounds to shorten main-board instructions. |
| POP on a 3870 | III-57, III-62 and III-194 (PDF 82, 87, 219) describe exchanging PO and P. | Shared `f8_busif` ROMC 04 copies PC1 to PC0 without changing PC1, matching the F3850 sequence. Determine whether the exchange description is an actual 3870 distinction or a documentation error before changing Expander return semantics. |
| Request/vector-selection boundary | III-37 (PDF 62), event B, inhibits changes to priority at the end of the freeze cycle. | Expander selects its source at ROMC 0F phase 1. A request arriving between freeze and selection needs a focused 3870 audit. Normal priority tests alone do not establish this boundary. |
| Source-clear and ICB-clear boundary | III-37/38 (PDF 62/63), events E/F and Figure 6-4, place vector-high delivery in a long cycle, then request/ICB clear in the short first-ISR-fetch cycle. This wording is already in 1978 printed p. 13 (PDF 16). | Expander clears its selected request in ROMC 13 phase 6; shared CPU clears ICB there too. This is earlier than the stated fetch cycle. Exact clear edge and simultaneous new-event behavior remain unresolved. The main-board F3853 completion audit is a separate device-specific result. |
| Timer read/load and request synchronization | III-26, III-39 and III-94 (PDF 51, 64, 119) describe synchronization to machine cycles and explicitly bounded timing errors. | Current timer is a functional counter with direct readback and event latches, not the documented internal synchronizer pipeline. Do not interpret passing timer tests as exact pin-to-ISR or readback-phase accuracy. |
| Reset state and timing | III-20/21 (PDF 45/46), section 4.9, preserves the interrupted PO in P and recognizes reset at a machine-cycle boundary, possibly during a multicycle instruction. | Shared bus reset clears both PC registers. This reset-state limitation is not new to 1981 and needs device-specific treatment if software depends on the saved P. |

The timer error tables define their endpoints: OUT/OUTS load/start/stop times
are referenced to the end of the last instruction machine cycle; IN/INS reads
use that instruction's last-cycle endpoint; interrupt generation is referenced
to the start of the cycle setting the request latch. They specify free-running
single-interval error of +/-6 PHI periods with zero cumulative error, and
load-to-request error of -2 through -9 PHI periods. These are 3870 timing bounds,
not constants to insert into the 3853 timer or UV202 wait logic.

## Errors within the newer book

The instruction-timing introduction, III-60 (PDF 85), says to scale its 4 MHz
time-base timings by `(time base frequency)/4 MHz`. For elapsed time the ratio
must be inverted: `4 MHz/(time base frequency)`. Cycle counts remain the safer
reference.

Table 8-4 omits a BR7 timing row even though III-52/53 (PDF 77/78) describes
the instruction and III-56 (PDF 81) lists it. It therefore supplies no new BR7
total to override Fairchild's detailed short/long sequence. Its LR W,J row
gives 4 us but prints only one S, rather than the two short cycles needed for
that total. The table must be read with these omissions visible.

## Validation and next work

No RTL or timing constants were changed in this audit. On 2026-10-24,
`make test-cpu-opcode-timing test-expander1` passed all 968 opcode timing cases,
the 3870 timer prescale/mode/readback/interrupt checks and the synthetic
Expander host-interface/ISR/mask/reset checks. The Expander integration run
also emits numeric_std metavalue warnings. These passes establish the existing
functional baseline; they do not resolve the conflicting source claims above.

Next distinguish 3870 DI/EI and POP behavior from F3850 behavior, and derive
3870 source selection/acknowledgement and timer read/load boundaries from a
consistent instruction/WRITE timeline. Any implementation correction needs
focused cases that distinguish the old and proposed behavior, followed by
original-ROM cassette and serial regressions. Keep shared-CPU changes from
silently altering the main-board F8 while resolving Expander differences.
