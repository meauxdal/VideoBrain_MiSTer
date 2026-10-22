# Music timing examples

Paired conversions of every MML source in the parent folder, for later tune
selection. Use Music Teacher 1, Program 1 / Play-Record, lower SHIFT (no light
square), and Music Mode > Playback. Loading a file erases the previous recording.
Playback avoids the cartridge recorder's capacity limit.

| Folder | Behavior |
| --- | --- |
| `score-timing` | Keeps score tempo by fitting octave switches into preceding rests or shortening preceding notes. |
| `note-timing` | Keeps note/rest lengths and adds the minimum acknowledged octave-switch delay. |

Both styles have passed hardware playback testing. Note timing requires a core
with bank acknowledgment and the original ED01 or current static-staff ROM.
Score timing's two-field bank presses were tested with the static-staff ROM.
Individual tunes still need listening and selection. Sources and arrangement
notes are in the parent folder.

Both use two-field minimum holds and key-off gaps. Timing is rounded to video
fields; each note includes its key-off gap. Without octave changes, both files
are identical. Score timing adds a startup delay when the first note requires
a bank change. It warns when a preceding note/rest cannot absorb a switch:
the full Bach cello prelude adds two fields at its last note; Sugar Plum Fairy
adds 45 fields across twelve switches.

Regenerate one tune from the repository root, replacing `TUNE` with its source
filename without the extension:

```sh
python3 verilator/keyboard_input.py examples/music/TUNE.mml examples/music/timing/score-timing/TUNE.vbk --profile music --start-mode letters --timing score
python3 verilator/keyboard_input.py examples/music/TUNE.mml examples/music/timing/note-timing/TUNE.vbk --profile music --start-mode letters --timing note
```

Score timing is the converter's default for new music conversions. The older
normal, smooth and ready files remain outside this folder; use this paired set
for comparison and selection.
