# Veswiki Opcode revision 786 comparison

Reviewed 2026-10-24 using the [Opcode page](https://channelf.se/veswiki/index.php?title=Opcode),
the user-supplied wikitext and the existing manufacturer-based expectations.
The public MediaWiki revision API identifies the latest revision as **786**,
edited by **E5frog on 2026-08-07 at 17:02:44 UTC**. Its parent is 785, edited
by the same account five minutes earlier. The dated reference is the
[revision permalink](https://channelf.se/veswiki/index.php?title=Opcode&oldid=786).

The page explicitly credits Dollhoff's `F8_info` table, Turner's instruction
page and the 1976 Fairchild User's Guide. This establishes a useful source
lineage: it is an actively edited synthesis of sources already under review,
not another independent measurement of F8 silicon. The editor name matches
the account that filed Optable issue 12.

## The detailed columns resolve five conflicting totals

The pasted table has 82 instruction, alias and hardware-event rows. Summing
each single-path S/L sequence as S=1 and L=1.5 exposes these five disagreements
with the same row's summary total. Branch alternatives and port-specific I/O
sequences were read separately rather than summed as one execution path.

| Instruction | Wiki summary total | Wiki cycle sequence | Sum / current main-board expectation | Wiki ROMC sequence |
| --- | --- | --- | --- | --- |
| PK | 2.5 | L, L, S | 4 | 12, 14, 00 |
| DI | 1 | S, S | 2 | 1C, 00 |
| EI | 1 | S, S | 2 | 1C, 00 |
| LR W,J | 1 | S, S | 2 | 1C, 00 |
| LR J,W | 2 | S | 1 | 00 |

The detailed sequences for these instructions agree with the manufacturer
tables and current implementation. The shorter DI/EI summaries are therefore
not evidence here for choosing the Mostek 3870 interpretation: this page's
own detailed columns describe the F3850-style two-cycle sequence. The status
transfer totals are reversed, even though their mnemonic directions are right.

## Useful corroboration

- BR7 correctly gives 2 when not taken and 2.5 when taken, with short 03 +
  short 00 versus long 01 + short 00. There is no BT/BF idle cycle in that row.
- 0E/0F/10/11 and 1E have the correct Q/H/DC and J/W transfer directions.
- AMD, ASD and CM mark O/Z/C/S as modified. CM is explicitly operand minus A,
  with flags updated and the accumulator retained. The affected-flag notation
  does not establish exact decimal flag values.
- IN/OUT are long 03 + long 1B/1A + short 00, totaling 4. CPU short I/O ports
  0/1 use short 1C + short 00, totaling 2; documented external short I/O ports
  4-F use long 1C + long 1B/1A + short 00, totaling 4.
- PI, JMP and DCI retain the expected 6.5, 5.5 and 6 totals and detailed
  long/short sequences. PI/JMP descriptions correctly use A for the high byte.
- POP is a copy of PC1 into PC0, not an exchange. XDC exchanges the data
  counters. These are generic F8 descriptions, not resolution of vendor-specific
  3870 conflicts.
- BT and BF descriptions correctly use any selected true flag versus all
  selected flags false, with the expected three-bit versus four-bit masks.

## Further exceptions and interpretation limits

The LR W,J flag columns show all dashes, despite loading W from R9. The CPU
loads the five-bit status register; the arithmetic flag fields should not be
read as preserved. The four-column table also omits a separate ICB effect
column, so those dashes cannot describe the complete status effect of DI/EI.

The branch subtables retain comments such as BT 5 being equivalent to BT 1,
BT 7 to BT 3, and corresponding BF equivalences. These are not universal
identities for arbitrary W loaded through LR W,J. For example, W low nibble
04 (Z=1, S=0) makes BT 5 take and BT 1 not take; BF 1 takes and BF 5 does not.
Do not replace mask tests with those comment-based aliases. Existing branch
tests exercise explicit flag/mask combinations. Likewise, BP's parenthetical
"sign bit 0" needs care: a positive result has result bit 7 clear, while F8's
W.S flag is set. The page's named conditions do not justify inverting W.S.

INS/OUTS prose includes ports 2/3, whereas the detailed sequence labels use
4-F for external ports. This does not change the documented-opcode audit's
exclusion of reserved A2/A3/B2/B3. Generic `$3x`/`$Cx`-style families likewise
must retain the scratchpad-mode restrictions rather than making every low
nibble legal.

The IRQ hardware-event row totals 5.5 for long 1C, long 0F, long 13 and short
00. It does **not** include the preceding ROMC 10 freeze replacing a fetch.
The current CPU likewise has that four-cycle body after its separate freeze.
Do not treat 5.5 as complete pin-to-ISR latency or infer a missing freeze from
that row. The RESET row's 3.5 total describes short 1C, long 08 and short 00;
it is not a specification of reset-pin hold time or oscillator startup.
Neither event row locates source acknowledgement within a cycle.

This comparison changes no RTL or test expectations. It corroborates important
ROMC/length information while retaining summary inconsistencies. No simulation
was rerun for the documentation-only change, and no original-machine timing
measurement was inferred from the page's recent edit date.
