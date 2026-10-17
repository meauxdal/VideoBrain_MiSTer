# Londonderry Air

Complete traditional melody from George Petrie, *The Ancient Music of
Ireland*, vol. 1 (Dublin, 1855), p. 57. Public-domain score:
[1855 print](https://commons.wikimedia.org/wiki/File:Londonderry_Air,_first_print_1855,_sheet_music_edited_by_George_Petrie.jpg).
[Trinity College Dublin](https://www.tcd.ie/library/exhibitions/in-tune/irish_folk_music.php)
confirms its inclusion in Petrie's 1855 collection. No lyrics or later arrangement.
This transcription and its timing are dedicated to the public domain (CC0).

Melody only, transposed from E-flat to B-flat: F#3 through D5, with no
octave-bank changes. Pickup plus 16 bars; each MML line follows that order.
The opening long notes in bars 1 and 5 use three eighths for four-beat phrasing.
Piano accompaniment and dynamic markings are omitted. Quarter note = 78,
with small phrase relaxations and a slower ending (72, then 70). The final
half-note/eighth-note tie is one held half note at 56, exactly five eighths
at 70. Slurs and articulation dots use the common two-field key-off gap.

Load Music Teacher 1, select Program 1 / Play-Record and lower SHIFT (no
light square). Set System > Music Teacher Input to Playback, then load
`londonderry-air.vbk`. Record truncates input at 79 notes; this file needs Playback.
98 note/rest events; 106 timed events including controls; about 53 seconds.
Hardware playback remains to be checked.

Regenerate from the repository root:

```sh
python3 verilator/keyboard_input.py examples/music/londonderry-air.mml --profile music --start-mode letters --min-hold 2 --gap 2
```

Checked against the historic melody: pitches, 64 quarter beats including
pickup and final tie, frame timing, capacity, VBK2 payload length and CRC-16
(`AC95`), and byte-for-byte regeneration. File size: 326 bytes.

