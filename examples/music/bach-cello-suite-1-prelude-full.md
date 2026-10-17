# Bach: Cello Suite No. 1, Prelude (BWV 1007), full

All 42 measures, original cello register (C2 through G4), quarter note = 80.
656 notes; 670 timed events including controls. About 2 minutes 10 seconds.
The original `bach-cello-suite-1-prelude` files remain the four-measure excerpt.

Load Music Teacher 1, select Program 1 / Play-Record and lower SHIFT (no light
square). Set Keyboard Entry > Music Input to Playback, then load
`bach-cello-suite-1-prelude-full.vbk`. Auto-Repeat restarts the file until a
keypress or opening the OSD. Record truncates input at 79 notes.

The tied D in measure 22 is held continuously. Fermatas use fixed timing.
The final chord is rolled G2, B3, G4: a half note, a 32nd, then a whole note.
The bass G lingers before the upper notes resolve, following the supplied clip.
Octave-bank changes add control-key time. Hardware playback needs checking.

Regenerate from the repository root:

```sh
python3 verilator/keyboard_input.py examples/music/bach-cello-suite-1-prelude-full.mml --profile music --start-mode letters --min-hold 2 --gap 2
```

Score: [Mutopia, Andreas Scherer, public domain](https://www.mutopiaproject.org/ftp/BachJS/BWV1007/bwv1007/bwv1007-lys/).
Pitches and durations checked against the edition's MIDI, with the ending
adapted for monophonic playback.
