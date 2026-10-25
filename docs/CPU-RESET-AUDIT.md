# CPU reset and APL/S cartridge reload

The reported failure is a reload at the moment APL/S reaches its entry screen:
the BIOS font becomes half height, the background flickers, and a tape error
appears even with no tape mounted.

## Reset defect

`f8_cpu` previously checked `reset_na` only inside `IF ce='1'`. The board clock
generator clears its CPU enable while reset is asserted. The CPU could therefore
retain its old opcode, microcode phase, branch state and output ports while the
bus interface, video hardware and Expander reset independently. Restart then
depended on the exact phase interrupted by the cartridge download.

Reset now takes priority over clock enable on every system clock. It installs
the first reset microinstruction, clears pending branch/write/interrupt state,
and releases both output ports to FF. Scratch registers and accumulator retain
their existing unspecified reset contents.

This applies to the main CPU and the Expander's instance of the shared CPU.
Cartridge download selection and the optional hot-load mode are unchanged.

## Upstream comparison

Compared against Grabulosaure's [CPU Fixes, 173e094](https://github.com/MiSTer-devel/ChannelF_MiSTer/commit/173e094ccc1864124e97bccfd54361ac44513dde).

- BF branches when every selected status bit is clear; BT branches when any
  selected bit is set. Our masked predicates already implement both fixes.
- BR7 takes a long operand cycle when ISAR's low three bits are not seven,
  otherwise a short operand cycle. Our implementation already has this fix and
  confines the override to the operand, keeping the following fetch short.
- Upstream also resets both output ports to FF. This was missing and is now
  included in the reset path that works with clock enable disabled.
- Existing interrupt handling remains in place. Upstream's removal of the unused
  `tick` ports is an interface cleanup and is not needed for these corrections.

## Regressions

Run from `verilator/`:

- `make test-cpu-reset`: actual clock generator, CPU and bus interface; reset
  while enable is low at each of the twelve CPU phases, verify idle output ports
  and restart at the BIOS entry. The original CPU fails this regression.
- `make test-apl-reload`: actual BIOS, APL/S and Expander ROMs, with both real tape
  decks and no mounted media; reload three times around entry readiness
  (`APL_RELOAD_ARGS=+reloads=12` extends the run),
  verify the video mode matches the initial entry screen, and reject tape errors
  or SD requests. APL/S normally selects Y zoom off at entry, so that bit alone
  is not evidence of the reported half-height BIOS font. Requires
  the ROM files in the paths specified by the Makefile.
- `make test-cpu-branches`: 320 BR7, 2560 BF and 1280 BT cases, including cycle
  lengths and the following fetch.
- CPU opcode timing, port readback, interrupt entry/chain, CPU-to-DAC timing,
  Expander firmware record/serial, tape and status-message tests cover related
  behavior.

Hardware verification should repeat the original rapid reload sequence with the
new bitstream; the simulated cartridge transfer does not exercise HPS transport.

Validation passed: all twelve reset phases; branch, opcode timing, port,
interrupt, audio, Expander record/serial, tape and OSD regressions; and three
real-ROM APL/S reloads. Each reload returned to input at PC 3C14 with the same
video state and no tape error or SD request. Simulator keyboard C++ also passed
a syntax check against the current generated core headers.
