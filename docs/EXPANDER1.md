# Expander 1

Preliminary processor and host interface support. With the real Expander 1
firmware, Information Manager now reaches its expected first menu without
I/O ERR:

```text
PROGRAM
ENTER
REVIEW
EDIT
: _
```

Further investigation is needed for serial, tape and other peripheral
operations. The 3870 timer/interrupt ports, cassette paths and serial
peripherals are not implemented. Expander 2 and the Timeshare modem are
not supported.

The 2K firmware dump has CRC-32 `dac31abc`. Load it from the OSD's
Expander 1 ROM entry, or put it in the VideoBrain games folder as `boot1.rom`.
Keep the existing 4K BIOS in `boot0.rom`. Without an Expander ROM, its host
outputs remain released. Reset restarts both processors and retains the ROM.

## Hardware evidence

`refs/VideoBrain Transfers/Set 1/Image (33).jpg` gives the host cable wiring:

| VideoBrain signal | Expander board connector | 3870 pin |
|---|---|---|
| CPU I/O-15 | 4 | P1.0, pin 37 |
| CPU I/O-16 | 6 | P1.7, pin 25 |
| External interrupt | 5 | P1.1, pin 36 |
| Reset | 2 | Reset |

`Set 1/Image (31).jpg` identifies the MK3870 and labels its crystal 3.58.
The implementation uses a 3.579545 MHz oscillator rate and the existing F8
CPU's half-cycle enables. Confirm the exact crystal specification if available.

The modem connector is separate from the host cable. `Set 2/Image (73).jpg`
corrects its pins to receive 4, transmit 2, and signal ground 1.

## Validation

`make -C verilator test-expander1` uses synthetic firmware to check download,
execution, clock input, output polarity, reset and oversize rejection.
It does not establish tape or serial compatibility. Information Manager's
first menu is confirmed by the user as of October 11, 2026.

After rebuilding the headless simulator, test the actual firmware:

```sh
cd verilator
make headless
./obj_dir_headless/Vtop \
  --cart "../software/converted/Information Manager (prototype).bin" \
  --expander1 "../software/VideoBrain Expander I (197x)(VideoBrain Computer Company)(VideoBrain)(ROM)[F3870].bin" \
  --frames 300 --shot-last --outdir out/expander1
```

Expected first menu: PROGRAM, ENTER, REVIEW, EDIT and the `: _` prompt.
Cassette and serial operations remain unsupported.
