# Information Manager user manual

Information Manager is a tape-based database tool for keeping structured lists, such as an inventory, an address list or a catalog. You decide what information each entry contains, enter the entries, and record the database on tape. You can then read the saved database or make an edited copy.

This guide describes the September 1978 VB-1200 prototype on the VideoBrain MiSTer core. It is a reconstructed guide, not an original VideoBrain manual. See [research notes](INFOMAN.md) for the ROM analysis and hardware test evidence behind it.

## How a database is organized

A **database** is a collection of entries that all use the same structure. Information Manager asks you to define that structure before you enter the data.

| Term | Meaning | Inventory example |
|---|---|---|
| Database name | The name you give the collection at the `DB:` prompt. | `STOCK` |
| Field | One category of information collected for every entry. | An `ITEM` field holds the item's name. |
| Field name | The label used to identify a field. It becomes a prompt during data entry. | Defining `ITEM` produces an `ITEM:` prompt. |
| Field length | The space allocated to a field. For a text field, this is its width in characters. | `8` gives ITEM eight character positions. |
| Field type | The kind of data a field accepts. | `A` is the text type. |
| Database definition | The database's name and the list of field names, lengths and types. Also called its structure or schema. | STOCK has a text field named ITEM, eight characters wide. |
| Record | One complete entry, containing a value for each field in the definition. | One inventory item. |
| Value | The actual information entered in a field of a particular record. | `APPLE` is a value in ITEM. |

For example, an inventory might have ITEM and LOCATION fields. A record would contain both an item's name and its location. Another item would be another record, using the same fields. Choose the fields according to what you want to know about each entry; do not create a new field for each item.

The database name is separate from the MiSTer tape image filename. The name entered at `DB:` belongs to the database; the filename identifies the file you mount in a tape deck.

### Choosing fields

Plan the definition before recording a database:

1. Decide what one record represents: one person, one item, one book, and so on.
2. Choose a field for each piece of information you want to keep about it.
3. Give each field a short, recognizable name.
4. Choose a text width large enough for the values you expect to enter.

An eight-character text field can hold `APPLE` with three unused character positions. Information Manager stores those positions as spaces. The length describes the field's capacity, not the number of records in the database. `8` means eight characters, not eight entries.

Choose the type according to the information the field holds:

| Type | Meaning | Use |
|---|---|---|
| `A` | Text | Names, descriptions and other character data. |
| `I` | Integer | Whole numbers, such as quantities or counts. Displayed without a decimal point. |
| `M` | Money / monetary | Amounts displayed with two decimal places. |

For example, an inventory could use A for ITEM, I for QUANTITY and M for PRICE. A numeric field's length controls its input/display width, including space for a sign and, for M, a decimal point. Both numeric types use eight bytes internally regardless of that width. The definition code accepts numeric widths from 1 through 15; choose enough positions for the value you need to show.

The numeric type definitions and formatting come from ROM analysis. Numeric entry, overflow behavior and save/reload still need hardware checks. Exact limits on field names and field counts are also not yet documented here.

## Controls and operating modes

Load the Information Manager cartridge and [Expander 1 firmware](EXPANDER1.md). The opening screen displays PROGRAM / ENTER / REVIEW / EDIT and a `:` prompt.

| Key | PC keyboard | Purpose |
|---|---|---|
| NEXT | F3 / Enter | Submit a command, accept a definition setting or accept a field value. |
| SPECIAL | F4 | Finish defining fields at an empty `NAME:` prompt, or finish entering records at the next empty record prompt. |

In the instructions below, **submit** means type the text and press NEXT. Numbers use the VideoBrain's shifted keyboard positions; the PC number row and numeric keypad also provide them. Check the displayed number before accepting a length.

Choose the mode according to the task:

| Mode | What it does | Tape decks needed |
|---|---|---|
| `ENTER` | Defines a new database and records the entries you supply. | A writable Record Tape. |
| `REVIEW` | Reads a saved database so you can display its records. | The saved database in Playback Tape. |
| `EDIT` | Reads a saved database and writes a modified copy. | The source in Playback Tape and a separate writable Record Tape. |

Enter a mode at the opening `:` prompt. REVIEW and EDIT then use a `/` command prompt. At `/`, `PRINT ALL` processes all remaining records; `EXIT` leaves the mode and returns to the opening screen. The effect of PRINT ALL depends on the mode: REVIEW displays records, while EDIT also lets you accept or change field values for the output copy.

`PRINT` here can display information on the screen; a printer is not required for `PRINT ALL`. `ALL` requests all remaining records rather than a selected subset. `LIST` is not a recognized command.

### Short commands

The two prompts use different parsers. At the opening `:` prompt, use `EN` for ENTER, `R` for REVIEW or `ED` for EDIT. The menu checks only those initial letters and ignores trailing characters: `REVIE`, for example, selects REVIEW because it starts with R.

At the `/` prompt, the command dictionary provides these explicit abbreviations:

| Short form | Full command |
|---|---|
| `P` | `PRINT` |
| `T` | `TOTAL` |
| `E` | `EXIT` |
| `A` | `ADD` |
| `R` | `REPLACE` |
| `D` | `DELETE` |
| `M` | `MERGE` |

Thus `P ALL` is the short form of `PRINT ALL`, and `E` means EXIT. `ALL`, `DESC`, `FLD`, `SORT`, `TOT` and `PTR` have no separate shorter spellings in the dictionary. `T` means TOTAL, not TOT; `A` means ADD, not ALL. `R` means REPLACE at `/`, even though it means REVIEW at the opening `:` prompt.

The `/` parser matches complete words against its command dictionary, unlike the main-menu prefix checks. These are defined aliases, not a general rule that any prefix works: use `P` or `PRINT`, not `PR` or `PRI`. The aliases select the same command paths as their full spellings; they do not establish the complete syntax of the additional commands discussed below.

### PRINT and PRINT ALL

`PRINT` is the command; `ALL` is a record-selection argument. They are separate words, so you can shorten the command to `P` and keep the argument: `P ALL`.

The ROM also accepts `PRINT` (or `P`) by itself. Its default is to advance one record and display that record. `PRINT ALL` includes the record already loaded and continues through the remaining records. Because REVIEW loads the first record before showing `/`, use `PRINT ALL` when you want a complete listing from the beginning. The bare-command behavior comes from ROM analysis and still needs a hardware check with several records.

## Working with tapes

A **tape image** is a `.vbt` file used as a cassette by the MiSTer core. The **Playback** deck supplies saved data; the **Record** deck receives data being written. An **input** or **source** database is the saved database you read. An **output** database is the new recording you create.

To prepare an output tape, copy [the blank tape image](../examples/blank-tape.vbt) to a new filename and mount the copy with **Mount Record Tape**. Use different filenames for a source and its edited output so that you can keep the original.

Tape access is sequential: the program reads forward through the recording. A tape's **position** is the point it has reached. Stopping does not return it to the start. Use **Rewind Playback Tape** before opening a database, or re-mount the image to rewind it. Rewind both decks before starting an edit into a fresh output image.

Recording also advances through the output tape. The first recording after mounting, rewinding the record deck or resetting starts at the beginning of that image. Use a fresh blank for a new database or edited copy.

Information Manager writes during entry and editing; there is no separate SAVE command in the workflows below. Finish the operation through the program, then wait for recording activity to finish and the user LED to clear before changing tapes or switching cores. **Tape idle** means that the controller is inactive. To check a saved database, read it back and inspect its contents.

See [tape operation](TAPE.md) for image preparation and controller details.

## Create a database

Creating a database has two stages: define the fields, then enter records that use those fields.

### Define the database

Mount a fresh writable blank in **Mount Record Tape**, then submit `ENTER` at `:`.

| Prompt | What to enter |
|---|---|
| `DB:` | A name for the database. |
| `NAME:` | The name of a field. |
| `LENGTH:` | The field's length; for example, `8` for eight characters. Leading zeroes are not required. |
| `TYPE:` | `A` for text, `I` for whole numbers or `M` for monetary amounts. |

Press NEXT after each answer. The program returns to `NAME:` to collect another field definition. When the definition is complete, leave the next `NAME:` empty and press SPECIAL. At `OK (Y/N)?`, check your definition before submitting `Y`. Confirming it records the database definition and begins record entry.

For a complete worked example, follow the [APPLE tape tutorial](../examples/saves/README.md#information-manager-apple). It covers database creation, recording, reload verification and an edited output copy.

### Enter records

The program uses the field names as prompts. Type a value at each prompt and press NEXT to accept it. A complete set of field values makes one record. Information Manager records a completed record before asking for the next one.

After a complete record, the next empty field prompt starts another record. It does not rename the field. Enter another record there, or leave the prompt empty and press SPECIAL to finish entry.

For a definition with several fields, fill in each field of the record in turn. Finish the last record before using SPECIAL at the start of the next empty record. The ROM contains loops for multiple fields and records; hardware verification so far covers a single text field and a single record. See [coverage and additional features](#coverage-and-additional-features) before relying on a larger database.

SPECIAL finishes the recording by writing an **end marker**, which tells a later read that there are no more records. Wait for the opening screen to return and recording activity to finish, then preserve the output file. Read it back using REVIEW to check the field labels and values before depending on it.

## Read a database

Use REVIEW when you want to inspect saved data. A Record Tape is not needed.

1. Mount the database with **Mount Playback Tape** and select **Rewind Playback Tape**.
2. Submit `REVIEW` at `:`. The program reads the definition and first record, then presents `/`.
3. Submit `PRINT ALL` at `/` to display the remaining records, including the first record already read.
4. Check every field label and value against the records you entered.
5. After the records, the program displays `END OF TAPE` and returns to `/`. Submit `EXIT` to return to the opening screen.

`END OF TAPE` after the expected records is normal completion of this listing. If records are missing, the message alone does not establish that the database is complete.

PRINT ALL advances through the input; it does not rewind it. To list the database again from the beginning, exit REVIEW, rewind Playback Tape, and enter REVIEW again.

### Display one field with FLD

In REVIEW, submit `FLD=fieldname` at `/` to choose one field for subsequent record display. The equals sign is required. Use an existing field name; for example:

```text
FLD=ITEM
PRINT ALL
```

If the database also contains LOCATION and PRICE, this listing shows only ITEM for each record. FLD changes which field is displayed; PRINT ALL still processes all remaining records. You can also use the short form `P ALL`.

FLD itself does not display or advance a record. The setting remains in effect until you choose another field or exit REVIEW. It accepts text and numeric fields. DESC continues to show the complete database definition regardless of the FLD setting.

The grammar accepts one field name. It provides no comma-separated field list or ALL reset form, and no shorter spelling of FLD. To restore display of all fields, exit and re-enter REVIEW; rewind the Playback Tape first to start again from the beginning.

FLD is accepted in REVIEW's `/` parser. EDIT's grammar does not include it. The setting changes presentation only; it does not remove fields from the saved database. These findings come from the ROM; a multi-field hardware display check remains outstanding.

### Group a report with SORT

In REVIEW, submit `SORT=fieldname` at `/` to choose a text field for grouping a numeric report. The equals sign is required, and the field must have type A. SORT has no shorter dictionary spelling and is not accepted in EDIT.

SORT groups the report by shared field values. Records remain in tape order; the report lists groups in the order their values were first encountered. There is no ascending/descending option or tape-reordering operation in this command path.

Use SORT with `TOT=numericfield`, which chooses the I or M field to sum. Starting from a freshly opened database, for example:

```text
SORT=LOCATION
TOT=QUANTITY
PRINT ALL
TOTAL
```

Here LOCATION is an A field and QUANTITY is an I field. PRINT ALL processes the input; TOTAL (or `T`) displays the accumulated report. SORT alone only changes the reporting setup: it does not process records, advance the tape or display a report. Without a TOT field, the accumulation and report routines return without producing grouped results.

For these source records:

| LOCATION | QUANTITY |
|---|---|
| WEST | 2 |
| EAST | 3 |
| WEST | 4 |

The predicted report has WEST first, with COUNT = 2 and TOTAL = 6, then EAST with COUNT = 1 and TOTAL = 3, and GRAND TOTAL = 9. Repeated values share a group even when their records are separated on tape.

The ROM has space for nine distinct named groups. Further distinct values share an OTHER group. Group comparisons and stored keys use eight bytes regardless of the field's defined length, so use an eight-character A field for initial checks. Other field widths and blank keys need further investigation.

The setting persists during REVIEW. Issuing SORT again clears the group keys, counts and sums; it does not clear the separate grand total. Set up SORT and TOT before processing records. For a clean new pass, exit, rewind and re-enter REVIEW, then configure the report again.

These instructions are derived from the ROM. Multi-record grouped reports, capacity limits and numeric results still need hardware verification.

### Inspect the database definition with DESC

At the `/` prompt in either REVIEW or EDIT, submit `DESC`. It displays the database's structure:

- The database name (`DB`).
- Each field's name (`NAME`), length (`LENGTH`) and type (`TYPE`), in definition order.

Use this to find out which fields a saved database contains and how they were defined. For the STOCK example, the information is DB = STOCK, NAME = ITEM, LENGTH = 8 and TYPE = A. The length display uses three character positions and may show leading zeroes.

The grammar accepts `DESC`, `PRINT DESC` and `P DESC` for the same operation. No record number, field name or ALL argument is needed. Spell DESC in full: `D` is DELETE.

DESC displays the definition without advancing the current record or writing tape data. It is read-only in EDIT as well as REVIEW; it does not rename fields or change their lengths or types. It describes the database, not an individual record's values.

For example, enter REVIEW, use DESC to inspect the fields, then use PRINT ALL to list the records. DESC leaves the first loaded record available for that listing. These behaviors are traced from the ROM; the screen presentation and complete interaction still need a hardware check.

### Printer output with PTR

In REVIEW, add `PTR` at the end of an output command to request printer output as well as the screen display:

| Command | Printer output requested |
|---|---|
| `PRINT ALL PTR` or `P ALL PTR` | All remaining records, starting with the loaded record. |
| `DESC PTR` or `P DESC PTR` | The database definition. |
| `TOTAL PTR` or `T PTR` | The accumulated numeric report; requires a TOT field as described above. |

PTR follows the record selection: use `PRINT ALL PTR`. Spell PTR in full; `P` is PRINT. The optional PTR suffix is in REVIEW's grammar, not EDIT's, and is not accepted after FLD, SORT or TOT configuration commands.

The printer flag applies to that output operation. An output command without PTR clears it, so `P ALL` uses the normal screen-only path. Use PTR as a suffix rather than a separate setup/toggle command. Adding it does not change which records the command processes or rewind the tape.

The ROM sends formatted screen text through the Expander 1 printer serial connection, converting VideoBrain glyphs to ASCII and terminating lines with carriage return and line feed. It selects the 300-baud timing setting and printer routing. The exact printer requirements and hard-copy formatting have not been verified in operation.

For file capture, select **System > UART Output > Printer** and start the Linux capture utility before issuing the PTR command. See [printer file capture](EXPANDER1.md#printer-file-capture) for setup and raw file handling. Printer input stays idle; the original-ROM tests require no response characters. The shared UART handles modem or printer output one at a time. Live report capture and physical printing remain unverified. Commands without PTR continue to use normal screen review.

## Change a database

Use EDIT to make a revised copy of an existing database. Keep the source image in Playback Tape and record the result into a separate blank image in Record Tape. EDIT needs both decks.

1. Mount the source with **Mount Playback Tape**.
2. Mount a separate fresh writable blank with **Mount Record Tape** and rewind both decks.
3. Submit `EDIT` at `:`. The program reads and copies the definition, then reads the first record and presents `/`.
4. Submit `PRINT ALL`. The program displays editable field values; the underlined character marks the editing position.
5. For each displayed field, press NEXT to accept its value unchanged, or change the value and press NEXT to accept the replacement. Accepting the fields lets the program write the record into the output copy and continue.
6. After `END OF TAPE` and the return to `/`, submit `EXIT`.
7. Wait for recording activity to finish and the user LED to clear.
8. Mount the output file as Playback Tape, rewind it, and use REVIEW followed by PRINT ALL to check the revised database.

Editing a value changes that record in the output copy; it does not rename the field or redefine its type or width. The [APPLE tape tutorial](../examples/saves/README.md#information-manager-apple) includes an edit and reload check.

The one-field workflow has been checked both by accepting an unchanged value and by changing it and reading back the output. Detailed cursor, insertion and deletion key behavior still needs documentation.

### ADD, DELETE and REPLACE

These commands are available at the `/` prompt in EDIT. Enter `ED` or `EDIT` at the opening `:` prompt with the source in Playback Tape and a separate output in Record Tape. REVIEW uses a grammar that excludes these three commands.

The **current record** is the source record already loaded into memory. On entering EDIT, it is the first record. Commands operate forward from this position; a number after DELETE is a count, not an absolute record number. `PRINT` advances to the next record, while `PRINT ALL` runs through the remaining input. Do not use PRINT ALL as a preliminary listing if you then want to change an earlier record in the same pass. To start again, finish the pass and restart EDIT from the rewound source with a fresh output.

The following syntax and target rules come from the ROM. These command paths still need hardware output/reload checks.

| Command | Target and effect |
|---|---|
| `ADD` or `A` | Copies the current record to output, then prompts for new records using the existing field definition. Completed new records are written after it, before the next source record. SPECIAL at the next empty record prompt exits the entry loop. |
| `REPLACE` or `R` | Prompts for a fresh set of field values for the current record. The replacement stays in the record buffer and is written when the program next copies/advances that record, including when finishing with EXIT. |
| `DELETE` or `D` | Omits the current record from output and reads the next source record. |
| `DELETE n` or `D n` | Omits n records starting with the current record. For example, `D 2` deletes the current record and the following record. |
| `DELETE ALL` or `D ALL` | Omits the current record and all remaining source records. Records already copied to output remain there. |
| `DELETE field=value` | Copies forward until a record matches the named field's text pattern, then omits that record. For example, `D ITEM=APPLE` targets the first matching record at or after the current position. |

ADD and REPLACE take their data at subsequent field prompts; neither has a record-number argument in this grammar. ADD's insertion loop is skipped if end of input has already been reached. Its pending-record buffer after SPECIAL still needs an output/reload check before treating the full insertion workflow as verified.

The field selector compares a text pattern from the start of the field. `ITEM=APPLE` can therefore also match a longer value beginning with APPLE; the equals sign does not enforce full-field equality. The DELETE handler passes records being omitted through the field display/input routine, so its exact prompt behavior also needs an operating check.

For a source containing APPLE, PEAR and PLUM, immediately after entering EDIT:

- `D 2`, followed by EXIT, should leave PLUM in the output.
- `R` targets APPLE and asks for its replacement field values.
- `A` begins inserting after APPLE.

These are predictions from the command handlers, not additional hardware test results. Finish with EXIT, wait for tape activity to end, and review the separate output to check the result.

### Combine databases with MERGE

In EDIT, submit `MERGE` or `M` at `/` to continue the output with another input database. The command takes no filename, field name or record-selection argument. REVIEW's grammar does not accept MERGE.

MERGE first copies the current record and all remaining records from the mounted input to the existing output. It then displays `REWIND` / `KEY NEXT` and waits. At that pause, prepare the next input in Playback Tape. After NEXT, the program reads its definition and first record, then returns to `/` for further commands. Records keep their source order, including duplicates.

For two saved databases A and B with matching field definitions, the ROM-derived procedure is:

1. Mount A as Playback Tape and a fresh blank as Record Tape. Rewind both and enter EDIT.
2. At `/`, submit `M`. Allow the rest of A to be copied.
3. At the REWIND / KEY NEXT prompt, mount B as Playback Tape and ensure it is at the beginning. Re-mounting an image rewinds it.
4. Keep the same Record Tape mounted at its existing position; do not rewind it.
5. Press NEXT. B's first record is loaded and the `/` prompt returns.
6. Submit EXIT to copy the rest of B, including its loaded first record, and finish the output. Wait for tape activity to end.
7. Mount the output as Playback Tape, rewind it, and check it with REVIEW / PRINT ALL.

If A contains APPLE and PEAR, and B contains PLUM, the predicted output is APPLE, PEAR, PLUM. For another input C, submit M again instead of EXIT: that copies B and pauses for C. Finish with EXIT after the final input.

The output keeps the first database's recorded definition. MERGE loads each later definition into memory but does not write it to the output or compare it with the original. Use matching field names, order, types and lengths; there is no automatic field mapping or compatibility check. The database names themselves are not compared. A later database's record length is loaded with its definition, but its records will eventually be read under the first database's output header, making mismatched layouts unsuitable for this procedure.

This tape-change and concatenation sequence is traced from the ROM. Multi-input hardware operation and output/reload still need verification.

## Troubleshooting

| Symptom | Action |
|---|---|
| `? ?` after a command | Check the prompt and command spelling. Choose ENTER, REVIEW or EDIT at `:`; use PRINT ALL or EXIT at `/`. Use `PRINT ALL` to display records. |
| `I/O ERR` on REVIEW | Check Expander 1 firmware, mount the saved database as Playback Tape, and rewind before retrying. Preserve the image if the read still fails. |
| `I/O ERR` on EDIT | Mount the source as Playback Tape and a separate writable blank as Record Tape; rewind both. |
| A later read starts at the end or fails | Exit REVIEW, rewind Playback Tape, and enter REVIEW again. |
| `END OF TAPE` appears | Check that all expected records appeared first. This message also follows a normal completed listing. |
| Recording is idle, but the contents are uncertain | Mount the output as Playback Tape, rewind it, and check it with REVIEW / PRINT ALL. |
| The core reports Tape error | Preserve the image. See [tape operation](TAPE.md) for controller troubleshooting. |

## Coverage and additional features

Hardware checks cover creating, reviewing and editing a database with one eight-character text field and one record, including reading back a changed value. Multiple fields and records follow loops identified in the ROM but still need equivalent hardware checks. The I and M type descriptions above come from their conversion and formatting code; numeric input edge cases and detailed editing keys still need checks.

The ROM also contains commands for more advanced database work. These terms describe their apparent purpose; their full syntax and mode restrictions remain under investigation:

| Term or command | Meaning and current limit |
|---|---|
| Record selection | Choosing which records a command acts on, potentially by a record number or a comparison with a field value. Exact selection expressions are not documented here. |
| `ADD`, `DELETE`, `REPLACE` | See the EDIT syntax and current-record rules above. Hardware output/reload checks, ADD termination and further selection forms remain outstanding. |
| `DESC` | Displays the database name and field names, lengths and types in REVIEW or EDIT; see the instructions above. Screen interaction still needs a hardware check. |
| `FLD` | In REVIEW, `FLD=fieldname` selects one field for subsequent record display. See the instructions above; multi-field hardware checks remain outstanding. |
| `SORT` | REVIEW's `SORT=fieldname` groups numeric reports by an A/text field; see the instructions above. It preserves tape order. Grouped hardware reports remain to be checked. |
| `TOT`, `TOTAL` | In REVIEW, TOT=numericfield chooses the I/M field to sum; TOTAL (T) displays the accumulated report. See SORT above for grouped counts, sums and the grand total. Numeric hardware reports remain unverified. |
| `MERGE` | EDIT's MERGE/M copies the remaining input, pauses for another tape and continues the same output. Use matching layouts; see the procedure above. Hardware tape-change/output checks remain outstanding. |
| `PTR` | REVIEW's trailing printer modifier, as in P ALL PTR, DESC PTR or TOTAL PTR. See the file-capture instructions above; physical printing remains unverified. |

Use the [research notes](INFOMAN.md) for command-table details and open questions. They distinguish recognized command words from complete, tested operating instructions.
