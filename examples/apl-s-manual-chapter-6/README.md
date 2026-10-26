# APL/S manual: chapter 6

Type-ins from *APL/S: The Computational Language User's Manual* (Wallace
Judd and Simon Cintz, VideoBrain Computer Company, 1978), chapter 6,
printed pages 49-59. See the [manual scan and publication details](https://www.orphanedgames.com/videobrain/manuals/VideoBrain_Manuals.htm).

Load one `.vbk` into a fresh Computational Language workspace using
Keyboard > Load Keyboard File. Each file includes its required subprograms.
Definitions finish in immediate mode; type the launch name and press NEXT.
The two immediate examples execute during entry. See [source entry](../../docs/APL-SOURCE.md).

| Source / matching VBK | Page | Launch and inputs |
| --- | --- | --- |
| `01-decimal.txt` | 51 | Set `XDEC`, call `DECI`, read `XDEC`. |
| `02-try-decimal.txt` | 51 | `TRYD`; enter decimals, then 1000 to end. Includes `DECI`. |
| `03-round.txt` | 51 | Set `RNUM`, call `ROUN`, read `RNUM`. |
| `04-round-example.txt` | 50-51 | Immediate example; displays 4. Includes `ROUN`. |
| `05-place-value-round.txt` | 52 | Set `RNUM` and nonzero positive `PV`, call `PVRO`, read `RNUM`. |
| `06-integer.txt` | 52 | Set `NUMB`, call `INTE`, read `NUMB`. |
| `07-pause.txt` | 52 | `PAUS`; short counting delay. |
| `08-scale.txt` | 52 | Set nonempty, nonzero `BIGN`, call `SCAL`, read `BIGN`. |
| `09-arctangent.txt` | 53 | `ARCT`; enter a value. Displays radians. |
| `10-arcsine.txt` | 54 | `ARCS`; enter a value strictly between -1 and 1. Includes utility `ARCT`. |
| `11-arccosine.txt` | 54 | `ARCC`; enter a value strictly between -1 and 1. Includes utility `ARCT`. |
| `12-colors.txt` | 55 | `COLR`; defines the sixteen color names. |
| `13-colors-example.txt` | 55 | Immediate color demo. Includes `COLR`. |
| `14-shift.txt` | 55 | Set nonempty array `ROWV`, call `SHIF`, read `ROWV`. |
| `15-spinning-top.txt` | 56 | `TOPP`; rotating bars and colors. Includes `SHIF`. |
| `16-find-maximum.txt` | 56 | Set nonempty array `RMAX`, call `FMAX`, read first maximum's index in `PTR`. |
| `17-safety.txt` | 57 | Set `SMIN`, `SMAX`, `SAFX`; call `SAFE`. Prompts until in range. |
| `18-sine.txt` | 57 | `SINE`; animated sine wave. |
| `19-sharpshooter.txt` | 58 | `SHRP`; guess the multiplier needed to hit the displayed target. |
| `20-guess-number.txt` | 59 | `GNUM`; guess a number from 1 to 100. |

Stop the continuous `TOPP` and `SINE` demos with RUN/STOP. The inverse
trig routines retain the printed five-term approximation; arcsine and
arccosine retain the division-by-zero limitation at -1 and 1. Their `ARCT`
definition omits input and output as instructed on page 54, so it replaces
the interactive version from `09-arctangent`.

## Transcription

Keywords and identifiers use their significant first four letters. `EDIT`
and `ENDE` delimit each definition; printed `PROG` headings are represented
by `EDIT`. Wrapped expressions are joined into one input line. Multiplication,
division, pi and high minus use the converter's ASCII tokens.

The decimal routine on page 51 needs one closing parenthesis, added here.
The round routine uses `RNUM`, and FMAX returns `PTR`, as in their listings;
the prose incorrectly names `XROU` and `MAXI`. The color example includes
the comma after `BLUE` shown in the scan. No numerical algorithms or game
rules have been changed.

Regenerate keyboard files from the repository root:

```sh
for f in examples/apl-s-manual-chapter-6/*.txt; do
    python3 tools/apl_source.py "$f"
done
```

Sources were checked against the scanned pages and keyboard files validated
with `tools/apl_source.py`. Interpreter execution and hardware testing remain
pending.
