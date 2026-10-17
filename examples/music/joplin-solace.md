# Joplin: Solace (A Mexican Serenade)

Full form: introduction, AABB, A return, CCDD; all repeats and alternate
endings expanded (148 performed bars). Quarter note = 72; E3 through E5.
731 notes and one final rest; 750 timed events including controls, about 4:09.

Melody reduction of the public-domain 1909 piano work, lowered one octave.
Accompaniment, chord and octave doubling, dynamics and fermata extensions are
omitted. The upper line leads except in printed measures 72-75 and 80-83,
where the moving line below the Bb/A pedal is retained; the pedal and upper
flourish in measure 83 are omitted. This keeps the final strain's moving motif.
The syncopated attacks and triplet ornaments remain (`48` means a triplet
32nd). Representable ties remain single notes; 21 ties of 5/16, 5/8 or 11/16
need reattacks because MML has no ties. Their total durations are unchanged.
Playback quantizes timing to fields and adds octave-bank control time.

Load Music Teacher 1, select Program 1 / Play-Record and lower SHIFT (no light
square). Select Keyboard Entry > Music Input > Playback, then load
`joplin-solace.vbk`. Record truncates input at 79 notes. Hardware playback untested.

Regenerate from the repository root:

```sh
python3 verilator/keyboard_input.py examples/music/joplin-solace.mml --profile music --start-mode letters --min-hold 2 --gap 2
```

Source: [Mutopia edition 482, Magnus Lewis-Smith](https://www.mutopiaproject.org/ftp/JoplinS/solace/),
`solace-lys.zip` and `solace.mid`. The typesetter dedicates the edition to the
public domain. This arrangement is also dedicated to the public domain (CC0).
Pitches and exact notated durations checked against the source MIDI and
LilyPond; VBK2 pitch/timing decode, 1365-event cap, CRC-16 (`11A9`) and
byte-identical regeneration verified.
