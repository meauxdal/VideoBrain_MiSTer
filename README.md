# VideoBrain Family Computer for MiSTer

An FPGA implementation of the 1978 Umtech VideoBrain Family Computer.

## Installing

Place the latest .rbf from releases in /media/fat/_Computers.

The core folder is /media/fat/games/VideoBrain. A BIOS is required. Verified BIOS ROMs are circulated split:

- uvres1.bin: MD5 CDF2F70F616AB61D7FBF31A3763BFC21, 2,048 bytes
- uvres2.bin: MD5 E4B8B681CCCF4E8ECB09C3FDC206B8B2, 2,048 bytes

Place boot0.rom in the VideoBrain games folder.

```text
tools/make_boot_rom.sh uvres1.bin uvres2.bin boot0.rom
```
- boot0.rom: MD5 E1E7F6120EB8E23CA5C63B4246F04F18, 4,096 bytes

System > Load BIOS manually loads an alternate combined 4K BIOS `.bin` through the same download path.

[Expander 1](docs/EXPANDER1.md) needs its 2K firmware as boot1.rom (or loaded manually). This is required for Information Manager, Timeshare, and tape operation.

## Using the core

The OSD provides these file actions:

| Action | Use |
| --- | --- |
| Load Cartridge | Load .bin cartridge and restart |
| Input > Load Keyboard File | Load .vbk automatic keyboard entry file |
| Mount Playback Tape | Mount read-only .vbt |
| Mount Record Tape | Mount writable .vbt |

.vbk files are custom automatic keyboard input files; basically macros. You can use them to automatically type in APL/S programs, play back music, enter game modes when using joysticks, among other things. They can be used in any software. [Example](/examples) files and a converter to create new files are provided. 

The converter generates unique musical .vbk files for automatic playback in the Play and Record freeform keyboard play in Music Teacher 1. Octave switching is handled automatically. 

Press Z (for 1) in Music Teacher 1 to get to the play/record screen before loading a .vbk. In other software, make sure you're at a text entry prompt.

Unload Cartridge returns to the built-in BIOS. System > Master Control (Soft Reset) and Esc can both be used for Master Control, which is a physical key that acts as a soft reset on VideoBrain hardware. What this leaves in memory depends on the software. In APL/S, this will instantly wipe out your program. Input > Esc Reset > Off can be set to prevent accidental Master Control activation.

System > Info Messages can optionally disable contextual notifications. 

See [tape setup and recording behavior](docs/TAPE.md) for more info on loading from/saving to tape.

## Keyboard

![VideoBrain keyboard manual](/docs/VB_Keyboard.gif)

In the BIOS and most software, VideoBrain's SHIFT key is a toggle (think CapsLock on a modern keyboard). A square in the bottom right of the screen appears in some software to indicate when SHIFT is active; white is unshifted, black is shifted. Other software will show your cursor as an L for unshifted (lowercase) and a U for shifted (uppercase). Timeshare uniquely uses SHIFT by holding, not as a toggle.

[How to play and use VideoBrain software](docs/HOW-TO-PLAY.md) provides
the original manual diagrams, cartridge keyboard layouts, game-selection
charts, and MiSTer control mappings for games and utilities.

Unique VideoBrain keys are mapped like this:

    SPACE       RUN/STOP
    ESC         MASTER CONTROL (soft reset)
    F1          BACK/TEXT
    F2          PREVIOUS/COLOR
    F3          NEXT/CLOCK
    F4          SPECIAL/ALARM
    F5          ERASE/RESTART

## Joystick

VideoBrain supports 4 analog joysticks with one fire button each, though only one game (Tennis) supports 4 players. The VideoBrain joystick does not self-center; this can make things bit awkward in Tennis, which relies on that behavior. Modern self-centering sticks will snap your player back to a neutral position when you let go.

Use Calibrate Sticks when joysticks are active in-game to fully calibrate all joysticks for use. Joysticks drift diagonally until calibrated.

Tennis and other games do not share centering positions - this is correct to hardware. Auto applies the correct centering. You can override this in the OSD.

Input > Paired Sticks lets a controller's right stick and Fire (Paired) operate another joystick. See [calibration and controller pairing](docs/JOYSTICK.md).

## Video

VideoBrain native output is interlaced. Video > 240p > On toggles progressive output. This changes vertical rollover and could affect joystick reads across that boundary. It seems to work fine, but please try with this setting disabled if you have issues.

### Split cartridge dumps

Information Manager and APL/S: The Computational Language need assembled ROM images. See [cartridge assembly](docs/CARTRIDGES.md#split-cartridge-conversion).

## Timeshare over UART - Telehack Example

Timeshare can connect to a text service through HPS, mimicking the function of the Expander 2 acoustic modem (aoustic emulation is not implemented). Notably, Timeshare can't send or display lowercase characters. This limits what you can realistically interface with. Telehack works well, though.

Expander 1 ROM (boot1.rom) is required for serial.

1. Load Timeshare cartridge
2. Set MiSTer's UART connection to None
3. Ensure SSH is enabled on your MiSTer, then run this command over SSH (requires socat and telnet):

```sh
stty -F /dev/ttyS1 300 raw -echo -ixon -ixoff -crtscts \
  cs8 -parenb -cstopb clocal istrip

TERM=dumb socat -d -d \
  FILE:/dev/ttyS1 \
  EXEC:'telnet telehack.com 23',pty,setsid,ctty,rawer,echo=0
```

In Timeshare, F5 is Carriage Return; your all-purpose Enter key. Unlike the rest of the software library, SHIFT is held, not a toggle. 

Telehack spacing will be disorganized as it expects a larger screen by default. Type this command (/ is Shift+H):

```text
STTY /TTY
```

(If you don't see what you're typing, you might be in half-duplex mode. To set full duplex in Timeshare use F4 + Shift + D. Full-duplex is the default. To set half-duplex, it's F4 + Shift + H)

You'll be prompted for the number of columns and rows your setup allows. Timeshare uses 24 by 15.

```text
NUMBER OF COLS? 24
NUMBER OF ROWS? 15
```

You should get a confirmation.

```text
%SIZE SET: 24X15
```

See [Timeshare setup, keys, and diagnostics](docs/EXPANDER1.md#timeshare-over-uart).

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
- [Home Computer & Video Game Museum - VideoBrain](http://hcvgm.org/VideoBrain.html)
- [oldcomputers.net/videobrain.html](https://www.oldcomputers.net/videobrain.html)
- [forums.atariage.com](https://forums.atariage.com/topic/71151-videobrain-anyone-have-info/)

## Credits

Core by [Elle Ball (meauxdal)](https://github.com/meauxdal) with assistance from [alanswx](http://github.com/alanswx). LLM assistance was used in the creation of this core.

The F8 CPU and packages derive from [Grabulosaure's Channel F core](https://github.com/MiSTer-devel/ChannelF_MiSTer).

## License

VideoBrain core sources are licensed under [GPL-2.0-or-later](LICENSE). Bundled components retain their respective licenses. See [licenses/LICENSING.md](licenses/LICENSING.md) for attribution and third-party terms.
