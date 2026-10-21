# Tape images

Load Expander 1 firmware. Copy `examples/tape/blank.vbt` to the SD card with a
new name, then choose **Mount Tape** on the main menu. Issue the cartridge's
SAVE command to record. The first SAVE after mounting, rewinding, playback or
reset replaces the recording from the beginning. Subsequent SAVE requests append,
including the separate records in one workspace save. Mounting and playback do
not write the image. Read-only images reject recording.
**Tape busy** is a popup refreshed during activity; **Tape idle** reports that
activity has ended. Notices wait until the OSD closes. Wait for the user LED to
clear before unmounting or switching cores. Idle does not verify cartridge data.
**Tape error** reports a controller failure,
even if the cartridge reports TAPE OK.

Issue the cartridge's LOAD or VERIFY command to replay the mounted recording.
Playback resumes from its current position across remote stops. Use
**Tape > Rewind Tape** before repeating LOAD or VERIFY. Both remotes enabled
is a setup state and does not start a transfer. Reset rewinds and cancels tape
activity. An interrupted recording is invalid; a new SAVE can replace it.

`python tools/new_tape.py [path.vbt]` creates an 8 MiB blank. Omitting the path
uses a timestamped name. Existing files are never replaced. Creating and mounting
a new image directly from the OSD requires MiSTer Main support.

VBT1 uses 512-byte sectors. Sector 0 contains `VBT1`, a little-endian 32-bit
clock rate (14318180 Hz), and a little-endian 32-bit interval count; remaining
header bytes are zero. Count FFFFFFFF marks an incomplete recording. Sector 1
onward holds little-endian 32-bit intervals: bit 31 is the digital level, bits
30:0 are its duration in clock ticks (minimum 2). Padding is ignored. Timing and
record gaps are retained while record remote is active. SD buffering uses 4 KiB;
overflow or playback underrun raises Tape error.

## Trim unused capacity

```text
python tools/trim_tape.py saved.vbt compact.vbt
```

Creates a separate copy with only the header and occupied 512-byte sectors,
retaining at least 1024 bytes for core compatibility. Header and interval bytes
remain unchanged. Invalid or incomplete recordings are rejected; existing files
are never replaced. Trimming does not make an image read-only. Use a separate
blank for future SAVE operations.

An 8 MiB blank reserves 2,097,024 waveform intervals, not 8 MiB of payload.
Enough recorded pulses can fill it; duration depends on pulse timing.
The modified Money Minder SAVE uses 57,985 intervals and trims to 232,960 bytes.
WAV imports from `tape_convert.py` already use the minimum sector-aligned size.

## WAV conversion

`tools/tape_convert.py` converts signal levels and durations without decoding
records or assuming a cartridge, baud rate, leader, gap length or checksum:

```text
python tools/tape_convert.py to-wav saved.vbt saved.wav
python tools/tape_convert.py to-vbt recording.wav recording.vbt
```

Export is mono signed 16-bit PCM, default 96000 Hz at 80% full scale. Use
`--rate 48000` or another supported playback rate if needed. `--amplitude`
sets the digital output level; cassette recording volume needs physical testing.
Both directions accept `--invert`. Existing output files are never replaced.

Import accepts uncompressed integer PCM WAV at 8, 16, 24 or 32 bits. Select
`--channel 1` or another 1-based channel for multichannel audio; channels are
never mixed. Default detection uses zero crossings. `--threshold` sets the
normalized center and `--hysteresis` sets a dead-band half-width; for example,
`--threshold 0.03 --hysteresis 0.02` switches high above 0.05 and low below 0.01.
Samples inside the band hold the previous level. The first sample uses the
center threshold. No automatic filtering, trimming, speed correction or added
leader is applied. Analog amplitude and noise cannot be retained in digital VBT.
Keep the original WAV as the preservation source.

Output VBT files are sector-aligned with at least two sectors. Their spare SAVE
capacity is limited; use `new_tape.py` for a separate recording blank. VBT does
not store time while record remote is stopped, so export cannot restore those
pauses. It retains all recorded levels and durations, including recorded gaps.

### Timing and validation

Edges are rounded from cumulative time, avoiding accumulated pulse-rounding
error. Export error is at most half a WAV sample per edge: 5.21 us at 96000 Hz
or 10.42 us at 48000 Hz. Individual interval error can reach one sample. Import
rounds detected sample positions to the nearest VBT clock tick (0.035 us maximum
error). A digital VBT/WAV/VBT round trip therefore has at most half a sample
plus half a VBT tick of edge error. A rate that erases an interval is rejected.
Adjacent equal-level intervals are coalesced; long VBT intervals are split as
needed without inserting edges. File bytes need not survive a round trip.

These bounds describe digital conversion. Analog threshold detection also
depends on sampling, gain, DC offset, noise and filtering; hysteresis can shift
edges. They are not the original cassette interface's acceptance limits.

`python -m unittest discover -s verilator/tests -p test_tape_convert.py` checks:

- Sean Riddle's local 12780 Hz, 8-bit WAV reproduces all 57983 intervals in
  `examples/tape/moneymindersave.vbt`, excluding its added lead-in and tail.
- Money Minder reference round trips at 22050, 44100, 48000 and 96000 Hz retain
  all edges within the bound and all seven decoded records and CRCs. Available
  local APL/S SAVE fixtures receive the same checks.
- Reference durations scaled to 90%, 95%, 105% and 110% survive conversion at
  48000 Hz and the existing timing-index-1 decoder's record/CRC checks.
  This tests the converter and that decoder, not firmware timing tolerance.
- Synthetic PCM tests cover all supported widths, channel isolation, inversion,
  long constant levels and arbitrary durations. Square-wave levels from 8% to
  80% full scale with +3% DC offset, bounded +/-1% noise and 2% hysteresis retain
  their edges. A separate first-order filtered signal at 48000 Hz retains all
  edges within two samples using an explicit threshold. These are controlled
  test conditions, not general limits for cassette recordings.

Sean's recording has loaded on MiSTer; edited data has also survived a core
SAVE, restart and LOAD. `examples/tape/moneymindersave-modified.vbt` contains the
million-dollar transfer, with cash changing from -$329.80 to $999,670.20.
Its direct waveform export is `examples/tape/moneymindersave-modified.wav`.
Original VideoBrain/Expander 1 playback of an exported
core SAVE remains unverified. A complete working setup may take weeks, months
or years to locate. Interoperability is plausible; analog levels, polarity and
firmware timing tolerance still require measurement. The next physical test is
to record that exported WAV onto cassette, then
LOAD it on an original VideoBrain with Expander 1 and Money Minder. Retain the
source VBT, exported WAV, recording settings and observed result.

`make -C verilator test-expander1-playback` checks two-record original-ROM
SAVE/LOAD through a remounted SD image, plus protection, sector boundaries,
buffer wrap, reset
and capacity limits. SD latency and broader program execution need MiSTer testing.

## APL/S dump conversion

`python tools/apl_tape.py convert input.bin output.vbt` extracts the two SAVE
records from a 16K MAME CPU-address-space dump: 67 bytes at 0E50 and 1001 bytes
at 1C02. SAVE places two-byte length fields at 0E4E and 1C00, before the payloads.
The output uses timing index 1, record CRCs and a two-second lead before each record.
Existing files are never replaced. Originals remain untouched.

`python tools/apl_tape.py inspect image.vbt` checks timing-index-1 record
framing and CRCs. `python -m unittest discover -s verilator/tests -p
test_apl_tape.py` checks extraction and the hardware-tested A=7, B=123 fixture.
Hardware testing passed the converted Guess program and regenerated A=7, B=123
save, including consecutive tape loads and execution without resetting.

`python tools/apl_tape.py regenerate input.vbt output.vbt` preserves decoded
records while regenerating their waveform, for a separate hardware timing check.

`python tools/apl_tape.py collection dumps_directory output_directory` converts
22 selected workspaces, with launch inputs in brackets in each filename.
NEXT submits each input; semicolons separate inputs. Sine and Pyramid retain
immediate expressions. Random Bars requires a separate native cassette save.
Existing identical images are checked; differing images are never replaced.
