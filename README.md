# VideoBrain Family Computer for MiSTer

An FPGA implementation of the 1978 Umtech VideoBrain Family Computer, with its Fairchild F8 CPU, Umtech UV201 video chip and UV202 clock/bus chip.

## Status

All eighteen cartridges reach their expected first screen. Joystick timing and analog audio response remain approximations. Expander 1 supports tape SAVE/LOAD through SD images; Expander 2 and modem peripherals are unsupported. See [cartridge coverage](docs/CARTRIDGES.md).

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

**System > Load BIOS** loads an alternate combined 4K BIOS `.bin` through the same download path.

[Expander 1 support](docs/EXPANDER1.md) accepts its separate 2K firmware as boot1.rom or through the OSD. This is required for Information Manager and tape SAVE/LOAD.

### Split cartridge dumps

Information Manager and APL/S: The Computational Language need assembled ROM images. See [cartridge assembly](docs/CARTRIDGES.md#split-cartridge-conversion) for chip order and padding. Copy the assembled `.bin` files to the VideoBrain games folder and load them through the OSD. The core selects their mappers automatically.

## Using the core

The main menu provides the three file actions:

| Action | Use |
| --- | --- |
| Load Cartridge | Load a `.bin` cartridge and restart the machine. |
| Load Keyboard File | Type a `.vbk` file into the running program. |
| Mount Tape | Mount a `.vbt` image for the program's LOAD, VERIFY or SAVE commands. |

**Unload Cartridge** returns to the built-in BIOS. **Reset** restarts the machine with its cartridge retained. **System > Master Control** and Esc provide the machine's Master Control button.

For APL/S, wait for its input prompt before loading a keyboard file. Entry starts when the OSD closes. Ready-to-load examples are in `examples/apl`. See [APL/S entry](docs/APL-SOURCE.md) and [other programs and music](docs/KEYBOARD-INPUT.md). Keyboard Entry holds Music Mode and Auto-Repeat settings.

Tape recording starts when the program issues SAVE; mounting alone does not change the image. Tape holds Rewind Tape and busy/error indicators. See [tape setup and recording behavior](docs/TAPE.md).

## Joystick

Joysticks default to Connected. **Input > Stick Preset > Auto** selects the cartridge's linear timing; Tennis and Gladiator can also be selected manually. Use **Calibrate Sticks** while the game is reading the joystick. Paired Sticks lets a controller's right stick and Fire 2 operate another joystick. See [calibration and controller pairing](docs/JOYSTICK.md).

## Video

Native output is interlaced, with integer scaling and scandoubler options. **Video > 240p** provides experimental progressive output at about 59.695 Hz. It changes vertical rollover and can affect joystick reads across that boundary. See [240p verification](verilator/joystick_verification.md#experimental-240p).

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

Use Quartus 17.0.2. Simulation and regression instructions are in [verilator/README.md](verilator/README.md).

## Sources

- [Sean Riddle](https://www.seanriddle.com/vbinfo.html)
- [kevtris](http://blog.kevtris.org/blogfiles/videobrain/videobrain_unwrapped.txt)
- [MAME](https://github.com/mamedev/mame/tree/master/src/mame/vidbrain)
- US patents [US4232374A](https://patents.google.com/patent/US4232374A) & [US4177462A](https://patents.google.com/patent/US4177462A)
- [atariprotos.com](https://www.atariprotos.com/othersystems/videobrain/videobrain.htm)
- [orphanedgames.com](https://orphanedgames.com/videobrain/)
- [channel_f_and_videobrain Yahoo/groups.io group](https://groups.io/g/Channel-F-and-VideoBrain)
- [James Price - 21 APL/S Games and One-Liners for Your Umtech VideoBrain (GitHub)](https://github.com/jamescprice/21-APL-Games-and-One-Liners-For-Your-Umtech-Videobrain)
- [James Price - 21 APL/S Games and One-Liners for Your Umtech VideoBrain (PDF)](https://orphanedgames.com/videobrain/Books/21_APL-S_Games/21_APLS_Games_and_One-Liners_for_Your_Umtech_VideoBrain_(2025)(James_Price).pdf)
- [Home Computer & Video Game Museum - VideoBrain](http://hcvgm.org/VideoBrain.html)
- [oldcomputers.net/videobrain.html](https://www.oldcomputers.net/videobrain.html)
- [forums.atariage.com](https://forums.atariage.com/topic/71151-videobrain-anyone-have-info/)

## Credits

Core by [Elle Ball (meauxdal)](https://github.com/meauxdal) with assistance from [alanswx](http://github.com/alanswx). LLM assistance was used in the creation of this core.

The F8 CPU and packages derive from [Grabulosaure's Channel F core](https://github.com/MiSTer-devel/ChannelF_MiSTer).

## License

VideoBrain core sources: GPL v2 or later. Combined MiSTer build: GPL v3 or later, as required by included framework modules. See [LICENSING.md](LICENSING.md) for attribution, license texts, and third-party terms.
