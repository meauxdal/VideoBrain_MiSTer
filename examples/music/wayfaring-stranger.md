# Wayfaring Stranger

Complete traditional melody, also called "Poor Wayfaring Stranger".
Source: [North Atlantic Tune List transcription](https://abcnotation.com/tunePage?a=natunelist.net/the-wayfaring-stranger/index.html/0001).
Transposed from E minor to D minor, C4 through D5, with no octave-bank changes.
One 32-bar verse, without repeat or accompaniment; quarter note = 80.
Ties are merged into held notes. Temporary MML tempo changes encode long
tied durations to the nearest video field; they do not change the musical tempo.

Load Music Teacher 1, select Program 1 / Play-Record and lower SHIFT (no light
square). Set Music Mode to Playback and load `wayfaring-stranger.vbk`.
The file erases the previous recording. Its 78 notes and 12 rests can exceed
the cartridge recorder's capacity; use Playback for the complete melody.
About 99 seconds including controls. Hardware playback has not been checked.

Regenerate from the repository root:

```sh
python3 verilator/keyboard_input.py examples/music/wayfaring-stranger.mml --profile music --start-mode letters --min-hold 2 --gap 2
```

The `smooth` copy is identical because no octave switches are needed.
Verified against the source pitches, ties, triplets and 32 four-beat bars:
98 timed events, 302 bytes, VBK2 CRC-16 `10E2`.
