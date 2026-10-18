# APL/S source entry

Boot the Computational Language cartridge and wait for its input prompt.
Load a `.vbk` file with **Keyboard Entry > Load Keyboard File**, then close the OSD. The core
types the listing through the keyboard matrix without resetting or restoring machine RAM.
Pressing a keyboard key or reopening the OSD cancels entry and releases the
generated key. Cancellation leaves any partially entered program in place.
Reset or reload the cartridge before retrying a partial listing.

Ready-to-load controls are in `examples/apl`: `arithmetic.vbk` should produce
2 then 5; `bars.vbk` should draw heights 10, 20, 30 and then produce 2.
Arithmetic and bars passed repeated hardware runs, including consecutive
source entries and executions. The five Price first-batch programs also passed
hardware testing. Other listings still need testing.

## Starting the Price games

Boot APL/S fresh, load a definition from `software/APL_S/price`, and wait for
entry to finish. Type its launch name in letter mode, then press NEXT (PC F3).
The name calls the stored program; no RUN command is needed. SHIFT toggles
letter/symbol mode. Use symbol mode for numbers and NEXT after each answer.

| File | Launch | Gameplay check |
| --- | --- | --- |
| `04-guess.vbk` | `GUES` | Answer `1` for the limit, then `1` for the guess. The score should be `1 1`. For a larger limit, follow TOO LOW/HIGH until correct. |
| `08-acey.vbk` | `ACEY` | Starts with cash 100 and two cards. Bet `0`: the third card is revealed, win/loss is reported, and the next deal still has cash 100. Bet `1` to check cash changes to 99 or 101. Only a card strictly between the two wins. `99` at BET? exits. CARD is included in the file. |
| `20-bulls.vbk` | `MOO4` | Enter `1 2 3 4` as one answer. Expect YOU WIN or WHITE/RED counts for exact/misplaced matches. Their sum must be 3 or 4. `99` exits. |
| `22-roulette.vbk` | `RO` | Answer `3`, then `0` to bet on zero. The spin is 0..36; cash becomes 134 on zero, otherwise 99. At the next round, `3` then `99` exits. |

Guess and Acey match the collection's listing images; Bulls and Roulette match
its text listings. These checks exercise input, branches, arrays, subroutine
calls and arithmetic. Source agreement does not verify emulated execution.
Roulette preserves a reference quirk: 23 is absent from both betting lists.

## Converting a listing

```sh
python3 verilator/apl_source.py listing.txt
```

This writes `listing.vbk`. Input is UTF-8 text containing exactly the lines
to enter at the APL/S prompt. Each nonblank line ends with NEXT. Program
definitions must include their entry commands, such as EDIT and ENDE;
printed headings, line numbers and OCR errors require proofreading first.
No RUN command is added. A one-line expression executes when NEXT is entered.

To load a definition without running it, end the file with ENDE and omit its
launch command. The Price definition files already do this. ENDE must receive
NEXT to finish the definition.

To leave a final command or immediate expression typed but unsubmitted:

```sh
python3 verilator/apl_source.py listing.txt held.vbk --hold-final
```

This removes only the final NEXT. Earlier lines still submit and may execute.
It does not remove RUN commands or prevent side effects from earlier lines.
Do not use it on a final ENDE when you want a completed definition. Existing
conversion behavior is unchanged unless this option is supplied.

Letters become uppercase. Blank lines and surrounding indentation are ignored;
CRLF and LF are accepted. Tabs become spaces. Smart double quotes become plain
quotes, nonbreaking spaces become spaces, and Unicode minus becomes hyphen.
Multiplication, division, pi and high minus use their UTF-8 APL glyphs.
Their ASCII spellings are `{MUL}`, `{DIV}`, `{PI}` and `{NEG}`.
ASCII `*` means exponentiation; it is not converted to multiplication.
Unsupported characters are rejected with their source line and column.
The limit is 4096 key tokens, including spaces and NEXT.

The interpreter must be ready for input. **Keyboard Entry > APL/S Entry Speed** selects Normal
(8 fields per press and release), Fast (6/6), or Slow (10/10). Continuous-entry
hardware testing confirmed 6/6 through automatic line clearances; 4/4 can lose
characters. Select before loading; the setting is latched per file. Normal is
the default. SHIFT and NEXT use at least 8 fields per press and release (10 at
Slow); every speed retains the 64-field startup wait. After NEXT's release gap,
lines up to 16 characters wait 64 fields; each additional character adds 4 fields,
capped at 125 characters (500 fields). Spaces count; implicit SHIFTs do not.
This provisional parsing margin applies before any following key and still needs
hardware validation against the timing sweep.
SHIFT must update the observed interpreter mode before the next character.
Other keys and prompts have no acknowledgement. Music Teacher's reliable 2/2
result does not establish it for APL/S.
Long operations or interactive prompts need separate testing. Avoid typing
during entry. VBK2 files, including music, retain their encoded timings.

## Entry timing test

`examples/apl/timing-100.vbk` submits `"AAABBBCCCDDDE"` 100 times. Each input
row is exactly 15 characters, including quotes; the result is `AAABBBCCCDDDE`
without quotes. Groups of three expose missed or repeated letters. The file
runs immediate expressions without storing a program.

Boot APL/S fresh, select a candidate speed, load the file and watch every row.
Allow about 8-12 minutes per run. Any shortened group, missing quote, error or
extra character is a failure, even if later rows look correct. Repeat at each
speed; a clean final screen alone cannot establish zero misses across 100 rows.

`examples/apl/timing-continuous-100.vbk` types the same quoted phrase 100 times
continuously, with no NEXT (PC F3) or line waits. It uses the selected
APL/S Entry Speed. Regenerate it with:

```sh
python3 verilator/apl_source.py examples/apl/timing-continuous-100.txt --hold-final
```

## File format and simulator

VBK1 has an 8-byte header: magic VBK1, little-endian 16-bit token count and
little-endian CRC-16/CCITT (polynomial 1021, initial FFFF) of the payload.
Each byte contains a matrix key in bits 5:0 and desired symbol mode in bit 6.
Bit 7 marks mode-independent SPACE (93 hex) or NEXT (9B hex).
The loader stages and validates the complete file before typing. SHIFT is
generated from the observed interpreter mode; raw SHIFT tokens are rejected.

```sh
cd verilator
make test-apl-source
make headless
./obj_dir_headless/Vtop --cart "../software/1 Cartridges/APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin" --source ../examples/apl/arithmetic.vbk@210 --frames 700 --shot-last --outdir out/apl/source
```

The headless run checks completion, not the displayed arithmetic result.
Inspect its capture. Building and running the full simulator may take time.
The headless option `--source-speed normal|fast|slow` selects the same timing.

For other titles and timed music, see [keyboard input](KEYBOARD-INPUT.md).
The RAM dump loader and its diagnostic entry paths are commented out; dump
files and code remain preserved.
