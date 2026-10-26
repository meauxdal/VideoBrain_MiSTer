# Music examples

Five pieces for Music Teacher 1, with MML sources and ready-to-load VBK files:

- Bach: Cello Suite No. 1, Prelude (`bach-cello-suite-1-prelude`)
- Bach: The Well-Tempered Clavier, Book I, Prelude No. 1 (`bach-wtc-1-prelude-1`)
- Chopin: Minute Waltz (`chopin-minute-waltz`)
- Joplin: The Entertainer (`joplin-the-entertainer`)
- Strauss: The Blue Danube (`strauss-blue-danube`)

See [sources, arrangement changes and licenses](SOURCES.md). The Blue Danube
MML and VBK use CC BY-SA 4.0; retain their attribution when sharing them.

Use Music Teacher 1, Program 1 / Play-Record, lower SHIFT (no light square), and **Keyboard > Music Mode > Playback**. Load a `.vbk` from this folder. Loading erases the previous recording. Playback avoids the cartridge recorder's capacity limit.

These examples use score timing, with two-field minimum holds and key-off gaps. Octave switches fit into preceding rests or shorten preceding notes to preserve the score tempo. Timing is rounded to video fields; each note includes its key-off gap. An octave switch can add delay if the preceding note or rest is too short to absorb it.

To regenerate a file from the repository root:

```sh
python3 tools/keyboard_input.py examples/music/chopin-minute-waltz.mml --profile music --start-mode letters --timing score
```

The converter also supports `--timing note`, which preserves note/rest lengths and adds octave-switch time. See the [keyboard converter](../../tools/README.md#keyboard-files) and [music input](../../docs/KEYBOARD-INPUT.md#music-teacher-1) for conversion options, notation, recording, replay and repeat settings.

All five VBKs reproduce exactly from their MML sources. Complete hardware
playback remains to be checked. Four songs exceed the cartridge's 79-entry
recording limit; use Playback for the full files. The cello prelude's final
octave switch adds two video fields because the preceding note is too short
to absorb it.
