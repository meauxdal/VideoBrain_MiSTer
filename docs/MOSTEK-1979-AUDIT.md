# Mostek 1979 F8/3870 source comparison

Checked 2026-10-24. Source:
[Mostek 1979 Microcomputer Products Data Book](https://bitsavers.trailing-edge.com/components/mostek/_dataBooks/1979_Mostek_Microcomputer_Products_Data_Book.pdf).
The title/copyright pages identify June 1979, publication MK79707. The PDF has
848 pages. Locations below give printed pages and one-based PDF pages.

This volume contains the detailed F8 device chapters absent from the 1981
volume. Compared the MK3850 and MK3853 chapters with their 1978 counterparts,
and the original MK3870 instruction/timer material relevant to the open
[3870 audit questions](MOSTEK-1981-AUDIT.md). Relevant instruction tables,
timer logic and interrupt diagrams were visually checked because text
extraction drops overbars, exchange arrows and table alignment.

## Chapter locations

| Device | 1979 printed pages | 1979 PDF pages | Corresponding 1978 PDF pages |
| --- | --- | --- | --- |
| MK3870 | 327-360 | 350-383 | 6-39 |
| MK3850 | 441-466 | 464-489 | 106-131 |
| MK3853 | 503-520 | 526-543 | 168-185 |

The detailed MK3850 comparison covered PDF 464-487, including the complete
instruction table and electrical/timing specifications. The MK3853 comparison
covered PDF 526-543. The MK3870 comparison covered PDF 350-383. These are
targeted device comparisons, not an audit of the book's Z80 and development
system sections. Later publication alone does not establish new silicon or
make every inherited entry an erratum to earlier manuals.

## Main-board F8 results

| Subject | 1979 evidence | Assessment |
| --- | --- | --- |
| Clock/cycle units | p. 444 (PDF 467), p. 448 (PDF 471) | WRITE falling edge begins a machine cycle; short/long cycles remain four/six PHI periods. |
| PK | p. 451 (PDF 474), Table 4 | Long 12, long 14, short 00: 16 PHI periods, agreeing with the core and 1978/Fairchild. |
| DI/EI and status transfers | p. 452 (PDF 475), Table 4 | DI/EI and LR W,J each have short 1C + short 00. LR J,W is one short 00. No main-board timing correction. |
| POP | p. 452 (PDF 475), Table 4; p. 505 (PDF 528), stack-register description | Copies P to PO. It does not describe exchanging them. Supports current main-board ROMC 04 behavior. |
| BR7 | p. 454 (PDF 477), Table 4 | Short 03 + short 00 if ISAR low = 7; long 01 + short 00 otherwise. Confirms 2 / 2.5 four-PHI units. |
| CM and decimal flags | pp. 453/454 (PDF 476/477), Table 4 | CM affects O/Z/C/S. AMD/ASD mark C result-dependent and O/Z/S with question marks; the legend on p. 451 says a question mark means the flag has no meaning. This does not specify preserving or clearing those bits. |
| SMI timer | pp. 507/508 (PDF 530/531), Figure 2 and Table 2 | Retains the /31 prescaler, polynomial feedback, FE timeout decode, FF stop state, and 255-count repeat interval. The count table retains 7F=0, C4=100, C8=215 and FE=254. The summary count-times-31 formula does not replace the earlier device manual's initial-clock phase description. |
| SMI interrupt source rules | pp. 508-510 (PDF 531-533), Figure 4 | Retains mutually exclusive timer/external enable modes, masked timer-event retention, and source-specific clears. Control writes clear the external request; timer loads clear the timer request. |
| SMI acknowledgement | pp. 509-512 (PDF 532-535), Figures 4, 6 and 7 | Freeze in ROMC 10; sequence 10, 1C, 0F, 13, 00; event G clears SERVICE REQUEST and the selected source as the first ISR fetch begins. Corroborates the existing main-board completion correction. |
| PC versus DC memory timing | pp. 514-518 (PDF 537-541), electrical table and Figures 10-13 | Retains later DC address timing, distinct from PC addressing, and late RAM WRITE timing. Supports the distinctions used in the DC0 phase audit; does not determine UV202 admission/service duration. |

The examined main-board timing descriptions and diagrams substantially
reproduce the 1978 chapters. No change found here overturns the current opcode
sequence, SMI acknowledgement endpoint or DC0 pause-position corrections.
The latter still rely on original-machine captures as well as device timing
classes; neither book specifies VideoBrain's external clock gate or UV202 waits.

## What changes or remains inconsistent in the 3870 material?

The 1979 MK3870 chapter still says it executes the entire F8 instruction set
with exact F8 timing (p. 343, PDF 366). However, its own miscellaneous table,
p. 345 (PDF 368), gives DI and EI one short cycle and 2 us each at 2 MHz PHI.
The MK3850 table in this same volume specifies two short cycles. Thus the
3870/F3850 discrepancy exists within one edition, rather than being explained
by the newer publication date. It remains a device/source conflict, not a
reason to shorten the main-board instructions.

The MK3870 POP row on p. 344 (PDF 367) uses the two-arrow **exchange** symbol,
as does the 1978 row on printed p. 20 (PDF 23). This agrees with the explicit
1981 exchange descriptions. The MK3850 chapter instead describes a one-way
copy. This strengthens the documented device distinction but does not resolve
whether the 3870 exchange claim represents silicon behavior or a repeated
documentation error. Current shared RTL implements the F3850 copy.

There is an actual annotation change between editions: on p. 344 (PDF 367),
the MK3870 AMD/ASD rows mark O/Z/S `?` and C `1/0`; the corresponding 1978
table on p. 20 (PDF 23) marks all four `1/0`. The 1979 legend on p. 345
(PDF 368) defines `?` as having no meaning. The 1981 table again marks all four
as modified. These annotations do not define exact O/Z/S values after decimal
adjustment and do not establish a hardware change. Keep the distinction
between an affected flag and a useful decimal arithmetic condition.

The interrupt event descriptions, p. 337 (PDF 360), retain the same freeze,
vector delivery and first-ISR-fetch source/ICB clear description as 1978 and
1981. The current Expander selection/clear phase and timer synchronization
questions therefore remain open. No new pin-edge latency has been inferred
from a repeated diagram or an instruction total.

## Errors not to import

The 1979 MK3870 miscellaneous table on p. 345 (PDF 368) reverses the LISL/LISU
opcode patterns: it prints LISL as `6(1bbb)` and LISU as `6(0bbb)`. The detailed
MK3850 table on p. 453 (PDF 476) correctly gives LISU `6e` and LISL `68+e`.
This is a conflicting summary entry, not grounds to reverse the implemented
opcodes. The 1978 MK3870 table on p. 21 (PDF 24) has the correct patterns.

The SMI event-E text on p. 511 (PDF 534) retains `ICB = 0` as the enabled
condition. The CPU's own status description on p. 444 (PDF 467) explicitly
says interrupts are allowed with ICB = 1; DI/EI in Table 4 corroborate that.
The event-E sentence must not invert the core's interrupt-enable sense.

No RTL or timing constants changed. This was a source/documentation comparison;
the existing passing simulation baseline recorded in the 1981 audit was not
rerun, and does not settle the 3870-specific conflicts. Further changes need
tests that distinguish the candidate device behaviors and retain the
main-board F3850 expectations separately.
