# APL/S source entry

Boot the Computational Language cartridge and wait for its input prompt.
Load a `.vbk` file with **Enter APL/S Source**, then close the OSD. The core
types the listing through the keyboard matrix without restoring machine RAM.
Pressing a keyboard key or reopening the OSD cancels entry and releases the
generated key. Cancellation leaves any partially entered program in place.
Reset or reload the cartridge before retrying a partial listing.

Ready-to-load controls are in `examples/apl`: `arithmetic.vbk` should produce
2 then 5; `bars.vbk` should draw heights 10, 20, 30 and then produce 2.
Hardware playback remains unverified.

## Converting a listing

```sh
python3 verilator/apl_source.py listing.txt
```

This writes `listing.vbk`. Input is UTF-8 text containing exactly the lines
to enter at the APL/S prompt. Each nonblank line ends with NEXT. Program
definitions must include their entry commands, such as EDIT and ENDE;
printed headings, line numbers and OCR errors require proofreading first.
No RUN command is added. A one-line expression executes when NEXT is entered.

Letters become uppercase. Blank lines and surrounding indentation are ignored;
CRLF and LF are accepted. Tabs become spaces. Smart double quotes become plain
quotes, nonbreaking spaces become spaces, and Unicode minus becomes hyphen.
Multiplication, division, pi and high minus use their UTF-8 APL glyphs.
ASCII `*` means exponentiation; it is not converted to multiplication.
Unsupported characters are rejected with their source line and column.
The limit is 4096 key tokens, including spaces and NEXT.

The interpreter must be ready for input. Entry uses 8 video fields per press,
8 per release and a 64-field wait after NEXT. These are fixed delays, not a
prompt acknowledgement; listings that execute long operations or request user
input need separate testing. Avoid typing during entry.

## File format and simulator

VBK1 has an 8-byte header: magic VBK1, little-endian 16-bit token count and
little-endian CRC-16/CCITT (polynomial 1021, initial FFFF) of the payload.
Each byte contains a matrix key in bits 5:0 and desired symbol mode in bit 6.
Bit 7 marks mode-independent SPACE (93 hex) or NEXT (9B hex).
The loader stages and validates the complete file before typing. SHIFT is
generated from the observed interpreter mode; raw SHIFT tokens are rejected.

```sh
cd verilator
make test-apl-source
make headless
./obj_dir_headless/Vtop --cart "../software/converted/The Computational Language (APL-S).bin" --source ../examples/apl/arithmetic.vbk@210 --frames 700 --shot-last --outdir out/apl/source
```

The headless run checks completion, not the displayed arithmetic result.
Inspect its capture. Building and running the full simulator may take time.
