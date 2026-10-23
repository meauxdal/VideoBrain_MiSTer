# APL/S dump audit

Authority: James Price, *21 APL/S Games and One-Liners for Your Umtech VideoBrain*, first edition, December 19, 2025. Page references below are PDF pages, counting the cover as page 1.

Scope: all 26 dumps in the *21 games for APL/S* collection for MAME. Stored PROGs were decoded from the dumps and compared with the printed listing images, not with our VBKs or the collection's separate text listings. Whitespace, indentation, four-character keyword/name truncation, compiled branch offsets, and native floating-point rounding are not differences. Live variable values are not treated as program edits.

## PROGs differing from print

These 16 dumps contain a confirmed difference. The examples identify why each file fails the comparison; they are not exhaustive patches.

| Dump | Printed PROG | PDF page | Confirmed difference |
| --- | --- | --- | --- |
| `bullsandcows3digits.bin` | `MOO` | 287 | Stored as `M`; prompt shortened to `GUESS` instead of `GUESS THE 3 NUMBERS`. |
| `bullsandcows4digits.bin` | `MOO4` | 294 | Stored as `M`; prompt shortened to `GUESS` instead of `GUESS THE 4 NUMBERS`. |
| `clocknye2026.bin` | `CLOCK` (`CLOC`) | 323 | Stored as `C`. |
| `collatz.bin` | `COLLATZ` (`COLL`) | 139 | Stored as `C`. |
| `dicejack.bin` | `D` | 217 | Dealer message is `BUSTED` instead of printed `I BUSTED`. |
| `dstats.bin` | `DSTATS` (`DSTA`) | 252 | Stored as `D`; also contains an extra empty `S` PROG. |
| `fib1liner.bin` | Immediate expression | 162-166 | Adds a stored `F` wrapper. Its expression uses `INDEX 12`; the printed bar-chart expression uses `INDEX 7`. The book's separately printed `FIB` is in `recursivefib.bin`. |
| `guess.bin` | `GUES` | 303 | Adds `WILL` to the printed `OK I CHOSE A NUMBER. WHAT IS YOUR GUESS` message; also adds a question mark to the limit prompt. |
| `gun.bin` | `GUN` | 124 | Printed lines say `BAR -30` and `BAR 30`; stored code uses `BARH`. See qualification below. |
| `lottochartmethod1.bin` | `LOTTO` (`LOTT`) | 256 | Stored as `L`. |
| `lottochartmethod2.bin` | `LOTTO2` (`LOTT`) | 259 | Stored as `L`. |
| `primesieve.bin` | `SIEVE` (`SIEV`) | 241 | Stored as `S`; omits printed in-PROG `N=INDEX 198`. Page 243 separately discusses initializing `N` before running. |
| `roulette.bin` | `RO` | 115 | Stored as `R`; changes betting-array variable `R` to `RR`; omits `10` from array `G`. |
| `slots.bin` | `SLOT` | 38 | Omits initial `BARH 20 20 20`; adds `BARH 25 25 25` inside the loop; three-of-a-kind award is `CASH+6` instead of printed `CASH+5`. |
| `stagorharegraph.bin` | `STAG` | 277 | Stored as `S`; omits printed `BARH 0 0 0` at the start of each loop. |
| `taylorseries.bin` | `TAYLOR` (`TAYL`) | 273 | Stored as `T`; uses `X=6, N=20` instead of printed `X=5, N=22`. |

Gunner is a printing discrepancy, apparently a correction of the book's `BAR` typo, rather than evidence of a different algorithm. Do not blindly reproduce those two printed lines or silently count the dump as a literal match.

`fib1liner.bin` should not be remade as a PROG if the collection is restricted to PROGs actually printed in the book. Keep that topic as immediate-input VBKs.

## PROGs with no decoded listing difference found

| Dump | PROG | Matching PDF page(s) |
| --- | --- | --- |
| `aceyducey.bin` | `ACEY`, `CARD` | 78, 80 |
| `coinchange.bin` | `C` | 313 |
| `estimatepibarchart.bin` | `PI` | 265 |
| `lunarlander.bin` | `LL` | 194 |
| `primebarchart.bin` | `P` | 234 |
| `recursivefactorial.bin` | `F` | 180, the ascending version that prints intermediate `Y` values |
| `recursivefib.bin` | `FIB` | 167 |
| `unicircle.bin` | `UNI` | 205 |

This comparison concerns the stored PROG bodies and names. These snapshots contain live execution state and data; they are not pristine book-initialized workspaces, nor does matching source establish hardware execution correctness.

## Immediate-expression dumps

Neither file contains a stored PROG. Preserve direct-expression VBKs and use separately identified named program wrappers for tape versions.

| Dump | Printed reference | Finding |
| --- | --- | --- |
| `sinebarchart1liner.bin` | PDF 61 | No stored PROG; retained input is the sine bar-height expression. |
| `pyramid.bin` | PDF 175 | No stored PROG; retained input uses scale 16, matching the printed expression. |
