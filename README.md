# VideoBrain Family Computer for MiSTer

An FPGA implementation of the 1977 VideoBrain Family Computer: Fairchild F8 (3850 CPU, 3853 SMI) with the Umtech UV201 video chip and UV202 clock/bus chip. 

## Status

- All tested software boots and plays
- 15.7kHz analog video works and is stable on 60Hz CRT
- WIP: Scratchy audio

## Installing

Place VideoBrain.rbf in e.g. /media/fat/_Computers. A BIOS is required. Verified BIOS ROMs are circulated split:

- uvres1.bin: MD5 `CDF2F70F616AB61D7FBF31A3763BFC21`, 2,048 bytes
- uvres2.bin: MD5 `E4B8B681CCCF4E8ECB09C3FDC206B8B2`, 2,048 bytes

A script to concatenate the circulating dumps is provided.

```text
tools/make_boot_rom.sh uvres1.bin uvres2.bin boot.rom
```
- boot.rom: MDS `E1E7F6120EB8E23CA5C63B4246F04F18`, 4,096 bytes

## Keyboard

![VideoBrain keyboard manual](/docs/VB_Keyboard.gif)

VideoBrain SHIFT is a toggle (think CapsLock on a modern keyboard). In the BIOS, the square in the bottom right of the screen changes color to indicate when SHIFT is active.

    SPACE       RUN/STOP                
    F1          BACK/TEXT
    F2          PREVIOUS/COLOR
    F3          NEXT/CLOCK
    F4          SPECIAL/ALARM
    F5          ERASE/RESTART

## Building

Use Quartus 17.0.2

## Sources

- kevtris
- Sean Riddle
- MAME
- US patents 4,232,374 & US 4,177,462