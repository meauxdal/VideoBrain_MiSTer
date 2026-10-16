# Bach: Cello Suite No. 1, Prelude (BWV 1007)

Opening four complete measures, 64 sixteenth notes, original cello register
(G2 through C4). Tempo: quarter note = 80; video-field timing rounds each
sixteenth to 11 fields. All notes use the Low bank.

Select Music Teacher 1 Program 1 / Play-Record, with lower SHIFT (no light
square), then load `bach-cello-suite-1-prelude.vbk`. It erases the previous
recording, enters the excerpt, stops recording, and replays in Record mode.
Select System > Music Teacher Input > Playback to play live without recording.
System > Auto-Repeat repeats the file until a keypress or opening the OSD.

Five measures need 80 notes; the documented recorder limit is 79 note/rest
entries. This excerpt uses two-field release gaps and no page waits to reduce
extra rest entries. Complete recording still needs hardware confirmation.

Regenerate from the repository root:

```sh
python3 verilator/keyboard_input.py examples/music/bach-cello-suite-1-prelude.mml --profile music --start-mode letters --min-hold 2 --gap 2 --replay
```

Score: [Mutopia, Andreas Scherer, public domain](https://www.mutopiaproject.org/ftp/BachJS/BWV1007/bwv1007/bwv1007-lys/).
The cello edition transposes its relative-pitch source down one octave.
