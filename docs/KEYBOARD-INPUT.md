# Keyboard input files

Choose **Enter Keyboard File**, select a `.vbk`, and close the OSD. Entry uses
the actual keyboard matrix. Typing, opening the OSD, or resetting cancels it.
The loader checks the complete file before pressing any key. Files cannot
detect prompts or cartridge changes. Start at the intended input screen.

APL/S VBK1 files retain their existing format, timing and live SHIFT handling.
See [APL/S entry and loading without running](APL-SOURCE.md).
Other profiles produce VBK2 and require the updated core.

```sh
python3 verilator/keyboard_input.py input.txt --profile keyboard --start-mode letters
python3 verilator/keyboard_input.py message.txt --profile text --start-mode letters --hold-final
python3 verilator/keyboard_input.py input.keys --profile keys
python3 verilator/keyboard_input.py song.mml --profile music --start-mode letters --replay
```

`--profile apl` is the default and matches `apl_source.py`. Text profiles require
the starting SHIFT mode explicitly. `letters` means lower/unshifted; `symbols`
means upper/shifted. Conversion emits physical SHIFT toggles, without observing
another program's latch. If a program resets its mode between prompts, split
the input into separate files with the correct starting mode.

## Text and title behavior

`keyboard` uses the printed keyboard: letters become uppercase, comma and
semicolon use their lower keys, numbers use upper keys. Unlike APL/S, P's upper
character is cent, not high minus. `{CENT}`, `{MUL}`, `{DIV}` and `{PI}` are
accepted. Whitespace and blank lines are preserved. Each line ends in lower
NEXT unless `--hold-final` suppresses the last one. NEXT receives an additional
72 released fields. No RUN is appended. `{BACK}`, `{ERASE}`, `{NEXT}`,
`{PREVIOUS}`, `{SPECIAL}`, `{SPACE}`, `{SHIFT}` and `{WAIT:120}` are available.

| Program | Entry behavior and profile |
| --- | --- |
| Built-in Text | Enter TEXT manually with upper SHIFT, then check its dark/lower indicator. Use `text --start-mode letters`. Seven lines of 16 characters; full lines wrap automatically, so the converter omits their NEXT. NEXT moves down; upper NEXT selects CLOCK. Start with an empty display. |
| Financier / VB-81 | Use `keyboard`. Its cursor starts L (lower); SHIFT toggles U/L. NEXT submits formulas, commands or answers. Maximum formula: three lines of 15 characters. BACK erases; PREVIOUS and SPECIAL are ignored. `examples/keyboard/financier.vbk` enters `1+1` from the initial menu. |
| Money Minder / VB-1000 | Use `keys`. It replaces text entry with a cash-register layout. Digits are the printed numeric positions without automatic SHIFT; punctuation and dollar formatting are automatic. Category keys depend on SHIFT. SPACE is ENTER/INITIAL VALUE, not a text space. Follow its account prompts. |
| Wordwise 1 | Use `keys` for numeric position moves and NEXT; it builds words by moving displayed letters, rather than by typing words. |
| Wordwise 2 | Its typing exercises accept printed character keys. Use `keyboard` for an appropriate exercise or `keys` for prompts; inspect the expected line before submitting NEXT. |
| Other titles, including Information Manager and Timeshare | Physical key scripts are available. Their text/mode transitions have not been established here; do not assume the APL/S mapping. |

The title rules above come from the local owner's, Financier, Money Minder and
Wordwise manuals in `vb_large_docs/videobrain-manuals.zip`. New title profiles
and timing remain hardware-unverified. The core permits VBK2 in any program;
acceptance by the program depends on its current screen and key handling.

`examples/keyboard/text.vbk` starts inside empty built-in Text in lower mode.
Expected lines: HELLO VIDEOBRAIN, 0123456789, and A, B; C?.

## Physical keys

One event per line: `KEY`, `KEY hold gap`, or `WAIT fields`. Times are video
fields (about 60 per second), not milliseconds. Bare keys use 8/8. Key names
are letters and SEMI, COMMA, QUESTION, SHIFT, ERASE, SPACE, SPECIAL, NEXT,
PREVIOUS, BACK. They refer to physical keys, irrespective of program meaning.
WAIT holds no key. Holds are 1..255 fields; gaps are 0..255. Long waits split
into events. MASTER CONTROL is excluded because it resets/cancels entry.

## Music Teacher 1

Select Program 1 / Play-Record manually. Ensure lower SHIFT (no light square),
then load an example from `examples/music`. Each generated song erases the
previous recording, enables Record, selects Middle, enters the notes, and
ends with No-Record to stop recording idle time. `--replay` presses REPLAY.
Afterward press physical T to replay the stored song again. Automatic repeated
playback has not been established. This uses the cartridge's own recorder and
sound routines; the loader supplies no replacement audio engine.

The monophonic MML subset accepts A-G, `#`/`+` sharp, `-` flat, O2-O6,
`<`/`>`, T32-T255, L1-L64, per-note lengths, one dot, and R/P rests.
Default: O4, T120, L4. C4 means middle C. Range: C2 through D6. Chords, ties,
loops, voices and other MML commands are rejected. MML conventions follow the
[QB64 PLAY notation](https://qb64phoenix.com/qb64wiki/index.php/PLAY).

```text
T100 O4 L4 C C G G A A G2 F F E E D D C2
```

The manual's Middle layout uses S for C4, D/F/G/H/J/K for D4..B4 and L for C5.
Lower staff C3..A3 uses QUESTION, BACK, PREVIOUS, NEXT, SPECIAL, ERASE.
The black-note keys complete the chromatic scale. Z selects Low (-1 octave),
V High (+1), SPACE Middle. Shifted SPACE erases, shifted Z records, shifted
COMMA selects No-Record, and unshifted T replays. Octave controls select a
fixed bank; repeated Low/High does not step indefinitely.

The converter keeps the current octave bank while it contains the next pitch.
Bank changes add control-key time; they can appear as extra rests in recording.
Use a single bank when precise rhythm matters. The manual specifies songs of
up to 80 notes. How rests affect capacity remains unverified. The compiler's
80 explicit note/rest limit does not prove the complete performance fits;
key-off gaps may also consume entries. For long songs inspect the recording.

## Music timing still needs hardware measurement

The default minimum hold and gap are 8 fields each (about 134 ms). These are
initial candidates borrowed from working APL/S entry, not measured music
limits. A quarter note at T120 is 30 fields: 22 held and 8 released. Notes too
short for `--min-hold` plus `--gap` are rejected instead of silently slowed.
Held notes longer than 255 fields are rejected; long rests are supported.

Page size, redraw latency, the minimum reliable note hold/gap and the effect
of long gaps on recording capacity remain unverified. No page interval is
assumed. `--page-notes N --page-wait 64` adds a wait after each N note/rest
entries once that interval is measured. These waits may be recorded as rests;
they do not acknowledge completion of redraw or preserve musical tempo.
The counter excludes implicit rests from key-off gaps; a measured interval
may not transfer to a different rhythm.

Build the updated core in Quartus, then test from a fresh lower-mode staff:

1. `scale.vbk`: eight ascending notes; replay twice with T.
2. `octaves.vbk`: C2, C3, C4, C5, C6, D6; check staff position and pitch.
3. `timing-8-8.vbk`: 32 notes, S S D D F F G G repeated four times, then replay.
   Count missed/repeated notes and note the first staff/page transition.
4. Repeat with `timing-4-4`, `timing-2-2`, and `timing-1-1` until errors appear.
   Test each passing pair several times; one pass does not establish a minimum.
5. If 8/8 misses at page changes, compare `timing-8-64.vbk`. It deliberately
   inserts long gaps on every note and will record a slower performance.

Report the last reliable pair, the failing note numbers, and the observed page
interval. These files are candidates, not hardware-verified songs.

## Format and checks

VBK2 retains the eight-byte VBK1 header, with magic `VBK2`. Count is payload
bytes, not event count; CRC is unchanged. Each three-byte event is matrix key
0..35 (or FF for WAIT), held fields 1..255, released fields 0..255. Limit:
4095 bytes / 1365 complete events. Raw SHIFT and function keys are valid in
VBK2. APL-only VBK1 remains gated to the recognized Computational Language ROM.

`make test-apl-source` runs both converters' tests and the loader RTL tests.
Full simulator captures and Quartus builds are separate checks.
