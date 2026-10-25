# Experimental Music Teacher static-staff patch

`tools/patch_music_teacher.py` accepts only the original 2048-byte ED01 ROM
(SHA256 `6f68d96533795159a18d757629a0fb5d5fa5d228c43361d8565b84cb1ee3d198`).
It creates a new image and refuses to overwrite an existing file:

```sh
python tools/patch_music_teacher.py original-ed01.bin musicteacher-static-staff.bin
```

The staff stays visible, note names use the existing six slots, and the five
scanlines containing the names are cleared at wrap. Rests retain their original
blank slots and playback delays. The patch bypasses note/rest staff glyphs while
retaining pitch decoding, audio setup and recording. It modifies shared drawing
code, so the glyph suppression also applies to Program 2; that program has not
been validated for this use. Entry, erase and replay startup still draw the staff.

The original static-staff patch only reset counters at wrap, allowing old note
names to accumulate through the ROM's OR blitter. This revision clears exactly
`$0EC4..$0EFF` (60 bytes), stopping before recorder memory at `$0F00`. It leaves
the shared OR blitter intact and suppresses the rest glyph as the first patch
did. Claude's attached attempt instead changes the shared blitter and removes
rest slots from replay; neither change is needed to fix accumulated names.

The helper occupies now-unused note positioning code at `$1388`. The entry at
`$1368` jumps to the existing POPK/PK epilogue; `$136B` jumps to the new wrap
helper. Live-note, replay and rest wrap sites call `$136B`. The helper makes no
nested calls and returns with POP, preserving the caller's return address.

## Octave switching

The ED01 octave handlers at `$114E` (Low), `$115E` (Middle), and `$1163` (High)
set R6 and converge at `$1153`. That instruction writes one background-colour
byte to `$08F5`. In Program 1 they return through `$115B` to `$109C`, which calls
the release/new-key routine at `$14C8`. They do **not** call the full redraw at
`$13D9`.

The redraw clears 768 framebuffer bytes with three calls to BIOS `$41C8` between
chunks, then draws the staff. Replacing page-wrap redraws therefore removes
substantial work, but does not remove the separate octave-key interaction.
The keyboard routine also calls `$41C8` while waiting for release and a new key;
the BIOS scheduler waits on video Y (see `AUDIO-DIAGNOSTIC.md`). No keyboard waits
are removed in this revision. Actual octave latency and audio improvement need
runtime measurement; this patch does not claim a measured speedup.

The core's ROM CRC allowlist includes this output (`3BE4D855`) so automatic
VBK2 octave acknowledgment remains available. Existing RBFs recognize only the
previous ROMs; rebuild the core to use these hooks with this revision. Physical
keyboard operation does not require that recognition. Score-timed VBK files
still budget four fields per switch in the converter, regardless of ROM changes.

## Pitch range and a possible dedicated player

The keyboard banks expose Low C2..D4, Middle C3..D5 and High C4..B5, covering 48
chromatic pitches in total. These are software mappings, not the hardware's
complete pitch range. The CPU drives a DAC; other software can use different
timing and waveforms. An expanded player would need to establish useful pitch
limits, tuning error and audio stability experimentally.

A dedicated score player could accept absolute pitches and durations directly,
avoiding octave-key events and keyboard polling. That is a separate implementation
from fixing the display of the existing interpreter.

## Validation

Run `python -B -m unittest discover -s verilator/tests -p test_music_teacher_patch.py`.
The checks execute the injected clearing loop, verify exact write bounds and
register preservation, reject invalid inputs, and (with the original ROM present)
verify patch bytes, unchanged keyboard/blitter/bank handlers and CRC recognition.
These are focused software checks, not a full F8 or hardware simulation.

MAME 0.289 validation on 2026-10-25 entered Program 1 and played
C4, D4, E4, F4, G4, A4, B4. Screenshots show six names followed by B alone
in the first slot; framebuffer bytes `$0C00..$0EC3` remained identical across
all seven notes. This validates live page wrap in that emulator. It does not
validate replay, Program 2, audio quality or MiSTer hardware timing.

For RTL readiness checks, run `make test-music-input MT1_PATCHED_ROM=/path/to/output.bin`
from `verilator/`. That test exercises the recognition hooks using synthetic
instruction fetches; it does not execute a song or validate the rendered display.
Full-machine visual/audio and Program 2 checks remain necessary.
