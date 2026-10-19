"""Measure IRQ modulation and export listening comparisons from a saved capture."""
import argparse
import csv
import math
from pathlib import Path
import statistics
import wave

import numpy as np

CLOCK = 14318181.0
RATE = 48000


def read_capture(path, first, last):
    with path.open(newline='') as source:
        rows = [row for row in csv.DictReader(source)
                if first <= int(row['frame']) <= last]
    if len(rows) < 64:
        raise ValueError('Need at least 64 DAC events in the selected frames')
    codes = np.array([int(row['code']) for row in rows])
    if set(codes) != {0, 3} or np.any(np.diff(codes) == 0):
        raise ValueError('Expected alternating DAC codes 0/3 for one held note')
    origin = int(rows[0]['cycle'])
    def timestamps(field):
        return np.array([int(row[field]) - origin for row in rows]) / CLOCK
    dac, irq, ack = map(timestamps, ['cycle', 'irq_cycle', 'ack_cycle'])
    if any(int(row['irq_cycle']) < 0 for row in rows):
        raise ValueError('Missing IRQ timestamps')
    if not (np.all(ack >= irq) and np.all(dac >= ack)):
        raise ValueError('Invalid IRQ/ack/DAC timestamp order')
    if not all(np.all(np.diff(edges) > 0) for edges in [dac, irq, ack]):
        raise ValueError('Timestamps must be strictly increasing')
    return rows, codes, dac, irq, ack


def transform(edges, codes, frequencies, start, stop):
    """Integrate held DAC levels exactly under a continuous Hann window."""
    length = stop - start
    lo = np.maximum(edges[:-1], start) - start
    hi = np.minimum(edges[1:], stop) - start
    valid = hi > lo
    lo, hi, levels = lo[valid], hi[valid], codes[:-1][valid] - 1.5
    result = []
    for frequency in frequencies:
        value = 0j
        for offset, weight in [(0, .5), (1 / length, -.25), (-1 / length, -.25)]:
            z = -2j * np.pi * (frequency + offset)
            if abs(z) < 1e-12:
                value += weight * np.sum(levels * (hi - lo))
            else:
                value += weight * np.sum(levels * np.exp(z * lo) *
                                         np.expm1(z * (hi - lo)) / z)
        result.append(abs(value))
    return np.array(result)


def reconstruct(edges, codes, start, stop):
    # Same 20 kHz reconstruction for every variant; excludes core/MiSTer filters.
    rate = RATE * 8
    margin = .002
    times = np.arange(start - margin, stop + margin + 1 / rate, 1 / rate)
    indices = np.searchsorted(edges, times, side='right') - 1
    if indices.min() < 0 or indices.max() >= len(codes) - 1:
        raise ValueError('Capture does not cover reconstruction margins')
    levels = (codes - 1.5) / 1.5
    integral = np.concatenate([[0], np.cumsum(np.diff(edges) * levels[:-1])])
    at_boundary = integral[indices] + (times - edges[indices]) * levels[indices]
    samples = np.diff(at_boundary) * rate
    taps = np.arange(257) - 128
    kernel = 2 * 20000 / rate * np.sinc(2 * 20000 / rate * taps)
    kernel *= np.kaiser(len(taps), 8.6)
    kernel /= kernel.sum()
    samples = np.convolve(samples, kernel, mode='same')
    first = round(margin * rate)
    count = round((stop - start) * RATE)
    return samples[first:first + count * 8:8]


def export(path, samples):
    # Silence separates repetitions so the capture seam is not part of a tone.
    samples = samples.copy()
    fade = min(round(.003 * RATE), len(samples) // 4)
    samples[:fade] *= np.linspace(0, 1, fade)
    samples[-fade:] *= np.linspace(1, 0, fade)
    clip = np.concatenate([samples, np.zeros(round(.08 * RATE))])
    pcm = np.rint(np.tile(clip, 8) * 12000).astype('<i2')
    with wave.open(str(path), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--output', type=Path, default=Path('out/audio_irq_diagnostic'))
    parser.add_argument('--first-frame', type=int, default=330)
    parser.add_argument('--last-frame', type=int, default=342)
    args = parser.parse_args()
    rows, codes, dac, irq, ack = read_capture(
        args.capture, args.first_frame, args.last_frame)
    start, stop = .005, min(.200, dac[-1] - .005)
    if stop - start < .15:
        raise ValueError('Need at least 0.16 s of held-note capture')
    variants = {
        'a_recorded': dac,
        'b_fixed_ack': irq + np.median(ack - irq) + dac - ack,
        'c_fixed_irq_to_dac': irq + np.median(dac - irq),
    }
    if any(np.any(np.diff(edges) <= 0) for edges in variants.values()):
        raise ValueError('Retiming would reorder DAC events')
    args.output.mkdir(parents=True, exist_ok=True)
    estimate = 1 / (2 * statistics.median(np.diff(irq)))
    grid = np.arange(estimate - 4, estimate + 4, .02)
    print(f'Capture: {args.capture}; frames {args.first_frame}..{args.last_frame}')
    print(f'{len(rows)} events; spectrum window {start:.3f}..{stop:.3f} s')
    print('Synthetic timestamp edits only; no proposed CPU/ROM correction.')
    print('Sidebands below are exact held-DAC integration, before reconstruction.')
    print('variant                 f0 Hz    -120    -60     +60    +120 Hz dBc')
    bands = {}
    for label, edges in variants.items():
        peaks = transform(edges, codes, grid, start, stop)
        peak = np.argmax(peaks)
        fundamental = grid[peak]
        band = []
        for offset in [-119.88, -59.94, 59.94, 119.88]:
            scan = np.arange(fundamental + offset - 1,
                             fundamental + offset + 1, .05)
            amplitude = max(transform(edges, codes, scan, start, stop))
            band.append(20 * math.log10(amplitude / peaks[peak]))
        bands[label] = band
        print(f'{label:23} {fundamental:7.2f} ' + ' '.join(f'{b:7.2f}' for b in band))
        export(args.output / f'{label}.wav', reconstruct(edges, codes, start, stop))
    reduction = np.array(bands['a_recorded']) - np.array(bands['b_fixed_ack'])
    print(f'Fixing IRQ-to-ack reduces +/-60 Hz sidebands by '
          f'{reduction[1]:.1f}/{reduction[2]:.1f} dB in this capture.')
    print('A: recorded DAC timing. B: fixed IRQ-to-ack, recorded ack-to-DAC.')
    print('C: fixed IRQ-to-DAC, retaining recorded IRQ timing.')
    print('WAVs use identical 20 kHz reconstruction, gain and 48 kHz sampling;')
    print('they exclude core/MiSTer/analog filtering. Each short clip repeats')
    print('eight times with 80 ms silence between repetitions.')
    print('Listen within each burst: does B remove the same ringing heard on hardware?')
    print('If B retains it but C removes it, investigate ack-to-DAC timing next.')
    print('If A does not reproduce it, these WAVs do not identify the audible fault.')
    print(f'WAV files: {args.output}')


if __name__ == '__main__':
    main()
