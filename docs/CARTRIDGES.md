# Cartridge status

All eighteen known cartridges are recognized. Current MiSTer coverage includes gameplay, APL/S programs, tape round trips and peripheral operations. Financier entry submission currently restarts the title. The table below records the narrower first-screen checks and selected follow-up evidence; it is not the complete current test inventory. Information Manager exploration continues primarily to complete its manual. See [current accuracy and remaining work](ACCURACY.md).

    verilator/obj_dir_headless/Vtop --cart <file> --frames 150 --shot 149

Known raw dumps are identified by CRC-32 and use the matching slot behavior. `--cart-type` and the OSD's System > Mapper Fallback setting apply only to unrecognized images: 0 standard, 1 Timeshare, 2 Money Minder, 3 CompLang, 4 Infoman. Assembled APL/S and Information Manager images are also identified automatically.

**Unload Cartridge** on the main menu removes the cartridge and resets to the built-in BIOS. **Reset** power cycles the machine, clears system and cartridge RAM, and restores the initial cartridge bank. Loaded ROMs remain installed. **Master Control** retains RAM and the cartridge bank; the restarted software decides what to preserve.

**System > Reset on Cartridge Load** defaults to On. When Off, loading a cartridge does not reset the running machine; press Master Control afterward to refresh the game layout from the new cartridge. Other reset sources and other ROM downloads continue to reset the machine.

Fingerprints for all sixteen released single-image cartridges come from MAME's [VideoBrain software list](https://github.com/mamedev/mame/blob/master/hash/vidbrain.xml).

## Summary

| Cartridge | Size | Slot device | First screen | Notes |
|---|---|---|---|---|
| Blackjack | 2K | standard | correct | "1 OR 2 PLAYERS?" over black and red card suits on green. |
| Checkers | 4K | standard | correct | RUN/STOP advances to "YOU MOVE FIRST ? Y OR N". |
| Demonstration | 4K | standard | correct | Six lines, each a different colour, seven colours on screen. |
| Financier | 4K | standard | correct | Full function menu on green; NEXT submission restarts the title. See below. |
| Gladiator | 4K | standard | correct | Game-number prompt; advances on RUN/STOP. |
| Lemonade Stand | 4K | standard | correct | Slow to boot: blank at frame 150, full menu by 280. |
| Math Tutor 1 | 4K | standard | correct | "CHOOSE / TUTOR 1 / PROBLEM 2" on olive. |
| Money Minder | 4K | money_minder | correct | Original-machine cassette data loaded, edited, saved and reloaded across a core restart. |
| Music Teacher 1 | 2K | standard | correct | "PLAY/RECORD 1 / LEARN A SONG 2". |
| Pinball | 2K | standard | correct | Background fix validated. |
| Tennis | 4K | standard | **plays** | RUN/STOP starts the game: court, net, scoreboard, player sprites. |
| Timeshare | 2K | timeshare | correct | Interactive Telehack sessions verified at 300 baud through Expander 1 and MiSTer's UART. See below. |
| Vice Versa | 4K | standard | correct | Advances to "YOU PLAY FIRST ? Y OR N". |
| VideoArtist | 2K | standard | correct | Design selection menu. |
| Wordwise 1 | 2K | standard | correct | Multi-colour skill menu. |
| Wordwise 2 | 2K | standard | correct | Four-entry multi-colour menu. |
| APL/S: The Computational Language | 16K | comp_language | correct | Assembled image; source entry, program execution and tape operations exercised. |
| Information Manager | 8K | info_manager | correct | Prototype; requires Expander 1 firmware. One-record entry, save, REVIEW / PRINT ALL and EDIT with changed-text reload verified on hardware. See [usage notes](INFOMAN.md). |

## Split cartridge conversion

Use the [cartridge converter](../tools/README.md#cartridges) to assemble MAME archives automatically, or follow the layouts below.

Extract the chip dumps from each archive and concatenate them in the order below. Every chip is 2,048 bytes; each padding block is 2,048 zero bytes.

### APL/S: The Computational Language (`complang.zip`)

Concatenate A, B, C, D, E, F, G, then 2,048 zero bytes:

```text
0310_apls-a.u1
0311_apls-b.u4
0312_apls-c.u3
0313_apls-d.u6
0314_apls-e.u2
0315_apls-f.u5
0316_apls-g.u11
2,048 zero bytes
```

Save as a `.bin` file: 16,384 bytes.

### Information Manager (`infoman.zip`)

Concatenate the 1000 chip, 2,048 zero bytes, the 3000 chip, then the 3800 chip:

```text
vb1200a_1000-17ff_9_25_78_51
2,048 zero bytes
vb1200c_3000-37ff_9_25_78_51
vb-1200_3800-3fff_9_26_78
```

Save as a `.bin` file: 8,192 bytes. Information Manager also requires [Expander 1 firmware](EXPANDER1.md). See [disassembly notes](INFOMAN.md) for ROM identity and interpreter details.

## Mapper tests

`make -C verilator test-cartridges` checks bank selection, RAM, DMA, reset behavior, and the existing cartridge mappings without ROM files.

## Capture method

Use `--frame-log` to locate screen changes. Timeshare's title disappears before frame 150; Lemonade Stand needs about 280 frames to reach its menu. Use the input each cartridge requests. Holding SPACE in Financier or Music Teacher 1 does not establish a rendering fault.

## Timeshare serial communication

With Expander 1 firmware loaded, Timeshare supports interactive Telehack sessions through MiSTer's HPS UART and a Linux Telnet bridge at 300 baud. Command pagination, Zork's opening screen, weather, and date output have been verified on MiSTer with the server set to 24 columns and 15 lines. See [Timeshare setup and keys](EXPANDER1.md#timeshare-over-uart). Earlier captures without a working peripheral path blanked after the title. Expander 2 acoustic modem behavior and live 110-baud operation remain unverified.

## Software behavior

### Financier

The title resets itself after pressing NEXT or typing for a bit due to an incomplete dump. The CPU calls `30F7` from `1C9F`, reads `FF` from the unmapped cartridge expansion window, and continues to the BIOS entry at `4000`. The published [disassembly](https://orphanedgames.com/videobrain/f8_programming/f8_source.htm) contains this call and further calls into `3000-3FFF`. A simple mirror of the 4K image would put `30F7` inside an instruction operand at `10F7`. The expected code and cartridge decoding for this region remain unverified.

## Slot device reference

From MAME `bus/vidbrain/`. `/CS1` is 1000-17FF and `/CS2` is 1800-1FFF.

| Mapper | CS1 | CS2 | 3000-3FFF |
|---|---|---|---|
| standard | ROM | ROM | - |
| timeshare | 2K ROM | 1K RAM, mirrored | - |
| money_minder | 4K ROM | 4K ROM | 1K RAM at 3800, mirrored |
| info_manager | 2K ROM | 1K RAM | ROM |
| comp_language | 2K ROM, bank writes | ROM to 1BFF, RAM at 1C00 | banked ROM |
