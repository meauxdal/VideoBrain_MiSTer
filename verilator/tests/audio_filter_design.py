"""Generate and check the core's 111.86 kHz antialias FIR coefficients."""
from pathlib import Path
import re
import sys

import numpy as np


RATE = 14318181 / 128
TAPS = 161
SCALE = 1 << 23
RTL = Path(__file__).resolve().parents[2] / "rtl/videobrain_audio.sv"


def coefficients():
    n = np.arange(TAPS) - TAPS // 2
    taps = np.sinc(2 * 22000 / RATE * n) * np.kaiser(TAPS, 8.6)
    taps = np.rint(taps / taps.sum() * SCALE).astype(np.int64)
    taps[TAPS // 2] += SCALE - taps.sum()
    return taps


if __name__ == "__main__":
    taps = coefficients()
    source = RTL.read_text()
    if "--write" in sys.argv:
        rows = [f"\t\t7'd{i}: coefficient = 24'sh{int(c) & 0xffffff:06x};"
                for i, c in enumerate(taps[:TAPS // 2 + 1])]
        source = re.sub(r"(\t// FIR coefficients begin\n).*?(\t// FIR coefficients end)",
                        lambda m: m[1] + "\n".join(rows) + "\n" + m[2],
                        source, flags=re.S)
        RTL.write_text(source, newline="\n")
    stored = [int(c, 16) for c in re.findall(r"coefficient = 24'sh([0-9a-f]{6})", source)]
    stored = np.array([c if c < 1 << 23 else c - (1 << 24) for c in stored])
    assert np.array_equal(stored, taps[:TAPS // 2 + 1])
    assert taps.sum() == SCALE
    spectrum = abs(np.fft.rfft(taps / SCALE, 262144))
    hz = np.fft.rfftfreq(262144, 1 / RATE)
    ripple = max(abs(20 * np.log10(spectrum[hz <= 20000])))
    rejection = -20 * np.log10(max(spectrum[hz >= 24000]))
    print(f"FIR: {TAPS} taps, {RATE:.2f} Hz, ripple {ripple:.4f} dB, stopband {rejection:.2f} dB")
    assert ripple < 0.002
    assert rejection > 80
