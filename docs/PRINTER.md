# Printer capture images

The core can save the actual Expander 1 printer output to a mounted `.vbp`
image while Timeshare continues bidirectional communication through the HPS
UART. Physical printing is not implemented. Printer receive stays idle; the
capture controller sends no acknowledgements or response characters.

## Capture a report or session

Information Manager's original prototype has printer row-count and serial
startup problems in the tested execution path. Printer > InfoMan Fix (Reload)
is Off by default, preserving the original software. To use the correction,
select On before loading the original cartridge. Reload after changing this
option in either direction. The core corrects only its loaded RAM copy of
the recognized original image; automatic mapper detection still applies.
See [Information Manager printer corrections](INFOMAN.md#printer-corrections)
for the ROM analysis, theoretical hardware effects and validation limits.

1. Copy `examples/blank-printer.vbp` to the SD card under a new name, or create
   an image with the tool below. Use a different file from either tape image.
2. Load Expander 1 firmware and a cartridge with printer support.
3. In **Printer > Mount Capture Image**, mount that file. Wait for scanning to
   finish; **Show Capture Status** reports Ready. Mounting does not write the file.
4. Select **Capture Baud**, then **Start Capture**. Wait for Active before
   requesting printer output. Information Manager uses 300; Timeshare uses its
   selected 110/300 transmission rate. Baud changes apply to the next session.
5. In Information Manager REVIEW, request `P DESC PTR`, `P ALL PTR`, or
   `TOTAL PTR` with the usual database/tape prerequisites. For simultaneous
   Timeshare, keep **System > UART Output > Modem** and run the normal UART
   bridge. The Printer UART selection remains an alternative diagnostic path.
6. When output finishes, choose **Stop and Save**, then wait for Ready and the
   user LED to clear. Unmount the printer image before exporting it, modifying
   it from Linux, switching cores, or removing media. Tape activity can also
   keep the LED on; check the individual status before changing either image.

Capture starts stopped after core startup. Stop/Start and clean remount append
separate sessions. Existing captured bytes are never intentionally overwritten.
For a new destination, mount a new blank file. There is no in-core erase/rewind.
Tape image mount/rewind does not reset printer storage. Machine reset stops
capture, aborts a partial serial character and marks the session interrupted;
complete buffered bytes are drained if storage remains available.

Do not start in the middle of a continuous stream. The receiver waits for two
mark intervals before arming, which cannot prove a boundary in arbitrary data.
Select the baud explicitly; a wrong rate can sometimes produce plausible bytes.
The eight sampled bits are retained even when the cartridge uses bit 7 as
parity. NUL, CR/LF, FF and flow-control values are not filtered.

Timeshare's manual describes both keyboard entries and host output going to
the printer. Its Expander routing copies modem input to printer TX. Remote
echo therefore includes keyboard entries in full duplex; local screen echo
alone does not print them in the tested original-ROM configuration. Capture never fills in missing printer
bytes from modem TX. PC ON/OFF controls display of control characters on the
screen and does not start or stop capture. See the validation results below for
the tested duplex/echo combinations.

## Tools

Run on Linux or a desktop with Python 3.9 or later:

```sh
python3 tools/printer_image.py new session.vbp
python3 tools/printer_image.py inspect session.vbp
python3 tools/printer_image.py export session.vbp printer.bin
python3 tools/printer_image.py export session.vbp report.bin \
  --session 1 --text report.txt --remove-nul --normalize-crlf
```

Creation defaults to 1 MiB; `--size` specifies allocated bytes, from 2048 to
16777216, in multiples of 512. Creation writes the allocation and syncs it.
Creation/export refuse to overwrite existing files. Export concatenates DATA
payloads only and emits a JSON summary with exact lengths, rate, stop reason
and diagnostic counters. Text conversion writes a separate file and does not
strip bit 7. Raw output preserves bytes, not waveform timing or character gaps.

Open, damaged or error sessions are refused by normal export. `--recover`
exports the contiguous verified prefix, warns and exits with status 2. It does
not skip a bad block or invent bytes. Inspect also exits 2 for incomplete/error
sessions. Invalid superblocks or operating-system errors exit 1. Keep the image
when investigating errors; recovery does not modify it. The core refuses to
append to interrupted/error images; create a new destination after recovery.

## Errors and storage limits

Show Capture Status distinguishes absent/read-only/bad/incomplete media, framing,
storage readback failure, FIFO overflow, image full and reset interruption.
Persistent Printer Error/Busy/Active menu rows remain available when info
popups are disabled. The Start action is unavailable during activity or a
latched error; remount an appropriate image before starting again.

Every written sector is read back and compared before being committed. A failed
comparison stops capture without automatic retry. An exchange pending for ten
seconds reports Stalled and retains its buffers. If service resumes before
overflow, capture can continue; on overflow it stops ingestion and reports an
incomplete capture. The 4096-byte FIFO can absorb approximately 136 seconds at
300 baud when initially empty; existing occupancy reduces this margin. It
cannot compensate for an indefinite Linux/SD stall or apply flow control to the
original firmware. Globally stalled HPS service can also affect cassette I/O.

DATA records flush at 480 bytes, after five seconds with pending bytes, or on
Stop. Partial sectors have an exact count and zero padding. The last available
record is reserved for STOP; Full never authorizes extending the image. A
1 MiB image stores about 982 KiB with full blocks, or roughly 300 KiB with
five-second partial flushes at 300 baud. Short sessions and pauses use space too.

Mounting scans the entire image for valid records followed by zero sectors.
Larger images take longer. A zero hole followed by nonzero data is an error,
not free space. Unexpected media replacement during an outstanding request
cannot be made atomic with the stock protocol; use the guarded mount entry.

Stock MiSTer ACK denotes sector exchange, not durable file-write success. Main
fetches the outgoing sector before writing the image; this implementation
requests readback afterward. Main opens ordinary writable images with O_SYNC,
but the FPGA has no explicit filesystem error or fsync response. Readback and
CRC do not guarantee power-loss durability. A core switch or power loss can
lose the buffered tail or tear the last sector. See the generic SD service in
[MiSTer Main](https://github.com/MiSTer-devel/Main_MiSTer/blob/master/user_io.cpp).

## VBP1 format

All integers are little-endian. Sectors are 512 bytes. CRC is reflected
CRC-32/ISO-HDLC (`zlib.crc32`) over all 512 bytes, with bytes 28..31 zeroed.

Sector 0 contains `VBP1` at 0, u32 version 1 at 4, u32 sector size 512 at 8,
u32 record header size 32 at 12, u32 allocated sector count at 16, and CRC at
28. Other bytes are zero. Subsequent allocated sectors start zeroed.

| Record offset | Field |
|---|---|
| 0 | Four bytes `VPR1` |
| 4 | u32 sequence, starting at 1 |
| 8 | u32 session ID, starting at 1 |
| 12 | u8 type: 1 START, 2 DATA, 3 STOP |
| 13 | u8 baud: 0=300, 1=110 |
| 14 | u16 payload byte count |
| 16 | u64 cumulative DATA byte offset before this record, across all sessions |
| 24 | u32 reason: 0 clean, 1 reset, 2 framing, 3 overflow, 4 full |
| 28 | u32 sector CRC |
| 32 | Payload, up to 480 bytes; remaining bytes zero |

START has no payload. DATA has 1..480 raw bytes and reason 0. STOP has 16 bytes:
four u32 counters for framing errors, rejected starts, known lost-byte lower
bound and storage stalls. Only DATA contributes to stream length. Counters do
not claim an exact total of bytes emitted after capture stops accepting data.
Every session uses one rate and ends with STOP. Sequence and byte offsets must
be contiguous. An interrupted session has no STOP. A non-clean STOP is an error
session even if all preceding bytes are recoverable.

## Validation

`make -C verilator test-printer` includes serial routing, the passive decoder,
image/export tests, faults and stock-hps_io three-drive contention. The
standalone tests scale CLOCK_HZ for speed; the original-ROM capture test uses
the real clock and firmware at both rates. `test-printer-cartridge` exercises
Timeshare keyboard/echo/duplex behavior through the original machine ROMs.
At both rates, typing A and CR and receiving X captured `41 8D 58` with remote
echo, and only `58` without echo, in both full and half duplex. Capture on/off
runs preserved keyboard modem transmission. The capture records printer TX;
it does not add locally displayed keyboard characters to the stream.
Stock hps_io tests suppress simulator diagnostics for pre-existing inactive
PS/2 and video helper constructs; sys itself is unchanged.

The October 25, 2026 Quartus 17.0.2 validation build used 13,641 ALMs and
144 RAM blocks, compared with the saved pre-capture baseline's 12,797 ALMs and
137 RAM blocks. Both capture memories infer as RAM. Constrained setup/hold
checks pass; the existing framework still has unconstrained external ports.
With the asynchronous board activity LED explicitly excluded in both timing
audits, the baseline and candidate have identical unconstrained-path counts.
The current candidate includes the committed OSD and Music Teacher changes.

For changes to the capture path, test both rates on MiSTer with a running
modem bridge, export known printer bytes, and confirm communication continues after
Stop. Run actual Information Manager PTR reports with playback and EDIT/SAVE/
reload with separate tape images. Check absent/read-only/full printer images
and a controlled storage-service stall. Record Main/RBF versions, byte
comparisons and cartridge results; a simulation pass is not a hardware pass.
Live capture cases without recorded results remain unverified. The remaining
Information Manager pass primarily supports the reconstructed manual; it is
not tracking a known core defect. See [current status](ACCURACY.md).
