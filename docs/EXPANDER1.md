# Expander 1

Preliminary processor and host interface support. With Expander 1
firmware, Information Manager reaches its first menu without
I/O ERR:

```text
PROGRAM
ENTER
REVIEW
EDIT
: _
```

The 3870 timer, interrupt control ports and digital cassette SAVE/LOAD path
are implemented. See [SD tape images](TAPE.md). The modem serial port connects
to MiSTer's HPS UART. Expander 2 acoustic modem behavior and a connected
printer are not implemented.

The 2K firmware dump has CRC-32 `dac31abc`. Load it from the OSD's
System > Load Expander 1 ROM entry, or put it in the VideoBrain games folder as `boot1.rom`.
Keep the existing 4K BIOS in `boot0.rom`. Without an Expander ROM, its host
outputs remain released. Reset restarts both processors and retains the ROM.

## Hardware evidence

`refs/VideoBrain Transfers/Set 1/Image (33).jpg` gives the host cable wiring:

| VideoBrain signal | Expander board connector | 3870 pin |
|---|---|---|
| CPU I/O-15 | 4 | P1.0, pin 37 |
| CPU I/O-16 (bidirectional) | 6 | P1.7, pin 25 |
| External interrupt | 5 | P1.1, pin 36 |
| Reset | 2 | Reset |

`Set 1/Image (31).jpg` identifies the MK3870 and labels its crystal 3.58.
The implementation uses the NTSC colorburst rate (3.579545 MHz) and the
existing F8 CPU's half-cycle enables.

The board connection table in `refs/seanriddle.com/vbexpander1.xlsx` shows
U04.4 driving P0.2 from inverted P0.3. P0.2 also drives U04.2/12, whose
outputs feed R13/R14, C16 and Record Data. `record_data` exposes this digital
level before the analog network. P0.1 low enables the U07/U08 record remote;
`record_enable` exposes that request. The core exposes both for simulator
capture. P0.0 drives the U07/U02 playback remote; the tape image player supplies
P0.7 through the port's open-drain input path. Playback remains idle without
a mounted recording.

The MK3870 data book (pages 7-13) defines ports 6/7: binary modulo-N
counting, prescales 2/5/10/20/40/100/200, interval, pulse width and event
modes, and separate interrupt latches. Timer interrupts take priority at
0x020; external interrupts use 0x0A0. The timer advances at half the crystal
rate before prescaling. Port 6 reads the EXT INT pin in bit 7.

EXT INT is currently held high; pulse width and event modes are tested at
the timer module but await peripheral wiring in Expander 1. Ports 4/5 expose
digital serial inputs on bit 7 and outputs on bit 0. The serial interface
uses logical mark/space levels (idle high), before RS-232 voltage conversion.
The modem port connects to MiSTer's HPS UART, with synchronized receive input.
The printer input remains idle and its output is unconnected.

Serial command `04` takes a timing selector and routing flags. Timeshare uses
`04 01 0D` and `04 02 0D` for 110 and 300 baud. Flags `0D` route host data to
the modem and modem input to both the host and printer. The timer vector at
`0020` contains `LR P0,Q`; command `04` sets Q to `041A`. Timer control `AA`
selects /40 and enables timer interrupts, with external interrupts disabled.

Select the MiSTer UART service and set its baud rate to match Timeshare:
300 or 110. This configures the HPS endpoint; the cartridge and Expander ROM
still control the VideoBrain's serial timing. The connection uses TX/RX only;
HPS handshakes are held asserted. Live MiSTer communication remains unverified.

The modem connector is separate from the host cable. `Set 2/Image (73).jpg`
corrects its pins to receive 4, transmit 2, and signal ground 1.

## Validation

`make -C verilator test-expander1` checks all timer prescales and modes,
reload, readback, interrupt masking, priority and vector retention. Synthetic
firmware checks download, host lines, CPU port readback, timer ISR entry and
return, CPU interrupt masking, reset and oversize rejection.

`make -C verilator test-expander1-serial` runs the original ROM with command
`04 02 0D`, simultaneous host transmit and 300-baud modem receive, and checks
host delivery and printer copying. It repeats at 110 baud (`04 01 0D`).
Both rates check reverse routing (`32`), start/data/stop bits, and reset with
retained firmware. This validates the
digital serial boundary, not the analog line drivers or Expander 2 modem.

`make -C verilator test-expander1-record` additionally runs the original ROM
with a simulated host. Override `EXPANDER1_ROM` if needed. It records one byte
(`A5`), checks remote stop and success status, then checks rejection of a bad
host checksum. The edge capture in `verilator/out/expander1/record.csv` stores
simulation time, digital record level and remote enable. It is a diagnostic,
not a persistence format. The checker verifies pulse widths, decodes the
record and writes the raw bytes to `record.bin`:

```text
FF (16 bytes), 01 CD, 00 01, A5, 7E D6, 00
```

This proves a firmware record transaction without analog playback feedback.
On October 16, 2026, hardware testing confirmed `A=7`, SAVE ending with
TAPE OK, and continued arithmetic using A afterward. This validates transaction
completion and continued interpreter operation. Full-machine SAVE capture and
MiSTer SD SAVE/LOAD verification are still pending.

`make -C verilator test-expander1-playback` records two distinct payloads through
the original ROM without OSD arming, resets and remounts the SD image,
then checks successive LOAD payloads, CRCs and success status. The host uses
record timing 00 and receive timing 01, with
receive mode 01 to return data. The controller also checks recording protection,
sector transfer, buffer wrap, replay timing, interrupted saves and image limits.

The headless simulator's `--record FILE` captures digital edges and remote
changes as `cycle,level,enabled`, with cycles at 14.31818 MHz. This is a
diagnostic trace, not a persistence format.

`make -C verilator capture-apl-save` builds the simulator, enters `A=7` and
`SAVE` through the keyboard, captures 7000 video fields, and decodes the trace.
This is a long run: SAVE writes the entire workspace, including unused space
(APL/S manual, printed page 44). Inspect the final screenshot for TAPE OK.
Outputs are under `verilator/out/expander1/apl-save`. The decoder checks timing
index 00, record framing, big-endian payload length and CRC-16/CCITT (initial
0000, length and payload, low CRC byte first). Its raw `.bin` includes framing.

The digital image path preserves firmware record pulses and replays them at
P0.7. It does not model the analog cassette amplifier or accept audio files.

After rebuilding the headless simulator, test the actual firmware:

```sh
cd verilator
make headless
./obj_dir_headless/Vtop \
  --cart "../software/1 Cartridges/Information Manager (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)(prototype)[VB-1200].bin" \
  --expander1 "../software/0 BIOS/VideoBrain Expander I (197x)(VideoBrain Computer Company)(VideoBrain)(ROM)[F3870].bin" \
  --frames 300 --shot-last --outdir out/expander1
```
