# Joystick verification

## Release status, 20261007

The user confirms the joystick fixes work on MiSTer and identifies Curve
as the fix. The October 7 release preserves VideoBrain_26_20261007.rbf.
Stick timing=Curve is the default; Linear retains 2580 + 7*pot.
The final hardware report does not enumerate the game/controller test matrix.

See [joystick timing](../docs/JOYSTICK.md) for the final mapping, calibration,
reasoning and retained evidence, and [release notes](../releases/VideoBrain_20261007.md)
for the artifact hash and source baseline.

## Retained investigation notes

The entries below record earlier tests and the Curve trial before hardware
confirmation. Their pending tests, next steps and candidate descriptions are
historical; the release status above supersedes them. Raw local runs remain
unchanged. Physical counter phase and pot resistance limits remain unmeasured.

Prioritize stationary neutral in Gladiator, Checkers and Vice Versa.
Hardware trial defaults to Curve; OSD Stick timing=Linear selects2580:7.
Simulator defaults remain2580:7; --curve selects the RTL curve.
Gladiator hardware at2580:7 is confirmed
stationary after full-extreme circle calibration, with all eight analog and
D-pad directions working. Preserve this milestone.
At2580:6, retained Gladiator and Checkers circle runs return60 at neutral.
Vice Versa uses the same BIOS routine and
has the same41..C0 stationary band as Checkers; hardware behavior is unverified.
Tennis hardware at step7 is confined to roughly the top half or top third of
the arena and cannot reach the lower area; early calibration attempts did not
help. The user reports Tennis good at Alan's step18 timing. Investigate the
shared timing conflict while preserving Gladiator's step7 success.

## Current evidence

- Gladiator circle: all four axes reach 03FE/0280, matching endpoint tests.
  Pots 112/128/144 return 54/60/6C, with 24 fixed coordinate samples per hold.
  One fighter is near a boundary. This supports sampled stationary inputs,
  not a complete region map or hardware fidelity.
- Checkers circle: P1 axes reach 03FE/0280. P2 is not read. Pots 112/128/144
  return 54/60/6C with 24 fixed cursor samples per hold. Cursor state is
  00 C0 00 00 at 0F0C..0F0F. The small black notch is in the upper-left board
  square. Interior board stability remains unconfirmed.
- Tennis circle: bounds stay 0700/0280; both vertical channels span 70..103,
  neutral 88. Full-circle input does not improve step6 travel. Pots
  112/128/144 return 55/58/58, with 24 fixed position samples per hold.
  These are absolute position holds, not directional neutral-region tests.
- Tennis analog1: controller isolation and monotonic travel are confirmed.
  Pots 0/32/64/96/128/160/192/224/255 map to 46/49/4F/52/58/5B/61/64/67.
  Position addresses are 0C86/0C8A/0C8E/0C92; 0FA5..0FA8 is auxiliary state.

The Gladiator manual requires fully forward, then a full circle at first-game
start. Slightly off-center aiming can remain stationary. The 50..70 scoring
band was only a search preference. Startup drift alone does not reject timing.
Calibrate each independent game test. Keep the raw completed runs unchanged.

## Alan reference comparison

Reference commit: 7fed834dd7a2b03b83415ef7077224c8aae90edc.
The user reports Tennis was relatively close to centered and playable there,
although imperfect. Treat that as a closer reference, not a validated default.

Alan's timer uses 2580 + pot * 18; recent circle tests explicitly used step6.
At pots 0/128/255, configured delays are 2580/4884/7170 for step18 versus
2580/3348/4110 for step6. The pot-dependent span is three times larger at18.
The step18 comparison uses Alan's numerical timing.

Later changes pair X/Y at the falling joystick line and use a registered
capture strobe. CPU clock generation also changed from the integer MCLK/7
schedule to a fractional 2MHz schedule. Input axis ordering, EJOY polarity,
and timer start condition match Alan's code. CPU arithmetic was not changed.
Do not attribute a regression to those differences without a comparison.

One focused current-core Tennis run at Alan's timing:

```sh
# WSL, /mnt/c/Workspace/Git/VideoBrain_MiSTer/verilator
python3 joystick_calibration_check.py tennis --base 2580 --step 18 --out out/joystick/tennis_alan_timing
```

This is 550 frames: startup, forward/full circle, then stationary input holds.
Compare raw extrema, both player positions, neutral and travel against step6.
It matches Alan's timer constants, not his entire implementation.

The completed run has 551 frames and all planned samples. Both vertical
channels span 70..175 (46..AF), neutral 124 (7C), versus 70..103 and neutral88
at step6. Bounds remain 0700/0280. Pots112/128/144 yield115/124/130
(73/7C/82); every measured hold has24 fixed position samples and8 returns
per channel. Both return124 on the final128 hold. Startup moves from138 to124.

This restores substantially wider travel and brings neutral14 units from the
initialized138, versus50 at step6. It supports the user's closer Alan reference
but does not establish exact centering or full travel to Tennis's D6 cap.
Retained Gladiator2580:18 endpoint tests still returnC7 at neutral and drift;
no shared-game pass is established. Do not change CPU/capture RTL from this
Tennis result alone.

## Neutral-stability build

The confirmed Linear baseline uses2580:7. Preserve paired capture and CPU clock
changes. From the repository root
with Quartus on PATH:

```sh
quartus_sh --flow compile VideoBrain
```

The project and revision are both VideoBrain. The user runs the build.
Check centered analog inputs in Gladiator and interior cursor stability in
Checkers and Vice Versa. Check analog and D-pad cardinal/diagonal movement
on both controllers. Calibrate once per game; do not restart during holds.

## Source and trace checks

BIOS 2250..228D chooses gains 8/6/4/3/2 at spans below
1333/1599/1867/2399/otherwise; equality advances to the next gain.
All gains pass the isolated diagnostic below; only gain8 has gameplay traces.
Checkers399: span017E, delta00C0,
product0600, return60. Correlate adjacent fetch records when reading operands.

Tennis uses fixed scaling rather than span-selected gain. In its normal path,
70 + 3*(delta >> 5) is capped at214. Byte truncation/wrap limits extrapolation.
At step6, center raw0340 minus lower0280 gives00C0 and position88.
The offline timing search was approximate and does not establish a CPU defect.

MiSTer signed axes XOR80; deadband -8..8 maps to128. Vertical is the high
analog byte; channel order is V1,H1,V2,H2,V3,H3,V4,H4. Digital overrides give
0/255. Simulator pot overrides bypass host analog reports and wrapper deadband.

TODO: Verify physical counter phase and Checkers interior stability.

## Shared measurement and unresolved circuit phase

BIOS stores initial Y+1 at21D1; Tennis stores initial Y at1F0D.
BIOS subtracts with COM/INC at21FC..21FD; Tennis uses COM at1F3B.
Both therefore count frozenY-initialY-1 lines (modulo256), then compute
raw = lines*228 + frozenX -38. Tennis rejects lines>=10; BIOS rejects
lines>=13. The two paths use the same X/Y units in their normal range.

RTL advances X once per4 MCLK ticks and Y once per228 X ticks. In the
retained step18 BIOS trace, initialY=57, frozenY=63, frozenX=114:
5*228+114-38=1216. Lower0280 leaves delta576. BIOS gain8 returns199;
Tennis's fixed scale returns124. Step6 neutral raw832 leaves delta192,
giving BIOS96 and Tennis88. Step7 predicts raw864, delta224, BIOS112
and Tennis91 if the same start phase and lower bound persist. The completed
Tennis run below confirms91; raw864/delta224 and BIOS112 remain predictions.

Corrected gain thresholds do not change the retained step18 case: its
span1147 is still below1333. Tennis needs delta1536 to first reach214
in the normal, unwrapped path. Thus increasing travel must also change
BIOS gain selection or the neutral delta; neither follows from a unit
conversion. Tennis's0700/0280 are startup bounds at102D..1035, not
measured physical endpoints. BIOS starts0353/033F and expands its bounds.

US4232374A specifies leading-edge VBLANK reset, but only says current Y
increments with each HBLANK pulse (FB). It does not identify that pulse's
edge. The dot counter receives horizontal-retrace reset (counter99), without
an exact reset phase or frozen-X origin. A leading-edge HBLANK Y increment
is therefore an assumption, not established patent evidence.
RTL increments Y at X rollover, six BRCLK ticks after HBLANK rises at222.
Retained Tennis pot0 samples freezeX=222. Sheet2 connects UV202 HBLANK to
UV201; sheet4 uses HBLANK in the555 reset gate. Neither exposes internal
X/Y counter timing or joystick mechanical resistance limits.
Sources: refs/seanriddle.com/videobrain2.jpg and videobrain4.jpg;
https://patents.google.com/patent/US4232374A/en (counter99, F8..FB).

Kevtris's measured sync table uses HBLANK high at222..227 and0..32;
his DMA tables instead call HBLANK falling cycle0 (lines534..537,
1198..1201 in refs/kevtris/videobrain_unwrapped.txt). Those are different
cycle origins, not measurements of the freeze counter. His MCLK is
28.6363MHz; RTL MCLK is14.318181MHz. Both describe BRCLK3.579MHz.

Model only, away from field reset: moving both counter origins to h222
gives X'=(h+6)%228 and Y'=v+[h>=222]. Then228*Y'+X'=228*v+h+6,
continuous across both h222 and rollover. With initial Y sampled outside
h222..227 and the same sample times, the raw formula gains6, not228;
pot0 raw640 would become646. Moving Y alone adds228 only over h222..227
and creates a discontinuity. Software waits for Y to change, so an actual
phase change also alters sampling/enable times; this mapping is not a run
prediction. Physical X origin and Y edge remain unverified. No RTL change
or new simulation is justified by these sources.

One unchanged-timing run, focused on the forward hold at frame281:

```sh
# WSL, /mnt/c/Workspace/Git/VideoBrain_MiSTer/verilator
python3 joystick_calibration_check.py tennis --base 2580 --step 7 --focus 281 --out out/joystick/tennis_step7_phase
```

Check initial Y, timer release/expiry h/v, freeze X/Y, raw, lower bound
and returned position. Compare with step18's pot0 freezeX222 and raw640.
The whole run also checks step7 neutral/travel; no restart or timing sweep.

Completed551 frames in131678971 cycles, with all planned state samples.
Both vertical positions span70..109; neutral91 confirms the prediction.
Pots112/128/144 return88/91/91. Each settled hold has24 fixed position
samples and8 returns per channel. Bounds stay0700/0280 through calibration.
Travel covers39 of the144 position units between70 and214 (27%).

Frame281: P1 initialY55, frozenY58; P2 initialY101, frozenY104.
Both freezeX222 and calculate2*228+222-38=640 at1F59. Subtracting
lower640 gives zero delta and return70. Each timer pulse measures2581
MCLK ticks, matching the programmed2580 plus expiry tick. Both paired
captures are accepted one cycle after expiry. No arithmetic or capture
mismatch is shown. Physical counter phase remains unresolved; this run
does not justify changing CPU/capture RTL or2580:7.

## Shared scaling model

joystick_scaling_model.py uses raw=floor(timer/4)-5, which fits retained
base2580 measurements. It assumes pot0/255 extrema, neutral128, fixed
measurement phase, expanding seeded bounds, and unwrapped Tennis scaling.
It does not model CPU waits, rejected measurements or acquisition order.

| Timer | Span | Gain | BIOS neutral | Tennis neutral |
| --- | --- | --- | --- | --- |
| 2580:7 | 446 | 8 | 112 | 91 |
| 2580:18 | 1147 | 8 | 199 | 124 |
| 2580:23 | 1466 | 6 | 199 | 139 |
| 2580:30 | 1912 | 3 | 180 | 160 |
| 2580:38 | 2422 | 2 | 152 | 184 |

For positive integer slopes and nonnegative modeled raw endpoints within
the14-bit timer range,60544 affine pairs give Tennis124..154. Minimum BIOS
neutral is192 at3348:12 (Tennis124). Gladiator's vertical path at152A..154F
moves below20 or at/above180. Thus this affine model gives no stationary
vertical neutral near Tennis center. This does not prove the full RTL domain
impossible: phase, rejection and byte-wrap behavior are outside the model.

A shared curved mapping can satisfy both arithmetic targets. Model candidate:
timer=1620+23*pot for pot<=128; above128, timer=4564+53*(pot-128).
At pots0/128/255, timers1620/4564/11295 give raw400/1136/2818.
Both lower bounds expand to400; BIOS span2418 selects gain2. Delta736 gives
BIOS92 and Tennis139. The upper measurement is within the BIOS normal raw
range; Tennis's line rejection can supply its214 cap. Actual acquisition,
travel monotonicity and all-direction stability need one focused simulation.
This curve is an intentional shared mapping, not evidence of physical pot
linearity or neutral. The headless simulator accepts --joy-timer-curve;
pot telemetry is retained. The trial build selects this same RTL curve.
Prepared full-circle runs focus on settled neutral (Gladiator342, Tennis432):

```sh
# WSL, /mnt/c/Workspace/Git/VideoBrain_MiSTer/verilator
python3 joystick_calibration_check.py gladiator --curve --focus 342 --out out/joystick/gladiator_shared_curve
python3 joystick_calibration_check.py tennis --curve --focus 432 --out out/joystick/tennis_shared_curve
```

Each command builds headless, runs one game, and writes summary.json.
Check expanded lower bounds, BIOS gain2/neutral92, Tennis neutral139,
calibrated fixed holds, and full-circle travel.

Completed curve runs: Gladiator461 frames/110132971 cycles;
Tennis551 frames/131678971 cycles. All planned state samples are present.
Gladiator bounds reach0B03/0190 on all four axes: span0973 (2419),
one above the scalar model. Frame342 P2 traces select gain2, delta02E0 (736),
product05C0 (1472), return5C (92). Both pulses measure4565 MCLK ticks.
All axes return92 at calibrated128 and final128; pots112/144 return80/118.
Each settled hold has24 fixed coordinate samples and3..4 reads per axis.
Both fighters are away from horizontal boundaries in the settled screenshot;
P1 Y209 is near the lower boundary, so vertical stability alone is weaker.

Tennis both vertical positions span70..214, neutral139 (initialized138).
Lower bounds reach0190 (400), upper0918 (2328); higher pots use the rejection
cap instead of extending the upper bound. Sampled circle returns rise
70/73/88/112/136/196/214 and retrace without a sampled reversal.
Pots112/128/144 return130/139/157; each settled hold has24 fixed position
samples and8 reads per player. First low-bound expansion returns0 once per
player; the settled pot0 position is70. Frame432 has no joystick reads;
Tennis's predicted neutral is confirmed by surrounding returns, not a focused
arithmetic trace. Interior screenshot positions agree with139.

The shared curve meets sampled neutral/travel goals. It is a hardware candidate,
not an all-direction hardware pass. The trial build adds the same curve to the
core and retains2580:7 under OSD Stick timing=Linear. Headless --curve now uses
the RTL selector. Test Curve with full calibration, cardinal/diagonal reach,
interior neutral holds and Tennis travel; Linear remains the confirmed baseline.
GHDL synthesis and Verilator lint complete; headless C++ syntax passes against
regenerated headers. Quartus build and hardware verification remain pending.

## MiSTer result at2580:18

Gladiator with analog sticks: user reports down-right drift with a centered
stick after calibration. Connected, uncalibrated player2 immediately drifts
down-right, as in nearly every tested build. Analog up-left cannot be activated;
other directions require fighting the drift. This setting fails hardware
movement and neutral checks.
2580:18 fails neutral checks. Step6 is selected from both Gladiator and Checkers
evidence under the user's revised priorities. Wrapper mapping and digital
overrides match Alan's reference.
Retained2580:18 endpoint traces returnC7 at neutral on all four channels,
but pot0 returns00 for UP and LEFT. Hardware D-pad reports: UP moves up-right,
UP+LEFT moves up-left, LEFT moves down-left. Only diagonal movement observed.
Digital up-left is reachable; these responses agree with the wrapper mapping.
Neutral drift on the other axis can explain diagonal movement from one direction.
Check actual analog range before another timing change.

## Focused Gladiator scaling check

Retained step18 endpoint bounds06FB/0280 give span047B (1147), below the
gain8 threshold0535 (1333). Applying gain8 to neutral predicts saturation;
gain selection and arithmetic at step18 still need runtime confirmation.
Run one full-circle calibration with centered-frame BIOS tracing, no restart:

```sh
# WSL, /mnt/c/Workspace/Git/VideoBrain_MiSTer/verilator
python3 joystick_calibration_check.py gladiator --base 2580 --step 18 --focus 342 --out out/joystick/gladiator_alan_scaling
```

Frame342 is in the settled centered hold. Check span, selected gain, raw delta,
product, and clamp path against adjacent records. This is diagnostic only;
do not change timer, CPU, or capture RTL from the prediction.

Completed461 frames. Frame342 confirms both P2 channels select gain8:
span047B minus0535 givesFF46; delta0240 (576) accumulates eight times to1200
(4608). PC229F branches to22AB because product>>12 is nonzero;22AD returnsC7.
The unclamped scaled value would be288, beyond199. No arithmetic mismatch is
shown in this path. All four channels returnC7 in the calibrated128 hold,
with bounds06FB/0280 and24/24 state samples. Fighter coordinates still change.
Region112 also returnsC7. Region144 and final128 have no joystick returns;
fixed coordinates there do not establish stability. This confirms neutral
saturation at2580:18 after full calibration.

## Isolated BIOS arithmetic check

```sh
# WSL, /mnt/c/Workspace/Git/VideoBrain_MiSTer/verilator; existing headless binary
python3 joystick_gain_check.py --run
```

All19 cases pass; run completes4 frames in725579 cycles. Coverage: each
threshold below/at/above, byte carry,
zero delta, and both clamp paths. The test cartridge seeds span/delta and enters
the original RES2 routine at225E. A temporary RES1 copy bypasses game startup;
stack helpers remain intact. No RTL or production ROM changes. The test checks
add-loop count, final16-bit product, returned byte, and completion marker.
It does not exercise timer/capture, bounds acquisition, or gameplay calibration.

Correct thresholds are0535/063F/074B/095F (1333/1599/1867/2399).
The previous offline model used1883/2415 for the last two thresholds; its
no-pair result needs re-evaluation. Step18 gain8 saturation remains confirmed.
Relevant F8 COM/LNK/CI and branch semantics match the programming guide:
https://bitsavers.computerhistory.org/components/fairchild/f8/67095664_F8_Guide_To_Programming_1976.pdf

Next: explain Tennis's compressed step7 travel from measurement units, bounds,
and fixed scaling while preserving calibrated Gladiator behavior. Checkers
and Vice Versa hardware interior stability at step7 remain unverified.

## Gladiator hardware at2580:6

User confirms full-extreme circle calibration gives stationary analog neutral.
All D-pad directions work after calibration. Analog directions work except
down-right. Uncalibrated top-left drift is not the acceptance criterion.

At2580:7, the user confirms flawless Gladiator control after a full-extreme
circle: stationary neutral and all eight analog directions. All D-pad directions
also work. Tennis hardware remains confined to the upper arena. BIOS scales
directional input with selected gain; Tennis uses fixed absolute scaling. This
explains the sensitivity conflict but does not establish a shared-circuit fix.
