# Accuracy report

Working draft, October 19, 2026. Describes source revision
`a3510278f226c33dc22b07dcbe1acc32cb8148c9`, rather than a particular released RBF.

## What this core represents

The aim is to recreate the VideoBrain's hardware behavior as faithfully as
the available evidence allows. The implementation includes the Fairchild F8
processor, UV201 video system, UV202 clock and bus control, memory and
cartridge interfaces, keyboard, joystick timing, sound output, and preliminary
Expander 1 support.

These parts operate together. The processor executes the original firmware;
video fetches compete for bus access; clock stops affect instruction progress;
interrupt handling affects sound and input. Reaching a working application
requires a substantial part of that environment to behave coherently.
Successful software execution is meaningful evidence of the reconstruction,
although it cannot establish that every cycle matches an original machine.

We have never had access to an original VideoBrain. Our evidence consists of
preserved documentation, reverse engineering, board connection records,
original software and cassette data, photographs, screenshots, and videos,
together with MAME and our own implementation tests. Tests on MiSTer establish
behavior of this core. They are not direct measurements of an original VideoBrain.

One of the strongest results is a complete Money Minder cassette round trip
using an original VideoBrain save shared by Sean Riddle. After conversion to
a tape image, the core loaded the data, accepted changes, saved it again, and
recovered the original values with our changes after a core restart.

The core is a working hardware reconstruction with specific unresolved
accuracy questions. We do not currently claim complete cycle accuracy or
electrical equivalence to the original machine.

## Evidence and confidence

Different checks answer different questions:

- Circuit records, component documentation, patents, and reverse-engineering
  notes explain how the machine is believed to work. Some records conflict
  or leave details unspecified.
- Original-machine images and recordings provide visible or audible comparison
  points. Their capture paths limit conclusions about exact timing, color,
  and analog response.
- Original-machine cassette data provides an independent compatibility check
  through the software and tape interface. Money Minder has completed a load,
  edit, save, restart, and reload cycle using such data.
- Simulation checks instruction timing, bus transactions, signal sequencing,
  and regressions against explicit expectations. A passing test supports those
  expectations; it does not independently prove the hardware model.
- MiSTer testing checks the implemented machine in use, including software,
  controls, and the output path. Coverage varies by application and feature.

The main references are Kevtris's *VideoBrain Unwrapped*, Sean Riddle's
preserved hardware material, VideoBrain patents and manuals, processor
documentation, and MAME. The [project source list](../README.md#sources)
provides starting points. The notes linked below preserve more specific
evidence and test limits.

## Current implementation

| Area | What is implemented and supported | Remaining limits |
| --- | --- | --- |
| CPU and bus | F8 execution and ROMC bus cycles, memory decoding, buffered accesses, CPU clock gating, video DMA arbitration, and interrupts. Focused tests cover instruction timing and several interrupt and contention paths. | Documented wait costs are not fully reconciled. CPU oscillator edges are quantized to the FPGA master clock. Comprehensive original-machine timing comparison is unavailable. |
| Video | UV201 registers, object fetching, FIFO, rendering, modifiers, zoom, blanking, and alternating 262/263-line fields. | Composite sync uses a whole-line approximation; exact half-line seams and some sync widths remain unresolved. Original analog color and composite output have not been comprehensively characterized. |
| Cartridges and software | All eighteen documented cartridges reach their expected first screen. Cartridge banking and RAM arrangements are implemented, with focused mapper tests. Tennis has gameplay coverage; APL/S has source-entry and execution checks beyond startup. Money Minder has loaded, edited, saved, and reloaded original-machine cassette data across a core restart. | First-screen coverage is not full application coverage. Broader financial functions, longer programs, gameplay, and peripheral use need further testing. |
| Keyboard and joysticks | Keyboard matrix input, four joystick channels with two axes each, fire buttons, timer-driven interrupts, and paired X/Y freeze capture. | Joystick delay ranges are calibrated approximations. Physical pot limits and UV201 counter phase remain unmeasured. |
| Audio | Firmware-generated DAC writes, sound-clock latching, filtering, and MiSTer output. Controlled CPU-to-DAC and digital output tests provide useful timing checks. | High-note grit and periodic timing modulation remain under investigation. Filtering is an effective recording-based approximation; original analog response and phase are not established. |
| Expander 1 and tape | Separate 3870 firmware execution, host signaling, timer and interrupt support, and digital tape recording/playback through SD images. Timeshare supports interactive Telehack sessions through MiSTer's HPS UART and a Linux Telnet bridge at 300 baud, including pagination, Zork's opening screen, weather, and date output. | Analog cassette circuitry, physical printer behavior, and some parallel/external interrupt wiring remain unimplemented or unverified. Expander 2 acoustic modem behavior is unsupported; Linux console login and live 110-baud operation are unverified. |

The [cartridge status](CARTRIDGES.md), [joystick notes](JOYSTICK.md),
[audio investigation](AUDIO-DIAGNOSTIC.md), and [Expander 1 notes](EXPANDER1.md)
describe the boundaries in more detail.

## What using the machine has taught us

Working software has repeatedly exposed behavior that a startup screen or
isolated component test would miss. Each correction gives us access to more
of the machine, which creates further opportunities to test the model.

### Money Minder: original cassette data through a complete round trip

Sean Riddle shared a Money Minder cassette save made on an actual VideoBrain.
We converted it to VBT and loaded it into Money Minder on the core. Reaching
that point exposed bugs unseen in the other software tested; those had to be
resolved before the tape could even load.

Once loaded, we changed values and saved the data back to tape. We then
restarted the core and loaded the new recording. Sean's original values,
including our changes, survived the complete journey.

This is one of the core's most significant validation results. It exercises
Money Minder, its cartridge memory, the Expander interface, and cassette
loading and saving together, beginning with data from an original machine.
Recovery after restarting establishes persistence through the saved tape
image, beyond retaining values in a running session. It also demonstrates
how preserved user data can expose gaps that other software has not reached.

The original-machine recording supplies an independent starting point. The
edited recording was reloaded on MiSTer; playback of that new recording on
an original VideoBrain remains untested.

### Pinball and the final color modifier

Pinball initially showed colored object rectangles against a black background
where original-machine screenshots showed the whole background changing.
The renderer was applying the final modifier only along the object path.
The patent's final-output selection logic supported applying it to background
pixels too. MAME's renderer did not provide the correct reference for this case.

The correction applies the modifier after object/background selection.
Regression comparisons preserved CPU and video-register state and object
pixels while correcting the affected background pixels. This is a concrete
example of evidence supporting a reconstruction beyond agreement with MAME.

### Sound led back to the bus and CPU clock

Music Teacher exposed timing variation that filtering alone could not explain.
Controlled tones and CPU-to-DAC programs helped distinguish the output path
from normal firmware execution. Captures then directed attention toward
interrupt latency, DMA service, and CPU clock stopping and restarting.

Board connection records revealed missing request-latch, WACK sampling, and
request-synchronization behavior in the external clock gate. The corrected
model passed a circuit-derived edge test. In the recorded full-ROM comparison,
DAC period RMS deviation fell from 20.315 to 8.875 us, and the approximately
60 Hz sidebands fell by about 9.5 dB. Those are improvements within the
simulation, not measurements of agreement with an original VideoBrain.

An important discrepancy remains: RAM/cartridge reads currently lose 6..7 CPU
half-clocks in the tested conditions, below the documented expectation of
7..9 used by the regression. That assertion still fails. The evidence supports
the sequencing correction without establishing that the entire wait model
is correct. See [CPU clock gate](CPU-CLOCK-GATE.md).

### APL/S and Expander 1 extended the test surface

APL/S testing progressed from startup to entering and executing programs
through the keyboard matrix. Arithmetic, graphics, and selected type-in games
exercise more of the system than a restored memory image alone.

Expander 1 work added actual execution of its firmware and digital tape
transactions. Original-ROM tests cover record framing, checksums, successive
records, and playback through a remounted image. MiSTer tests have also
confirmed selected converted workspace loads and continued execution.
These results support the implemented digital path; they do not establish
interoperability with a physical cassette recorder or original Expander.
See [APL/S](APL-SOURCE.md) and [tape images](TAPE.md).

## Where MAME contributes

MAME is an important preserved implementation and a practical reference where
hardware measurements are missing. The core uses MAME-derived information for
cartridge identification and slot layouts, parts of address decoding, and
device behavior. The F8 implementation credits assistance from MAME's CPU
model; the F3853 implementation explicitly references MAME.

This creates shared assumptions that software compatibility cannot resolve.
In particular, the current F3853 timer is an eight-bit down-counter with a
prescale driven by BRCLK enables. Its sequence, clock source, and equivalence
to the original device remain unverified. The implemented single-device subset
also omits memory addressing and priority daisy chaining.

Agreement with MAME is useful corroboration, especially for software and
memory layouts. Where stronger hardware evidence disagrees, that evidence
guides the core. Pinball demonstrates why the distinction matters.

## Approximations and conveniences

Joystick presets select linear delay ranges by cartridge to provide useful
centering and travel. Preserved notes describe game-dependent physical trim
adjustments, but do not establish our numerical settings. These presets
are calibrated input behavior, not measured replicas of particular pots.

The audio filter is tuned against available recordings, including their
unknown receiver and capture response. Its band limit also provides alias
protection. It is not a component-level recreation of the RF sound chain.

Keyboard files supply timed matrix inputs. Tape images preserve digital
recording intervals and replay them at the Expander input. Both retain
firmware participation while replacing physical input or storage media.
Experimental 240p output changes vertical rollover and can affect joystick
measurements across that boundary; native interlaced operation is the baseline.

A separate, optional Music Teacher ROM patch reduces display redraw work for
live playback. Results obtained with that modified ROM must be identified
separately from original-software accuracy checks. The audio timing comparison
above uses the unmodified cartridge.

## Most useful future evidence

Original-machine measurements would be especially valuable for:

- CPU oscillator, request, WACK, and CPU clock traces during buffered reads,
  writes, and DMA contention, to reconcile total wait costs and restart phase.
- UV202 field transitions, equalization and sync pulses, with a clear counter
  origin, to resolve the current half-line and pulse-width uncertainties.
- F3853 timer behavior, including clock source, prescale, sequence, reload,
  and interrupt timing.
- Joystick pot ranges and pulse widths at known positions, together with
  UV201 freeze-counter phase and the effect of trim adjustments.
- Matched audio captures at the DAC and receiver output, with the cartridge,
  key sequence, and recording path identified.
- Expander cassette and serial signal captures, plus broader application and
  gameplay comparisons against original machines.

Access may remain limited. Continued software testing, source comparison,
and targeted regressions can still improve the reconstruction. Keeping each
claim tied to its evidence makes new observations useful, whether they confirm
the model or reveal its next correction.
