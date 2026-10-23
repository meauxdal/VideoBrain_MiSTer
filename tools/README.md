# VideoBrain tools

Run these commands from the repository root. The Python tools require Python 3.9 or newer and use only the standard library. Use `python` instead of `python3` if that is how Python is installed on your system. The BIOS tool requires a POSIX shell, available on Linux, macOS, WSL or Git Bash.

| Tool | Purpose |
| --- | --- |
| `make_boot_rom.sh` | Combine the two BIOS chips into `boot0.rom`. |
| `convert_software.py` | Assemble cartridge images from MAME ZIP archives. |
| `apl_source.py` | Convert APL/S listings to `.vbk` keyboard files. |
| `keyboard_input.py` | Convert text, physical key scripts or music to `.vbk`. |
| `new_tape.py` | Create a blank `.vbt` recording image. |
| `trim_tape.py` | Remove unused capacity from a recorded `.vbt`. |
| `tape_convert.py` | Convert between PCM WAV and `.vbt` waveforms. |

## BIOS

```sh
sh tools/make_boot_rom.sh uvres1.bin uvres2.bin boot0.rom
```

Each input must be 2,048 bytes. The output contains RES1 followed by RES2; an existing output is replaced. Copy `boot0.rom` to the MiSTer VideoBrain games folder. See [installation](../README.md#installing) for ROM checksums and Expander 1 firmware.

## Cartridges

```sh
python3 tools/convert_software.py /path/to/software
```

Place MAME ZIP archives in `vidbrain (MAME)` inside the supplied directory. The default directory is this repository's `software` folder. Both `complang.zip` (APL/S) and `infoman.zip` (Information Manager) are required; the tool checks their chip sizes and CRCs, assembles their ROMs and adds padding. Other archives must contain a single cartridge image.

Output goes to `converted` inside the supplied directory, with CRC-32 and SHA-1 values in `checksums.tsv`. Images matching existing `.bin` files in the supplied directory are skipped for single-chip cartridges. An existing output image with different contents is rejected. See [cartridge layouts](../docs/CARTRIDGES.md#split-cartridge-conversion) for manual assembly.

## Keyboard files

```sh
python3 tools/apl_source.py listing.txt
python3 tools/keyboard_input.py input.txt --profile keyboard --start-mode letters
python3 tools/keyboard_input.py message.txt --profile text --start-mode letters --hold-final
python3 tools/keyboard_input.py input.keys --profile keys
python3 tools/keyboard_input.py song.mml --profile music --start-mode letters --timing score
```

Both converters accept an optional output path after the source; otherwise they write beside the source with a `.vbk` extension. Existing outputs are replaced, but the source cannot be overwritten. Input is UTF-8. Copy the `.vbk` to MiSTer and choose **Input > Load Keyboard File** at the program's input prompt.

| Profile | Input |
| --- | --- |
| `apl` (default) | APL/S lines; also available through `apl_source.py`. Blank lines and indentation are ignored; each line submits with NEXT. |
| `keyboard` | Printed keyboard characters, with explicit starting SHIFT mode. Each line ends with NEXT. |
| `text` | Built-in Text: up to seven lines of 16 characters, with automatic line wrapping. |
| `keys` | Physical key events, independent of the program's character mapping. |
| `music` | Monophonic MML for Music Teacher 1, Program 1 / Play-Record. |

`--start-mode letters` means unshifted; `symbols` means shifted. It is required for `keyboard`, `text` and `music`. For text profiles, `--hold-final` omits only the last NEXT, leaving the last line unsubmitted.

APL/S accepts the glyphs ×, ÷, π and ¯ or `{MUL}`, `{DIV}`, `{PI}` and `{NEG}`. ASCII `*` means exponentiation. See [APL/S entry](../docs/APL-SOURCE.md) for program definitions, launching games and the bundled listings.

Physical key scripts use one event per line: `KEY`, `KEY hold gap`, or `WAIT fields`. Times are video fields, about 60 per second; bare keys use 8 held and 8 released fields. For example:

```text
A
NEXT 8 72
WAIT 120
```

Music accepts A-G notes, sharps/flats, octaves, tempo, note lengths and rests. For example, save `T100 O4 L4 C C G G A A G2` as `song.mml`. `--timing score` (default) fits octave switches into the score's timing; `--timing note` preserves note lengths and adds octave-switch time. `--gap` and `--min-hold` default to two fields. `--replay` requests playback after entry in Record mode. `--page-notes N --page-wait FIELDS` inserts extra waits at regular entry intervals.

See [keyboard and music input](../docs/KEYBOARD-INPUT.md) for key names, character mappings, MML syntax and Music Mode settings. Ready-to-load songs are in [examples/music](../examples/music).

## Tape images

```sh
python3 tools/new_tape.py blank.vbt
python3 tools/trim_tape.py saved.vbt compact.vbt
python3 tools/tape_convert.py to-wav saved.vbt saved.wav
python3 tools/tape_convert.py to-vbt recording.wav recording.vbt
```

These tools require a new output filename; they never replace an existing file.

`new_tape.py` creates an 8 MiB recording blank. Omit the filename for a timestamped name. A blank is also provided at `examples/blank-tape.vbt`.

`trim_tape.py` copies the header and occupied sectors, retaining at least 1,024 bytes. It rejects invalid or incomplete images. Use a separate blank for future recording; a trimmed image has little spare capacity.

`tape_convert.py` preserves signal levels and durations without decoding cassette records. WAV export is mono 16-bit PCM, default 96,000 Hz at 80% full scale. Use `--rate` and `--amplitude` to change these. Import accepts uncompressed integer PCM WAV at 8, 16, 24 or 32 bits. For multichannel audio, select a 1-based `--channel`; channels are never mixed.

Import uses zero crossings by default. `--threshold` sets the normalized center; `--hysteresis` sets a dead-band half-width. For example, `--threshold 0.03 --hysteresis 0.02` switches high above 0.05 and low below 0.01. Both directions accept `--invert` to reverse polarity. No filtering, trimming, speed correction or extra leader is applied. Keep the original WAV: VBT cannot retain analog amplitude or noise, or time while the record remote was stopped.

See [tape operation](../docs/TAPE.md) for mounting, recording and playback.
