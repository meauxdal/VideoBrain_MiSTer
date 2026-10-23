# Information Manager

## Using the cartridge

Load the cartridge and [Expander 1 firmware](EXPANDER1.md). The initial menu shows PROGRAM / ENTER / REVIEW / EDIT. NEXT is F3; SPECIAL is F4.

### Create a small database

Mount a fresh writable [blank tape](TAPE.md) in **Mount Record Tape** before confirming the definition. This ENTER path records incrementally; it does not wait for a separate SAVE.

| Prompt | Type | Press |
|---|---|---|
| Initial `:` | `ENTER` | NEXT |
| `DB:` | `TEST` | NEXT |
| `NAME:` | `ITEM` | NEXT |
| `LENGTH:` | `008` | NEXT |
| `TYPE:` | `A` | NEXT |
| Next empty `NAME:` | Nothing | SPECIAL |
| `OK (Y/N)?` | `Y` | NEXT |
| `ITEM:` | `APPLE` | NEXT |
| Next empty `ITEM:` | Nothing | SPECIAL |

Hardware testing completed entry and returned to the main page. The saved image contains nine CRC-valid blocks: three identical copies each of the 253-byte TEST definition (ITEM, length 008, type A), the eight-byte `APPLE   ` record, and the zero-length end marker. Hardware REVIEW followed by PRINT ALL displayed `ITEM: APPLE`, then END OF TAPE, confirming the one-record save/load round trip.

The ROM writes the definition after Y, each completed record before the next field prompt, and an end marker when SPECIAL finishes record entry. Each write is repeated three times. Allow the transfer pauses and wait for the user LED to clear before unmounting. Tape idle only reports controller inactivity.

### Load and display records

1. Finish entry with SPECIAL at an empty ITEM prompt and wait for tape activity to end. Preserve the resulting image.
2. Start the cartridge again with Expander 1 loaded and choose **Mount Playback Tape** for the saved image.
3. Choose **Rewind Playback Tape** before playback.
4. At the initial `:`, type `REVIEW` and press NEXT (F3).
5. At the `/` prompt, type `PRINT ALL` and press NEXT.
6. The test database displays `ITEM: APPLE`, then END OF TAPE and another `/` prompt. END OF TAPE is the observed completion of this one-record listing.
7. At `/`, type `EXIT` and press NEXT to return to the main menu. This is hardware-verified after PRINT ALL.

REVIEW's `05 00 02` setup enables the record remote before switching to playback. The controller must preserve the image and playback position during this transition-free handoff; immediate recording invalidation causes I/O ERR. The original-firmware two-record SAVE/LOAD test covers this setup, alongside controller timing, append, protection and interruption tests.

The REVIEW path at 119D calls 3BAF to read the database definition, then 3B49 to read a record, before accepting a command through 1228. Multiple records, additional field types and further keyboard functions still need hardware testing.

### EDIT records

Mount the saved database as **Playback Tape** and a separate writable blank as **Record Tape**. Rewind both, then type `EDIT` at the main `:` and press NEXT. At `/`, type `PRINT ALL` and press NEXT. Hardware testing displayed `ITEM: APPLE` with the A underlined. Pressing NEXT without changing the field reached END OF TAPE and returned to `/`. After EXIT and Tape idle, mounting the output as Playback Tape, rewinding and using REVIEW / PRINT ALL displayed ITEM: APPLE and END OF TAPE. The unchanged-record EDIT round trip is hardware-verified.

Changing APPLE to PEPSI and accepting with NEXT (F3) also survived output recording and reload: REVIEW / PRINT ALL displayed `ITEM: PEPSI` with the edited tape in the playback deck and the record deck empty. To finish an edit, return to `/`, enter `EXIT` with NEXT, and wait for Tape idle before mounting the output as Playback Tape and rewinding it. REVIEW does not require a record image. Use different files for input and output; inspect the output separately after finishing.

EDIT reads the definition (3BAF), writes it (3BD1), then reads the first record (3B49). Independent deck controllers preserve the source cursor while output flushes. The original-firmware test exercises read/write/read across separate images and replays the output, checking payloads, CRCs and status.

## Further research

The following capabilities are inferred from the ROM, not hardware-verified operating instructions. Recognized keywords alone do not establish complete syntax or availability in REVIEW versus EDIT.

| Capability | Evidence and open questions |
|---|---|
| Multiple fields and records | ENTER loops over field definitions and records. Verify field order, record boundaries and reload of several records. |
| Numeric fields | TYPE accepts I and M as well as A; numeric conversion and storage paths exist. Establish formatting, precision, signs and length limits. |
| Adding records | ADD has a field-entry loop in EDIT's grammar. Establish insertion position, completion keys and output persistence. |
| Deleting and replacing | DELETE and REPLACE have command paths distinct from interactive PRINT ALL editing. Establish record selection and which records are retained. |
| Record selection | Grammar and handlers support numbers, field names, value comparisons and wildcard handling. Establish exact syntax and matching rules. |
| Field selection | FLD configures field processing/display. Establish selection syntax and ordering. |
| Database description | DESC leads toward the field-definition display path. Test whether it lists names, types and lengths; do not assume it means descending sort. |
| Counts and totals | Accumulation routines and COUNT=, TOTAL= and GRAND TOTAL= strings support numeric reporting. Distinguish TOTAL from TOT configuration. |
| Grouped summaries | SORT FIELD: and per-value counts/totals suggest grouping by a field. Physical reordering of tape records is not established. |
| Tape merging | MERGE processes remaining input, prompts for rewind/NEXT, then reads another definition and record. Establish schema compatibility and tape-change procedure. |
| Printer reports | PTR, printer character conversion and output routines indicate a hard-copy path. Establish syntax, routing and peripheral requirements. |

Single-deck append or editing remains unverified. EDIT with only the record deck populated produced I/O ERR; ENTER starts by defining a database. REVIEW's grammar and write-suppression path do not suggest a persistent ADD workflow.

## ROM identity

The three chips in MAME's `infoman.zip` are identical to Sean Riddle's corresponding ROM dumps. The assembled cartridge contains the same bytes plus a 2 KB zero-filled gap.

| CPU addresses | MAME chip | SHA-1 |
|---|---|---|
| 1000-17FF | vb1200a_1000-17ff_9_25_78_51 | 39c2821f73c86c3e368fe5429628672cfe594306 |
| 3000-37FF | vb1200c_3000-37ff_9_25_78_51 | d98b94ae1cce2ce6e6ae933180a7bf001b73932f |
| 3800-3FFF | vb-1200_3800-3fff_9_26_78 | 3a38a889b552acaa1a284e2ca7447f142b494737 |

These are 6,144 ROM bytes. Cartridge RAM occupies the 1800-1FFF window; its physical size is 1 KB. ROM dates are September 25/26, 1978.

## Interpreter and commands

Entry is 1012. The menu-selection code at 1068 checks the input's BIOS glyph codes: `EN` branches to 10AD, `ED` to 11E1, and initial `R` to 119D. The menu checks only these prefixes, not the complete words. `REVIE` was hardware-verified to select REVIEW. This does not establish prefix matching for commands at the `/` prompt. 10AD clears the field count and collects field definitions. The other paths process records using different interpreter requests.

1641 interprets three-byte entries from the table at 174B. 1741 computes `H = 1748 + 3 * R1`; 16FD dispatches a one-based operation number through 27 big-endian addresses at 3000. Parser callbacks at 3036 and 317C are selected through the two pointers at 16F9. Keyword indices are interpreter entry indices, not direct indices into the operation-address table.

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

Each dictionary record has an index byte and a zero-terminated glyph string; 7F ends the dictionary. These spellings establish recognized tokens, not complete command syntax or which modes accept them.

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

Strings include field names/lengths, sorting, totals, tape rewind/end, and I/O errors. The glyph mapping comes from the BIOS font at 2010 and decimal table at 245E, corroborated by Sean's BIOS listing in `vbasm.zip`.

The generator checks chip hashes, instruction overlap and complete byte coverage. It follows direct calls/branches and seeds the known computed dispatch, continuation and interrupt entries. Two additional instruction sequences at 39E5 and 3C9F have no identified direct caller. Static coverage does not prove that every path executes or establish full peripheral behavior.
