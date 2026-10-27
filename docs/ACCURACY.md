# Accuracy report

Current source status, October 27, 2026. This describes the core approaching 1.0, rather than a particular released RBF. Linked audits retain their own revision and test scope.

## What this core represents

The aim is to recreate the VideoBrain's hardware behavior as faithfully as the available evidence allows. The implementation includes the Fairchild F8 processor, UV201 video system, UV202 clock and bus control, memory and cartridge interfaces, keyboard, joystick timing, sound output, and Expander 1 support.

The implementation has been developed without direct access to an original VideoBrain. Its evidence consists of preserved documentation, reverse engineering, board connection records, original software and cassette data, photographs, screenshots, and videos, together with MAME and our own implementation tests. Further original-machine testing is planned. Tests on MiSTer establish behavior of this core; they are not direct measurements of an original VideoBrain.

Daily MiSTer use and testing of the difficult software and peripheral paths have revealed no further known core bugs. The observed Information Manager defect is in the original software. The core is close to meeting its 1.0 goals; the principal remaining accuracy work depends on original-machine measurements and can continue after release. Complete cycle accuracy and electrical equivalence remain unverified.

## Evidence and confidence

- Circuit records, component documentation, patents, and reverse-engineering notes explain how the machine is believed to work. Some records conflict or leave details unspecified.
- Original-machine images and recordings provide visible or audible comparison points. Their capture paths limit conclusions about exact timing, color, and analog response.
- Original-machine cassette data provides an independent compatibility check through the software and tape interface. Money Minder has completed a load, edit, save, restart, and reload cycle using such data.
- Simulation checks instruction timing, bus transactions, signal sequencing, and regressions against explicit expectations. A passing test supports those expectations; it does not independently prove the hardware model.
- MiSTer testing checks the implemented machine in use, including software, controls, and the output path. Coverage varies by application and feature.

The main references are Kevtris's *VideoBrain Unwrapped*, Sean Riddle's preserved hardware material, VideoBrain patents and manuals, processor documentation, and MAME. The [project source list](../README.md#sources) provides starting points. The [timing source audit](TIMING-SOURCES.md) distinguishes active opcode cycles from board waits, records discrepancies in secondary tables, and inventories the saved capture channels. The notes linked below preserve more specific evidence and test limits.

## Current implementation

| Area | What is implemented and supported | Remaining limits |
| --- | --- | --- |
| F8 CPU and bus | Instruction cycle timings have been cross-referenced against the available manufacturer documentation and secondary references. Execution, ROMC cycles, interrupts, clock gating and contention have extensive focused coverage. | Further progress chiefly needs test ROMs, diagnostics and oscilloscope or logic-analyzer measurements. Board wait costs and oscillator phase need direct comparison. No comparative accuracy ranking against MAME is established. |
| UV201 | Registers, object fetching, FIFO, rendering, modifiers, zoom and freeze capture work across tested software. No current visible discrepancy has been identified. | Highest priority for exhaustive original-machine tests, including access timing, counter phase and edge cases that ordinary software may not expose. |
| UV202 | Clock and bus control, DMA arbitration and native interlaced output work across tested software. | Lower-priority hardware verification of clock/bus timing, field transitions, half-line seams and sync widths. |
| Cartridges and software | All eighteen known cartridges are supported. Coverage extends beyond startup to gameplay, APL/S programs, tape round trips, Timeshare sessions and Information Manager operations. | Information Manager exploration is primarily work to complete its reconstructed manual and identify original-software quirks. It is not tracking a known core defect. |
| Keyboard and joysticks | Keyboard matrix, calibration, four analog sticks, fire buttons and paired controls work well in MiSTer use. Games are fully playable with the current timing model. | Physical pot ranges, pulse widths, trim effects and UV201 freeze-counter phase need measurements. Current presets provide practical travel and centering; exact hardware behavior may be less convenient. |
| Audio | DAC writes, sound-clock latching, filtering and output work. Tempest's Music Teacher 1 recordings confirm sidebands on original hardware, supporting the audible grit as characteristic of the machine. | Exact sideband levels, timing and analog response remain unverified. The receiver and recording path affect comparisons. |
| Expander 1 and tape | Firmware execution, host signaling, digital tape save/load, Timeshare UART and independent printer capture are implemented. Difficult tape and peripheral paths have been exercised. | Detailed guides retain the evidence limits for individual workflows. Analog cassette circuitry, physical printing and Expander 2 acoustic modem behavior are outside the implemented digital interfaces. |

The [cartridge status](CARTRIDGES.md), [joystick notes](JOYSTICK.md), [audio investigation](AUDIO-DIAGNOSTIC.md), and [Expander 1 notes](EXPANDER1.md) describe the boundaries in more detail.

## Software validation

### Money Minder: original cassette data through a complete round trip

Sean Riddle shared a Money Minder cassette save made on an actual VideoBrain. We converted it to VBT and loaded it into Money Minder on the core. Reaching that point exposed bugs unseen in the other software tested; those had to be resolved before the tape could even load.

Once loaded, we changed values and saved the data back to tape. We then restarted the core and loaded the new recording. Sean's original values, including our changes, survived the complete journey.

The original-machine recording supplies an independent starting point. The edited recording was reloaded on MiSTer; playback of that new recording on an original VideoBrain remains untested.

### Pinball and the final color modifier

Pinball initially showed colored object rectangles against a black background where original-machine screenshots showed the whole background changing. The renderer was applying the final modifier only along the object path. The patent's final-output selection logic supported applying it to background pixels too. MAME's renderer did not provide the correct reference for this case.

The correction applies the modifier after object/background selection. Regression comparisons preserved CPU and video-register state and object pixels while correcting the affected background pixels.

### Sound led back to the bus and CPU clock

Music Teacher exposed timing variation that filtering alone could not explain. Controlled tones and CPU-to-DAC programs helped distinguish the output path from normal firmware execution. Captures then directed attention toward interrupt latency, DMA service, and CPU clock stopping and restarting.

Board connection records revealed missing request-latch, WACK sampling, and request-synchronization behavior in the external clock gate. The corrected model passed a circuit-derived edge test. In the recorded full-ROM comparison, DAC period RMS deviation fell from 20.315 to 8.875 us, and the approximately 60 Hz sidebands fell by about 9.5 dB. Those are improvements within the simulation, not measurements of agreement with an original VideoBrain.

The recorded CPU clock-gate audit measured 6..7 lost half-clocks for RAM/cartridge reads against a 7..9 expectation derived from a secondary description. That audit's assertion failed. This remains a hardware measurement question, not an established explanation for an audible defect. See [CPU clock gate](CPU-CLOCK-GATE.md).

Tempest subsequently supplied Music Teacher 1 recordings from an original VideoBrain. Sidebands are present on that hardware too, supporting the remaining audible grit as original-machine behavior. Their presence is no longer evidence of a core defect by itself; exact agreement in sideband strength, timing and analog response remains unverified.

### APL/S and Expander 1 extended the test surface

APL/S testing progressed from startup to entering and executing programs through the keyboard matrix. Arithmetic, graphics, and selected type-in games exercise more of the system than a restored memory image alone.

Expander 1 work added actual execution of its firmware and digital tape transactions. Original-ROM tests cover record framing, checksums, successive records, and playback through a remounted image. MiSTer tests have also confirmed selected converted workspace loads and continued execution. These results support the implemented digital path; they do not establish interoperability with a physical cassette recorder or original Expander. See [APL/S](APL-SOURCE.md) and [tape images](TAPE.md).

## Where MAME contributes

MAME is an important preserved implementation and a practical reference where hardware measurements are missing. The core uses MAME-derived information for cartridge identification and slot layouts, parts of address decoding, and device behavior. The F8 implementation credits assistance from MAME's CPU model; the F3853 implementation explicitly references MAME.

This creates shared assumptions that software compatibility cannot resolve. The F3853 timer now uses the documented feedback shift-register sequence, with all 255 running seeds checked against the Mostek 1978 data book's conversion table (printed p.170). Tests also cover repeat periods, masked pending interrupts, reloads, stopping, and external-interrupt isolation. The initial timer clock follows the two-input-period delay shown in the F3852/F3853 timer block diagram (Figure 6).

The timer input uses CPU PHI periods, including CPU wait gating. [Sean Riddle's board connection workbook and captures](https://www.seanriddle.com/vbinfo.html) connect F3853 U16 pin 2 to F3850 U17 pin 1 and TP4 on the PHI net, and show PHI stopping with XTALY during waits. The core advances the CPU twice per PHI period, so the timer advances on every second accepted CPU enable. A full-core regression checks repeated timer interrupts against the nominal 2 MHz PHI rate. Exact edge phase and timer intervals under board-level contention remain unmeasured. The implemented single-device subset also omits memory addressing and priority daisy chaining.

The timer audit records MiSTer checks and the subsequent PHI connection correction. Its revision-specific results are preserved as evidence; original-machine edge phase and contention timing still need measurement.

## Approximations and conveniences

Joystick presets select linear delay ranges by cartridge to provide useful centering and travel. Preserved notes describe game-dependent physical trim adjustments, but do not establish our numerical settings. These presets are calibrated input behavior, not measured replicas of particular pots.

The audio filter is tuned against available recordings, including their unknown receiver and capture response. Its band limit also provides alias protection. It is not a component-level recreation of the RF sound chain.

Keyboard files supply timed matrix inputs. Tape images preserve digital recording intervals and replay them at the Expander input. Both retain firmware participation while replacing physical input or storage media. Experimental 240p output changes vertical rollover and can affect joystick measurements across that boundary; native interlaced operation is the baseline.

A separate, optional Music Teacher ROM patch reduces display redraw work for live playback. Results obtained with that modified ROM must be identified separately from original-software accuracy checks. The audio timing comparison above uses the unmodified cartridge.

## Remaining accuracy work

Original-machine testing is the principal next step, with UV201 the highest priority and UV202 next. Useful evidence includes:

- Exhaustive UV201 test ROMs covering register access, fetching, modifiers, zoom, counter/freeze behavior and boundary conditions.
- CPU oscillator, request, WACK, and CPU clock traces during buffered reads, writes, and DMA contention, to reconcile total wait costs and restart phase.
- UV202 field transitions, equalization and sync pulses, with a clear counter origin, to resolve the current half-line and pulse-width uncertainties.
- F3853 PHI and timer interrupt traces, including wait gating, reload phase, and interrupt timing.
- Joystick pot ranges and pulse widths at known positions, together with UV201 freeze-counter phase and the effect of trim adjustments.
- Matched audio captures at the DAC and receiver output, with the cartridge, key sequence, and recording path identified.
- Expander cassette and serial signal captures, plus broader application and gameplay comparisons against original machines.

## Documentation and optional future work

The remaining Information Manager pass is intended to complete the [manual](INFOMAN-MANUAL.md): exercise its commands, document supported workflows and distinguish prototype software bugs from hardware behavior. Existing command-specific verification limits remain in the [research notes](INFOMAN.md).

Core quality-of-life features meet the current release goals, including relative analog movement for Tennis with three speed settings. Spinner support and MIDI input for Music Teacher or homebrew are optional future work. A 1080p 5x crop is deferred because native interlacing needs separate handling.

Further [Music Teacher patch](MUSIC-TEACHER-PATCH.md) improvements and a possible musical homebrew exploring the machine's full audible frequency range are software projects, separate from core release requirements.
