# Audio diagnostic

Audio remains unresolved. Rounded waveform shape and cycle timing require
separate comparisons with original hardware.
Consistent periods and pulse widths can be checked without an original-machine
recording. That reference is needed to establish the intended analog shape.

`System > Audio Test` selects a 500 Hz, 1 kHz, 2 kHz or 4 kHz square-wave
source ahead of the existing audio filter. It uses no CPU, ROM, keyboard or
interrupt timing. The computer continues running. Off selects normal audio.
This is an isolation test, not a sound correction. Filtering rounds its output.

After building the core, record several seconds at each setting through the
same output used for normal audio. Keep output rate, volume and MiSTer filter
settings fixed. Compare with `verilator/out/audio_path_<frequency>_<rate>.wav`.

- If test tones differ from simulation, investigate FPGA implementation,
  clock crossing, output configuration and capture path.
- If test tones match, capture the core's normal DAC codes and timestamps
  before filtering. This localizes the implementation discrepancy upstream.
- Compare waveform shape with original hardware at the same pitch. Low
  nonharmonic noise alone does not establish faithful sound.

Run the short digital-path check from `verilator`:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tests/check_audio_path.py --run
```

It checks source pulse widths and decodes actual I2S words after the core
filter and MiSTer output modules at independent 14.318181/24.576 MHz clocks.
It tests 500/1000/2000/4000 Hz at 48/96 kHz, with default MiSTer filter
coefficients, unity volume, no boost and no Linux audio.

Verilator 5.032 requires a simulation copy of `audio_out.sv`: five procedural
declaration initializers are removed and initialized with `--x-initial 0`.
No `sys` source is modified. Build diagnostics are in `out/audio_path_build.log`.
The test excludes analog circuitry, HDMI transport, metastability and FPGA
timing failures. It does not validate the original machine's analog response.

Measured on 2026-10-19: all eight cases pass. I2S nonharmonic RMS ranges from
-79.9 to -60.7 dBc; interpolated period spread is below 0.15 us over each
0.25-second capture. These figures describe controlled test inputs only.
The output third harmonic is -15.9 dBc at 1 kHz and -37.8 dBc at 4 kHz,
versus -9.54 dBc for an ideal square wave. The current filters therefore
produce substantial rounding even when timing is regular.

The saved post-fix held-note trace in `out/music_audio_b5/events.csv` has
DAC full periods of 932.241..1106.216 us, around a 1019.264 us median.
Corresponding IRQ full periods span 1017.448..1020.800 us. IRQ-to-ack delay
spans 5.029..93.867 us; ack-to-DAC spans 86.813..89.327 us. This localizes
most reproduced timing variation before acknowledgement, ahead of filtering.
It does not establish which implementation behavior differs from hardware.
