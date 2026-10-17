# Tape images

Load Expander 1 firmware. Copy `examples/tape/blank.vbt` to the SD card with a
new name, then choose **Tape > Mount Tape**. Set **Arm Recording** to **On** before
issuing the cartridge's SAVE command. It returns to **Off** when recording starts;
select **Off** before SAVE to cancel arming. Arming permits one recording, replacing
the mounted tape's contents. Wait for **Tape busy** and the user LED to clear
before unmounting or switching cores. **Tape error** means persistence failed,
even if the cartridge reports TAPE OK.

Issue the cartridge's LOAD or VERIFY command to replay the mounted recording.
Playback starts at the beginning on each playback remote request. Reset disarms
recording and cancels tape activity. An interrupted recording is invalid; arm
it again to reuse the image. Read-only images cannot be armed.

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

`make -C verilator test-expander1-playback` checks original-ROM SAVE/LOAD through
a remounted SD image, plus protection, sector boundaries, buffer wrap, reset
and capacity limits. Full APL/S workspaces and SD latency need MiSTer testing.
