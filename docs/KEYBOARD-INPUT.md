# Keyboard input files

Choose **Keyboard > Load Keyboard File** and select a `.vbk`. A keyboard key cancels entry. **Keyboard > Menu Aborts VBK > Off** lets entry continue while the OSD is open.

See [APL/S entry and loading without running](APL-SOURCE.md).

See [converter commands and options](../tools/README.md#keyboard-files).

`--profile apl` is the default and matches `apl_source.py`. Text profiles require the starting SHIFT mode explicitly. `letters` means lower/unshifted; `symbols` means upper/shifted. Conversion emits physical SHIFT toggles, without observing another program's latch. If a program resets its mode between prompts, split the input into separate files with the correct starting mode.

## Text and title behavior

`keyboard` uses the printed keyboard: letters become uppercase, comma and semicolon use their lower keys, numbers use upper keys. Unlike APL/S, P's upper character is cent, not high minus. `{CENT}`, `{MUL}`, `{DIV}` and `{PI}` are accepted. Whitespace and blank lines are preserved. Each line ends in lower NEXT unless `--hold-final` suppresses the last one. NEXT receives an additional 72 released fields. No RUN is appended. `{BACK}`, `{ERASE}`, `{NEXT}`, `{PREVIOUS}`, `{SPECIAL}`, `{SPACE}`, `{SHIFT}` and `{WAIT:120}` are available.

| Program | Entry behavior and profile |
| --- | --- |
| Built-in Text | Enter TEXT manually with upper SHIFT, then check its dark/lower indicator. Use `text --start-mode letters`. Seven lines of 16 characters; full lines wrap automatically, so the converter omits their NEXT. NEXT moves down; upper NEXT selects CLOCK. Start with an empty display. |
| Financier / VB-81 | Use `keyboard`. Its cursor starts L (lower); SHIFT toggles U/L. NEXT submits formulas, commands or answers. Maximum formula: three lines of 15 characters. BACK erases; PREVIOUS and SPECIAL are ignored. |
| Money Minder / VB-1000 | Use `keys`. It replaces text entry with a cash-register layout. Digits are the printed numeric positions without automatic SHIFT; punctuation and dollar formatting are automatic. Category keys depend on SHIFT. SPACE is ENTER/INITIAL VALUE, not a text space. Follow its account prompts. |
| Wordwise 1 | Use `keys` for numeric position moves and NEXT; it builds words by moving displayed letters, rather than by typing words. |
| Wordwise 2 | Its typing exercises accept printed character keys. Use `keyboard` for an appropriate exercise or `keys` for prompts; inspect the expected line before submitting NEXT. |
| Timeshare | F5 sends Carriage Return; F4 is CONTROL. Shift is held, not toggled; Shift+H types `/`. Hold F4 + Shift and tap D for full duplex or H for half duplex/local echo. Use manual input for its held-key combinations. See [Timeshare setup and keys](EXPANDER1.md#timeshare-over-uart). |
| Other titles, including Information Manager | Use physical key scripts that follow the program's prompts and SHIFT behavior. |

VBK2 files can be loaded in any program; use the profile and starting mode that match its current screen and key handling.

## Physical keys

One event per line: `KEY`, `KEY hold gap`, or `WAIT fields`. Times are video fields (about 60 per second), not milliseconds. Bare keys use 8/8. Key names are letters and SEMI, COMMA, QUESTION, SHIFT, ERASE, SPACE, SPECIAL, NEXT, PREVIOUS, BACK. They refer to physical keys, irrespective of program meaning. WAIT holds no key. Holds are 1..255 fields; gaps are 0..255. Long waits split into events. MASTER CONTROL is excluded because it resets/cancels entry.

## Music Teacher 1

Select Program 1 / Play-Record manually. Ensure lower SHIFT (no light square), then load an example from `examples/music/score-timing` or `examples/music/note-timing`. Each generated song erases the previous recording, selects Middle, enters the notes, and ends with No-Record. **Keyboard > Music Mode** selects **Playback** (default) or **Record**. Record enables the cartridge recorder; `--replay` presses REPLAY afterward. Playback keeps Record off and ignores that replay request, playing the file live. Regenerate older music files to use this setting; their physical Record/Replay keys retain their original behavior. After recording, press physical T to replay the stored song again. **Keyboard > Music Repeat** restarts the file from the top until entry is canceled. Repeat forces Playback and grays out Music Mode, preserving the selected mode for when Repeat is turned off. The loader does not wait for the cartridge's Replay routine. Use lower SHIFT and files generated with `--start-mode letters` so each music pass starts in the same mode. This uses the cartridge's own recorder and sound routines; the loader supplies no replacement audio engine.

The monophonic MML subset accepts A-G, `#`/`+` sharp, `-` flat, O2-O6, `<`/`>`, T32-T255, L1-L64, per-note lengths, one dot, and R/P rests. Default: O4, T120, L4. C4 means middle C. Range: C2 through B5, checked after accidentals; O6 permits only C- (B5). Chords, ties, loops, voices and other MML commands are rejected. MML conventions follow the [QB64 PLAY notation](https://qb64phoenix.com/qb64wiki/index.php/PLAY).

```text
T100 O4 L4 C C G G A A G2 F F E E D D C2
```

The manual's Middle layout uses S for C4, D/F/G/H/J/K for D4..B4 and L for C5. Lower staff C3..A3 uses QUESTION, BACK, PREVIOUS, NEXT, SPECIAL, ERASE. The black-note keys complete the chromatic scale. Z selects Low (-1 octave), V High (+1), SPACE Middle. Shifted SPACE erases, shifted Z records, shifted COMMA selects No-Record, and unshifted T replays. Octave controls select a fixed bank; repeated Low/High does not step indefinitely. The cartridge's key table and bank routine confirm Low C2..D4, Middle C3..D5, and High C4..B5.

The converter keeps the current octave bank while it contains the next pitch. Choose one of two music timing styles. Both default to `--min-hold 2 --gap 2`:

- **Score timing** (`--timing score`, default) preserves tempo by fitting each octave switch into preceding rests or release gaps, then shortening the preceding held note if needed. Switches use two held and two released fields. At least two held and two released note fields remain with the defaults. If insufficient time remains, the converter warns and adds the excess delay. A switch before the first note adds startup time.
- **Note timing** (`--timing note`) preserves note/rest durations and adds the minimum ROM-acknowledged octave-switch time. The loader presses the bank key when the ROM is ready, releases it when accepted, then waits for confirmed readiness before continuing. Each stage times out after 255 fields.

Timing is rounded to video fields; the key-off gap is included in each note's duration.

Ready-to-load songs are in [music examples](../examples/music/README.md).

The manual specifies songs of up to 80 notes; this ROM's recorder appears to stop at 79 note/rest records. Key-off gaps may also consume entries. The loader enters at most 79 note keys in Record mode, skipping the remaining music and delays before No-Record and optional Replay. Rests and bank changes do not count toward this input limit, but may leave fewer notes in the cartridge's recording. Playback bypasses recorder capacity; files still have a 1365-event limit, including control keys, octave changes and waits. The converter warns above 79 notes that Record will truncate the song.
