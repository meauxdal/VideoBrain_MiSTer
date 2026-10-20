"""Compare pre-filter DAC timing from the same held-note capture sequence."""
import csv
import math
import statistics
import sys


def percentile(values, fraction):
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    index = int(position)
    tail = min(index + 1, len(ordered) - 1)
    return ordered[index] + (ordered[tail] - ordered[index]) * (position - index)


def measure(path):
    with open(path, newline="") as source:
        events = [row for row in csv.DictReader(source)
                  if 330 <= int(row["frame"]) <= 342]
    if len(events) < 64:
        raise ValueError(f"{path}: insufficient held-note events in frames 330..342")
    if {row["code"] for row in events} != {"0", "3"}:
        raise ValueError(f"{path}: expected alternating full-volume DAC codes 0/3")
    edges = events[:1] + [b for a, b in zip(events, events[1:])
                          if a["code"] != b["code"]]
    periods = [(int(b["cycle"]) - int(a["cycle"])) / 14.318181
               for a, b in zip(edges, edges[2:])]
    if len(periods) < 32:
        raise ValueError(f"{path}: insufficient DAC transitions")
    median = statistics.median(periods)
    deviations = [abs(value - median) for value in periods]
    requests = [row for row in edges if int(row["irq_cycle"]) >= 0]
    if len(requests) < 32 or any(int(row["ack_cycle"]) < int(row["irq_cycle"])
                                 for row in requests):
        raise ValueError(f"{path}: missing interrupt timestamps")
    waits = [(int(row["ack_cycle"]) - int(row["irq_cycle"])) / 14.318181
             for row in requests]
    service = [(int(row["cycle"]) - int(row["ack_cycle"])) / 14.318181
               for row in requests]
    irq_periods = [(int(b["irq_cycle"]) - int(a["irq_cycle"])) / 14.318181
                   for a, b in zip(requests, requests[2:])]
    return {
        "DAC periods": len(periods),
        "Median period us": median,
        "Period min us": min(periods),
        "Period max us": max(periods),
        "Period spread us": max(periods) - min(periods),
        "Period RMS deviation us": math.sqrt(statistics.mean(
            (value - median) ** 2 for value in periods)),
        "Period p95 deviation us": percentile(deviations, 0.95),
        "IRQ period spread us": max(irq_periods) - min(irq_periods),
        "IRQ-to-ack p95 us": percentile(waits, 0.95),
        "IRQ-to-ack max us": max(waits),
        "Ack-to-DAC median us": statistics.median(service),
        "Ack-to-DAC spread us": max(service) - min(service),
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: compare_audio_timing.py BASELINE.csv CURRENT.csv")
    baseline, current = map(measure, sys.argv[1:])
    print("Pre-filter timing, original ED01 ROM, held K, frames 330..342")
    print(f"{'Metric':<27} {'Baseline':>12} {'Current':>12}")
    for name, before in baseline.items():
        print(f"{name:<27} {before:12.3f} {current[name]:12.3f}")
    for name in ("Period spread us", "Period RMS deviation us", "Period p95 deviation us"):
        change = 100 * (current[name] / baseline[name] - 1) if baseline[name] else 0
        print(f"{name}: {change:+.1f}% (negative means less variation)")
    print("Compare these timing changes before evaluating another FPGA build.")


if __name__ == "__main__":
    main()
