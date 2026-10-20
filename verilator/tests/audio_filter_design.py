"""Generate the core's compensated 13 kHz audio FIR and check its response."""
from pathlib import Path
import re
import sys

import numpy as np


MCLK = 14318181
RATE = MCLK / 128
TAPS = 225
SCALE = 1 << 23
RTL = Path(__file__).resolve().parents[2] / "rtl/videobrain_audio.sv"


def infrastructure_response(hz):
    z = np.exp(-2j * np.pi * hz / MCLK)
    response = np.ones(len(hz), dtype=complex)
    for shift in (10, 9, 8, 8, 7, 7, 7, 7):
        alpha = 2.0 ** -shift
        response *= alpha / (1 - (1 - alpha) * z)
    return response * np.sinc(hz / RATE)


def target_response(hz):
    # Effective magnitude response fitted below the reference's encoded cutoff.
    return 1 / np.sqrt((1 + (hz / 1500) ** 2) * (1 + (hz / 6900) ** 2))


def coefficients():
    size = 262144
    hz = np.fft.rfftfreq(size, 1 / RATE)
    desired = target_response(hz) / abs(infrastructure_response(hz))
    desired[hz > 13000] = 0
    impulse = np.fft.fftshift(np.fft.irfft(desired))
    taps = impulse[size // 2 - TAPS // 2:size // 2 + TAPS // 2 + 1]
    taps *= np.kaiser(TAPS, 8.6)
    # Quarter gain preserves FIR headroom; reconstruction restores unity DC.
    taps = np.rint(taps / taps.sum() * (SCALE // 4)).astype(np.int64)
    taps[TAPS // 2] += SCALE // 4 - taps.sum()
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
    assert taps.sum() == SCALE // 4
    assert max(abs(taps)) < SCALE
    assert np.array_equal(taps, taps[::-1])
    assert 3000000 * abs(taps).sum() / SCALE < 1 << 23
    assert TAPS // 2 + 4 < 128
    # Bound the restored reconstruction input for any bounded DAC sequence.
    impulse = np.zeros(262144)
    impulse[np.arange(TAPS) * 128] = taps / SCALE
    hz_core = np.fft.rfftfreq(len(impulse), 1 / MCLK)
    z = np.exp(-2j * np.pi * hz_core / MCLK)
    response = np.fft.rfft(impulse)
    for shift in (10, 9, 8, 8):
        alpha = 2.0 ** -shift
        response *= alpha / (1 - (1 - alpha) * z)
    bound = 8192 * 256 * abs(np.fft.irfft(response)).sum()
    assert bound < (1 << 21) * 0.99
    print(f"FIR output bound before gain restoration: {bound:.0f} / {1 << 21}")
    spectrum = abs(np.fft.rfft(taps / SCALE, 262144)) * 4
    hz = np.fft.rfftfreq(262144, 1 / RATE)
    combined = spectrum * abs(infrastructure_response(hz))
    passband = hz <= 11500
    error = max(abs(20 * np.log10(combined[passband] / target_response(hz[passband]))))
    rejection = -20 * np.log10(max(combined[hz >= 14500]))
    print(f"FIR: {TAPS} taps, {RATE:.2f} Hz, magnitude error {error:.3f} dB, "
          f"core stopband {rejection:.2f} dB")
    for frequency in (500, 1000, 2000, 4000, 8000, 11000, 12000, 13000, 14000, 14500):
        gain = 20 * np.log10(np.interp(frequency, hz, combined))
        print(f"{frequency:5d} Hz: {gain:7.2f} dB")
    assert error < 0.25
    assert rejection > 100
