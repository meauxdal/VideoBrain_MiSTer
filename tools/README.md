# Tools

Run commands from the repository root. Python tools require Python 3.9 or
later; use `python` instead of `python3` where appropriate.

## BIOS

Combine the two 2,048-byte BIOS dumps in RES1, RES2 order using a POSIX shell:

```sh
sh tools/make_boot_rom.sh uvres1.bin uvres2.bin boot0.rom
```

See [installation](../README.md#installing) for ROM checksums and placement.

## Cartridges

`convert_software.py` assembles APL/S and Information Manager from MAME chip
archives. Supply a directory containing `vidbrain (MAME)/complang.zip` and
`vidbrain (MAME)/infoman.zip`; assembled images go in its `converted/` folder.

```sh
python3 tools/convert_software.py /path/to/roms
```

See [cartridge layouts](../docs/CARTRIDGES.md#split-cartridge-conversion).
ROMs and firmware are not bundled.

Optional cartridge modifications are described in the
[Music Teacher patch](../docs/MUSIC-TEACHER-PATCH.md) and
[Information Manager printer corrections](../docs/INFOMAN.md#printer-corrections).
`patch_music_teacher.py` and `patch_infoman_printer.py` each take an original
ROM path and a separate output path. Read the corresponding report before use.

## Keyboard files

Convert APL/S input, text, physical keys or Music Teacher MML to `.vbk`:

```sh
python3 tools/apl_source.py program.txt program.vbk
python3 tools/keyboard_input.py text.txt text.vbk --profile keyboard --start-mode letters
python3 tools/keyboard_input.py keys.txt keys.vbk --profile keys
python3 tools/keyboard_input.py music.mml music.vbk --profile music --start-mode letters
```

`apl_source.py` and the default `keyboard_input.py --profile apl` generate
APL/S input with NEXT after each nonblank line. `--hold-final` leaves the
last line unsubmitted. The `text` profile handles the built-in Text screen;
`keyboard` follows the printed keyboard. Both require `--start-mode`.
The `keys` profile accepts physical key scripts such as `NEXT 8 8` and
`WAIT 120`, with durations in video fields.

Music conversion defaults to score timing. `--timing note` retains note
lengths and adds octave-switch time; `--replay` requests replay after entry.
Use `--help` for all options. See [keyboard input](../docs/KEYBOARD-INPUT.md),
[APL/S entry](../docs/APL-SOURCE.md) and [examples](../examples/README.md).

## Printer images

Copy `examples/blank-printer.vbp` to a new name and mount it under Printer in
the OSD, or create one with Python:

```sh
python3 tools/printer_image.py new session.vbp
python3 tools/printer_image.py inspect session.vbp
python3 tools/printer_image.py export session.vbp printer.bin
```

After Stop and Save, wait for Ready and unmount before exporting. Export
preserves all eight bits and exact payload length. It refuses existing outputs
and incomplete/error sessions unless `--recover` is explicit. Optional
`--session N`, `--text FILE`, `--remove-nul` and `--normalize-crlf` select a
session or create a separate readable copy. See [printer images](../docs/PRINTER.md)
for operation, format, errors and hardware validation limits.

`capture_printer.py` remains the shared-UART diagnostic tool. Select System >
UART Output > Printer for it; simultaneous modem service uses the mounted-image
path instead.

## Tape images

`new_tape.py`, `trim_tape.py` and `tape_convert.py` create blank images, trim
unused capacity and convert VBT/WAV waveforms. See [tape images](../docs/TAPE.md).
