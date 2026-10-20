"""Measure nonharmonic content before and after the actual MiSTer I2S path."""
from pathlib import Path
import re
import subprocess
import sys
import wave

import numpy as np


def analyze(path, frequency, rate):
    data = np.fromfile(path, dtype="<i2").reshape(-1, 3).astype(float)
    assert len(data) == rate // 4
    hz = np.fft.rfftfreq(len(data), 1 / rate)
    print("stage,fundamental_hz,nonharmonic_rms_dbc,largest_nonharmonic_dbc,"
          "period_spread_us,high_width_spread_us,h3_dbc,h5_dbc")
    for column, name in enumerate(("core", "i2s_left", "i2s_right")):
        samples = data[:, column] - data[:, column].mean()
        power = abs(np.fft.rfft(samples * np.hanning(len(samples)))) ** 2
        fundamental = abs(hz - frequency) <= 12
        noise = hz > 20
        for harmonic in range(frequency, rate // 2 + 1, frequency):
            noise &= abs(hz - harmonic) > 16
        reference = power[fundamental].sum()
        assert reference > 1e6, "Missing tone"
        rms = 10 * np.log10(power[noise].sum() / reference)
        spur = 10 * np.log10(power[noise].max() / power[fundamental].max())
        peak = hz[fundamental][np.argmax(power[fundamental])]
        indices = np.flatnonzero((samples[:-1] < 0) & (samples[1:] >= 0))
        crossings = indices - samples[indices] / (samples[indices + 1] - samples[indices])
        spread = np.ptp(np.diff(crossings)) / rate * 1e6
        indices = np.flatnonzero((samples[:-1] >= 0) & (samples[1:] < 0))
        falling = indices - samples[indices] / (samples[indices + 1] - samples[indices])
        rising = crossings[crossings < falling[-1]]
        widths = falling[np.searchsorted(falling, rising)] - rising
        width_spread = np.ptp(widths) / rate * 1e6
        harmonics = [10 * np.log10(power[abs(hz - h * frequency) <= 12].sum() / reference)
                     for h in (3, 5)]
        print(f"{name},{peak:.1f},{rms:.2f},{spur:.2f},{spread:.3f},"
              f"{width_spread:.3f},{harmonics[0]:.2f},{harmonics[1]:.2f}")
        assert rms < -50, f"{name}: excessive nonharmonic content"
        assert spur < -55, f"{name}: excessive nonharmonic component"
        assert spread < 1, f"{name}: irregular output periods"
        assert width_spread < 1, f"{name}: irregular output pulse widths"
    with wave.open(str(Path(path).with_suffix(".wav")), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(data[:, 1:].astype("<i2").tobytes())


def run():
    root = Path(__file__).resolve().parents[1]
    output = root / "out"
    output.mkdir(exist_ok=True)
    source = (root.parent / "sys/audio_out.sv").read_text()
    # Verilator 5.032 repeats these procedural initializers each clock.
    # Represent their initial zero with --x-initial 0 in a simulation copy.
    source, count = re.subn(r"(?m)^(\treg\s+\[[^\n;]+\]\s+\w+)\s*=\s*0;", r"\1;", source)
    assert count == 5, "Recheck upstream procedural initializers"
    (output / "audio_out_sim.sv").write_text(source)
    command = [
        "verilator", "-cc", "--exe", "--build", "-j", "2", "--x-initial", "0", "-Wno-fatal",
        "--top-module", "tb_audio_path", "--Mdir", "out/obj_audio_path",
        "tests/tb_audio_path.sv", "../rtl/videobrain_audio.sv", "out/audio_out_sim.sv",
        "../sys/iir_filter.v", "../sys/i2s.v", "../sys/spdif.v", "../sys/sigma_delta_dac.v",
        str(root / "tests/tb_audio_path.cpp"),
    ]
    with (output / "audio_path_build.log").open("w") as log:
        subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, check=True)
    for rate in (48000, 96000):
        for frequency in (500, 1000, 2000, 4000, 8000):
            path = output / f"audio_path_{frequency}_{rate}.bin"
            subprocess.run([str(output / "obj_audio_path/Vtb_audio_path"),
                            str(frequency), str(rate), str(path)], check=True)
            analyze(path, frequency, rate)


if __name__ == "__main__":
    if sys.argv[1:] == ["--run"]:
        run()
    else:
        path, frequency, rate = sys.argv[1:]
        analyze(path, int(frequency), int(rate))
