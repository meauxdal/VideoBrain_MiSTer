# Cartridge status

The sixteen single-image cartridges were run in the headless simulator and
their screens inspected. These first-screen results do not establish gameplay
coverage. Checkers is confirmed fixed by the user as of October 10, 2026;
the earlier hang is no longer a known issue.

    verilator/obj_dir_headless/Vtop --cart <file> --frames 150 --shot 149

Known raw dumps are identified by CRC-32 and use the matching slot behavior.
`--cart-type` and the OSD's Fallback setting apply only to unrecognized
images: 0 standard, 1 Timeshare, 2 Money Minder.

Fingerprints for all sixteen released single-image cartridges come from MAME's
[VideoBrain software list](https://github.com/mamedev/mame/blob/master/hash/vidbrain.xml).
CRC-32 is used to identify the loaded image, not to validate its integrity.

## Summary

**All sixteen boot and render their first screen correctly.** Tennis plays.

| Cartridge | Size | Slot device | First screen | Notes |
|---|---|---|---|---|
| Blackjack | 2K | standard | correct | "1 OR 2 PLAYERS?" over black and red card suits on green. Best colour test in the set. |
| Checkers | 4K | standard | correct | RUN/STOP advances to "YOU MOVE FIRST ? Y OR N". |
| Demonstration | 4K | standard | correct | Six lines, each a different colour, seven colours on screen. |
| Financier | 4K | standard | correct | Full function menu on green. |
| Gladiator | 4K | standard | correct | Game-number prompt; advances on RUN/STOP. |
| Lemonade Stand | 4K | standard | correct | Slow to boot: blank at frame 150, full menu by 280. |
| Math Tutor 1 | 4K | standard | correct | "CHOOSE / TUTOR 1 / PROBLEM 2" on olive. |
| Money Minder | 4K | money_minder | correct | "MONEY MANAGER" title. RAM at 3800-3FFF is reachable; deeper functions untested. |
| Music Teacher 1 | 2K | standard | correct | "PLAY/RECORD 1 / LEARN A SONG 2". |
| Pinball | 2K | standard | correct | Input works flawlessly. Collision-driven full-background changes fixed in simulation; MiSTer validation pending. |
| Tennis | 4K | standard | **plays** | RUN/STOP starts the game: court, net, scoreboard, player sprites. |
| Timeshare | 2K | timeshare | correct | "TIMESHARE" title on cyan, then the screen blanks around frame 130. See below. |
| Vice Versa | 4K | standard | correct | Advances to "YOU PLAY FIRST ? Y OR N". |
| VideoArtist | 2K | standard | correct | Design selection menu. |
| Wordwise 1 | 2K | standard | correct | Multi-colour skill menu. |
| Wordwise 2 | 2K | standard | correct | Four-entry multi-colour menu. |
| APL / Computational Language | - | comp_language | **not loadable** | Dumped as separate .u1-.u11 chip images, and the mapper is not implemented. |

## Capture method

Use `--frame-log` to locate screen changes. Timeshare's title disappears
before frame 150; Lemonade Stand needs about 280 frames to reach its menu.
Use the input each cartridge requests. Holding SPACE in Financier or Music
Teacher 1 does not establish a rendering fault.

## Open questions

### Timeshare blanks after its title

The title renders correctly on cyan, then the screen goes blank around frame
130 and stays blank. Timeshare is the communications cartridge and expects the
Expander modem, which is not emulated. Blanking may be expected while waiting
for it; the cause has not been confirmed.

### Pinball background color

Input works flawlessly. Collision-driven full-background changes are fixed in
simulation. The final modifier now applies to gaps and empty-FIFO pixels as
well as objects. User-supplied VideoBrain screenshots show the expected
full-background colors. Validation on MiSTer remains pending.

### Financier after an invalid key

Holding SPACE leaves Financier drawing striped colour bands. VideoBrain
software paints bands by rewriting the background register from the
Y-interrupt handler, so the mechanism is in use. Whether this is a real
rendering fault or simply what the cartridge does when handed a key it did not
ask for is unresolved. The way to settle it is to type a valid function name.

## Not implemented

- **comp_language** (APL): a split-chip dump, bank register at 1000-100F with
  a documented bus conflict quirk, six ROM banks. MAME
  `bus/vidbrain/comp_language.cpp`.
- **info_manager**: 6K ROM, 1K RAM. A prototype; no dump here.
- The Timeshare image identifies the cartridge board, not the separate
  Expander modem it expects to communicate with.

## Slot device reference

From MAME `bus/vidbrain/`. `/CS1` is 1000-17FF and `/CS2` is 1800-1FFF.

| Mapper | CS1 | CS2 | 3000-3FFF |
|---|---|---|---|
| standard | ROM | ROM | - |
| timeshare | 2K ROM | 1K RAM, mirrored | - |
| money_minder | 4K ROM | 4K ROM | 1K RAM at 3800, mirrored |
| info_manager | 2K ROM | 1K RAM | ROM |
| comp_language | ROM + RAM above 1C00 | same | banked ROM |
