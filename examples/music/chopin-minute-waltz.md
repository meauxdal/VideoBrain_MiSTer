# Chopin: Minute Waltz, Op. 64 No. 1

Complete repeated form, reduced to the uppermost right-hand line. 688 notes,
4 rests, 709 loader events. Quarter note = 200, slowing to 168 for the final
flourish; about 2 minutes 10 seconds with `smooth`.

The melody is one octave lower. The final high F and the remaining descending
flourish are lowered a further octave, including the final D-flat. Range:
C2 through F5. Accompaniment and chord doublings are omitted. Explicit MIDI
grace notes are retained at four fields, borrowing time from preceding notes.
Ties remain continuous; trills and mordents retain the MIDI's plain held notes.
Local lengths and tempo commands preserve durations at field resolution.

Load Music Teacher 1, select Program 1 / Play-Record and lower SHIFT (no light
square). Select Keyboard Entry > Music Mode > Playback. Record truncates the
song at 79 notes. Hardware playback needs checking with both ROM versions.

Regenerate from the repository root:

```sh
python3 verilator/keyboard_input.py examples/music/chopin-minute-waltz.mml --profile music --start-mode letters --min-hold 2 --gap 2
python3 verilator/keyboard_input.py examples/music/chopin-minute-waltz.mml examples/music/ready/chopin-minute-waltz.vbk --profile music --start-mode letters --min-hold 2 --gap 2 --bank-ready
python3 verilator/keyboard_input.py examples/music/chopin-minute-waltz.mml examples/music/smooth/chopin-minute-waltz.vbk --profile music --start-mode letters --min-hold 2 --gap 2 --bank-fields 2
```

The main file uses fixed 8/8 octave controls. `ready` uses ROM acknowledgments;
`smooth` fits fixed 2/2 octave controls into preceding note time. Compare both
ROM versions before choosing a common setting.

Source: [Mutopia's public-domain Edition Peters transcription](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=483),
typeset by Magnus Lewis-Smith, revision 2015/01/17. Melody extracted from the
right-hand MIDI track and checked against its LilyPond notation.
