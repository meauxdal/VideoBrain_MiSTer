# Fairchild F8/F3870 reference-card comparison

Checked 2026-10-24 against
`refs/datasheets-databooks-fairchild-mostek-manuals/2033-249-A-75-020_F8_User_Reference_Card.pdf`.
The two-page PDF scans a Fairchild **F8 and F3870 Microprocessor User Reference
Card**. The printed identifier is `2033-249-A-75-020/5M/500526`.
No publication year is assigned here solely from the identifier or filename.

PDF page 1 contains numerical and alphabetical opcode listings, register
organization, port assignments and local interrupt controls. PDF page 2 has
instruction groups, flag effects, byte lengths, totals, branch-condition
tables and footnotes. Both pages and enlarged instruction panels were
visually inspected; OCR misreads codes, overbars and conditional totals.

## Corroboration of main-board F8 behavior

| Subject | Card evidence | Result against current expectations |
| --- | --- | --- |
| PK | Page 1, numerical/alphabetical listings; page 2, Program Counter Instructions: one byte, four cycles | Agrees with detailed F3850/MK3850 long 12 + long 14 + short 00; contradicts Dollhoff/Optable's 2.5 |
| DI/EI | Both pages give one byte and two cycles each; DI resets ICB, EI sets it | Supports current main-board timing and enable sense |
| LR W,J / LR J,W | Page 1 listings and page 2 Status Register Instructions give two / one cycles respectively | Supports direction and distinct totals |
| BR7 | Page 1 numerical listing gives 2.5 / 2; page 2 Branch Instructions explicitly gives 2.5 when ISAR low != 7 and 2.0 when equal to 7 | Supports current 2 / 2.5 not-taken/taken totals; see alphabetical-list error below |
| IN/OUT and short I/O | Page 2 Input/Output Instructions gives four cycles, with footnote reducing CPU-port INS/OUTS to two and marking that exception non-privileged | Supports long-address totals, CPU-port exception and interrupt restriction |
| Register mappings | Both pages: 0E = LR Q,DC; 0F = LR DC,Q; 10 = LR DC,H; 11 = LR H,DC; 1E = LR J,W | Agrees with implementation and issue-12 corrections |
| AMD, ASD and CM | Page 2 Memory Reference / Scratchpad Register Instructions marks O/Z/C/S `1/0` for all three | Supports affected arithmetic flags, rather than preserving them or clearing O/C as Optable specifies for AMD; exact decimal flag values are not defined by that notation |
| POP | Page 2 Program Counter Instructions gives `PC0 <- (PC1)`, one byte, two cycles | Supports F8 copy semantics, not an exchange |
| Branch masks | Page 2 Branch Instructions and BT/BF condition tables: BT tests any selected Z/C/S bit; BF requires all selected O/Z/C/S bits false | Agrees with current mask semantics; BT 0 is a two-byte, three-cycle no-op |
| Indirect scratchpad modes | Page 1 Register Organization explicitly limits increment/decrement to ISARL and preserves ISARU | Agrees with low-three-bit wrapping |
| SMI registers and enable codes | Page 1 assigns 0C/0D vector bytes, 0E interrupt control and 0F timer; control 00/10 disables, 01 selects external, 11 selects internal | Agrees with main-board 3853 register decode and mutually exclusive source enables |

The timing totals use the same short-cycle units as the other audited tables:
one unit corresponds to four PHI periods. The card is an instruction summary;
it does not give ROMC sequences or establish VideoBrain waits. Byte lengths
for the entries above also agree with the current decode. The grouped table
additionally retains PI 3 bytes / 6.5, JMP 3 / 5.5, DCI 3 / 6, DS 1 / 1.5,
and ASD 1 / 2.

## Internal errors and device scope

- **BR7:** page 1's alphabetical listing prints `2.5/3`, contradicting both its
  own numerical listing (`2.5/2`) and the explicit taken/not-taken rows on
  page 2. The footnote says to use the second number when not taken. The
  generic page-2 branch heading also claims three cycles when not taken;
  BR7 is an explicit exception to that heading. Use its detailed rows, not
  the erroneous alphabetical total or blanket heading.
- **DC update:** page 2's Memory Reference Instructions heading says the
  counter is always incremented but prints `DC <- DC - 1`. The minus sign
  conflicts with the heading and detailed device manuals. Do not reverse
  the implemented increment.
- **XDC:** the page-2 Data Counter Instructions entry carries a `tt` footnote,
  defined as "F8 instruction only - not for F387X". The Mostek 3870 manuals
  explicitly provide an auxiliary DC and XDC. Preserve the Fairchild/Mostek
  source distinction; this card does not justify removing XDC from the
  Mostek-based Expander model.
- **Shared F8/F3870 title:** the card lists DI/EI as two cycles and POP as a
  copy without separate F3870 rows. This is manufacturer evidence against
  treating the shorter DI/EI and POP-exchange descriptions as universal
  3870 behavior. It does not establish which vendor/device/revision produced
  the differences. The [Mostek 1981 audit](MOSTEK-1981-AUDIT.md) and
  [1979 comparison](MOSTEK-1979-AUDIT.md) retain those unresolved questions.

The card supplies another manufacturer presentation supporting the main-board
instruction totals and semantics. It is not an independent measurement of
silicon, and no independence from Fairchild's other tables is claimed.
No RTL, timing constants or test expectations changed. This documentation-only
comparison did not rerun simulation; the earlier regression passes do not
resolve the vendor/device conflicts.
