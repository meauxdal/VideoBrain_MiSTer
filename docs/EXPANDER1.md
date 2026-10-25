# Expander 1

Preliminary processor and host interface support. With Expander 1 firmware, Information Manager reaches its first menu without I/O ERR:

```text
PROGRAM
ENTER
REVIEW
EDIT
: _
```

The 3870 timer, interrupt control ports and digital cassette SAVE/LOAD path are implemented. See [SD tape images](TAPE.md). MiSTer's HPS UART defaults to the modem serial port and can select the printer port for [file capture](#printer-file-capture). Expander 2 acoustic modem behavior and physical printing are not implemented.

The 2K firmware dump has CRC-32 `dac31abc`. Load it from the OSD's System > Load Expander 1 ROM entry, or put it in the VideoBrain games folder as `boot1.rom`. Keep the existing 4K BIOS in `boot0.rom`. Without an Expander ROM, its host outputs remain released. Reset restarts both processors and retains the ROM.

## Hardware evidence

The VideoBrain Transfers board photograph (Set 1, Image 33) gives the host cable wiring:

| VideoBrain signal | Expander board connector | 3870 pin |
|---|---|---|
| CPU I/O-15 | 4 | P1.0, pin 37 |
| CPU I/O-16 (bidirectional) | 6 | P1.7, pin 25 |
| External interrupt | 5 | P1.1, pin 36 |
| Reset | 2 | Reset |

Image 31 in the same set identifies the MK3870 and labels its crystal 3.58. The implementation uses the NTSC colorburst rate (3.579545 MHz) and the existing F8 CPU's half-cycle enables.

Sean Riddle's board connection table in `vbexpander1.xlsx` shows U04.4 driving P0.2 from inverted P0.3. P0.2 also drives U04.2/12, whose outputs feed R13/R14, C16 and Record Data. `record_data` exposes this digital level before the analog network. P0.1 low enables the U07/U08 record remote; `record_enable` exposes that request. The core exposes both for simulator capture. P0.0 drives the U07/U02 playback remote; the tape image player supplies P0.7 through the port's open-drain input path. Playback remains idle without a mounted recording.

The MK3870 data book (pages 7-13) defines ports 6/7: binary modulo-N counting, prescales 2/5/10/20/40/100/200, interval, pulse width and event modes, and separate interrupt latches. Timer interrupts take priority at 0x020; external interrupts use 0x0A0. The timer advances at half the crystal rate before prescaling. Port 6 reads the EXT INT pin in bit 7.

The [1981 Mostek source audit](MOSTEK-1981-AUDIT.md) corroborates these functional rules but records unresolved DI/EI timing, POP semantics, interrupt selection/clearing, timer synchronization and reset-state questions in the shared F8 implementation. Current tests do not establish those internal 3870 timing boundaries.

EXT INT is currently held high; pulse width and event modes are tested at the timer module but await peripheral wiring in Expander 1. Ports 4/5 expose digital serial inputs on bit 7 and outputs on bit 0. The serial interface uses logical mark/space levels (idle high), before RS-232 voltage conversion. The modem port connects to MiSTer's HPS UART by default, with synchronized receive input. System > UART Output selects Modem or Printer. In Printer mode the UART transmits printer port 4, modem receive is held idle, and printer receive remains idle. HPS handshakes remain asserted in both modes.

Serial command `04` takes a timing selector and routing flags. Timeshare uses `04 01 0D` and `04 02 0D` for 110 and 300 baud. Flags `0D` route host data to the modem and modem input to both the host and printer. The timer vector at `0020` contains `LR P0,Q`; command `04` sets Q to `041A`. Timer control `AA` selects /40 and enables timer interrupts, with external interrupts disabled.

For managed MiSTer UART services, set the baud rate to match Timeshare: 300 or 110. For direct Linux access, select connection None and configure `/dev/ttyS1` as below. The cartridge and Expander ROM still control the VideoBrain's serial timing. The connection uses TX/RX only; HPS handshakes are held asserted. Bidirectional communication with Timeshare has been verified on MiSTer at 300 baud; live 110-baud operation is unverified.

The modem connector is separate from the host cable. `Set 2/Image (73).jpg` corrects its pins to receive 4, transmit 2, and signal ground 1.

## Timeshare over UART

The working path is Timeshare -> Expander 1 serial port -> MiSTer HPS UART -> Linux -> remote server. Select System > UART Output > **Modem** (the default). Linux replaces the telephone connection with a network bridge. Expander 2 dialing, acoustic coupling, and telephone-line behavior are bypassed, not emulated.

### Setup and keys

Load Expander 1 firmware and the Timeshare cartridge. Set MiSTer's UART connection to **None** so Linux can access `/dev/ttyS1` directly. Timeshare defaults to 300 baud and full duplex. Its display is 24 columns by 15 lines. The Timeshare owner's handbook, printed pages 8-16, describes its terminal behavior and keyboard overlay. These PC key mappings use the core's keyboard matrix. PC Enter (including keypad Enter) aliases F3 (NEXT), not Carriage Return; Ctrl does not replace CONTROL. In Timeshare, Shift is held while pressing a key, not toggled as in the BIOS.

| Function | PC keyboard action |
| --- | --- |
| Carriage Return / submit line | F5, without Shift |
| CONTROL | Hold F4 |
| Slash (`/`) | Hold Shift, tap H, then release |
| Full duplex, remote echo (default) | Hold F4 + Shift, tap D, then release |
| Half duplex, local echo | Hold F4 + Shift, tap H, then release |
| Select 300 baud | Hold F4 + Shift, tap C, then release |
| Select 110 baud (live operation unverified) | Hold F4 + Shift, tap Z, then release |

Full duplex expects the host to echo typed characters. If typing is invisible, enable host echo or select half duplex. If characters appear twice, select full duplex or disable host echo. The bridge below uses full duplex and leaves echo to the remote service.

### Internet connection

The tested MiSTer installation provides `/usr/bin/telnet`, `/usr/bin/socat`, `/usr/bin/python3`, and `/usr/bin/nc`; only Telnet and socat are needed here. Stop any UART diagnostic or local service before starting the bridge. Run over SSH:

```sh
stty -F /dev/ttyS1 300 raw -echo -ixon -ixoff -crtscts \
  cs8 -parenb -cstopb clocal istrip

TERM=dumb socat -d -d \
  FILE:/dev/ttyS1 \
  EXEC:'telnet telehack.com 23',pty,setsid,ctty,rawer,echo=0
```

`istrip` removes bit 7 from incoming Timeshare keyboard bytes for the text session. The separate raw-byte diagnostic below deliberately omits it. The Telnet client runs on a pseudo-terminal and handles Telnet negotiation; protocol control bytes are not sent directly to Timeshare. `TERM=dumb` requests a basic terminal. The serial connection uses TX/RX only, with hardware and software flow control disabled. At 300 baud, output arrives at about 30 characters per second; allow the banner to finish.

[Telehack](https://telehack.com/telehack.html) accepts uppercase commands. On the VideoBrain, enter `STTY /TTY` for teleprinter mode and answer its dimension prompts as follows. Type `/` with Shift+H; press F5 after the command and each answer.

```text
STTY /TTY
NUMBER OF COLS? 24
NUMBER OF ROWS? 15
%SIZE SET: 24X15
```

These dimensions make output fit the display and let the server pause at its `--MORE--` prompt; press Space to continue. Some output retains fixed spacing or wraps within words. Terminal dimensions and paging belong to the server, not the UART bridge. Stop socat with Ctrl+C in SSH.

On October 20, 2026, this bridge supported interactive Telehack sessions: paginated command lists, Zork's opening scene and input prompt, weather, and date output were displayed on the VideoBrain. Space successfully advanced server pagination. This validates remote text sessions at 300 baud; it does not establish ANSI terminal compatibility, complete game coverage, Linux console login, or live 110-baud operation.

### Local command service

For a small offline host, run this over SSH instead of the network bridge. Select half duplex for local echo. Type TIME, DATE, HELP, or QUIT on the VideoBrain, followed by F5. Ctrl+C in SSH also stops the service.

```sh
stty -F /dev/ttyS1 300 raw -echo -ixon -ixoff -crtscts \
  cs8 -parenb -cstopb clocal istrip icrnl

(
  printf '\r\nTIMESHARE HOST\r\nTIME DATE HELP QUIT\r\n> '
  while IFS= read -r cmd; do
    case "$cmd" in
      TIME) date '+%H:%M:%S' | tr '\n' '\r' ;;
      DATE) date '+%Y-%m-%d' | tr '\n' '\r' ;;
      HELP) printf 'TIME DATE HELP QUIT' ;;
      QUIT) printf 'GOODBYE\r\n'; break ;;
      '') continue ;;
      *) printf 'TYPE HELP' ;;
    esac
    printf '\r\n> '
  done
) < /dev/ttyS1 > /dev/ttyS1
```

`icrnl` converts Timeshare's Carriage Return to the newline expected by `read`. This is a diagnostic example; the confirmed remote-session results above use the Telnet bridge.

## Printer file capture

The first capture path shares MiSTer's existing HPS UART. Select **System > UART Output > Printer** before starting printer output, then capture `/dev/ttyS1` from Linux to a normal file. This carries the actual Expander printer TX signal, including host-to-printer output and any firmware-directed modem-to-printer copies. It does not substitute modem TX for printer TX. Selecting **Modem** restores Timeshare's existing bidirectional connection. The single UART cannot service a Timeshare network bridge and printer capture simultaneously; stop the bridge before switching. Switching during a character can corrupt it.

A mounted SD image would allow simultaneous ports but would need FPGA serial decoding, buffering, capacity handling and a fixed-size image/export format. Sharing the UART provides ordinary variable-length files with Linux handling framing and storage. Independent simultaneous capture is deferred.

Load the Expander ROM and a cartridge with printer support. Set MiSTer's UART connection to **None**, and stop other processes using `/dev/ttyS1`. Copy `tools/capture_printer.py` to MiSTer, then run over SSH, using a new destination filename:

```sh
python3 /media/fat/Scripts/capture_printer.py \
  /media/fat/printer-report.bin --baud 300
```

Wait for `Capturing` before requesting output. In Information Manager REVIEW, use an output command with the `PTR` suffix, for example `P ALL PTR`, `DESC PTR` or `TOTAL PTR`; the normal tape/record prerequisites still apply. Wait for output to finish, then press Ctrl+C in SSH. The utility syncs the file, reports the byte count and restores the previous UART settings. It refuses to overwrite an existing file. `--baud 110` supports firmware configured for 110 baud; `--idle-timeout 10` optionally stops after ten seconds without bytes, including before the first byte. The default waits until stopped because pauses between pages can be long.

The file preserves all eight bits, including leading NULs, parity-bearing bytes and CR/LF. It is a raw printer stream, not a screenshot or a Unicode conversion. For Information Manager only, a separate readable copy can remove its leading NULs:

```sh
tr -d '\000' < /media/fat/printer-report.bin > /media/fat/printer-report.txt
```

Keep the raw capture when investigating another cartridge's encoding. The utility configures 8N1 reception, with no echo, parity stripping, CR/LF translation, XON/XOFF or hardware flow control. An 8N1 receiver accepts Information Manager's extra stop interval. It sends no response characters.

### Firmware findings

Serial command `04` consumes a timing selector and routing flags. Original-ROM tests cover timing selectors `01` (110 baud) and `02` (300 baud), with one start bit, eight LSB-first data bits and a stop mark. The Expander 1 manual advertises ASCII RS232-C at 110/300/1200 baud, but 1200 baud is not verified here. The firmware samples a host command bit after releasing its interrupt strobe; the test host holds the final routing bit for 2 ms before driving serial idle, rather than changing it immediately on strobe release.

Information Manager's ROM listing (`VideoBrain-ASM/infoman/infoman.lst`, 3716-377F) sends `04 02 02`: 300 baud, host to printer port 4. Its serial-byte routine at 3E2D-3E5C supplies a start, eight data bits and two mark intervals. Each formatted line contains NUL, five spaces, sixteen screen glyphs converted through table 3782, and CR/LF. The printer-only regression reproduces this command and framing with NUL, space, high-bit data, CR, LF and FF bytes at both rates and after reset. Printer RX stays high throughout; transmission requires no printer ACK, status byte or echo. This establishes a passive sink for this route, not a general model of every physical printer protocol. The unused modem TX does not carry the printer payload.

Timeshare uses routing `0D`, which sends host data to modem TX and copies modem RX to printer TX as well as the host. The reverse-route test uses `32`. These routes remain firmware-controlled and unchanged by the OSD selector; the selector only chooses which physical TX connector reaches Linux. Live printer capture on MiSTer and actual cartridge report/listing completion remain to be checked on hardware.

## Validation

### MiSTer UART

On October 20, 2026, Timeshare displayed `UUUUUUUU` and `MISTER CONNECTED` sent from Linux through `/dev/ttyS1`. Linux also captured Timeshare keyboard transmissions. The confirmed Linux settings were 300 baud, 8 data bits, no parity checking, one stop bit, and no hardware or software flow control. MiSTer's UART connection was set to None to leave the device available for direct access. With Expander 1 firmware and Timeshare loaded, run over SSH:

```sh
stty -F /dev/ttyS1 300 raw -echo -ixon -ixoff -crtscts cs8 -parenb -cstopb clocal
printf '\r\nUUUUUUUU\r\nMISTER CONNECTED\r\n' > /dev/ttyS1
od -An -tx1 -v < /dev/ttyS1
```

The banner checks receive; typing in Timeshare checks transmit. Stop `od` with Ctrl+C in SSH. All 61 non-space bytes in the 64-byte keyboard capture had even parity; three spaces were `20`. Masking bit 7 recovered readable keyboard sequences. Preserve raw bytes until the parity behavior is resolved. Linux 8N1 is a verified transport setting, not proof of the cartridge's intended character format. Remote text sessions were subsequently verified with the bridge above. Console login, printer connector behavior, and acoustic modem operation remain unverified.

### Simulation

`make -C verilator test-expander1` checks all timer prescales and modes, reload, readback, interrupt masking, priority and vector retention. Synthetic firmware checks download, host lines, CPU port readback, timer ISR entry and return, CPU interrupt masking, reset and oversize rejection.

`make -C verilator test-expander1-serial` runs the original ROM with command `04 02 0D`, simultaneous host transmit and 300-baud modem receive, and checks host delivery and printer copying. It repeats at 110 baud (`04 01 0D`). Both rates check reverse routing (`32`), start/data/stop bits, and reset with retained firmware. This validates the digital serial boundary, not the analog line drivers or Expander 2 modem.

`make -C verilator test-printer` includes those regressions and adds printer-only routing `02`, multi-byte output at 110/300 baud without printer responses, reset/restart, and idle modem TX at serial bit centers. It tests the actual MiSTer wrapper's UART source selection, receive isolation and return to Modem. A Linux pseudo-terminal test runs the capture utility at both rates, checks every byte value and control characters through the file path, restores tty settings and checks overwrite refusal.

`make -C verilator test-expander1-record` additionally runs the original ROM with a simulated host. Override `EXPANDER1_ROM` if needed. It records one byte (`A5`), checks remote stop and success status, then checks rejection of a bad host checksum. The edge capture in `verilator/out/expander1/record.csv` stores simulation time, digital record level and remote enable. It is a diagnostic, not a persistence format. The checker verifies pulse widths, decodes the record and writes the raw bytes to `record.bin`:

```text
FF (16 bytes), 01 CD, 00 01, A5, 7E D6, 00
```

This proves a firmware record transaction without analog playback feedback. On October 16, 2026, hardware testing confirmed `A=7`, SAVE ending with TAPE OK, and continued arithmetic using A afterward. This validates transaction completion and continued interpreter operation. Full-machine SAVE capture and MiSTer SD SAVE/LOAD verification are still pending.

`make -C verilator test-expander1-playback` records two distinct payloads through the original ROM without OSD arming, resets and remounts the SD image, then checks successive LOAD payloads, CRCs and success status. The host uses record timing 00 and receive timing 01, with receive mode 01 to return data. The controller also checks recording protection, sector transfer, buffer wrap, replay timing, interrupted saves and image limits.

The headless simulator's `--record FILE` captures digital edges and remote changes as `cycle,level,enabled`, with cycles at 14.31818 MHz. This is a diagnostic trace, not a persistence format.

`make -C verilator capture-apl-save` builds the simulator, enters `A=7` and `SAVE` through the keyboard, captures 7000 video fields, and decodes the trace. This is a long run: SAVE writes the entire workspace, including unused space (APL/S manual, printed page 44). Inspect the final screenshot for TAPE OK. Outputs are under `verilator/out/expander1/apl-save`. The decoder checks timing index 00, record framing, big-endian payload length and CRC-16/CCITT (initial 0000, length and payload, low CRC byte first). Its raw `.bin` includes framing.

The digital image path preserves firmware record pulses and replays them at P0.7. It does not model the analog cassette amplifier or accept audio files.

After rebuilding the headless simulator, test the actual firmware. Replace the ROM placeholders with paths to your Information Manager cartridge and Expander 1 firmware images:

```sh
cd verilator
make headless
./obj_dir_headless/Vtop \
  --cart /path/to/infoman.bin \
  --expander1 /path/to/expander1.bin \
  --frames 300 --shot-last --outdir out/expander1
```
