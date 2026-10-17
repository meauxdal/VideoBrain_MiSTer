# Bach: Jesu, Joy opening figure (BWV 147/6)

Opening instrumental passage only: first violin/oboe line, measures 1-8,
plus its closing G at measure 9. Strictly monophonic, without chorale voices
or accompaniment. Original G major and register, D4 through G5; 72 notes
and two rest events. This is not the complete chorale or cantata.

Tempo is an adaptation: dotted-quarter beat = 72 in the instrumental 9/8.
MML uses T72 L12 for three equal notes per beat. Each eighth rounds to 17
video fields. The closing G and two quarter rests at the chorale entry use
one beat each; the rests are merged as R2. Slurs do not join repeated notes.
One octave-bank change adds 16 fields. The file takes about 26 seconds,
including controls and the closing silence, and can auto-repeat.

Load Music Teacher 1, select Program 1 / Play-Record and lower SHIFT (no light
square). Set System > Music Teacher Input to Playback, then load
`bach-jesu-joy-figure.vbk`. System > Auto-Repeat repeats until a keypress or
opening the OSD. Hardware playback has not been checked.

Regenerate from the repository root:

```sh
python3 verilator/keyboard_input.py examples/music/bach-jesu-joy-figure.mml --profile music --start-mode letters --min-hold 2 --gap 2
```

Verified: pitches and rhythm against printed page 213 (PDF page 23),
byte-identical regeneration, VBK2 CRC B202, 83 timed events, 257 bytes.

Source: J. S. Bach, Bach-Gesellschaft Ausgabe, Band 40, edited Paul Waldersee,
Breitkopf & Hartel, 1884, plate B.W. XL; public domain.
[IMSLP, complete score #01405](https://imslp.org/wiki/Herz_und_Mund_und_Tat_und_Leben,_BWV_147_(Bach,_Johann_Sebastian)).
Transcribed from the supplied `IMSLP01405-BWV0147.pdf`; no piano arrangement used.
