# VideoBrain Family Computer for MiSTer

An FPGA implementation of the 1978 Umtech VideoBrain Family Computer.

## Installing

Place the latest .rbf from releases in /media/fat/_Computers.

The core folder is /media/fat/games/VideoBrain. A BIOS is required. Verified BIOS ROMs are circulated split:

- **uvres1.bin** (a.k.a. **uvres_1n.d67**): MD5 CDF2F70F616AB61D7FBF31A3763BFC21, 2,048 bytes
- **uvres2.bin** (a.k.a. **resn2.e5**): MD5 E4B8B681CCCF4E8ECB09C3FDC206B8B2, 2,048 bytes

Use the [BIOS tool](tools/README.md#bios) to combine the files.

```text
tools/make_boot_rom.sh uvres1.bin uvres2.bin boot0.rom
```

Place boot0.rom in the VideoBrain games folder.

- boot0.rom: MD5 E1E7F6120EB8E23CA5C63B4246F04F18, 4,096 bytes

[Expander 1](docs/EXPANDER1.md) needs its firmware as boot1.rom (or loaded manually). This is required for Information Manager, Timeshare, and tape operation.

- boot1.rom: MD5 41DE2BCEFFB8257930A16E03FC431550, 2048 bytes

## Using the core

The OSD provides these file actions:

| Action | Use |
| --- | --- |
| Load Cartridge | Load .bin cartridge |
| Mount Playback Tape | Mount read-only .vbt |
| Mount Record Tape | Mount writable .vbt |
| Keyboard > Load Keyboard File | Load .vbk automatic keyboard entry file |

For tape function in most software, loading a single cassette into the Record deck is sufficient. Software can load from either deck, so the Playback deck can be used to prevent accidental overwrite. Information Manager's EDIT mode requires a tape with an existing saved record in Playback, in addition to Record tape to receive modified data. If this is not configured, an I/O ERR will occur. You may also encounter this error when tape data is invalid, or if the tape had advanced and was not rewound before operation. Re-mounting a tape also rewinds it to the beginning. See the [Information Manager user manual](docs/INFOMAN-MANUAL.md) for the tested create, review and edit sequences.

.vbk files are effectively macros. The principal use case is to have the core automatically input APL/S programs for you, though they have other uses as well. They can be used in any software. [Example](/examples) files and a [converter](tools/README.md#keyboard-files) to create new files are provided.

The converter accepts valid text files and converts them to .vbk files which will replay the input sequence. SHIFT state is observed to avoid flipped-state entries.

Music Macro Language (.mml) files can also be converted. MML files must use a simplified subset of the QB64 PLAY format. The converter generates unique musical .vbk files (with VBK2 header for differentiation from text entry files) for automatic playback in the free play mode in Music Teacher 1. Press Z (for 1) in Music Teacher 1 to get to the play/record screen before loading a .vbk. In other software, make sure you're at a text entry prompt.

Unload Cartridge returns to the built-in BIOS.

System > Master Control (Soft Reset) and Esc can both be used for Master Control, which is a physical key that acts as a soft reset on VideoBrain hardware. What this leaves in memory depends on the software. In APL/S, pressing this key will instantly wipe out any program in RAM. Keyboard > Esc Soft Reset > Off can be set to prevent accidental activation.

System > Info Messages can optionally disable pop-up notifications.

See [tape setup and recording behavior](docs/TAPE.md) for more info on loading from/saving to tape.

## Keyboard

![VideoBrain keyboard manual](/docs/VB_Keyboard.gif)

In the BIOS and most software, VideoBrain's SHIFT key is a toggle (like CapsLock on a modern keyboard). A square in the bottom right of the screen appears in some software to indicate when SHIFT is active; a light square is unshifted, dark is shifted. Other software will show your cursor as an L for unshifted (lowercase) and a U for shifted (uppercase). Timeshare uniquely uses SHIFT by holding, not as a toggle.

[How to play and use VideoBrain software](docs/HOW-TO-PLAY.md) provides the original manual diagrams, cartridge keyboard layouts, game-selection charts, and MiSTer control mappings for games and utilities.

Unique VideoBrain keys are mapped like this:

    SPACE           RUN/STOP
    ESC             MASTER CONTROL (soft reset)
    F1 / Backspace  BACK/TEXT
    F2 / Home       PREVIOUS/COLOR
    F3 / Enter      NEXT/CLOCK
    F4 / End        SPECIAL/ALARM
    F5 / Ctrl+Enter ERASE/RESTART

Both main Enter and keypad Enter alias F3. Enter and Backspace follow the same SHIFT mode and cartridge functions as F3 and F1; in Timeshare, carriage return remains F5.

The PC number row and numeric keypad also map `1234567890` to the VideoBrain key positions `ZXCSDFWER/`. These are aliases for the physical keys: select VideoBrain's numeric/SHIFT mode when the software requires it. In letter mode, they enter the corresponding letters (or `?` for `0`); cartridge overlays can assign other functions.

## Joysticks

VideoBrain supports 4 analog joysticks with one fire button each, though only one game (Tennis) supports 4 players. The VideoBrain joystick does not self-center; this can make things bit awkward in Tennis, which relies on that behavior. Modern self-centering sticks will snap your player back to a neutral position when you let go.

Use Calibrate Sticks when joysticks are active in-game to fully calibrate all joysticks for use. Joysticks drift diagonally until calibrated.

Tennis and other games do not share centering positions - this is correct to hardware. Auto applies the correct centering. You can override this in the OSD.

Joysticks > Paired Sticks lets a controller's right stick and Fire (Paired) operate another joystick. See [calibration and controller pairing](docs/JOYSTICK.md).

## Video

VideoBrain native output is interlaced. Video > 240p > On toggles progressive output. This changes vertical rollover and could affect joystick reads across that boundary. It seems to work fine, but please try with this setting disabled if you have issues.

## Split cartridge dumps

Information Manager and APL/S: The Computational Language need assembled ROM images. See [cartridge assembly](docs/CARTRIDGES.md#split-cartridge-conversion).

## Timeshare over UART - Telehack Example

Timeshare can connect to a text service through HPS, mimicking the function of the Expander 2 acoustic modem (acoustic emulation is not implemented). Notably, Timeshare can't send or display lowercase characters. This limits what you can realistically interface with. Telehack works well, though.

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

In Timeshare, F5 sends Carriage Return to submit a line. PC Enter still aliases F3 (NEXT), not Carriage Return. Unlike the rest of the software library, SHIFT is held, not a toggle.

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

## Tools

See [tools/README.md](tools/README.md) for BIOS and cartridge assembly, keyboard file conversion, and tape utilities.

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
- [Lowell O. Turner - nyx.net](https://www.nyx.net/~lturner/public_html/Fairchild_F8.html)
- [VESWiki](https://channelf.se/veswiki/index.php?title=Opcode)
- [James Price - 21 APL/S Games and One-Liners for Your Umtech VideoBrain (GitHub)](https://github.com/jamescprice/21-APL-Games-and-One-Liners-For-Your-Umtech-Videobrain)
- [Home Computer & Video Game Museum - VideoBrain](http://hcvgm.org/VideoBrain.html)
- [oldcomputers.net/videobrain.html](https://www.oldcomputers.net/videobrain.html)
- [forums.atariage.com](https://forums.atariage.com/topic/71151-videobrain-anyone-have-info/)

## Credits

Core by [Elle Ball (meauxdal)](https://github.com/meauxdal) with assistance from [Alan Steremberg (alanswx)](http://github.com/alanswx). LLM assistance was used in the creation of this core.

The F8 CPU and packages derive from [Grabulosaure's Channel F core](https://github.com/MiSTer-devel/ChannelF_MiSTer).

## License

[GPL-2.0-or-later](LICENSE). Bundled components retain their respective licenses.
