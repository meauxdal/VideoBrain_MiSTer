# Joystick measurement notes

See [joystick timing](../docs/JOYSTICK.md) for setup, the Curve mapping and
release verification. Results below are retained simulator measurements unless
marked hardware. Raw runs remain ignored under out/joystick/.

## Measurement and scaling

BIOS stores initial Y+1 at 21D1 and subtracts with COM/INC at 21FC..21FD.
Tennis stores initial Y at 1F0D and uses COM at 1F3B. Both compute:

```text
lines = frozenY - initialY - 1 (modulo 256)
raw = lines*228 + frozenX - 38
```

Tennis rejects lines >= 10; BIOS rejects lines >= 13. BIOS 2250..228D selects
gains 8/6/4/3/2 at spans below 1333/1599/1867/2399/otherwise. Equality advances
to the next gain. Tennis normally returns 70 + 3*(delta >> 5), capped at 214;
byte truncation and wrap limit extrapolation. Tennis seeds bounds 1792/640 at
102D..1035; BIOS seeds 851/831 and expands them.

joystick_gain_check.py enters the original RES2 routine at 225E with seeded
span/delta and a temporary RES1 that bypasses startup. All 19 threshold,
carry, product and clamp cases passed in 4 frames/725579 cycles. It does not
exercise timer/capture, bounds acquisition or gameplay calibration.

## Linear results

| Timer, MCLK ticks | Simulator result | Hardware report |
| --- | --- | --- |
| 2580 + 6*p | Gladiator and Checkers calibrated neutral 96; Tennis 70..103, neutral 88. | Gladiator neutral stationary; analog down-right failed, D-pad passed. |
| 2580 + 7*p | Tennis 70..109, neutral 91. | Gladiator neutral and all eight analog/D-pad directions passed after calibration; Tennis confined to upper arena. |
| 2580 + 18*p | Tennis 70..175, neutral 124; Gladiator neutral saturates at 199. | Gladiator neutral drift and analog up-left failure. Tennis was reported playable at reference revision 7fed834dd7a2b03b83415ef7077224c8aae90edc. |

Step 6 circle runs: Gladiator's four axes and Checkers P1 reach bounds
1022/640; pots 112/128/144 return 84/96/108 with 24 fixed samples per hold.
Checkers P2 is not read; cursor bytes at 0F0C..0F0F are 00 C0 00 00.
Gladiator is near a boundary and Checkers is in the upper-left square, so
these runs do not establish interior stability. Vice Versa shares the BIOS
routine and Checkers's 0x41..0xC0 stationary band; hardware was unverified.

Step 6 Tennis bounds remain 1792/640. Controller isolation and monotonic
travel were checked: pots 0/32/64/96/128/160/192/224/255 return
70/73/79/82/88/91/97/100/103. Position addresses are 0C86/0C8A/0C8E/0C92;
0FA5..0FA8 is auxiliary state.

Step 18 Tennis: 551 frames, pots 112/128/144 return 115/124/130. Bounds stay
1792/640; each hold has 24 fixed samples and 8 returns per channel.
Step 7 Tennis: 551 frames/131678971 cycles, pots 112/128/144 return 88/91/91
with the same sample counts and bounds. Travel covers 39 of 144 units (27%).

Step 18 Gladiator, frame 342: bounds 1787/640 give span 1147 and gain 8.
Neutral delta 576 accumulates to 4608; PC 229F branches to 22AB and 22AD
returns 199. All four channels return 199 at calibrated pot 128 while fighter
coordinates change. Pot 112 also returns 199. Pot 144 and final pot 128 have
no reads, so fixed coordinates there do not establish stability.

## Counter phase

RTL advances X once per 4 MCLK ticks and Y once per 228 X ticks.
Step 18 BIOS: initialY=57, frozenY=63, frozenX=114 gives raw 1216 and delta
576 above lower bound 640. BIOS gain 8 returns 199; Tennis fixed scale gives
124. Step 6 neutral raw 832 gives delta 192, BIOS 96 and Tennis 88.
Step 7 raw 864/delta 224 predicts BIOS 112 and Tennis 91; only Tennis 91
was confirmed by the completed phase run.

Step 7 Tennis frame 281: P1 initialY/frozenY=55/58, P2=101/104. Both freezeX
values are 222: 2*228+222-38=640 at 1F59, giving zero delta and return 70.
Pulses measure 2581 MCLK ticks; paired captures arrive one cycle after expiry.
No arithmetic or capture mismatch was observed.

Retained source readings:

- US4232374A specifies leading-edge VBLANK reset and Y increment per HBLANK
  pulse, but no HBLANK edge or exact dot-counter reset phase (counter 99,
  F8..FB). [Patent](https://patents.google.com/patent/US4232374A/en).
- Board sheets 2 and 4 connect UV202 HBLANK to UV201 and the 555 reset gate;
  they do not expose internal X/Y timing or mechanical pot limits. Local
  refs/seanriddle.com/videobrain2.jpg and videobrain4.jpg.
- Kevtris's sync table uses HBLANK high at 222..227/0..32, while DMA tables
  call HBLANK falling cycle 0. These are distinct cycle origins. Local
  refs/kevtris/videobrain_unwrapped.txt:534..537,1198..1201. His MCLK is
  28.6363 MHz; RTL uses 14.318181 MHz. Both use BRCLK near 3.579 MHz.

RTL Y advances at X rollover, six BRCLK ticks after HBLANK rises at 222.
Away from field reset, moving both origins to h222 gives X'=(h+6)%228 and
Y'=v+[h>=222], hence 228*Y'+X'=228*v+h+6. With unchanged sample times and
initial Y sampled outside h222..227, raw gains 6, not 228. Moving Y alone
adds 228 only over h222..227 and creates a discontinuity. Software waits for
Y to change, so changing phase also changes sample times. This model does
not establish a hardware counter phase or justify a timing change.

## Curve evidence and model limits

joystick_scaling_model.py uses raw=floor(timer/4)-5, pot extrema 0/255,
neutral 128, fixed phase, expanding seeded bounds and unwrapped Tennis scaling.
It omits CPU waits, rejected measurements and acquisition order. Of 60,544
affine pairs giving Tennis neutral 124..154, the lowest modeled BIOS neutral
is 192 at 3348:12. Gladiator's vertical path at 152A..154F moves below 20 or
at/above 180. This result applies only within the model's assumptions.

Curve endpoints give modeled raw 400/1136/2818, span 2418 and gain 2.
Measured Gladiator bounds are 2819/400, one unit above that span.
Frame 342 P2 selects gain 2: delta 736, product 1472, return 92. Both pulses
measure 4565 ticks. The run has 461 frames/110132971 cycles, 24 fixed samples
per settled hold and 3..4 reads per axis. P1 Y=209 is near the lower boundary.

Curve Tennis has 551 frames/131678971 cycles. Lower bounds reach 400, upper
2328; higher inputs use the rejection cap. Sampled circle returns
70/73/88/112/136/196/214 retrace without a sampled reversal. The first lower
bound expansion returns 0 once per player; settled pot 0 returns 70.
Frame 432 has no reads; surrounding returns confirm neutral 139.

Retained runs: cal_glad_circle, cal_checkers_circle, cal_tennis_circle,
analog1, tennis_alan_timing, tennis_step7_phase, gladiator_alan_scaling,
gladiator_shared_curve, tennis_shared_curve and gain_check.

TODO: Measure physical counter phase and pot limits; verify interior stability.
