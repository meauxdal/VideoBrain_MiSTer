# VideoBrain Family Computer for MiSTer

An FPGA implementation of the 1977 VideoBrain Family Computer: Fairchild F8 (3850 CPU, 3853 SMI) with the Umtech UV201 video chip and UV202 clock/bus chip. 

## Status

- Sixteen single-image cartridges boot and render; see [cartridge status](docs/CARTRIDGES.md) for test coverage and limitations
- Working joystick
- 15.7kHz analog video works
- Known issues: Imperfect audio. Pinball background fix awaits MiSTer validation (see [cartridge status](docs/CARTRIDGES.md)).

## Joystick

Set Joystick=On and Stick timing=Curve in the OSD. Curve is the default.
In Gladiator, push fully forward, then make a full-extreme circle on each
controller at first-game start. See [joystick timing and verification](docs/JOYSTICK.md).

## Installing

Place VideoBrain.rbf in e.g. /media/fat/_Computers. A BIOS is required. Verified BIOS ROMs are circulated split:

- uvres1.bin: MD5 `CDF2F70F616AB61D7FBF31A3763BFC21`, 2,048 bytes
- uvres2.bin: MD5 `E4B8B681CCCF4E8ECB09C3FDC206B8B2`, 2,048 bytes

A script to concatenate the circulating dumps is provided.

```text
tools/make_boot_rom.sh uvres1.bin uvres2.bin boot.rom
```
- boot.rom: MD5 `E1E7F6120EB8E23CA5C63B4246F04F18`, 4,096 bytes

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
