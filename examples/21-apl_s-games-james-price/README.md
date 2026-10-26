# James Price APL/S programs

Thirty source listings and matching `.vbk` files adapted from
[James Price's APL/S collection](https://github.com/jamescprice/21-APL-Games-and-One-Liners-For-Your-Umtech-Videobrain).
Redistribution terms have not been confirmed. Resolve them before including
these listings or their [tape conversions](../price-tape-conversions/README.md)
in a release.

Load the Computational Language cartridge and wait for its input prompt.
Start each listing in a fresh workspace using **Keyboard > Load Keyboard File**.
After entry finishes, type the launch command below and press NEXT (F3/Enter).
Use symbol mode for numeric responses. Stop continuous programs with RUN/STOP
(PC SPACE). See [APL/S entry](../../docs/APL-SOURCE.md).

| Listing | Launch |
| --- | --- |
| `01-sine` | Executes during entry. |
| `02-fibonacci` | Executes during entry. |
| `02-fibonacci-recursive` | `FIB`; entry initializes X and Y. |
| `03-random-bars` | Executes during entry. |
| `04-guess` | `GUES` |
| `05-min` | Executes during entry. |
| `06-factorial` | `F`; entry initializes N=5 and Y=1. |
| `07-slots` | `SLOT` |
| `08-acey` | `ACEY`; includes utility CARD. |
| `09-lander` | `LL` |
| `10-sphere` | `UNI`; entry initializes G. |
| `11-gunner` | `GUN` |
| `12-dicejack` | `D` |
| `13-primes`, `13-primes-text` | `P` |
| `13-sieve` | `SIEV`; entry initializes N. |
| `14-collatz` | `COLL` |
| `15-stats` | `DSTA` |
| `16-lotto` | `LOTT` |
| `16-lotto-method2` | `LOTT`; an alternative definition, loaded separately. |
| `17-pi`, `17-pi-text` | `PI` |
| `18-taylor` | `TAYL` |
| `19-stag` | `STAG` |
| `20-bulls` | `MOO4`; four-number game. |
| `20-bulls-three` | `MOO`; three-number game. |
| `21-clock` | `CLOC`; entry initializes date and time. |
| `22-roulette` | `RO` |
| `22-roulette-text` | `ROUL` |
| `23-change` | `C` |

APL/S identifies names by their significant first four letters. The text,
recursive and alternative-method variants are separate listings; load one
at a time. See [transcription corrections and limits](../../docs/APL-SOURCE.md)
for Gunner, Dicejack and Roulette.

Regenerate a keyboard file from the repository root:

```sh
python3 tools/apl_source.py examples/21-apl_s-games-james-price/04-guess.txt
```

All keyboard files reproduce exactly from their sources. This checks encoding
and checksums; it does not establish successful interpreter execution or
gameplay for every listing.
