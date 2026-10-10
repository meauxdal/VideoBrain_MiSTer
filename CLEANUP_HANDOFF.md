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

## User clarification for phase 2

Delete first-party code comments unless they are load-bearing: needed to
understand a constraint, non-obvious behavior, or avoid a regression.
Useful navigation alone is insufficient. Preserve licenses and attribution.
Important explanation that does not belong in code can live in documentation;
record relocation candidates here for the documentation phase.
The user will review remaining comments after the repo sweep, not per phase.
Continue safe cleanup without waiting for interim authorship review.

## Phases

- [x] 1. Audit and remove unnecessary first-party code comments.
- [x] 2. Verify retained comments against code and hardware evidence.
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

Phase 1 is in HEAD c13d54f. Phase 2 preserved that baseline and the incoming
uncommitted tracker clarification. No commits or PRs made in phase 2.

## Phase 2 audit and human review queue

First-party RTL, VideoBrain.sv, simulator harnesses, Makefile, tools and test
scripts swept. Local F8 additions audited against 2233fc3 separately. Original
F8, sys/, vendor/ImGui, generated PLL and build-directive comments preserved.
No replacement code comments written. Remaining first-party authorship is
unconfirmed; a human must replace necessary generated comments after the sweep.
Locations below refer to the phase 2 working tree. Reference-only comments
remain as source attribution. Evidence verifies implementation unless a local
hardware source is explicitly named; it does not certify human authorship.

| File:lines | Load-bearing fact and evidence / human action |
| --- | --- |
| rtl/buffered_bus.vhd:1-6,69-70 | DMA cannot see CPU UV201 window; FF is a placeholder. Decoder and local Kevtris text:850-882 agree. Keep open-bus constraint. |
| rtl/f3853.vhd:1-4 | Single-SMI subset omits memory interface and daisy chain. Entity/core have one instance; MAME attribution retained. Timer equivalence unverified; see below. |
| rtl/uv201/uv201_fetcher.vhd:23-24,237-240 | Zoom scales X; width/height zero encode maximum size. ST_DY/ST_DECIDE implement this; Kevtris text:1058-1062 confirms height. Archive date/width-zero claim needs source recovery. |
| rtl/uv201/uv201_fifo.vhd:1-2,16-17,59-61,100-102 | Clear independent of enable; clear storage and 10-to-8 hysteresis. Process branches and Kevtris text:1769-1777 agree. |
| rtl/uv201/uv201_pack.vhd:11-17 | Payload changes meaning with is_gap; colour combines intensity and hue. Fetcher assignments/render consumption and Kevtris rendering section support the contract. |
| rtl/uv201/uv201_regs.vhd:97 | FRZ capture uses a negative interrupt edge. capture_stb source in core agrees; patent citation retained, patent text not located locally. |
| rtl/uv201/uv201_yint.vhd:1 | Equality with INT=1/FRZ=0, not a pulse on crossing. Comparator and test-yint agree; patent citation still needs primary-source review. |
| rtl/uv201/uv201_render.vhd:116,126,163-164 | First pixel is emitted before state advances; modifier affects object background, not gaps. idx_c/fresh_data and shift/gap updates agree. |
| rtl/uv202/f8_busif.vhd:64-65,140,177-180,278-281 | Port source depends on ROMC; grant works while CPU held; dr_l differs from dw; PC1 backs over discarded fetch. Phase branches and f8_cpu dispatch agree. |
| rtl/f8/f8_cpu.vhd:225-228 | Local addition: discarded opcode must be refetched on interrupt return. Diff from 2233fc3 and f8_busif ROMC_0F pc1 <= pc0-1 agree. |
| rtl/uv202/uv202_clkgen.vhd:1-11,25-26 | Separate CPU oscillator, not integer /7; CPU_CLK_DIV unused. Kevtris text:96-140 and accumulator agree. Human replacement should explain fractional 4MHz half-cycle enables without history. |
| rtl/uv202/uv202_pack.vhd:1-2,39-41,66,125-128,153-155 | Source/CRC attribution, 14-bit mirror, RES1 bypass, selective 2800 fold. Busif truncation/classify and cpu_addr_fold agree; Kevtris address-space section supports mirror. |
| rtl/uv202/uv202_timing.vhd:1,26-28,32,56-57,128-130 | Half-line approximation; line_start at hpos 0; registered HBLANK edges align to output count. Wrap/edge logic and fetcher wiring agree. Keep approximation warning; human must resolve timing questions below. |
| rtl/uv202/uv202_top.vhd:25-26 | Second DMA interface retained for real UV202. Kevtris text:601-613 and arbiter ports agree. |
| rtl/sys_bus.vhd:98-99,138-139,194-197,206-211,251-252,367-368 | Open CPU cart-device window, 2K mirroring, no RAM reset, synchronous reads and separate memory processes, mapper-only expansion access. Decode/write logic and GHDL RAM-inference output agree. Quartus claims require phase 6 build evidence. |
| rtl/videobrain_audio.sv:16 | Filter poles depend on MCLK, before resampling. Shifts 10/9 yield approximately 2.23/4.46kHz at 14.318181MHz; not a measured analog response. |
| rtl/videobrain_core.vhd:48-49,342,345-346,400 | Record boundary, current-Y HBLANK advance, 555 reset/edge behavior. Entity/assignments/process agree; Quartus record restriction and pot calibration need hardware/build review. |
| rtl/videobrain_io.vhd:1-3,17-19,70-71,80 | KBD active low, inverted F8 pins, sound-clock write event. CPU NOT alu, I/O NOT pins and DAC gate agree; hardware edge description must include both write event AND clock transition. |
| VideoBrain.sv:128-130,141-143,154-202,216-217 | Boot index translation, packed matrix/scancodes, vertical/horizontal pot ordering. Decode/matrix logic and core I/O agree. External Main_MiSTer boot convention, board netlist/MAME mapping and Tennis source attribution need source recovery. Key labels decode otherwise opaque numeric constants. |
| verilator/Makefile:34-35,47-48; verilator/strip_modules.py:7 | CONVERTED replacement contract and two SDL include spellings; flat module split assumption. Make rules/includes and generated netlist agree. CONVERTED remains empty. |
| verilator/sim_headless.cpp:31-34,72-73,82,291,619,679,836,872-873 | Flattened RAM indexing, PNG format bytes, download settling, reset release by cycles, capture before eval and sampling domains. Netlist/get_obj_byte, PNG writer and loop ordering agree. |
| verilator/sim_main.cpp:8,181-182 | Required global for sim_input; early file check because download failures only log. sim_input extern and QueueDownload agree. |
| verilator/joystick_calibration_check.py:59; verilator/joystick_gain_check.py:46,56,67 | Pre-game bounds, BIOS stack return, bypass startup, telemetry before LIS completion. Trace parsing/generated ROM and local BIOS disassembly agree. |
| verilator/sim/sim_video.h:37 | Resize must precede framebuffer allocation. Resize changes size; Initialise mallocs it. No current caller; retained API constraint. Provenance below. |

## Queued investigations and documentation candidates

- Clock generator: local Kevtris text (verilator/out/videobrain_unwrapped.txt,
  ignored) distinguishes the stock 4MHz/2 CPU source from its modified shared
  oscillator test rig. The accumulator emits 3- or 4-MCLK intervals, not a
  strict alternation. CPU_CLK_DIV has no use. brclk_phase advances each BRCLK,
  is exported and OPEN in the core; neither fetcher nor arbiter consumes it.
  Removed false fetcher-use claim and duplicate stage prose. Human constraint
  replacement: independent CPU rate and unused generic. Documentation candidate:
  oscillator wiring and test-rig distinction. No new clock logic requested.
- Timing origin: Kevtris normal-sync table:535-537 uses CSYNC 0-17 and HBLANK
  222-227/0-32; rendering tables:1198-1201 explicitly reset cycle 0 at HBLANK
  falling. RTL hpos 0 is line wrap; HBLANK falls at output hpos 33. Removed
  claims equating these origins. Human replacement must distinguish the two.
- Vsync width: Kevtris text:569-571 says 18 clocks but lists 105-113 and
  219-227 (9 each). RTL uses width 18: comparisons cover old hpos 105-122 and
  219-227, the latter clipped by wrap; registered csync is one BRCLK later.
  Burst is also registered from old hpos and suppressed by 21-line vblank,
  contrary to removed prose claiming first 9 lines. Half-line seams remain
  unverified. Preserve these contradictions for a separate timing task; do
  not pick a hardware interpretation or change constants in this phase.
- F3853: removed 31-stage LFSR claim. timer_val is uv8, decremented to zero;
  PRESCALE=31 counts brclk_ena, not CPU phi/2. Mode decode makes external and
  timer enable mutually exclusive, so removed simultaneous-priority claim.
  No local F3853 primary timer source found. Human replacement needs measured
  clock source, prescaler and actual timer sequence; separate behavior task
  must compare the current down-counter to hardware, not bless equivalence.
- Local F8 inhibition prose wrongly grouped EI/POP/JMP as loading PC1/W/I/O.
  Removed it; predicate unchanged. Human replacement needs authoritative
  instruction-inhibition rationale. Keep fetch-discard/PC1 regression warning.
- Simulator support: compared all non-ImGui sim/* files with local StudioII,
  MacLC and MacQuadra800 counterparts. StudioII sim_bus.cpp differs only in
  ioctl_index pointer width; sim_bus.h/sim_input.h historical Verilator
  comments are shared. sim_video differs by Resize method/declaration/comments.
  Kept its allocation-order constraint; removed machine-selection prose
  because raster dimensions are constants and Resize has no caller. Shared
  comments, ElectronAsh credit, ImGui example and ADB/IIgs material preserved.
  These copies establish reuse, not the original upstream or human authorship.
  Unmatched support comments retain uncertain provenance; see comparison log.
- Relocate to docs only if useful: boot-ROM tool usage/layout, clock pin map,
  register/command maps, wait-state truth table, mapper memory layout, active
  raster dimensions, palette explanation, harness launch commands, and
  joystick fit/search methodology. Existing code/README often suffices.
  Removed source paths docs/uv201.cpp and docs/videobrain_unwrapped.txt do not
  exist here; recover citations in documentation phase. Do not copy ignored
  evidence into source without reviewing provenance.
- CPU-clock test: fixed 28-MCLK expectation remains unchanged. Phase 1
  reproduced the same failure on untouched HEAD; user considers it stale.
  Reconcile with fractional enables in a separate behavior/test task.

## Phase 1 validation

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

## Phase 2 validation

- PASS: exact noncomment content preserved in all 30 changed source files,
  compared with saved entry snapshots. Strings, code indentation, Python
  tokens and compiler directives unchanged; only comment text and its trailing
  separator whitespace removed. Entry source snapshots equal HEAD c13d54f.
- PASS: git diff --check; changes limited to comments and this tracker.
- PASS: make lint (GHDL analysis/synthesis and Verilator lint), test-yint,
  test-audio and headless build. Existing warning classes remain, including
  tick unassigned, PINCONNECTEMPTY, UNUSEDSIGNAL, UNSIGNED, CMPCONST and
  SYNCASYNCNET. GHDL reports inferred system/cartridge/RES RAMs.
- PASS: headless selftest.rom smoke, --frames 8: 9 frames, 1919817 cycles;
  final frame 189x241, hash 6DAC9D6F, has content.
- PASS: AST syntax check of 8 tracked Python scripts; bash -n of 11 tracked
  shell scripts in tools/ and verilator/.
- FAIL, pre-existing: test-cpu-clock at 2725ns, fixed 28-MCLK assertion.
  Reproduced from untouched current HEAD in isolated GHDL work directory.
  Comment deletion moves the reported line from 43 to 42; assertion unchanged.
- FAIL, pre-existing: graphical make all, sim_console.cpp:20 IM_FMTARGS(2),
  GCC rejects attributes on a function definition. Reproduced with untouched
  HEAD sim_console.cpp and unchanged support headers. No compiler workaround
  or source fix in this phase. This blocks graphical build validation, not
  the comment sweep; resolve before phase 6 completion.
- Initial overlapping Make invocations raced on gen/videobrain.v.tmp. Final
  checks ran sequentially and supersede those failed attempts.
- Ignored evidence: verilator/out/phase2_preservation.log,
  phase2_checks_final.log, phase2_cpu_clock.log, phase2_baseline.log,
  phase2_baseline/{cpu_clock,graphical}.log, phase2_smoke.log,
  phase2_support_provenance.log; entry source snapshots in phase2_comments/.

Phase 2 comment sweep complete. Uncertain hardware claims, source provenance
and human authorship remain explicitly queued above. No Quartus/full game
suite run; no behavior/test edits, refactoring, commits or PR work performed.
