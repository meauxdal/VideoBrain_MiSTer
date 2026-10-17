"""Measure 48/96 kHz foldback, including FIR decimation and output images."""
import sys

import numpy as np


data = np.fromfile(sys.argv[1], dtype="<i4").reshape(-1, 3)
print("note,output_hz,previous_alias_rms,new_alias_rms,change_db")
for note in range(12):
    samples = data[data[:, 0] == note, 1:].astype(float)
    assert len(samples) == 262144
    samples -= samples.mean(axis=0)
    window = np.hanning(len(samples))[:, None]
    spectrum = np.fft.rfft(samples * window, axis=0)
    hz = np.fft.rfftfreq(len(samples), 1 / 14318181)
    for rate in (48000, 96000):
        inband = spectrum.copy()
        inband[hz >= rate / 2] = 0
        reference = np.fft.irfft(inband, n=len(samples), axis=0)
        # Compare at identical core-clock instants so sampling jitter cancels.
        indices = np.floor(np.arange(int(len(samples) * rate / 14318181)) *
                           14318181 / rate).astype(int)
        alias = (samples * window - reference)[indices]
        rms = np.sqrt(np.mean(alias ** 2, axis=0) / np.mean(window[indices] ** 2))
        change = 20 * np.log10(rms[1] / rms[0])
        print(f"{note},{rate},{rms[0]:.4f},{rms[1]:.4f},{change:.2f}")
        assert rms[1] < 0.5
        if rate == 48000:
            assert change < -6
