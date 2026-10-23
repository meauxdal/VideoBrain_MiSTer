# VideoBrain Family Computer for MiSTer

An FPGA implementation of the 1978 Umtech VideoBrain Family Computer, with its Fairchild F8 CPU, Umtech UV201 video chip and UV202 clock/bus chip.

## Status

All eighteen cartridges reach their expected first screen. Joystick timing and analog audio response remain approximations. Expander 1 supports tape SAVE/LOAD through SD images and Timeshare internet sessions through MiSTer's UART. Expander 2 acoustic modem behavior is unsupported. See [cartridge coverage](docs/CARTRIDGES.md).

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

[Expander 1 support](docs/EXPANDER1.md) accepts its separate 2K firmware as boot1.rom or through the OSD. This is required for Information Manager, Timeshare serial communication, and tape SAVE/LOAD.

### Split cartridge dumps

Information Manager and APL/S: The Computational Language need assembled ROM images. See [cartridge assembly](docs/CARTRIDGES.md#split-cartridge-conversion) for chip order and padding. Copy the assembled `.bin` files to the VideoBrain games folder and load them through the OSD. The core selects their mappers automatically.

## Using the core

The OSD provides these file actions:

| Action | Use |
| --- | --- |
| Load Cartridge | Load a `.bin` cartridge from the main menu and restart the machine. |
| Input > Load Keyboard File | Type a `.vbk` file into the running program. |
| Mount Playback Tape | Mount a `.vbt` source for LOAD, VERIFY or database input. |
| Mount Record Tape | Mount a separate writable `.vbt` for SAVE or database output. |

**Unload Cartridge** returns to the built-in BIOS. **Reset** restarts the machine with its cartridge retained. **System > Master Control (Soft Reset)** and Esc provide the machine's Master Control button.

Set **Input > Esc Reset > Off** to prevent accidental Master Control presses
while using F1 for backspace. It defaults to On; the OSD Master Control action
remains available when Esc is disabled.

For APL/S, wait for its input prompt before loading a keyboard file. Entry starts when the OSD closes. Ready-to-load examples are in `examples/apl`. See [APL/S entry](docs/APL-SOURCE.md) and [other programs and music](docs/KEYBOARD-INPUT.md). **Input** holds **Music Mode** and **Music Repeat** settings.

[Music examples](examples/music/timing/README.md) provide Score timing and Note timing versions for Playback.

Tape recording starts when the program issues SAVE; mounting alone does not change the image. Each tape has its own rewind entry on the main menu. Use different source and output files. **System > Info Messages** controls keyboard-entry and tape notifications. See [tape setup and recording behavior](docs/TAPE.md).

## Timeshare over UART

Timeshare can connect to an internet text service through MiSTer's Linux side.
The original cartridge and Expander 1 firmware handle serial communication;
Linux bridges the UART to the network without an Expander 2 modem.

1. Load the Expander 1 firmware and Timeshare cartridge. Timeshare defaults to 300 baud.
2. Set MiSTer's UART connection to **None**, leaving `/dev/ttyS1` available for direct access.
3. Select Timeshare full duplex: hold **F4 + Shift**, tap **D**, then release.
4. Over SSH to MiSTer, run the following with `socat` and `telnet` installed:

```sh
stty -F /dev/ttyS1 300 raw -echo -ixon -ixoff -crtscts \
  cs8 -parenb -cstopb clocal istrip

TERM=dumb socat -d -d \
  FILE:/dev/ttyS1 \
  EXEC:'telnet telehack.com 23',pty,setsid,ctty,rawer,echo=0
```

Watch the VideoBrain for the banner. Press **F5** for Carriage Return after
each command or answer. In Timeshare, **hold Shift** for shifted characters;
it does not lock. Type `/` with **Shift+H**. Configure Telehack as follows:

```text
STTY /TTY
NUMBER OF COLS? 24
NUMBER OF ROWS? 15
%SIZE SET: 24X15
```

Space advances its `--MORE--` prompt.
Stop the bridge with Ctrl+C in SSH.

Telehack sessions have displayed Zork, weather, date, and paginated command
lists on MiSTer at 300 baud. See [Timeshare setup, keys, and diagnostics](docs/EXPANDER1.md#timeshare-over-uart)
for echo settings, limitations, and a local command service.

## Joystick

Joysticks default to Connected. **Input > Stick Preset > Auto** selects the cartridge's linear timing; Tennis and Gladiator can also be selected manually. Use **Input > Calibrate Sticks** while the game is reading the joystick. **Input > Paired Sticks** lets a controller's right stick and **Fire (Paired)** operate another joystick. See [calibration and controller pairing](docs/JOYSTICK.md).

## Video

Native output is interlaced, with integer scaling and scandoubler options. **Video > 240p** provides experimental progressive output at about 59.695 Hz. It changes vertical rollover and can affect joystick reads across that boundary. See [240p verification](verilator/joystick_verification.md#experimental-240p).

## Keyboard

![VideoBrain keyboard manual](/docs/VB_Keyboard.gif)

In the BIOS, VideoBrain SHIFT is a toggle (think CapsLock on a modern keyboard). The square in the bottom right of the screen changes color to indicate when SHIFT is active. Programs can use SHIFT differently: in Timeshare, hold it while pressing the desired key.

**[How to play and use VideoBrain software](docs/HOW-TO-PLAY.md)** provides
the original manual diagrams, cartridge keyboard layouts, game-selection
charts, and MiSTer control mappings for games and utilities.

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

VideoBrain core sources are licensed under [GPL-2.0-or-later](LICENSE). Bundled components retain their respective licenses. See [licenses/LICENSING.md](licenses/LICENSING.md) for attribution and third-party terms.
