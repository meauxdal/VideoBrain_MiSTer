# VideoBrain Family Computer for MiSTer

An FPGA implementation of the 1977 VideoBrain Family Computer: Fairchild F8 (3850 CPU, 3853 SMI) with the Umtech UV201 video chip and UV202 clock/bus chip. 

## Status

- All cartridges reach their expected first screen
- Joystick works (timing is approximate)
- 15.7 kHz analog video
- Preliminary Expander 1 support (no Expander 2 / modem / tape support currently)
- Integer scaling and scandoubler support

## Joystick

Set Joystick=On in the OSD. Stick Timing=Linear and Linear Preset=Auto are the defaults; Tennis and Gladiator presets can also be selected manually. Curve remains available. Paired Sticks lets the right stick and Fire 2 control the paired joystick: 1+2 / 3+4, or Doubles for 1+3 / 2+4. In Gladiator, push fully forward, then make a full-extreme circle on each controller at first-game start. See [joystick timing and verification](docs/JOYSTICK.md).

## Installing

Place the latest .rbf from releases in /media/fat/_Computers.

The core folder is /media/fat/games/VideoBrain. A BIOS is required. Verified BIOS ROMs are circulated split:

- uvres1.bin: MD5 CDF2F70F616AB61D7FBF31A3763BFC21, 2,048 bytes
- uvres2.bin: MD5 E4B8B681CCCF4E8ECB09C3FDC206B8B2, 2,048 bytes

Place boot0.rom in the VideoBrain games folder. Rename an existing firmware boot.rom to boot0.rom.

```text
tools/make_boot_rom.sh uvres1.bin uvres2.bin boot0.rom
```
- boot0.rom: MD5 E1E7F6120EB8E23CA5C63B4246F04F18, 4,096 bytes

Preliminary [Expander 1 support](docs/EXPANDER1.md) accepts its separate 2K firmware as boot1.rom or through the OSD. This is required for Information Manager.

### Split cartridge dumps

Information Manager (infoman.zip in MAME) and APL/S: The Computational Language (complang.zip) need assembled ROM images. Place the .zip files in software/vidbrain (MAME) and run from the repository root:

```sh
python3 tools/convert_software.py
```

Copy the resulting .bin files from software/converted to the VideoBrain games folder and load them through the OSD. The core selects their mappers automatically. See [chip order and padding](docs/CARTRIDGES.md#split-cartridge-conversion) to assemble them manually.

## APL/S source entry

Boot APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin and wait for its input prompt.
Choose **System > Enter Keyboard File**, select a `.vbk` file and close the OSD. The core
types the listing through the keyboard. Ready-to-load controls and their text
sources are in `examples/apl`. See [conversion, cancellation and limits](docs/APL-SOURCE.md).
Arithmetic, bars and the five Price first-batch programs passed hardware tests.
The RAM dump path is commented out; its code and files remain preserved.
For other programs and Music Teacher 1, see [keyboard input](docs/KEYBOARD-INPUT.md).

## Keyboard

![VideoBrain keyboard manual](/docs/VB_Keyboard.gif)

VideoBrain SHIFT is a toggle (think CapsLock on a modern keyboard). In the BIOS, the square in the bottom right of the screen changes color to indicate when SHIFT is active.

    SPACE       RUN/STOP
    ESC         MASTER CONTROL (reset)
    F1          BACK/TEXT
    F2          PREVIOUS/COLOR
    F3          NEXT/CLOCK
    F4          SPECIAL/ALARM
    F5          ERASE/RESTART

## Building

Use Quartus 17.0.2

## Sources

- [kevtris](http://blog.kevtris.org/blogfiles/videobrain/videobrain_unwrapped.txt)
- [Sean Riddle](https://www.seanriddle.com/vbinfo.html)
- [MAME](https://github.com/mamedev/mame/tree/master/src/mame/vidbrain)
- US patents [US4232374A](https://patents.google.com/patent/US4232374A) & [US4177462A](https://patents.google.com/patent/US4177462A)
- [orphanedgames.com/videobrain](https://orphanedgames.com/videobrain/)
- [channel_f_and_videobrain Yahoo/groups.io group](https://groups.io/g/Channel-F-and-VideoBrain)
