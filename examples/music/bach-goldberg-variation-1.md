# Bach: Goldberg Variations, Variation 1 (BWV 988)

Soprano voice, all 32 measures, each half played once. Transposed one octave
down to D2..D5; quarter note = 96. 298 notes, about one minute.
Rests, staff crossings and ties are preserved. The final fermata uses fixed timing.
The temporary T128 encodes the continuous B tied across measures 20-21.

Load Music Teacher 1, select Program 1 / Play-Record and lower SHIFT (no light
square). Set Keyboard Entry > Music Mode to Playback, then load
`bach-goldberg-variation-1.vbk`. Record truncates input at 79 notes.
The `smooth` version compensates octave-bank timing with 2/2-field controls;
see [keyboard input](../../docs/KEYBOARD-INPUT.md). Hardware playback untested.

Regenerate from the repository root:

```sh
python3 verilator/keyboard_input.py examples/music/bach-goldberg-variation-1.mml --profile music --start-mode letters --min-hold 2 --gap 2
python3 verilator/keyboard_input.py examples/music/bach-goldberg-variation-1.mml examples/music/smooth/bach-goldberg-variation-1.vbk --profile music --start-mode letters --min-hold 2 --gap 2 --bank-fields 2
```

Adapted from [Mutopia, JD Erickson, Bach-Gesellschaft](https://www.ibiblio.org/mutopia/cgibin/piece-info.cgi?id=980).
Pitches and durations checked against the edition's MIDI.
This transcription is licensed under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/).
