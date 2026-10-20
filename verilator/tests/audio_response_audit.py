"""Audit the saved Happy Birthday recordings and the core filter response."""
from pathlib import Path
import re
import subprocess

import numpy as np

from audio_filter_design import coefficients


ROOT = Path(__file__).resolve().parents[2]
MCLK = 14318181
RATE = 48000
HARMONICS = np.arange(1, 22, 2)


def recording(name):
    path = ROOT / "refs/happy-birthday-audio" / f"{name}-happy-birthday.ogg"
    result = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f64le",
         "-acodec", "pcm_f64le", "-ac", "1", "-ar", str(RATE), "pipe:1"],
        check=True, capture_output=True)
    return np.frombuffer(result.stdout, dtype="<f8")


def tone(samples, start, duration, guess):
    x = samples[round(start * RATE):round((start + duration) * RATE)].copy()
    x -= x.mean()
    window = np.hanning(len(x))
    t = np.arange(len(x)) / RATE
    frequencies = np.linspace(guess - 1, guess + 1, 401)
    strength = [abs(np.sum(x * window * np.exp(-2j * np.pi * f * t)))
                for f in frequencies]
    f0 = frequencies[np.argmax(strength)]
    spectrum = np.array([np.sum(x * window * np.exp(-2j * np.pi * f0 * h * t))
                         for h in HARMONICS])
    db = 20 * np.log10(abs(spectrum / spectrum[0]))
    return f0, db, x, t


def poles(frequencies, shifts):
    z = np.exp(-2j * np.pi * frequencies / MCLK)
    response = np.ones(len(frequencies), dtype=complex)
    for shift in shifts:
        alpha = 2.0 ** -shift
        response *= alpha / (1 - (1 - alpha) * z)
    return response


def relative_db(response):
    return 20 * np.log10(abs(response / response[0]))


def fir_response(frequencies, taps):
    phase = np.exp(-2j * np.pi * frequencies[:, None] *
                   np.arange(len(taps)) / (MCLK / 128))
    return phase @ taps / taps.sum()


def main():
    source = (ROOT / "rtl/videobrain_audio.sv").read_text()
    analog = tuple(map(int, re.findall(r"\bdelta\d >>> (\d+)", source)))
    recon = tuple(map(int, re.findall(r"recon_delta\d \+ 26'sd64\) >>> (\d+)", source)))
    assert analog == (10, 9, 8, 8) and recon == (7, 7, 7, 7), "Recheck core stages"
    taps = coefficients()
    output = ROOT / "verilator/out/audio_response_audit"
    output.mkdir(parents=True, exist_ok=True)
    recordings = {name: recording(name) for name in ("hardware", "mister")}
    lines = ["C5: 0.080..0.250 s after measured note onset.",
             "Measured harmonics: hardware_harmonics.csv, mister_harmonics.csv."]
    for name, samples in recordings.items():
        onset, guess = (7.060, 524.471) if name == "hardware" else (7.035, 523.334)
        f0, db, _, _ = tone(samples, onset + .08, .17, guess)
        np.savetxt(output / f"{name}_harmonics.csv",
                   np.column_stack((HARMONICS, HARMONICS * f0, db)),
                   delimiter=",", header="harmonic,frequency_hz,dbc",
                   comments="", fmt="%.4f")

    f = HARMONICS * 524.471
    lines += ["", "Core stages: relative loss from C5 fundamental (dB).",
              "harmonic,hz,first_two_poles,extra_two_poles,reconstruction,hold,fir,net"]
    stages = [relative_db(poles(f, shifts))
              for shifts in (analog[:2], analog[2:], recon)]
    stages.append(relative_db(np.sinc(f / (MCLK / 128))))
    stages.append(relative_db(fir_response(f, taps)))
    stages.append(np.sum(stages, axis=0))
    for i, harmonic in enumerate(HARMONICS):
        lines.append(f"{harmonic},{f[i]:.1f}," +
                     ",".join(f"{stage[i]:.3f}" for stage in stages))

    # Fit only harmonics below the compressed reference's steep cutoff.
    hw = np.loadtxt(output / "hardware_harmonics.csv", delimiter=",", skiprows=1)
    fc = np.geomspace(500, 20000, 240)
    attenuation = -10 * np.log10(1 + (hw[:, 1, None] / fc) ** 2)
    attenuation -= attenuation[0]
    predicted = (attenuation[:, :, None] + attenuation[:, None, :] -
                 20 * np.log10(HARMONICS[:, None, None]))
    error = np.sqrt(np.mean((predicted[1:] - hw[1:, 2, None, None]) ** 2, axis=0))
    a, b = np.unravel_index(np.argmin(error), error.shape)
    lines += ["", "Two independent low-pass poles fitted to C5 magnitudes only:",
              f"{fc[a]:.1f} Hz, {fc[b]:.1f} Hz; RMS {error[a, b]:.3f} dB.",
              "This fit does not separate coupling, duty variation, or recording response.",
              "It does not identify the RF module circuit."]
    lines += ["", "Other sustained notes, relative odd-harmonic fit error (dB):",
              "Current-core prediction excludes downstream MiSTer/recording filters.",
              "note,hardware_f0_hz,two_pole_fit_rms,current_core_rms"]
    for label, onset, duration, guess in (("C4", 1.455, .17, 262.234),
                                         ("D4", .955, .17, 291.382),
                                         ("E4", 2.455, .45, 327.798),
                                         ("F4", 8.065, .17, 349.653),
                                         ("G4", 5.01, .17, 393.357),
                                         ("A4", 7.56, .17, 437.068)):
        f0, db, _, _ = tone(recordings["hardware"], onset + .08, duration, guess)
        frequencies = HARMONICS * f0
        fitted = np.prod([1 / (1 + 1j * frequencies / cutoff)
                          for cutoff in (fc[a], fc[b])], axis=0)
        current = (poles(frequencies, analog + recon) *
                   np.sinc(frequencies / (MCLK / 128)) * fir_response(frequencies, taps))
        errors = [np.sqrt(np.mean((relative_db(h)[1:] -
                  20 * np.log10(HARMONICS[1:]) - db[1:]) ** 2))
                  for h in (fitted, current)]
        lines.append(f"{label},{f0:.3f},{errors[0]:.3f},{errors[1]:.3f}")
    report = "\n".join(lines) + "\n"
    (output / "comparison.txt").write_text(report, encoding="ascii")
    print(report)


if __name__ == "__main__":
    main()
