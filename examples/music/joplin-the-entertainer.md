# Scott Joplin: The Entertainer

Complete repeated form, reduced to one melodic line. Quarter note = 72;
about 4 minutes 19 seconds. 754 notes, 15 rests, 803 loader events.

The uppermost right-hand line is retained, including the introduction's
cross-staff phrase. Chords, octave doublings and accompaniment are omitted.
The arrangement is one octave lower (G2 through B5); the second B strain
follows the score's Repeat 8va instruction, returning down for the A pickup.
Long ties use local tempo commands to preserve their held duration at field
resolution. Octave-bank changes add control-key time.

Load Music Teacher 1, select Program 1 / Play-Record and lower SHIFT (no light
square). Select Keyboard Entry > Music Input > Playback, then load
`joplin-the-entertainer.vbk`. Auto-Repeat loops until a keypress or opening
the OSD. Record truncates input at 79 notes.

Regenerate from the repository root:

```sh
python3 verilator/keyboard_input.py examples/music/joplin-the-entertainer.mml --profile music --start-mode letters --min-hold 2 --gap 2
```

Source: [Mutopia's public-domain reproduction of the 1902 edition](https://www.mutopiaproject.org/ftp/JoplinS/entertainer/),
typeset by Chris Sawer and revised by Simon Albrecht. Pitches and durations
checked against its LilyPond source and MIDI. Hardware playback needs checking.
