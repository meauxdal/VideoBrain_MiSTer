# Information Manager

For database concepts and operating instructions, see the [user manual](INFOMAN-MANUAL.md), including planning fields, entering records, reading saved data and making an edited copy. These notes retain the ROM analysis and hardware evidence.

## Using the cartridge

Load the cartridge and [Expander 1 firmware](EXPANDER1.md). The initial menu shows PROGRAM / ENTER / REVIEW / EDIT. NEXT is F3 or Enter; SPECIAL is F4.

### Worked tape example

Follow the [APPLE tape tutorial](../examples/saves/README.md#information-manager-apple) to create, record, reload and edit the one-record TEST database.

Hardware testing completed entry and returned to the main page. The saved image contains nine CRC-valid blocks: three identical copies each of the 253-byte TEST definition (ITEM, length 008, type A), the eight-byte `APPLE   ` record, and the zero-length end marker. Hardware REVIEW followed by PRINT ALL displayed `ITEM: APPLE`, then END OF TAPE, confirming the one-record save/load round trip. EXIT returned to the main menu.

The ROM writes the definition after Y, each completed record before the next field prompt, and an end marker when SPECIAL finishes record entry. Each write is repeated three times.

REVIEW's `05 00 02` setup enables the record remote before switching to playback. The controller must preserve the image and playback position during this transition-free handoff; immediate recording invalidation causes I/O ERR. The original-firmware two-record SAVE/LOAD test covers this setup, alongside controller timing, append, protection and interruption tests.

The REVIEW path at 119D calls 3BAF to read the database definition, then 3B49 to read a record, before accepting a command through 1228. Multiple records, additional field types and further keyboard functions still need hardware testing.

### EDIT records

Mount the saved database as **Playback Tape** and a separate writable blank as **Record Tape**. Rewind both, then type `EDIT` at the main `:` and press NEXT. At `/`, type `PRINT ALL` and press NEXT. Hardware testing displayed `ITEM: APPLE` with the A underlined. Pressing NEXT without changing the field reached END OF TAPE and returned to `/`. After EXIT and Tape idle, mounting the output as Playback Tape, rewinding and using REVIEW / PRINT ALL displayed ITEM: APPLE and END OF TAPE. The unchanged-record EDIT round trip is hardware-verified.

Changing APPLE to PEPSI and accepting with NEXT (F3) also survived output recording and reload: REVIEW / PRINT ALL displayed `ITEM: PEPSI` with the edited tape in the playback deck and the record deck empty. To finish an edit, return to `/`, enter `EXIT` with NEXT, and wait for Tape idle before mounting the output as Playback Tape and rewinding it. REVIEW does not require a record image. Use different files for input and output; inspect the output separately after finishing.

EDIT reads the definition (3BAF), writes it (3BD1), then reads the first record (3B49). Independent deck controllers preserve the source cursor while output flushes. The original-firmware test exercises read/write/read across separate images and replays the output, checking payloads, CRCs and status.

## Field types

The type codes are BIOS glyphs: A = 11, I = 01, M = 29 (hex). The definition validator at 3235-324A accepts these three codes. A uses the requested text length; I and M are numeric types with an eight-byte representation: a sign byte followed by seven bytes of packed decimal digits. These findings are from static ROM analysis, not a numeric hardware round trip.

| Type | Interpretation | Code evidence |
|---|---|---|
| A | Text | 3377-3397 sends the record's field buffer directly to the input/display routine. 1189-119B uses the defined length for storage. |
| I | Integer, displayed without a decimal point | 3A53-3A5D selects interpreter request 30 for glyph 01. The formatter at 3A77 expands packed decimal digits without inserting a point for this type. |
| M | Money / monetary, displayed with two decimal places | Other numeric input uses request 33. Its grammar adds the decimal-fraction path through entry 36. At 3AB0-3AC4, the formatter checks glyph 29 and inserts the decimal-point glyph 12 before the final two digits. |

At 3399-33C3, numeric fields are formatted into a temporary character buffer of the defined width, edited/displayed there, then converted back by 3A29. The numeric width is therefore an input/display width, not the number of bytes stored. 321C-3222 rejects zero and lengths above 126; 3242-324A additionally rejects numeric lengths above 15. The formatter reserves the first character for a sign, writes a minus for a nonzero sign byte, and blanks leading zeroes. M also reserves a character for its decimal point.

The input grammar shares digit accumulation through 15E5/161A, which shifts packed decimal digits into the record. The M fraction path includes 15EC, which shifts twice to reserve two fractional digits, followed by handlers 15F9 and 160C for those digits. This distinguishes a fixed two-place monetary value from floating-point storage. Exact accepted input forms, narrow-width behavior, overflow handling and numeric save/reload remain to be checked in operation.

## Further research

The following capabilities are inferred from the ROM, not hardware-verified operating instructions. Recognized keywords alone do not establish complete syntax or availability in REVIEW versus EDIT.

| Capability | Evidence and open questions |
|---|---|
| Multiple fields and records | ENTER loops over field definitions and records. Verify field order, record boundaries and reload of several records. |
| Numeric fields | I is integer; M is monetary with two decimal places. Both use a sign byte and seven packed-decimal bytes; numeric width is 1-15. Check accepted input forms, narrow widths, overflow and hardware save/reload. |
| Adding records | ADD copies the current record before its field-entry loop, inserting after it. Check SPECIAL termination, the pending buffer and output persistence. |
| Deleting and replacing | See the EDIT command analysis below for current-record targeting and DELETE selectors. Hardware output/reload checks remain outstanding. |
| Record selection | Grammar and handlers support numbers, field names, value comparisons and wildcard handling. Establish exact syntax and matching rules. |
| Field selection | REVIEW accepts FLD=fieldname to display one field; EDIT excludes it. See the analysis below; check a multi-field database on hardware. |
| Database description | P DESC displays the database name and field names, lengths and types. REVIEW display is hardware-verified; EDIT still needs a hardware check. |
| Counts and totals | REVIEW's TOT=numericfield selects an I/M field for accumulation; TOTAL (T) invokes the report. See SORT and PTR below. Hardware numeric reports remain unverified. |
| Grouped summaries | SORT=fieldname selects a text key for grouped numeric reports in REVIEW. Groups retain first-encounter order; nine named groups plus OTHER. See the analysis below; hardware reports remain unverified. |
| Tape merging | EDIT's MERGE/M concatenates inputs through a REWIND / KEY NEXT pause. No schema comparison, field mapping or later-header write. See the analysis below; hardware tape-change/output checks remain outstanding. |
| Printer reports | REVIEW accepts trailing PTR on PRINT, DESC and TOTAL output. Use Printer > Mount Capture Image and 300 baud for independent file capture; see [printer capture](PRINTER.md). See the analysis below; live report capture and physical printing remain unverified. |

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

### Abbreviations and PRINT arguments

The paired spellings above have identical interpreter indices, so P/PRINT, T/TOTAL, E/EXIT, A/ADD, R/REPLACE, D/DELETE and M/MERGE are explicit aliases. P ALL follows the same grammar and handlers as PRINT ALL. ALL has no A alias, and TOT has no T alias. Opening-menu prefixes are a separate mechanism: R selects REVIEW at `:`, but is the REPLACE token at `/`.

The scanner at 3053-3067 collects an entire alphanumeric word. The dictionary comparison at 30F1-3106 requires the word to end when the dictionary spelling ends. It does not implement arbitrary prefix matching, so PR and PRI do not abbreviate PRINT.

Sean Riddle's extracted strings show pairs such as `AP APRINT`, `CT CTOTAL` and `FR FREPLACE`. The leading apparent letter is the interpreter-index byte rendered as a BIOS glyph: 11 looks like A, 31 like C and 1D like F. Those bytes are metadata, not part of the commands. The actual spellings are P/PRINT, T/TOTAL and R/REPLACE.

PRINT is a command token, and ALL is one possible selection token after it. Grammar entry 18 at 1790 matches PRINT and invokes operation 14 (1425), which clears the command parameters and sets processing mode 1. The selection grammar at entries 1B-1E accepts a field name, ALL, a number, or end of input. In particular:

| Form | Parameter setup and processing |
|---|---|
| PRINT ALL / P ALL | Entry 1C invokes operation 10 (1434): 1B10 = 0, 1B11 = 7F. No initial advance; process the loaded record and continue through the input. |
| PRINT / P | Entry 1E accepts end of input and invokes operation 09 (1456): 1B10 = 1, 1B11 = 1. Advance once, then display the newly loaded record. |

At 327D-32A2, 1B10 controls initial record advances through 3B40. At 32A4-32D1, 1B11 controls the display loop and final record display. Consequently, bare PRINT is valid syntax but is not equivalent to PRINT ALL: after REVIEW's initial read, it advances past the first loaded record. This behavior is traced from the ROM; a multi-record hardware check remains outstanding. The remaining selection forms need their own documented usage checks.

### FLD: persistent field display selection

REVIEW starts at grammar entry 01 (174B): `27 04 08` matches FLD and calls operation 04 (138D). That pushes target slot 0 for the shared field-name resolver. Entry 08 at 1760 requires glyph 2E (`=`); entry 09 at 1763 requires identifier token 21 and invokes operation 08 (13A0), then entry 07 requires end of command. The accepted form is FLD=fieldname. There is no field-list loop, optional equals sign, numeric selector, ALL form or shorter dictionary spelling. EDIT starts at entry 10 and does not reach the FLD configuration branch.

13A0 searches the database's eight-byte field names through 14BA. 13B9 retrieves target slot 0 and writes the zero-based field index to 1B0C. Unlike the SORT/TOT slots, slot 0 has no field-type restriction. An unknown name takes the command-error path at 13B1.

At 3331-333D, the record input/display loop tests 1B0C. A negative value permits every field; a nonnegative value permits only the matching field index R6 and skips the others. This changes presentation of the loaded record, not its stored structure or record selection. FLD's own handlers have no tape calls and do not invoke record display/advance, so the setting affects subsequent commands without consuming a record.

Startup at 1041-1047 initializes 1B0C, 1B0D and 1B0E to FF. A successful FLD remains set until another FLD or the return to startup after EXIT; no successful FLD argument restores FF. Exiting, rewinding and re-entering REVIEW restores all-field display from the first record. DESC iterates the definition directly at 31C5 and ignores the display gate at 3331, so it still describes every field and does not reset FLD.

Example for a database with ITEM, LOCATION and PRICE: FLD=ITEM followed by PRINT ALL should display ITEM only for every remaining record. The command syntax, persistence and display gate are established by static ROM analysis; multi-field hardware presentation is not yet verified.

### SORT: grouped numeric reporting

REVIEW grammar entry 02 at 174E is `29 05 0A`: SORT invokes operation 05 (1393), pushing target slot 1 for the common field resolver. Entry 0A at 1766 requires `=`; entry 0B at 1769 requires a field-name token and invokes operation 08 (13A0), then entry 07 requires end of command. The syntax is SORT=fieldname, with no abbreviation, direction argument or multiple-key list. EDIT starts at entry 10 and excludes this configuration command.

The resolver stores the field index in 1B0D. At 13CB-13DC, slot 1 specifically requires type A (glyph 11); an I or M field resets the selection to FF and raises a command error. Successful configuration clears 170 bytes at 1B24 through 1BCD, then writes OTHER as the last key:

| Workspace | Role |
|---|---|
| 1B24-1B73 | Ten eight-byte keys; slots 0-8 are allocated to encountered values, slot 9 is OTHER. |
| 1B74-1B7D | Ten one-byte record counts. |
| 1B7E-1BCD | Ten eight-byte numeric sums. |

SORT itself has no tape calls. Processing in REVIEW reaches 130F through the write-suppression branch of 3B8C when a record is copied/advanced. The first check at 130F-1314 requires a selected TOT field at 1B0E; without it, neither grand-total nor grouped accumulation occurs. The numeric value is first added to the separate grand total at 1B1C. If SORT is also selected, 1330-133D compares its field value with nine keys using 14BA, which performs eight-byte equality comparisons. Nonadjacent matching values therefore share a bucket.

For a new value, 1344-136C scans for the first empty named slot and copies eight bytes into it. If all nine are occupied, the selected index is 9 and the key is not copied, retaining OTHER. 136E-1387 adds the numeric value to that bucket's sum and increments its byte count. There is no key-order comparison, record-swap routine or output-tape write in this reporting path.

TOTAL (T) selects processing mode 3 via 141F and reaches the report at 123F through 3267/331A. The report also requires a TOT field. It displays TOTAL FIELD and SORT FIELD, then walks slots in index order at 1284-12C7, displaying each VALUE, COUNT and TOTAL, followed by GRAND TOTAL. This is first-encounter order, not alphabetical order. FLD's record-display gate does not suppress the report's direct descriptor calls.

Use a fresh REVIEW pass with SORT=LOCATION, TOT=QUANTITY, PRINT ALL, then TOTAL. Source pairs WEST/2, EAST/3, WEST/4 should produce WEST (count 2, total 6), EAST (count 1, total 3), grand total 9. PRINT ALL preserves input order while its advances accumulate the report. SORT configuration clears group state but not the grand total; TOT configuration clears the grand total but not group state, so configure both before the pass.

Important limits from the code: keys always use eight bytes even if the declared text width differs; an empty slot is identified by a zero first byte; counts occupy one byte. Narrow/wide fields, blank-leading keys, count overflow, the OTHER bucket and complete report interaction need runtime checks. These are static findings, not verified hardware report results.

### PTR: per-operation printer output

REVIEW grammar entry 04 (TOTAL) and entry 05 (shared PRINT/DESC/selection grammar) continue at entry 0E, address 1772: `0F 0A 07`. PTR token 0F invokes operation 0A (1411), then entry 07 requires end of command. If PTR is absent, entry 0F at 1775 (`00 07 87`) invokes operation 07 (1415). These handlers set 1B1A to FF or 00 respectively, then enter processing at 3267.

Thus the explicit forms include PRINT ALL PTR / P ALL PTR, PRINT PTR / P PTR, PRINT DESC PTR / P DESC PTR, and TOTAL PTR / T PTR. PTR follows any record-selection argument. FLD/SORT/TOT configuration branches go directly to the end-of-command entry, so they have no PTR suffix. EDIT uses its own continuation at entry 15: the shared grammar is followed by operation 07 and entry 16, omitting the optional PTR branch. PTR has no shorter dictionary spelling.

The flag is not a persistent printer-configuration toggle: a subsequent output operation without PTR executes 1415 and clears it. Use PTR only as a suffix to an output command.

The display routine formats screen text first. At 3615-3626 it calls 3716 only when display mode 1B0B is 3 and printer flag 1B1A is nonzero. Otherwise it follows the normal display/pacing path. This adds hard-copy transmission to formatted display rather than selecting a different record set.

3716 initializes Expander communication and sends bytes `04 02 02`: serial command 04, timing selector 02 (the 300-baud setting), routing flags 02. In the Expander firmware, the routing-bit check at 04C4-04CE sends host data to printer port 4. This is separate from modem port 5, which the core connects to the MiSTer UART.

At 3732-3777, the cartridge transmits a leading zero byte, five ASCII spaces, sixteen converted screen glyphs, then CR (0D) and LF (0A) for each buffered line. Glyph conversion uses the table at 3782, indexed at 3755. It iterates the buffered display lines using the count at 0C28, then waits for completion and returns through 3B19. This is a short-line screen-text dump; exact hard-copy layout, framing and physical-printer compatibility need operating checks.

The core holds Expander printer RX idle and exposes printer TX to the MiSTer wrapper. Use Printer > Mount Capture Image at 300 baud to capture this stream independently; see [printer capture images](PRINTER.md). The shared-UART diagnostic remains available in [printer file capture](EXPANDER1.md#printer-file-capture). Modem remains the default UART source. Original-ROM tests verify printer-only transmission without responses at 110/300 baud; complete cartridge reports and physical printing still need hardware validation.

### DESC: database definition display

The shared REVIEW/EDIT grammar requires PRINT or P before DESC. Entry 18 at 1790 is `11 14 99`: PRINT invokes operation 14 and continues at entry 19. Entry 19 at 1793 is `17 0F 00`: DESC invokes operation 0F and returns from the shared grammar. Use PRINT DESC or P DESC, with an optional trailing PTR in REVIEW. Hardware REVIEW accepted P DESC and rejected bare DESC and DESC PTR. There is no DESC record/field selector. DESC has no separate short dictionary spelling; D is DELETE.

Operation 0F at 1422 clears processing mode 1B0F. The shared processing action at 3267 sees zero, sets input/display mode 1B0B to 3, and calls 31C5. This applies in EDIT too: it overrides EDIT's interactive field-input mode for this operation.

31C5 first displays the database-name descriptor at 117D (DB label at 3F71, value at 1802, width 10). It then iterates R3 from zero to the field count at 180C. For each field, 31E4 uses these descriptors:

| Display | Descriptor and value |
|---|---|
| NAME | Descriptor 3259, label 3F87, eight-character value at `180D + 8 * R3`. |
| LENGTH | Descriptor 325D, label 3F8D, value from `18D5 + R3` converted to three decimal glyphs at 0C18 by 3839. |
| TYPE | Descriptor 3263, label 3FF3, one glyph at `18E9 + R3`. |

The shared routine at 3444-344B checks mode 3 and bypasses keyboard editing through the display-only path at 3544. The definition-display loop contains no tape read/write calls and does not call the record-advance routine 3B40. It therefore leaves the current record and tape position unchanged. Although the existing definition validation code is reused, DESC does not offer interactive schema changes. It describes database fields rather than sorting records or displaying their values.

Hardware REVIEW displayed the database definition with P DESC. The ROM establishes mode availability and lack of record advance; EDIT interaction and printer output still need hardware checks.

### EDIT mutation commands

EDIT's requests at 1222/1225 start at grammar entry 10; REVIEW's requests at 11DB/11DE start at entry 01. REVIEW reaches the shared PRINT/selection grammar but skips the EDIT alternatives at entries 10-13. The dictionary alone therefore does not make ADD, DELETE or REPLACE available in REVIEW.

| Entry | Token | Handler | Continuation |
|---|---|---|---|
| 10 (1778) | DELETE / D (1B) | Operation 14, 1425: reset selection parameters and select sequential processing. | Entry 17 calls selection grammar 1B, then operation 0B at 1504. |
| 11 (177B) | ADD / A (0B) | Operation 0C, 14EE. | Entry 16 requires end of command. |
| 12 (177E) | REPLACE / R (1D) | Operation 0D, 1567. | Entry 16 requires end of command. |

EDIT reads the first source record at 11EF before accepting a command. This loaded record is the current record. 3B40 writes the current buffer through 3B8C and then reads the next record; 3B49 reads without first writing. EDIT's EXIT path at 1211 copies remaining source records with 3B40, then writes the end marker at 121D.

**ADD:** 14EE checks the end-of-input flag and does nothing if it is negative. Otherwise 14F5 writes the current record through 3B8C, sets input mode 1 and calls 3320 for a fresh record. A completed entry loops back to write it and prompt for another. SPECIAL returns a negative input status and exits this loop. The source is not advanced in the loop, so completed additions are placed after the current source record and before the next one. The routine reuses the current record buffer; the pending buffer after SPECIAL and its effect on the next command/EXIT need a runtime round trip. Do not treat clean ADD completion as hardware-verified yet.

**REPLACE:** 1567 sets input mode 1 and calls 3320. At 3412-3429, that mode clears each field before entry, so this collects fresh values for the loaded record. There is no source advance or immediate write in the REPLACE handler. The revised buffer is written by a subsequent 3B40/3B8C, including EXIT's copy-through loop. The grammar permits no selector after REPLACE.

**DELETE:** Selection grammar entries 1B-1E are shared with PRINT. The handler at 1504 omits records by calling 3B49 instead of 3B40 for the selected records. Numeric deletion does not seek an absolute record index:

- Bare DELETE sets 1B10 = 1 and 1B11 = 1; one record is omitted starting at the current buffer.
- DELETE n for n greater than 1 sets 1B10 = 1 and 1B11 = n. At 1511-151C the handler computes the deletion count as `1B11 - 1B10 + 1`, then loops through 3320/3B49. Thus DELETE 2 omits the current and following record. The zero case also produces a count of one; do not document DELETE 0 as a no-op.
- DELETE ALL sets 1B10 = 0 and 1B11 = 7F. The resulting count is 80; 151D-1524 treats this as the discard-remainder case and marks end of input, so EXIT does not copy the remaining records. It does not erase already-written output.
- A field-name selector sets processing mode 2 at 145C-1478. Entry 1F requires `=` and entries 20-25 build a text pattern. For DELETE ITEM=APPLE, 1540-1563 searches from the current record, copying nonmatches with 3B40, then reads past the match with 3B49 without writing it. The comparison at 15AC permits `*` as a single-character wildcard and compares the stored pattern length; full-field equality is not established by the equals sign. Additional pattern delimiters and repetition options need separate documentation.

Syntax and target behavior above are traced from the ROM. Full ADD/DELETE/REPLACE output/reload checks have not yet been performed on hardware.

One DELETE interaction detail needs particular attention: 1508 stores the incoming accumulator into input mode 1B0B, and both deletion loops call 3320 before reading past a selected record. Dispatch at 171B loads A from R6, so prompt behavior may depend on the selector's remaining R6 value. Do not assume every DELETE form silently skips records without field interaction.

### MERGE: continue EDIT with another input

EDIT grammar entry 13 at 1781 is `19 0E 16`: MERGE/M token 19 invokes operation 0E (1571), then entry 16 requires end of command. REVIEW does not traverse this EDIT branch. MERGE has no filename, selection or field argument.

At 1571-157B, MERGE tests the input status at 1B1B and calls 3B40 until end of input. In EDIT, each call writes the current record through 3B8C and reads the next. This copies the remaining source, including the record already loaded. There is no call to 3BE2, so it does not finish the output with an end marker at this boundary.

At 157D-158A, the routine sets bit 0 of mode byte 1BCE, reinitializes the Expander through 3AF5, then displays message 2. The message pointer at 3F4B leads to 3FA1, the REWIND / KEY NEXT text. The key loop at 158D-1596 accepts returned codes 43/44: adding BD and comparing with 01 accepts that two-code range. This is an operator pause; the handler contains no mechanical or image-controller rewind command.

After the operator prepares the next Playback input and presses NEXT, 1598-15A1 clears mode bit 0 and reinitializes communication. 15A4 calls 3BAF to read a definition, and 15A7 calls 3B49 to read its first record. The handler then returns to command processing. It does not immediately copy that first record: subsequent EDIT commands act on it. EXIT's loop at 1211 copies the remainder and 121D writes the output end marker. Repeating MERGE instead drains this input and pauses for another.

This is stream concatenation. There is no key comparison, duplicate suppression, interleaving of sorted records or reconciliation of schemas in 1571-15AA. Initial EDIT writes the first definition at 11EC; MERGE never calls definition writer 3BD1, so the output retains that first header.

The definition block has a two-byte length prefix at 1800/1801 and a 253-byte payload at 1802-18FE: database name (10), field count (1), field names (160), field pointers (40), field widths (20), types (20), and total record length (2). MERGE loads all of these from the later input, including record length at 18FD/18FE. No comparison with the earlier definition occurs. Matching field layouts and record lengths are required for a coherent combined output because its later records must eventually be interpreted using the first header; differing database names are not rejected. After a tape swap, DESC describes the later header in memory, which need not be the header already recorded in the output.

Predicted procedure: enter EDIT with source A and a fresh output, submit M, mount/rewind B at the prompt while preserving the output position, press NEXT, then EXIT to copy B and finish. Source records A1/A2 followed by B1 should reload as A1/A2/B1 under A's definition. The physical tape-change handoff, multiple inputs, schema mismatches and output reload still need hardware checks.

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

The annotated listing and its generator are maintained in the separate **VideoBrain-ASM** repository, at `infoman/infoman.lst` and `tools/disassemble_infoman.py`. The generator checks chip hashes, instruction overlap and complete byte coverage. Its address-based notes preserve comments on command grammar and handlers when the listing is regenerated. In that repository, run it with `--unidasm <path-to-unidasm> --rom <path-to-infoman.zip>`; the output defaults to `infoman/infoman.lst`. It follows direct calls/branches and seeds the known computed dispatch, continuation and interrupt entries. Two additional instruction sequences at 39E5 and 3C9F have no identified direct caller. Static coverage does not prove that every path executes or establish full peripheral behavior.
