# Music sources and arrangements

These files reduce the cited scores to one melodic line for Music Teacher 1.
The matching `.mml` files are the editable sources; `.vbk` files use score
timing. See [playback and regeneration](README.md).

## Bach: Cello Suite No. 1, Prelude (BWV 1007)

`bach-cello-suite-1-prelude` contains all 42 measures, with 656 notes in the
original cello register. The tied D in measure 22 is held continuously.
Fermatas use fixed timing; the final chord is rolled G2, B3, G4.

Source: [Mutopia edition by Andreas Scherer](https://www.mutopiaproject.org/ftp/BachJS/BWV1007/bwv1007/bwv1007-lys/),
public domain. Pitches and durations were checked against the edition's MIDI;
the ending is adapted for monophonic playback.

## Bach: The Well-Tempered Clavier, Book I, Prelude No. 1 (BWV 846)

`bach-wtc-1-prelude-1` contains all 35 measures, with 549 notes. Sustained
bass notes end at the next attack; the final chord is rolled C2, C3, E4, G4,
then C5. The final fermata uses fixed timing. Each MML line is one measure.

Source: [Mutopia edition by Tobias Erbsland](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=5),
public domain. Pitches were checked against the LilyPond source.

## Chopin: Minute Waltz, Op. 64 No. 1

`chopin-minute-waltz` contains the repeated form, reduced to the uppermost
right-hand line, with 688 notes. The melody is lowered one octave; the final
high F and descending flourish are lowered a further octave. Accompaniment
and chord doublings are omitted. Explicit MIDI grace notes are retained;
trills and mordents retain the MIDI's plain held notes.

Source: [Mutopia's Edition Peters transcription](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=483),
typeset by Magnus Lewis-Smith, revision January 17, 2015, public domain.
The melody was extracted from the right-hand MIDI track and checked against
its LilyPond notation.

## Joplin: The Entertainer

`joplin-the-entertainer` contains the repeated form, with 754 notes. The
uppermost right-hand line is retained, including the introduction's
cross-staff phrase. Chords, octave doublings and accompaniment are omitted.
The arrangement is lowered one octave; the second B strain follows the
score's Repeat 8va instruction, returning down for the A pickup.

Source: [Mutopia's reproduction of the 1902 edition](https://www.mutopiaproject.org/ftp/JoplinS/entertainer/),
typeset by Chris Sawer and revised by Simon Albrecht, public domain.
Pitches and durations were checked against its LilyPond source and MIDI.

## Strauss: The Blue Danube Waltz, Op. 314, main theme

`strauss-blue-danube` contains the pickup and 33 bars of the main theme,
with 72 notes. The melody is transposed from C major to D major and lowered
an octave. Melody calls alternate with the highest notes of response chords;
responses sound for an eighth note, with rests suggesting pizzicato.
Accompaniment is omitted and ties are merged into held notes.

Source: [Mutopia's main-theme piano reduction](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=519),
arranged and typeset by Nikos Kouremenos, from Christian Mondrup's four-hand
piano reduction at the Werner Icking Music Archive.

The source arrangement and the adapted `strauss-blue-danube.mml` and
`strauss-blue-danube.vbk` are licensed under
[Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
Retain this attribution and license when redistributing these files.
