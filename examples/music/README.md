# Music examples

Use Music Teacher 1, Program 1 / Play-Record, lower SHIFT (no light square),
and **Input > Music Mode > Playback**. Load a `.vbk` from either folder.
Loading erases the previous recording. Playback avoids the cartridge
recorder's capacity limit.

| Folder | Behavior |
| --- | --- |
| `score-timing` | Keeps score tempo by fitting octave switches into preceding rests or shortening preceding notes. |
| `note-timing` | Keeps note/rest lengths and adds the acknowledged octave-switch delay. |

Both use two-field minimum holds and key-off gaps. Timing is rounded to video
fields; each note includes its key-off gap. Without octave changes, the two
versions are identical. Score timing can add delay if the preceding note or
rest is too short to absorb an octave switch.

To convert your own MML, see the [keyboard converter](../../tools/README.md#keyboard-files).
See [music input](../../docs/KEYBOARD-INPUT.md#music-teacher-1) for notation,
recording, replay and repeat settings.
