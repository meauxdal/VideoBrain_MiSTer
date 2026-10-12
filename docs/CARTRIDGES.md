# Cartridge status

All eighteen cartridges reach their correct first screen. The sixteen
single-image cartridges also have headless simulator screen coverage.
First-screen results do not establish full gameplay or peripheral coverage.

    verilator/obj_dir_headless/Vtop --cart <file> --frames 150 --shot 149

Known raw dumps are identified by CRC-32 and use the matching slot behavior.
`--cart-type` and the OSD's Fallback setting apply only to unrecognized
images: 0 standard, 1 Timeshare, 2 Money Minder. APL and Information Manager
assembled by `tools/convert_software.py` are also identified automatically.

Fingerprints for all sixteen released single-image cartridges come from MAME's
[VideoBrain software list](https://github.com/mamedev/mame/blob/master/hash/vidbrain.xml).

## Summary

| Cartridge | Size | Slot device | First screen | Notes |
|---|---|---|---|---|
| Blackjack | 2K | standard | correct | "1 OR 2 PLAYERS?" over black and red card suits on green. |
| Checkers | 4K | standard | correct | RUN/STOP advances to "YOU MOVE FIRST ? Y OR N". |
| Demonstration | 4K | standard | correct | Six lines, each a different colour, seven colours on screen. |
| Financier | 4K | standard | correct | Full function menu on green. |
| Gladiator | 4K | standard | correct | Game-number prompt; advances on RUN/STOP. |
| Lemonade Stand | 4K | standard | correct | Slow to boot: blank at frame 150, full menu by 280. |
| Math Tutor 1 | 4K | standard | correct | "CHOOSE / TUTOR 1 / PROBLEM 2" on olive. |
| Money Minder | 4K | money_minder | correct | "MONEY MANAGER" title. RAM at 3800-3FFF is reachable; deeper functions untested. |
| Music Teacher 1 | 2K | standard | correct | "PLAY/RECORD 1 / LEARN A SONG 2". |
| Pinball | 2K | standard | correct | Background fix validated. |
| Tennis | 4K | standard | **plays** | RUN/STOP starts the game: court, net, scoreboard, player sprites. |
| Timeshare | 2K | timeshare | correct | "TIMESHARE" title on cyan, then the screen blanks around frame 130. See below. |
| Vice Versa | 4K | standard | correct | Advances to "YOU PLAY FIRST ? Y OR N". |
| VideoArtist | 2K | standard | correct | Design selection menu. |
| Wordwise 1 | 2K | standard | correct | Multi-colour skill menu. |
| Wordwise 2 | 2K | standard | correct | Four-entry multi-colour menu. |
| APL / Computational Language | 16K | comp_language | correct | Assembled MAME image; full program execution coverage pending. |
| Information Manager | 8K | info_manager | correct | Prototype; with Expander 1 firmware, reaches PROGRAM / ENTER / REVIEW / EDIT without I/O ERR. Tape and serial operations need investigation. |

## Split cartridge conversion

Use the chip names from MAME's
[VideoBrain software list](https://github.com/mamedev/mame/blob/master/hash/vidbrain.xml).
Every chip below is 2,048 bytes. Offsets are hexadecimal positions in the
output file, not CPU addresses. Padding must contain zero bytes.

### Computational Language (`complang.zip`)

Concatenate A, B, C, D, E, F, G, then 2,048 zero bytes:

| File offset | Dump |
|---|---|
| 0000 | `0310_apls-a.u1` |
| 0800 | `0311_apls-b.u4` |
| 1000 | `0312_apls-c.u3` |
| 1800 | `0313_apls-d.u6` |
| 2000 | `0314_apls-e.u2` |
| 2800 | `0315_apls-f.u5` |
| 3000 | `0316_apls-g.u11` |
| 3800 | 2,048 zero bytes |

Output: `The Computational Language (APL-S).bin`, 16,384 bytes.

### Information Manager (`infoman.zip`, also known as `infomgr`)

Concatenate the 1000 chip, 2,048 zero bytes, the 3000 chip, then the 3800 chip:

| File offset | Dump |
|---|---|
| 0000 | `vb1200a_1000-17ff_9_25_78_51` |
| 0800 | 2,048 zero bytes |
| 1000 | `vb1200c_3000-37ff_9_25_78_51` |
| 1800 | `vb-1200_3800-3fff_9_26_78` |

Output: `Information Manager (prototype).bin`, 8,192 bytes. Load the separate
Expander 1 firmware as described in [Expander 1 setup](EXPANDER1.md).

### Converter

Place both archives in `software/vidbrain (MAME)`, then run
`python3 tools/convert_software.py` from the repository root. Alternatively,
pass a software directory containing a `vidbrain (MAME)` subdirectory:

```sh
python3 tools/convert_software.py /path/to/software
```

The converter checks chip sizes and CRC-32, writes the assembled images and
`checksums.tsv` into `software/converted` (or the supplied directory's
`converted` subdirectory), and skips other cartridges matching existing images.
Copy the assembled `.bin` files to the VideoBrain games folder and load through
the OSD.

## Mapper tests

`make -C verilator test-cartridges` checks bank selection, RAM, DMA,
reset behavior, and the existing cartridge mappings without ROM files.

## Capture method

Use `--frame-log` to locate screen changes. Timeshare's title disappears
before frame 150; Lemonade Stand needs about 280 frames to reach its menu.
Use the input each cartridge requests. Holding SPACE in Financier or Music
Teacher 1 does not establish a rendering fault.

## Open questions

### Timeshare blanks after its title

The title renders correctly on cyan, then the screen goes blank around frame
130 and stays blank. Timeshare is the communications cartridge and expects the
Expander 2 and modem, which are not implemented. Blanking is the expected
behavior in this configuration by all accounts. Additional investigation is 
warranted.

### Financier after an invalid key

Holding SPACE leaves Financier drawing striped colour bands. This appears to
most likely be accurate behavior based on available references. Additional
investigation is warranted.

## Slot device reference

From MAME `bus/vidbrain/`. `/CS1` is 1000-17FF and `/CS2` is 1800-1FFF.

| Mapper | CS1 | CS2 | 3000-3FFF |
|---|---|---|---|
| standard | ROM | ROM | - |
| timeshare | 2K ROM | 1K RAM, mirrored | - |
| money_minder | 4K ROM | 4K ROM | 1K RAM at 3800, mirrored |
| info_manager | 2K ROM | 1K RAM | ROM |
| comp_language | 2K ROM, bank writes | ROM to 1BFF, RAM at 1C00 | banked ROM |
