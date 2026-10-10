# MiSTer-devel cleanup

## Rules

Read AGENTS.md each session. Preserve behavior and existing structure.
Keep code and comments plain ASCII. No generated replacement code comments.
Human authorship is required; shortening generated prose does not satisfy it.
Preserve licenses, attribution, and necessary hardware constraints.

User supplied Sorgelig's PR template:

> Make sure you removed all AI comments from code. You still can add hand-made comments if it's required for further development or to make attention to specific part of code.
> Make sure you run all local tests before opening this PR.
> Try to avoid excessive and obfuscated, hard to understand AI description. Write description by yourself.
> All comments in code are hand-made

Code should explain itself. Retained functional comments cover hardware
behavior, non-obvious implementation or decisions, and regression pitfalls.
Do not infer authorship from style alone. Flag uncertain or necessary generated
comments for human review; do not silently discard unique technical facts.
PR descriptions and review comments must be human-written. Do not open a PR.

## Phases

- [x] 1. Audit and remove unnecessary first-party code comments.
- [ ] 2. Verify retained comments against code and hardware evidence.
- [ ] 3. Reduce docs and reconcile current status claims.
- [ ] 4. Clean whitespace and review source/script organization.
- [ ] 5. Review upstream submission contents and dependency modifications.
- [ ] 6. Run all local tests, build checks, and human self-review before PR.

## Phase 1 scope

Start with rtl/uv202/uv202_clkgen.vhd, then remaining first-party RTL,
VideoBrain.sv, simulator source, Makefile, and tools/test scripts.
Remove narrative, repetition, code paraphrases, development history, and
excessive banners. Preserve concise navigation where useful.
Do not change logic, interfaces, identifiers, test behavior, or documentation
outside this tracker. Leave third-party source and generated PLL files alone.
Treat upstream F8 source separately: preserve original comments and attribution;
audit local additions. Do not assume sys/ or vendored code is first-party.

For comments needing human replacement, record file/line, technical fact,
evidence, and reason here. Do not write replacement comments into code.
Check the diff for accidental code changes and run git diff --check.
Record checks and unresolved questions; mark phase complete only when finished.
No commits or PR publication requested.

## Initial findings to verify

- Clock generator: long narrative header, repeated timing explanations,
  f8_psu.vhd reference, and retained integer-divisor interface commentary.
- sys_bus.vhd: cartridge stub claim appears obsolete.
- README.md: MDS typo; current status needs reconciliation with CARTRIDGES.md.
- docs/JOYSTICK.md and verilator/joystick_verification.md: conversational reports,
  superseded trials, and duplicated evidence. Preserve useful raw evidence.
- joystick_verification.md: release link points to releases/ rather than docs/.
- verilator/README.md: conversion workflow and selftest regeneration reference
  need review. Makefile CONVERTED is empty; do not remove machinery without review.
- .gitignore: duplicate *.log entry.

## Progress

Planning inspection complete. Working tree was clean before this tracker.
Phase 1 pending in a new local chat.

## Human review queue

Retained first-party comments have unconfirmed human authorship. Confirm it;
if generated, a human must replace necessary facts. Do not infer authorship
from Git author names or style. Navigation labels need authorship review too.
Locations below use the current working tree.

Evidence for each row: implementation in the named file and its existing
source references. Hardware/source claims are not yet independently verified;
that is phase 2. Reason for retention: preserve constraints, non-obvious
behavior, attribution, or useful navigation until human review.

| File:lines | Retained facts / review topic |
| --- | --- |
| rtl/buffered_bus.vhd:1-9,21,25,30,35,40-42,79-80 | DMA visibility, WACK, open bus |
| rtl/f3853.vhd:1-15,26-27,33,40,42,68,71,78,97,112 | timer/LFSR, vector bit, interrupt priority |
| rtl/uv201/uv201_fetcher.vhd:1,24-25,202,239-242 | zoom, hardware width/height and zero sizes |
| rtl/uv201/uv201_fifo.vhd:1-7,21-22,47,65-67,106-108 | 10-to-8 hysteresis, clear enable, reset contents |
| rtl/uv201/uv201_pack.vhd:1,12-18 | FIFO payload and colour packing |
| rtl/uv201/uv201_regs.vhd:1-3,18,24-25,27,32-38,40-41,46,54,63-65,103-107,112,130-131,141 | register map, status access, freeze edge, field packing |
| rtl/uv201/uv201_render.vhd:1-13,28,45,64,90,113,131,141,153,173,180-181,193 | FIFO, zoom, colour modifier, palette |
| rtl/uv201/uv201_yint.vhd:1-2 | equality and FRZ/INT gating |
| rtl/uv202/f8_busif.vhd:1,36,43,67-68,143,180-183,188,281-284,298,308 | ROMC data source, PC1 backup, I/O sequencing |
| rtl/uv202/uv202_arbiter.vhd:1 | module label |
| rtl/uv202/uv202_clkgen.vhd:1-14,28-29,42-44,89-92,117-121 | CPU oscillator, BRCLK phase, unused CPU_CLK_DIV |
| rtl/uv202/uv202_pack.vhd:1-3,14-23,26,28,32-33,35-36,38,40-41,44-45,49-51,55,57-59,61,64-66,70,73,76,79,82-85,88,107-108,110,112-114,116,119-120,122-130,132-135,137-140,142-150,152-161,164-167,174-176,182-186,194-196 | clocks, timing, maps, wait classes, CRC attribution |
| rtl/uv202/uv202_timing.vhd:1-4,18,20-25,27-32,35-36,44,60-61,132-134,143-145,173-174 | field/HBLANK/burst timing, half-line TODO |
| rtl/uv202/uv202_top.vhd:1,26-27,33-34 | second DMA channel, CPU enables |
| rtl/videobrain_audio.sv:16 | filter poles |
| rtl/videobrain_core.vhd:1,22,25,27,52-53,218,345,348,351-353,407 | record boundary, 555, wired-OR interrupt, pot TODO |
| rtl/videobrain_io.vhd:1-15,29-35,37-39,49-50,87-88,97,115 | port/KBD polarity, matrix, audio write event |
| tools/make_boot_rom.sh:2-6 | boot layout/index and usage |
| verilator/joystick_calibration_check.py:59 | pre-game telemetry bounds |
| verilator/joystick_gain_check.py:67 | PC telemetry vs LIS completion |
| verilator/joystick_scaling_model.py:8 | base2580 measurement fit |
| verilator/joystick_sweep.py:66 | search preference vs drift |
| verilator/Makefile:1,13,36-37,49-50,83,93,99 | analysis order, CONVERTED, SDL includes |
| verilator/sim_headless.cpp:1-2,33-36,45,75-76,85,110-111,115-116,204,211-212,223-225,245,304,309,342,598,614-615,636,679,697,854,856-857,875,893-894,915 | RAM packing, PNG, sample phases, reset, traces |
| verilator/sim_main.cpp:1,9,58-59,104,173,185-186,213-214,237,390 | raster, inputs, download/reset order |
| verilator/sim.v:2,32,134 | matrix layout, DAC |
| verilator/strip_modules.py:1-2,9 | module splitting contract |
| verilator/tests/tb_cpu_clock.vhd:40 | LIS short cycle |
| VideoBrain.sv:21,37,44,46,115,117,132,134-136,146,148-150,161,165-168,170-173,175-179,181-184,186-189,191-194,196-199,201-204,206-209,215,220,225-226,238,241,308,343,345 | aspect, clocks, downloads, keyboard/pot/fire mapping, DAC |

- rtl/f8/f8_cpu.vhd:47-49,228-231: local interrupt inhibition and discarded
  opcode/PC1 backup. Evidence: diff from 2233fc3, int_inhibited(), interrupt
  dispatch, f8_busif ROMC 0F. Human authorship unconfirmed; preserve semantics.
- rtl/uv202/uv202_clkgen.vhd:6-13,28-29,89-92,117-121: human replacement if
  generated. Preserve separate 4MHz/2 CPU source, continuous BRCLK phase,
  fractional half-cycle enables, and unused CPU_CLK_DIV. Evidence: phase
  accumulator, BRCLK counter, uv202_top enable gate; hardware reference cited
  in header. Header and stage prose still overlap; human can condense it.
- rtl/uv202/uv202_pack.vhd:28,40-41 and rtl/f3853.vhd:26-27: phase 2 must
  check cycle-origin, vsync-width and LFSR-stage claims against implementation
  and hardware sources before any human replacement.
- verilator/sim/*.{cpp,h}: preserved as potentially reused support source.
  Evidence: sim_console.cpp:5-6 resembles the ImGui console example;
  sim_video.cpp:346-348 credits ElectronAsh; sim_input.cpp:373-605 references
  ADB/IIgs. Initial import 9c16982 supplies no usable pre-import baseline.
  Identify provenance and local additions before removing any comments.
  Includes historical Verilator comments in sim_bus.cpp:7, sim_bus.h:3,
  sim_input.h:8,40 and raster constraint in sim_video.h:37-39.
- CPU-clock test expects a fixed 28-MCLK short cycle, while clkgen uses
  fractional 4MHz half-cycle enables. Untouched HEAD fails identically.
  Reconcile the test and intended timing in a separate behavior/test task.

## Validation

- PASS: diff contains 260 comment-only deletions across 24 files, no source
  additions. Reviewed diff; interfaces, statements and directives unchanged.
- PASS: git diff --check.
- PASS: make lint (GHDL analysis/synthesis and Verilator lint). Warnings:
  PINCONNECTEMPTY, UNUSEDSIGNAL, UNSIGNED, CMPCONST, SYNCASYNCNET.
- PASS: make test-yint; make test-audio.
- PASS: AST syntax check of all 8 tracked Python scripts; bash -n of all
  tracked shell scripts in tools/ and verilator/.
- FAIL, pre-existing: make test-cpu-clock, tb_cpu_clock.vhd:43 at 2725ns:
  "F8 short cycle must take 28 master clocks". Same failure reproduced from
  untouched HEAD sources in an isolated GHDL work directory. User also
  identified the 28-MCLK expectation as likely stale. No test changes made.
- Logs (ignored): verilator/out/comment_cleanup_checks.log,
  verilator/out/comment_cleanup_remaining.log,
  verilator/out/comment_cleanup_baseline/result.log.

WSL checks succeeded after sandbox escalation. No Quartus or full game suite
run in this comment-only phase; phase 6 still requires all local checks.
Human authorship/provenance review and the stale timing test remain open;
phase 1 safe deletions are complete, not an upstream-readiness certification.
This tracker is a local coordination artifact; remove from upstream submission.
