# APL/S source entry

Boot the Computational Language cartridge and wait for its input prompt. Choose **Keyboard > Load Keyboard File** and select a `.vbk`. Once the OSD closes, the core types the listing. A keyboard key cancels entry and releases the generated key. Reopening the OSD also cancels entry unless **Keyboard > Menu Aborts VBK** is Off. Partial input remains; reset or reload the cartridge before retrying a partial listing.

The bundled [Price games and listings](../examples/21-apl_s-games-james-price) come with `.txt` sources and ready-to-load `.vbk` files.

## Starting a program

Load a definition and wait for entry to finish. Type its launch name in letter mode, then press NEXT (PC F3). No RUN command is needed. SHIFT toggles letter/symbol mode; use symbol mode for numbers and NEXT after each answer.

| File | Launch | Use |
| --- | --- | --- |
| `04-guess.vbk` | `GUES` | Enter a limit, then guess the number. |
| `08-acey.vbk` | `ACEY` | Starts with cash 100 and two cards. Bet on the third card falling strictly between them; `99` at BET? exits. |
| `20-bulls.vbk` | `MOO4` | Enter four distinct digits separated by spaces. WHITE/RED counts report exact/misplaced matches; `99` exits. |
| `22-roulette.vbk` | `RO` | Follow the betting prompts; `3` then `99` at the next round exits. |
| `23-change.vbk` | `C` | Starts with X=89 and calculates coin change. |

Immediate expressions, such as `01-sine.vbk`, execute as they are entered. For other programs, see the launch name and prompts in their `.txt` source. Roulette preserves the printed listing's omission of 23 from both betting lists.

Gunner corrects the printed listing's `BAR -30` and `BAR 30` to `BARH -30` and `BARH 30`. The original lines cause a syntax error; continued automatic entry appends later text to the rejected line and can produce repeated `SYNTAX 168` errors. Restart from a fresh cartridge prompt before loading the corrected file.

Dicejack uses `BUSTED` instead of the printed dealer message `I BUSTED`, matching the stored dump. The longer message exceeds APL/S's 255-byte program limit, causing `CAPACITY 6` followed by `SYNTAX 6` at the final `ENDE`. Launch the corrected program with `D`.

## Preparing a listing

See [keyboard converters](../tools/README.md#keyboard-files) for commands. Supply UTF-8 text containing exactly the lines to enter at the APL/S prompt. Program definitions must include EDIT and ENDE; remove printed headings, line numbers and OCR errors. Each nonblank line ends with NEXT.

To load a definition without running it, end the source with ENDE and omit its launch command. ENDE must receive NEXT to finish the definition. `--hold-final` leaves the final line unsubmitted; earlier lines still submit and may execute. Do not use it on a final ENDE for a completed definition.

Letters become uppercase. Blank lines and surrounding indentation are ignored; CRLF and LF are accepted. Tabs and nonbreaking spaces become spaces, smart double quotes become plain quotes, and Unicode minus becomes hyphen. Multiplication, division, pi and high minus accept ×, ÷, π and ¯ or `{MUL}`, `{DIV}`, `{PI}` and `{NEG}`. ASCII `*` means exponentiation. Unsupported characters are rejected with their line and column. The limit is 4096 key tokens, including spaces and NEXT.

APL/S entry waits for the interpreter to accept each key and its release. After NEXT, it waits for parsing, execution and screen updates before typing the next line. There is no entry-speed setting. Timed VBK2 files, including music, use their encoded timings; see [keyboard input](KEYBOARD-INPUT.md).
