# Bach: Well-Tempered Clavier, Book I, Prelude 1 (BWV 846)

All 35 measures, original register (C2 through A5), quarter note = 60.
549 notes; 618 timed events. The smooth version takes about 2 minutes 23 seconds.

Load Music Teacher 1, select Program 1 / Play-Record and lower SHIFT (no light
square). Set Keyboard Entry > Music Mode to Playback, then load
`smooth/bach-wtc-1-prelude-1.vbk` with the static-staff ROM, or
`bach-wtc-1-prelude-1.vbk` for standard octave-control timing.
Record truncates input at 79 notes. Hardware playback untested.

Each MML line is one measure. All note attacks through measure 34 are retained;
sustained bass notes end at the next attack for monophonic playback.
The final chord is rolled C2, C3, E4, G4 as sixteenths, then C5 as a dotted half.
The final fermata uses fixed timing.

Regenerate from the repository root:

```sh
python3 verilator/keyboard_input.py examples/music/bach-wtc-1-prelude-1.mml --profile music --start-mode letters --min-hold 2 --gap 2
python3 verilator/keyboard_input.py examples/music/bach-wtc-1-prelude-1.mml examples/music/smooth/bach-wtc-1-prelude-1.vbk --profile music --start-mode letters --min-hold 2 --gap 2 --bank-fields 2
```

Score: [Mutopia, Tobias Erbsland, public domain](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=5).
Pitches checked against the LilyPond source; VBK pitch decode, timing bounds,
payload length, CRC-16 and byte-identical regeneration verified.
