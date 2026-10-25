# Information Manager: practical user manual

This guide covers the September 1978 VB-1200 prototype on the VideoBrain MiSTer core. It is reconstructed from hardware testing and ROM analysis; it is not an original VideoBrain manual. The create, review and edit workflows below have hardware test evidence. Commands whose complete operation remains uncertain are listed separately.

## Before starting

Load the Information Manager cartridge and [Expander 1 firmware](EXPANDER1.md). The opening screen shows PROGRAM / ENTER / REVIEW / EDIT, with a `:` prompt.

| Key | PC keyboard | Use in this guide |
|---|---|---|
| NEXT | F3 / Enter | Submit text or accept a field |
| SPECIAL | F4 | Finish field definitions or finish record entry at an empty prompt |

Type the commands and values shown below, then press the indicated key. Numbers use the VideoBrain's shifted keyboard positions, also available through the PC number row and numeric keypad; check that the screen actually reads `008` when entering the example field length.

The two command prompts have different purposes:

| Prompt | What to enter |
|---|---|
| `:` | `ENTER` to create a database, `REVIEW` to read one, or `EDIT` to produce a modified copy |
| `/` | `PRINT ALL` to display records, or `EXIT` to return to the opening screen |

**Use `PRINT ALL` to list records. `LIST` is not an Information Manager command.** Question marks after `LIST` do not establish a tape failure. In the October 24, 2026 hardware check, using `PRINT ALL` read the saved records back successfully.

## Prepare the tapes

Use different filenames for the original database and any edited output.

| Operation | Playback Tape | Record Tape |
|---|---|---|
| Create with ENTER | Not required | Fresh writable blank |
| Read with REVIEW | Saved database | Not required |
| Modify with EDIT | Saved database | Separate fresh writable blank |

Copy [the blank tape image](../examples/blank-tape.vbt) to a new filename before mounting it in **Mount Record Tape**. Keep a copy of any database you want to preserve. The first recording after mounting, rewinding the record deck or resetting starts at the beginning of that image.

Before reading, use **Rewind Playback Tape**. Stopping playback does not rewind it. Re-mounting an image also rewinds it.

Wait for recording activity to finish and the user LED to clear before changing tapes or switching cores. **Tape idle** reports controller inactivity; reading the records back is the check that the database was saved correctly. See [tape operation](TAPE.md) for image preparation and controller details.

## Create your first database

This example creates database TEST with one text field, ITEM, and one record, APPLE.

1. Mount a fresh writable blank in **Mount Record Tape**.
2. Follow this sequence, allowing tape transfers to finish between prompts:

| Screen prompt | Type | Press |
|---|---|---|
| `:` | `ENTER` | NEXT |
| `DB:` | `TEST` | NEXT |
| `NAME:` | `ITEM` | NEXT |
| `LENGTH:` | `008` | NEXT |
| `TYPE:` | `A` | NEXT |
| Next empty `NAME:` | Leave empty | SPECIAL |
| `OK (Y/N)?` | `Y` | NEXT |
| `ITEM:` | `APPLE` | NEXT |
| Next empty `ITEM:` | Leave empty | SPECIAL |

3. Wait for the opening screen to return and recording activity to finish. Preserve the recorded file.

`A` is the text field type used in this verified example. The eight-character field stores APPLE followed by three spaces.

There is no separate SAVE step in this workflow. Confirming the definition writes the database description; accepting a completed record writes that record. SPECIAL at the next empty record prompt writes the end marker and finishes entry. Returning to the opening screen alone is not a substitute for waiting for the recording to finish.

## Read the saved database

1. Start Information Manager with Expander 1 firmware loaded.
2. Mount the saved file in **Mount Playback Tape**.
3. Select **Rewind Playback Tape**.
4. At `:`, type `REVIEW` and press NEXT.
5. Wait for the `/` prompt. Type `PRINT ALL` and press NEXT.
6. For the example above, expect `ITEM: APPLE`, followed by `END OF TAPE` and another `/` prompt.
7. At `/`, type `EXIT` and press NEXT to return to the opening screen.

`END OF TAPE` after the expected record is the observed normal completion of this example. It does not mean that APPLE failed to load.

REVIEW reads the database definition and first record before accepting a command at `/`. Reaching that prompt is useful evidence that the initial read completed, but it does not validate every remaining record. Check the displayed contents.

To repeat the complete read, exit REVIEW, rewind the playback tape, and enter REVIEW again. Playback retains its position across stops.

## Edit a database into a new tape

EDIT reads the source while writing a separate output. Both decks are needed for the verified workflow.

1. Mount the saved database in **Mount Playback Tape**.
2. Mount a separate writable blank in **Mount Record Tape**.
3. Rewind both decks.
4. At `:`, type `EDIT` and press NEXT.
5. At `/`, type `PRINT ALL` and press NEXT.
6. In the one-record example, `ITEM: APPLE` appears with its first character underlined. Accepting it unchanged with NEXT has been verified. Changing the value to `PEPSI` and accepting with NEXT has also been verified through output reload.
7. After `END OF TAPE` and the return to `/`, type `EXIT` and press NEXT.
8. Wait for recording activity to finish and the user LED to clear.
9. Mount the output file as Playback Tape, rewind it, and use `REVIEW` followed by `PRINT ALL` to check the result.

The changed-record test displayed `ITEM: PEPSI` after reload. REVIEW of that output worked with the record deck empty. Single-deck editing is not established; testing EDIT without a source in the playback deck produced `I/O ERR`.

## Troubleshooting

| Symptom | Check or next action |
|---|---|
| `? ?` after entering `LIST` | Use `PRINT ALL` at the `/` prompt. `LIST` is absent from the ROM command dictionary. |
| `I/O ERR` when entering REVIEW | Check Expander 1 firmware, mount the saved image as Playback Tape, and rewind before retrying. If it still fails, preserve the image for inspection. |
| `I/O ERR` when entering EDIT | Check that the source is in Playback Tape and a separate writable blank is in Record Tape; rewind both. |
| First read works, later attempt fails or starts at the end | Exit REVIEW and rewind Playback Tape before entering REVIEW again. |
| `END OF TAPE` after the expected records | This is the observed completion of the verified listing. Check that all expected contents appeared first. |
| Tape idle appears, but saved contents are uncertain | Reload with REVIEW / PRINT ALL. Idle does not validate application data. |
| Core reports Tape error | Preserve the image and investigate the controller failure separately from command syntax. |

For a suspected regression, first repeat the one-field APPLE example with a fresh blank and the exact commands above. Record the core build, the last successful prompt, any application error, and any core tape notice. Keep the resulting VBT file so its blocks and checksums can be examined.

## Commands still being investigated

The ROM recognizes the following tokens, but their complete syntax, mode restrictions and effects have not all been verified:

| Tokens | Research area |
|---|---|
| `ADD`, `DELETE`, `REPLACE` | Adding, deleting and replacing selected records |
| `DESC` | Database field descriptions |
| `FLD` | Field selection |
| `SORT`, `TOT`, `TOTAL` | Grouping, totals and reporting |
| `MERGE` | Processing another input tape |
| `PTR` | Printer output |

The dictionary also contains single-letter spellings for several commands. Use the full tested forms in this guide until a particular abbreviation and command sequence has been checked.

Multiple fields and records, numeric types I and M, selection expressions, insertion positions and detailed editing keys need further documented testing. This guide does not infer operating instructions from keyword names alone.

For ROM identity, command tables, transfer details and the evidence behind this guide, see [Information Manager research notes](INFOMAN.md).
