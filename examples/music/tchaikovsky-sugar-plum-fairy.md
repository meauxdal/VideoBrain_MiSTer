# Tchaikovsky: Dance of the Sugar Plum Fairy

Complete 52-bar monophonic reduction. 336 notes, quarter note = 60, about
1 minute 45 seconds plus ROM acknowledgment time. Range: D2 through B5.

The celesta is lowered two octaves. The middle section follows the clarinet
and English horn; bass-clarinet responses, introductory pizzicato and celesta
arpeggios fill melody gaps. Chords use their highest note. Dynamics and
staccato markings are reduced to the fixed two-field key-off interval.

Load Music Teacher 1, select Program 1 / Play-Record and lower SHIFT (no light
square). Select Keyboard Entry > Music Mode > Playback, then load
`ready/tchaikovsky-sugar-plum-fairy.vbk`. Record truncates the song at 79 notes.
This file uses Ready controls for octave changes. Hardware playback has not
been checked for this arrangement.

Regenerate from the repository root:

```sh
python3 verilator/keyboard_input.py examples/music/tchaikovsky-sugar-plum-fairy.mml examples/music/ready/tchaikovsky-sugar-plum-fairy.vbk --profile music --start-mode letters --min-hold 2 --gap 2 --bank-ready
```

Source: [Ted Muller's score and MusicXML files](https://tedmuller.us/Piano/SugarPlumFairy.htm),
orchestral and celesta parts. Celesta upper staff supplies the outer sections;
orchestral clarinet and English horn supply bars 21-32. Celesta lower-staff
arpeggios supply bars 33-36, ending with the flute response.
