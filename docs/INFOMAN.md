# Information Manager disassembly

Local listing: `refs/infoman/infoman.lst`. Regenerate with:

```text
python tools/disassemble_infoman.py --unidasm C:/Users/Elle/Downloads/mame0289b_x64/unidasm.exe
```

The listing retains addresses and every ROM byte. It uses MAME's F8 syntax,
labels branch targets, and separates identified tables from instructions.
It is an annotated static disassembly, not assembler input or a recovered
manual. Runtime command behavior and peripheral transactions remain untested.
The listing stays under ignored `refs/`, consistent with the other local
cartridge disassemblies.

## ROM identity

The three chips in `software/3 MAME (vidbrain)/infoman.zip` are identical to
Sean Riddle's corresponding loose dumps in `refs/seanriddle.com/`.
The assembled cartridge contains the same bytes plus a 2 KB zero-filled gap.
There is no second Infoman archive in that MAME directory; `complang (older).zip`
is APL/S.

| CPU addresses | MAME chip | SHA-1 |
|---|---|---|
| 1000-17FF | vb1200a_1000-17ff_9_25_78_51 | 39c2821f73c86c3e368fe5429628672cfe594306 |
| 3000-37FF | vb1200c_3000-37ff_9_25_78_51 | d98b94ae1cce2ce6e6ae933180a7bf001b73932f |
| 3800-3FFF | vb-1200_3800-3fff_9_26_78 | 3a38a889b552acaa1a284e2ca7447f142b494737 |

These are 6,144 ROM bytes. Cartridge RAM occupies the 1800-1FFF window;
its physical size is 1 KB. ROM dates are September 25/26, 1978.

## Interpreter and commands

Entry is 1012. The menu-selection code at 1068 checks the input's BIOS glyph
codes: `EN` branches to 10AD, `ED` to 11E1, and initial `R` to 119D.
10AD clears the field count and collects field definitions. The other paths
process records using different interpreter requests.

1641 interprets three-byte entries from the table at 174B. 1741 computes
`H = 1748 + 3 * R1`; 16FD dispatches a one-based operation number through
27 big-endian addresses at 3000. Parser callbacks at 3036 and 317C are
selected through the two pointers at 16F9. Keyword indices are interpreter
entry indices, not direct indices into the operation-address table.

The dictionary at 3115 contains these exact spellings:

| Keyword(s) | Interpreter index (hex) |
|---|---|
| P, PRINT | 11 |
| T, TOTAL | 31 |
| E, EXIT | 1F |
| A, ADD | 0B |
| R, REPLACE | 1D |
| D, DELETE | 1B |
| M, MERGE | 19 |
| DESC | 17 |
| ALL | 15 |
| FLD | 27 |
| SORT | 29 |
| TOT | 2B |
| PTR | 0F |

Each dictionary record has an index byte and a zero-terminated glyph string;
7F ends the dictionary. These spellings establish recognized tokens, not
complete command syntax or which modes accept them.

## Data and peripheral routines

| Address | Function |
|---|---|
| 33DD | Copy a six-byte input descriptor into 0C10 |
| 3782 | Printer/ASCII lookup indexed by BIOS glyph code |
| 3839 / 3888 | Binary byte to three decimal glyphs / reverse conversion |
| 38AD / 38B6 | Decimal digit and BIOS glyph conversion |
| 391E / 3922 | Increment / decrement a byte in memory |
| 393A | Look up a pointer in the table at 18AD |
| 3AF5 | Initialize Expander communication with bytes 05, 00 and mode at 1BCE |
| 3CB5 / 3EB5 | Interrupt transfer and context handling |
| 3D25 | Two-byte checksum over a length-prefixed block |
| 3DEC / 3E2D | Bit output and framed byte output through port 1 |
| 3F47 | Five message pointers |
| 3F51 | Menu and prompt strings in BIOS glyph encoding |

Strings include field names/lengths, sorting, totals, tape rewind/end, and
I/O errors. The glyph mapping comes from the BIOS font at 2010 and decimal
table at 245E, corroborated by Sean's BIOS listing in `vbasm.zip`.

The generator checks chip hashes, instruction overlap and complete byte
coverage. It follows direct calls/branches and seeds the known computed
dispatch, continuation and interrupt entries. Two additional instruction
sequences at 39E5 and 3C9F have no identified direct caller. Static coverage
does not prove that every path executes or establish full peripheral behavior.
