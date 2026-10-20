"""Compare repeated MT1 notes using observed key, pin and interrupt timing."""
import argparse
import csv
from pathlib import Path

import numpy as np

from audio_irq_diagnostic import CLOCK, transform


def read_rows(path):
    with path.open(newline='') as source:
        return list(csv.DictReader(source))


def audit_latches(rows):
    failures = []
    for row in rows:
        reset = int(row['reset'])
        rise = int(row['port_b_n']) & 16 and not int(row['clock_previous'])
        strobe = int(not reset and rise)
        code = 0 if reset else int(row['port_a_n']) & 3 if strobe else int(row['held_code'])
        if (int(row['stb']) != strobe or int(row['code']) != code or
                not int(row['latch_ok'])):
            failures.append(int(row['cycle']))
    return failures


def audit_events(rows, events):
    latches = {int(row['cycle']): row for row in rows if int(row['stb'])}
    if set(latches) != set(events):
        raise ValueError('DAC trace and event log have different latch cycles')
    edges = {}
    for field in ('irq', 'ack'):
        previous = False
        edges[field] = set()
        for row in rows:
            level = bool(int(row[field]))
            if level and not previous:
                edges[field].add(int(row['cycle']))
            previous = level
    for cycle, row in events.items():
        if int(row['code']) != int(latches[cycle]['code']):
            raise ValueError('DAC trace and event log disagree')
        for field, timestamp in [('irq', 'irq_cycle'), ('ack', 'ack_cycle')]:
            if int(row[timestamp]) >= 0 and int(row[timestamp]) not in edges[field]:
                raise ValueError(f'{timestamp} is absent from the independent edge trace')


def key_intervals(rows, bit):
    intervals = []
    down = None
    for row in rows:
        pressed = int(row['keys']) & (1 << bit)
        if pressed and down is None:
            down = row
        elif not pressed and down is not None:
            intervals.append((down, row))
            down = None
    if down is not None:
        raise ValueError('Capture ends before the final key release')
    return intervals


def note_burst(rows, down, limit):
    latches = [row for row in rows if int(row['stb']) and
               down <= int(row['cycle']) < limit]
    groups = []
    for row in latches:
        if not groups or int(row['cycle']) - int(groups[-1][-1]['cycle']) > CLOCK * .02:
            groups.append([])
        groups[-1].append(row)
    groups = [group for group in groups if len(group) >= 64]
    if len(groups) != 1:
        raise ValueError(f'Expected one sustained note after key-down {down}, got {len(groups)}')
    return groups[0]


def spectrum(edges, codes, estimate, start=.100, stop=.300):
    if edges[0] > start or edges[-1] < stop:
        raise ValueError('Note does not cover the common 0.100..0.300 s window')
    grid = np.arange(estimate - 5, estimate + 5, .02)
    peaks = transform(edges, codes, grid, start, stop)
    index = int(np.argmax(peaks))
    if index in (0, len(grid) - 1):
        raise ValueError('Carrier peak lies outside the search range')
    frequency = grid[index]
    bands = []
    for offset in (-119.88, -59.94, 59.94, 119.88):
        scan = np.arange(frequency + offset - 1, frequency + offset + 1, .05)
        bands.append(20 * np.log10(max(transform(edges, codes, scan, start, stop)) / peaks[index]))
    return frequency, bands


def measure(burst, events):
    origin = int(burst[0]['cycle'])
    cycles = np.array([int(row['cycle']) for row in burst], dtype=np.int64)
    codes = np.array([int(row['code']) for row in burst])
    edges = (cycles - origin) / CLOCK
    selected = (edges >= .100) & (edges <= .300)
    indices = np.flatnonzero(selected)
    if len(indices) < 64 or edges[-1] < .310:
        raise ValueError(f'Incomplete sustained note at {origin}')
    if set(codes[indices]) != {0, 3} or np.any(np.diff(codes[indices]) == 0):
        raise ValueError(f'Nonalternating/full-volume steady DAC codes in note at {origin}')
    periods = (cycles[indices[2:]] - cycles[indices[:-2]]) / CLOCK * 1e6
    intervals = np.diff(cycles[indices]) / CLOCK * 1e6
    levels = codes[indices[:-1]]
    median = np.median(periods)
    frequency, bands = spectrum(edges, codes, 1e6 / median)

    # Every steady DAC event must have its own request and acknowledgement.
    logged = [events[int(cycle)] for cycle in cycles]
    if any(int(row['code']) != code for row, code in zip(logged, codes)):
        raise ValueError('DAC trace and event log disagree')
    irq = np.array([int(row['irq_cycle']) for row in logged], dtype=np.int64)
    ack = np.array([int(row['ack_cycle']) for row in logged], dtype=np.int64)
    if (np.any(irq[indices] < 0) or np.any(ack[indices] < irq[indices]) or
            np.any(cycles[indices] < ack[indices]) or
            np.any(np.diff(irq[indices]) <= 0) or np.any(np.diff(ack[indices]) <= 0)):
        raise ValueError('Missing, stale or reordered steady-note IRQ/ack timestamps')
    latency = (ack[indices] - irq[indices]) / CLOCK * 1e6
    service = (cycles[indices] - ack[indices]) / CLOCK * 1e6
    # Discard startup events without a valid IRQ before the synthetic comparison.
    valid = (irq >= 0) & (ack >= irq) & (cycles >= ack) & (edges >= .090) & (edges <= .310)
    retimed = (irq[valid] - origin + np.median(ack[indices] - irq[indices]) +
               cycles[valid] - ack[valid]) / CLOCK
    if np.any(np.diff(retimed) <= 0):
        raise ValueError('Fixed-ack comparison would reorder DAC edges')
    _, fixed_bands = spectrum(retimed, codes[valid], frequency)
    # Integrate the held high level over the exact common window.
    widths = np.maximum(0, np.minimum(edges[1:], .300) - np.maximum(edges[:-1], .100))
    high_fraction = widths[codes[:-1] == 3].sum() / .200
    return dict(frequency=frequency, bands=bands, fixed_bands=fixed_bands,
                period_rms=np.sqrt(np.mean((periods - median) ** 2)),
                period_min=min(periods), period_max=max(periods),
                high_us=np.median(intervals[levels == 3]),
                low_us=np.median(intervals[levels == 0]), high_fraction=high_fraction,
                latency_p95=np.percentile(latency, 95), latency_max=max(latency),
                long_waits=int(np.sum(latency > 40)), service_spread=np.ptp(service))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--expected-notes', type=int, default=4)
    args = parser.parse_args()
    rows = read_rows(args.capture / 'trace.csv')
    events = {int(row['cycle']): row for row in read_rows(args.capture / 'events.csv')}
    if not rows or not events:
        raise ValueError('Empty trace or DAC event log')
    if any(int(b['cycle']) <= int(a['cycle']) for a, b in zip(rows, rows[1:])):
        raise ValueError('Trace cycles must be strictly increasing')
    failures = audit_latches(rows)
    print(f'Physical clock/data/hold checks: {len(rows)} sampled rows, {len(failures)} mismatches')
    if failures:
        raise ValueError(f'Latch mismatches at MCLKs {failures[:8]}')
    audit_events(rows, events)
    intervals = key_intervals(rows, 5)  # Physical K matrix bit.
    if len(intervals) != args.expected_notes:
        raise ValueError(f'Expected {args.expected_notes} K presses, got {len(intervals)}')
    phases = []
    print('Original ED01 ROM; identical K notes; pre-filter held-DAC analysis.')
    print('Each spectrum uses 0.100..0.300 s after its first DAC write.')
    print('F = synthetic fixed IRQ-to-ack latency; recorded IRQ and service timing retained.')
    for index, (down, up) in enumerate(intervals):
        limit = int(intervals[index + 1][0]['cycle']) if index + 1 < len(intervals) else int(rows[-1]['cycle'])
        burst = note_burst(rows, int(down['cycle']), limit)
        if int(burst[-1]['cycle']) < int(up['cycle']) - CLOCK * .05:
            raise ValueError('Note stopped more than 50 ms before key release')
        if limit - int(burst[-1]['cycle']) < CLOCK * .08:
            raise ValueError('Missing quiet interval after note release')
        result = measure(burst, events)
        first = burst[0]
        phase = int(first['frame_cycle']) / CLOCK * 1e6
        phases.append(phase)
        print(f'\nNote {index + 1}: key-down frame {down["frame"]} + '
              f'{int(down["frame_cycle"]) / CLOCK * 1e6:.3f} us; '
              f'DAC onset MCLK {first["cycle"]}, frame {first["frame"]} + {phase:.3f} us, '
              f'Y/H={first["vpos"]}/{first["hpos"]}')
        print(f'  Idle/first/final codes: {down["held_code"]}/{first["code"]}/{burst[-1]["code"]}; '
              f'key-to-DAC {(int(first["cycle"]) - int(down["cycle"])) / CLOCK * 1e6:.3f} us')
        print(f'  f0 {result["frequency"]:.3f} Hz; period min/max/RMS deviation '
              f'{result["period_min"]:.3f}/{result["period_max"]:.3f}/{result["period_rms"]:.3f} us')
        print(f'  Median high/low {result["high_us"]:.3f}/{result["low_us"]:.3f} us; '
              f'exact high fraction {result["high_fraction"]:.6f}')
        print(f'  IRQ-to-ack p95/max {result["latency_p95"]:.3f}/{result["latency_max"]:.3f} us; '
              f'>40 us {result["long_waits"]}; ack-to-DAC spread {result["service_spread"]:.3f} us')
        for label, key in [('Recorded', 'bands'), ('F', 'fixed_bands')]:
            print(f'  {label:8} -120/-60/+60/+120 Hz dBc: ' +
                  '/'.join(f'{value:.2f}' for value in result[key]))
    print(f'\nObserved DAC-onset phase range: {min(phases):.3f}..{max(phases):.3f} us into frame.')
    print('Keyboard scan timing can collapse different requested phases to similar onsets.')
    print('A clean latch audit with varying sidebands implicates ongoing timing, not wrong latch data.')
    print('F reducing sidebands identifies sensitivity to IRQ latency; it is not a hardware correction.')


if __name__ == '__main__':
    main()
