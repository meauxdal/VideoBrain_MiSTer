# APL/S NEXT timing sweep

Run in WSL from the repository root. Build once:

```sh
make -C verilator headless
cd verilator
```

Start with the exact 46-character Clock condition:

```sh
python3 apl_next_sweep.py --families clock --delays 32,64,72,96,128,256 --out out/next-clock
```

Then sweep content and preceding program context (many independent simulations):

```sh
python3 apl_next_sweep.py --repeat 2 --out out/next-sweep
```

Use `--prepare` to generate files and command arrays without running them.
Use `--analyze --out DIR` to regenerate summaries from existing traces.
Each trial starts a fresh machine. Timed VBK2 input uses 8-field holds and
releases, explicit SHIFT keys, and 512 extra fields after setup NEXTs.
`--settle`, `--hold`, and `--observe` change these experiment settings only.
The recorded length is the actual logical line length, at most the requested
length. Source files, screenshots, logs, commands, and CSV traces are retained.

Delays count video fields from target NEXT release to probe press. The current
Normal loader waits 8 release fields plus 64 LINE_WAIT fields for short lines:
compare with 72, not 64. Lines over 30 characters and ENDE use 96 LINE_WAIT fields,
so the 46-character Clock condition waits 104 fields after release.
The timed sweep bypasses these waits. Idle events extend waits beyond VBK2's
255-field gap.
SHIFT, an ordinary character in the current mode (A or 0), and a no-key control
run independently. No acknowledgement changes or stops input delivery.

`results.csv` records SHIFT response or failure, response latency, port-1
polling and RAM-write counts. Expected setup letter/symbol modes are checked
against emitted-key logs; a mismatch invalidates that trial. This cannot prove
every setup character was accepted. Inspect screenshots for syntax errors or
incorrect setup before interpreting a curve.

`shift_curve.csv` and `shift_curve.svg` show the smallest tested delay for which
all larger tested delays and repetitions also responded. This is a measured
SHIFT response bound for the tested content and hold duration. It does not
certify ordinary-character acceptance, untested delays, other workspaces, or a
universal length-only timing formula. CHAR and NONE results stay unclassified.

`snoop.csv` records key edges, mode changes, RAM writes, I/O reads/writes, and
scratch-register writes, with PC0/PC1/DC0, accumulator, flags, ISAR, all 64 scratch
registers, and keyboard column selection. The `registers` field is 64 consecutive
hex bytes on begin/key/mode events; scratch events supply intervening writes.
Other addresses and values are decimal. Traces can be large.
RAM events use effective CPU addresses and include system and cartridge RAM.
Writes are sampled before their committing edge; consecutive identical held
strobes are collapsed. Register snapshots precede the pending write. Port-1
reads may be STOP checks rather than general input readiness. Compare CHAR
against NONE and late-delay trials to locate candidate acceptance signals.

The same passive interception is available for an ordinary source replay:

```sh
./obj_dir_headless/Vtop --cart '../software/1 Cartridges/APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin' \
  --source '../software/2 VideoBrain Keyboard Input Files (vbk)/21-apl_s-games-james-price/21-clock.vbk@210' \
  --source-trace --source-snoop out/clock-snoop.csv --source-snoop-from 200 \
  --frames 14000 --max-cycles 6000000000
```

Create `out` first. No production RTL or loader timing is changed.
