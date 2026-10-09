import csv
import sys
import wave
from pathlib import Path

import numpy as np


events_path, samples_path, output_dir = sys.argv[1:4]
notes = sys.argv[4:] or ["K:260:330", "P:380:450", "L:500:570", "F:620:690"]
with open(events_path) as source:
    events = list(csv.DictReader(source))
samples = np.loadtxt(samples_path, delimiter=",", skiprows=1)
output = Path(output_dir)
output.mkdir(parents=True, exist_ok=True)
rate = 384000

print("key,frequency_hz,fundamental_db,raw_alias_rms,filtered_alias_rms,alias_change_db,min,max")
for note_range in notes:
    key, start, stop = note_range.split(":")
    start, stop = int(start), int(stop)
    note = [e for e in events if start <= int(e["frame"]) < stop]
    assert len(note) > 100
    first, last = int(note[0]["cycle"]), int(note[-1]["cycle"])
    data = samples[(samples[:, 0] >= first) & (samples[:, 0] < last), 1:]
    data = data[:len(data) // 8 * 8]
    centered = data - data.mean(axis=0)
    window = np.hanning(len(data))[:, None]
    spectrum = np.fft.rfft(centered * window, axis=0)
    frequencies = np.fft.rfftfreq(len(data), 1 / rate)
    peak = np.argmax(np.abs(spectrum[1:int(2000 * len(data) / rate), 0])) + 1
    gain = 20 * np.log10(abs(spectrum[peak, 1] / spectrum[peak, 0]))
    inband = spectrum.copy()
    inband[frequencies >= 24000] = 0
    reference = np.fft.irfft(inband, n=len(data), axis=0)[::8]
    alias = (centered * window)[::8] - reference
    alias_rms = np.sqrt(np.mean(alias ** 2, axis=0) / np.mean(window ** 2))
    change = 20 * np.log10(alias_rms[1] / alias_rms[0])
    frequency = 14318181 / (2 * np.mean(np.diff([int(e["cycle"]) for e in note])))
    print(f"{key},{frequency:.2f},{gain:.3f},{alias_rms[0]:.2f},"
          f"{alias_rms[1]:.2f},{change:.2f},{data[:, 1].min():.0f},{data[:, 1].max():.0f}")
    assert -1 < gain <= 0.05
    assert change < -20
    assert data[:, 1].min() >= -8194 and data[:, 1].max() <= 4096
    for column, name in [(0, "raw"), (1, "filtered")]:
        with wave.open(str(output / f"music_{key}_{name}.wav"), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(48000)
            wav.writeframes(centered[::8, column].astype("<i2").tobytes())
