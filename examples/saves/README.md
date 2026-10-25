# Make, save and reload

Three small projects for learning tape use: a Money Minder account, an Information Manager database and an original APL/S countdown. Each example tape is 8 MiB so you can save changes to a working copy. The trimmed [Price program tapes](../price-tape-conversions) are a separate collection.

| Cartridge | Example save | Contents |
|---|---|---|
| Money Minder | [Cash and Groceries](<Money Minder - Cash and Groceries.vbt>) | $87.50 cash remaining after a $12.50 food purchase. |
| Information Manager | [APPLE](<Information Manager - APPLE.vbt>) | TEST database, ITEM text field, one APPLE record. |
| APL/S | [Countdown](<APL-S - Countdown [DOWN].vbt>) | Original program DOWN; type `DOWN` after LOAD. |

These images were generated from cartridge workspace data in a software emulator and encoded as cassette records. Record framing and CRCs have been checked. Restoring the APL/S and Money Minder payloads in the emulator reproduces the countdown and account balances. These particular VBT files still need LOAD/REVIEW verification on MiSTer; the steps below provide that check.

Load the appropriate cartridge and Expander 1 firmware. Start each project from a fresh cartridge session. Copy [blank-tape.vbt](../blank-tape.vbt) under a new name and mount it with **Mount Record Tape**. Keep different files in the playback and record slots. Wait for the user LED to clear before changing images or resetting.

Recreating an example and reloading your own recording checks the complete path. A return to the menu or **Tape idle** alone does not verify saved data. See [tape setup](../../docs/TAPE.md) for mounting and rewinding.

## Money Minder: cash and groceries

Money Minder uses a financial keypad. The PC keys below refer to the [Money Minder overlay](../../docs/controls/money-minder-keyboard.jpg), not text entry. Amounts are entered as digits in cents, without a decimal point. SPACE is ENTER. SHIFT selects the next upper function and then returns to lower mode.

1. Press Q (CLEAR) to leave the title screen, then SHIFT and A (RESET) to clear the accounts.
2. Enter `10000` ($100.00), press F1/BACK (CASH), then SHIFT and SPACE (INITIAL VALUE).
3. Enter `1250` ($12.50), press G (FOOD), F1/BACK (CASH), then SPACE (ENTER).
4. Press CASH to inspect its balance: expect $87.50. Press FOOD: expect $12.50. Other account totals should be zero.
5. With your writable tape mounted, press P (STORE SUMMARY). At the scratch-tape prompt, press SPACE (ENTER). Wait for the operation to finish and the user LED to clear.

To check the save, restart the cartridge, clear the accounts with SHIFT and A, then mount the saved file as **Playback Tape** and rewind it. Press SHIFT, then P (LOAD SUMMARY), and SPACE (ENTER) at the tape prompt. Inspect CASH and FOOD again: expect $87.50 and $12.50. Start from cleared accounts for each verification: loading adds income and expense totals to those already in memory.

To make a changed save, record another purchase, then mount or rewind your working **Record Tape** before STORE SUMMARY so the new summary replaces the old recording. Reload into cleared accounts and check the new balances.

## Information Manager: APPLE

This creates database `TEST`, with one text field named `ITEM` and one record containing `APPLE`. NEXT is F3/Enter; SPECIAL is F4. Use SHIFT for numeric entry and check that the displayed length is `008` before accepting it.

With a fresh writable tape mounted in **Mount Record Tape**, follow these prompts. Press NEXT after each typed answer.

| Prompt | Answer | Finish with |
|---|---|---|
| Initial `:` | `ENTER` | NEXT |
| `DB:` | `TEST` | NEXT |
| `NAME:` | `ITEM` | NEXT |
| `LENGTH:` | `008` | NEXT |
| `TYPE:` | `A` | NEXT |
| Next empty `NAME:` | Leave empty | SPECIAL |
| `OK (Y/N)?` | `Y` | NEXT |
| `ITEM:` | `APPLE` | NEXT |
| Next empty `ITEM:` | Leave empty | SPECIAL |

The database name, field name and record value are different things: TEST names the database, ITEM names its field, and APPLE is the value stored in that field. Its width is eight characters; the five letters are stored with three trailing spaces. Information Manager records the definition after Y, the record after APPLE, and an end marker after the final SPECIAL. There is no separate SAVE command.

Wait for the opening screen and the user LED to clear. Restart the cartridge, mount your recording with **Mount Playback Tape**, then **Rewind Playback Tape**. At `:`, submit `REVIEW` with NEXT. At `/`, submit `PRINT ALL`. Expect `ITEM: APPLE`, then `END OF TAPE` and another `/` prompt. Submit `EXIT` to return to the opening screen.

To try an edited save, mount this database as **Playback Tape** and a different writable blank as **Record Tape**. Rewind both. Submit `EDIT` at `:`, then `PRINT ALL` at `/`. Change APPLE to PEPSI and accept with NEXT. After `END OF TAPE`, submit `EXIT` and wait for recording activity to finish. Mount the output as Playback Tape, rewind, and use REVIEW / PRINT ALL: expect `ITEM: PEPSI`. The source should still display APPLE when separately rewound and reviewed.

See the [Information Manager manual](../../docs/INFOMAN-MANUAL.md) for field types, database planning and other commands.

## APL/S: countdown

[countdown.txt](countdown.txt) defines the original program `DOWN`. Enter each line at the APL/S prompt and press NEXT, or choose **Keyboard > Load Keyboard File** and load [countdown.vbk](countdown.vbk). `ENDE` finishes editing. Enter `DOWN` and press NEXT to run it. At `COUNT FROM`, enter `3` and NEXT. Expect 3, 2, 1, 0, then DONE, with a shrinking bar.

The countdown uses a short loop delay, not a real-time clock. Its steps are not exact seconds. Change the `5` in `WHIL K LT 5` to adjust the delay. Bar heights above 64 are clipped. Negative inputs are made positive and fractional inputs are rounded down.

To save, finish or stop the program and return to the prompt. Mount your writable tape in **Mount Record Tape**, then submit `SAVE` with NEXT. Wait for `TAPE OK` and the user LED to clear.

To verify, restart APL/S, mount the saved image as **Playback Tape**, rewind, then submit `LOAD`. After `TAPE OK`, run `DOWN` with 3 again and compare the result. Also try 0: it should display 0 and DONE without counting. Save an edited version to a working copy, restart, reload, and check that the edit survived.
