# Keyboard input files

Choose **Load Keyboard File** on the main menu and select a `.vbk`. Entry starts
when the OSD closes and uses the actual keyboard matrix. Typing, opening the
OSD, or resetting cancels it.
Loading a keyboard file does not reset the machine; confirmed on APL/S in RC7.
The loader checks the complete file before pressing any key. Start at the
intended input screen; files do not interpret prompt contents.

Earlier intermittent first-load restarts are currently unreproducible in RC14.
Hardware checks reported on 2026-10-19 found no restarts across four fresh-boot
CHANGE loads and one CLOCK load. The cause remains unconfirmed; treat this as
an unresolved issue that may recur, rather than a verified fix.

The OSD submenus are Input, Video, Keyboard Entry, System, in that order.
Keyboard Entry contains file loading, Music Mode, Auto-Repeat,
and the status messages "Keyboard entry active" and "Keyboard file rejected".

APL/S VBK1 files retain their format and live SHIFT handling. Entry waits for
the interpreter to accept each key and become ready again, including after NEXT.
VBK2 retains its encoded event timings.
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
Wordwise manuals in `vb_large_docs/videobrain-manuals.zip`. Other title profiles
remain hardware-unverified; Music Teacher results are below. The core permits
VBK2 in any program; acceptance depends on its current screen and key handling.

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
previous recording, selects Middle, enters the notes, and ends with No-Record.
**Keyboard Entry > Music Mode** selects **Playback** (default) or **Record**.
Record enables the cartridge recorder; `--replay` presses REPLAY afterward.
Playback keeps Record off and ignores that replay request, playing the file live.
Regenerate older music files to use this setting; their physical Record/Replay
keys retain their original behavior.
After recording, press physical T to replay the stored song again.
**Keyboard Entry > Auto-Repeat** restarts the file from the top until a keyboard key or
opening the OSD cancels entry. Use Playback for continuous music; the loader
does not wait for the cartridge's Replay routine. Use lower SHIFT and files
generated with `--start-mode letters` so each music pass starts in the same mode.
This uses the cartridge's own recorder and
sound routines; the loader supplies no replacement audio engine.

The monophonic MML subset accepts A-G, `#`/`+` sharp, `-` flat, O2-O6,
`<`/`>`, T32-T255, L1-L64, per-note lengths, one dot, and R/P rests.
Default: O4, T120, L4. C4 means middle C. Range: C2 through B5, checked after
accidentals; O6 permits only C- (B5). Chords, ties, loops, voices and other MML
commands are rejected. MML conventions follow the
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
The cartridge's key table and bank routine confirm Low C2..D4, Middle C3..D5,
and High C4..B5. `scale.vbk` enters all 48 chromatic pitches C2..B5 and replays;
`octaves.vbk` probes C2, C3, C4, C5, B5, then returns to C2 and replays.

The converter keeps the current octave bank while it contains the next pitch.
Bank changes add control-key time; they can appear as extra rests in recording.
For experimental live playback, add `--bank-fields 2` when converting MML.
This uses two held and two released fields per bank control, taking that time
from preceding rests or release gaps, then shortening the preceding held note
if needed. It retains at least `--min-hold` held fields and the smaller of
`--gap` and `--bank-fields` released fields before the control. If insufficient
time remains, the converter warns and adds only the uncompensated fields.
A bank change before the first note may still add startup time. Hardware testing
confirmed successful live playback at 2/2 with the static-staff ROM and Playback
mode on 2026-10-18. Smooth files are in `examples/music/smooth`, generated with `--min-hold 2 --gap 2
--bank-fields 2`; their MML sources remain in `examples/music`.
Without this option, bank controls retain their 8/8 timing.
The manual specifies songs of
up to 80 notes; this ROM's recorder appears to stop at 79 note/rest records.
Key-off gaps may also consume entries. The loader enters at most 79 note keys in
Record mode, skipping the remaining music and delays before No-Record and optional
Replay. Rests and bank changes do not count toward this input limit, but may leave
fewer notes in the cartridge's recording.
Playback bypasses recorder capacity; files still have a 1365-event limit,
including control keys, octave changes and waits. The converter warns above
79 notes that Record will truncate the song.

MT1 provides no cassette save/load or Expander 1 commands; its recording is held
in the machine's RAM. Keep the source or VBK file to enter a song again.

For an experimental static-staff ROM, run
`python3 verilator/patch_music_teacher.py ORIGINAL.bin OUTPUT.bin` with the
original ED01 cartridge. Use Program 1 normally, with existing VBK files.
The patch skips note/rest drawing and recurring page redraws, retaining pitch
setup, recording, and sound routines. Program 2's visual teaching is affected.
Live playback improvement is hardware-confirmed; recording behavior remains
unverified.

TODO: Explore further ROM changes to eliminate remaining octave-switch delays.
Improve the mostly static display: accumulated note overdraw produces glitched
"8b" markers as every possible note pixel fills in. Preserve sound timing when
restoring or replacing visual feedback.

## Music hardware results

Hardware testing reported on 2026-10-18:

- The static-staff ROM with the smooth VBK files was reported a total success
  during live Playback. Cartridge Record was not used.
- The converter compensates octave-control time within preceding notes/rests.
  Its full cello prelude still adds two fields at the final switch; eliminating
  remaining switch delays is a possible ROM follow-up, not yet a measured result.
- Higher notes still have clearly audible aliasing. Audio filtering is a
  separate follow-up from ROM timing and display work.

Hardware testing reported on 2026-10-15:

- `timing-1-1.vbk` produced no notes in several tests; 1/1 is too short.
- `timing-2-2.vbk` was consistently recognized, as were higher tested values.
  This is the shortest tested reliable pair: about 33 ms held and 33 ms released.
  Independent minimum hold and gap values have not been measured.
- `timing-8-64.vbk` displayed rests between notes as expected.
- Pages flip after six notes during type-in. The cartridge counts stored notes
  and rests during playback.
- Recorded durations appear to match targets even across page flips, with a
  small playback delay. Full onset capture during input redraw is unmeasured.
- O5 reportedly failed on hardware; the confirmed pitch range does not explain
  that result. Upper-range hardware testing remains open.

The default minimum hold and gap remain 8 fields each (about 134 ms).
`--min-hold 2 --gap 2` permits the tested shorter pair. A quarter note at T120
is 30 fields: 22 held and 8 released at the defaults. Notes too
short for `--min-hold` plus `--gap` are rejected instead of silently slowed.
Held notes longer than 255 fields are rejected; long rests are supported.

Redraw duration and the effect of rests on recording capacity remain unverified.
No page wait is enabled by default. `--page-notes N --page-wait 64` uses a
cumulative note/rest count to schedule waits. Its current counter includes
explicit rests, unlike observed initial type-in pagination; setting N to 6
matches only input without explicit rests. Correcting that counter is pending.
Added waits may be recorded as rests; they do not acknowledge redraw completion or preserve
musical tempo. Measure type-in and playback separately before adding automatic
page compensation or lowering the defaults.

## Format and checks

VBK2 retains the eight-byte VBK1 header, with magic `VBK2`. Count is payload
bytes, not event count; CRC is unchanged. Each three-byte event is matrix key
0..35 (or FF for WAIT), held fields 1..255, released fields 0..255. Limit:
4095 bytes / 1365 complete events. Raw SHIFT and function keys are valid in
VBK2. APL-only VBK1 remains gated to the recognized Computational Language ROM.

VBK2 also accepts FE for the music Record/No-Record selector (inside shifted
mode), and FD for Replay (inside lower mode). The menu setting is latched at
download: Record maps FE to Z and FD to T; Playback maps FE to COMMA and FD
to a silent wait with the encoded duration. Older cores reject these events.
Auto-Repeat applies to both VBK1 and VBK2 and can be disabled during entry.

`make test-apl-source` runs both converters' tests and the loader RTL tests.
Full simulator captures and Quartus builds are separate checks.
