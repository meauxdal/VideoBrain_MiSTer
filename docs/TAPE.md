# Tape images

Load Expander 1 firmware. Copy `examples/tape/blank.vbt` to the SD card with a
new name, then choose **Tape > Mount Tape**. Set **Arm Recording** to **On** before
issuing the cartridge's SAVE command. Arming starts a new recording at the beginning
of the image. It stays **On** across record requests so multi-record saves append
all their blocks. Select **Off** after SAVE; starting playback also disarms it.
Wait for **Tape busy** and the user LED to clear before unmounting or switching
cores. **Tape error** reports a controller failure,
even if the cartridge reports TAPE OK.

Issue the cartridge's LOAD or VERIFY command to replay the mounted recording.
Playback resumes from its current position across remote stops. Remount the image
to rewind before another LOAD or VERIFY. Both remotes enabled is a setup state
and does not start a transfer. Reset disarms recording, rewinds and cancels tape
activity. An interrupted recording is invalid; arm it again to reuse the image.
Read-only images cannot be armed.

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
and capacity limits. Full APL/S workspaces and SD latency need MiSTer testing.
