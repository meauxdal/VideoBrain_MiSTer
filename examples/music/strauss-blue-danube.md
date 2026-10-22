# Strauss: The Blue Danube Waltz

Simple monophonic arrangement of the complete main theme, with pickup and
33 bars in 3/4. D major, C#3 through D5; 72 notes, quarter note = 150,
40 seconds plus controls. Both timing files are identical because the
arrangement needs no octave-bank changes.

Source: [Mutopia's main-theme piano reduction](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=519),
arranged and typeset by Nikos Kouremenos, from Christian Mondrup's four-hand
piano reduction at the Werner Icking Music Archive. Adapted from C major to
D major and lowered an octave. Melody calls alternate with the highest notes
of the response chords. Responses sound for an eighth note, with rests filling
their remaining score duration to suggest pizzicato. Accompaniment is omitted;
ties are merged into held notes. One MML line per source bar; tied notes extend
into the following line.

The MML and both generated VBKs are adaptations under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

Load Music Teacher 1, select Program 1 / Play-Record and lower SHIFT (no light
square). Set Music Mode to Playback, then load either
`timing/note-timing/strauss-blue-danube.vbk` or
`timing/score-timing/strauss-blue-danube.vbk`. Loading erases the previous
recording. Hardware playback has not been checked.

Regenerate from the repository root:

```sh
python3 verilator/keyboard_input.py examples/music/strauss-blue-danube.mml examples/music/timing/note-timing/strauss-blue-danube.vbk --profile music --start-mode letters --timing note
python3 verilator/keyboard_input.py examples/music/strauss-blue-danube.mml examples/music/timing/score-timing/strauss-blue-danube.vbk --profile music --start-mode letters --timing score
```
