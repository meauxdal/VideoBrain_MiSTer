"""Compare recorded full-ROM IRQ latency and held-DAC sidebands."""
import argparse
from pathlib import Path

import numpy as np

from audio_irq_diagnostic import read_capture, transform


def measure(path):
    rows, codes, dac, irq, ack = read_capture(path, 330, 342)
    start, stop = .005, .200
    if dac[-1] < stop + .005:
        raise ValueError(f'{path}: capture does not cover the common spectrum window')
    latency = (ack - irq) * 1e6
    estimate = 1 / (2 * np.median(np.diff(irq)))
    grid = np.arange(estimate - 4, estimate + 4, .02)
    peaks = transform(dac, codes, grid, start, stop)
    peak = np.argmax(peaks)
    fundamental = grid[peak]
    result = {
        'DAC events': len(rows),
        'IRQ-to-ack min us': min(latency),
        'IRQ-to-ack median us': np.median(latency),
        'IRQ-to-ack p95 us': np.percentile(latency, 95),
        'IRQ-to-ack max us': max(latency),
        'IRQ-to-ack >40 us': int(np.sum(latency > 40)),
        'Fundamental Hz': fundamental,
    }
    for offset in [-119.88, -59.94, 59.94, 119.88]:
        scan = np.arange(fundamental + offset - 1, fundamental + offset + 1, .05)
        amplitude = max(transform(dac, codes, scan, start, stop))
        result[f'{offset:+.2f} Hz dBc'] = 20 * np.log10(amplitude / peaks[peak])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('baseline', type=Path)
    parser.add_argument('current', type=Path)
    args = parser.parse_args()
    before, after = map(measure, [args.baseline, args.current])
    print('\nOriginal ED01 ROM; frames 330..342; exact held-DAC Hann integration')
    print('Common 0.005..0.200 s window; each capture uses its own carrier peak.')
    print(f'Baseline: {args.baseline}\nCurrent:  {args.current}')
    print(f'{"Metric":27} {"Baseline":>12} {"Current":>12} {"Change":>12}')
    for key in before:
        print(f'{key:27} {before[key]:12.3f} {after[key]:12.3f} '
              f'{after[key] - before[key]:+12.3f}')
    print('Recorded timestamps only; no IRQ retiming or audio filtering.')
    print('Changes measure this simulated workload, not hardware equivalence.')


if __name__ == '__main__':
    main()
