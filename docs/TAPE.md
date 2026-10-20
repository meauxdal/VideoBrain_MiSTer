# Tape images

Load Expander 1 firmware. Copy `examples/tape/blank.vbt` to the SD card with a
new name, then choose **Mount Tape** on the main menu. Issue the cartridge's
SAVE command to record. The first SAVE after mounting, rewinding, playback or
reset replaces the recording from the beginning. Subsequent SAVE requests append,
including the separate records in one workspace save. Mounting and playback do
not write the image. Read-only images reject recording.
Wait for **Tape busy** and the user LED to clear before unmounting or switching
cores. **Tape error** reports a controller failure,
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
