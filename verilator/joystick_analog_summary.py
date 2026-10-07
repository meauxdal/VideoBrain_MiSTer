#!/usr/bin/env python3
"""Report Tennis travel by input phase; no automatic pass claim."""

import csv
import json
from pathlib import Path
import re
import sys


def summarize(out):
    with (out / "tennis_phases.tsv").open() as source:
        phases = list(csv.DictReader(source, delimiter="\t"))
    returns = []
    for line in (out / "tennis_trace.txt").read_text().splitlines():
        match = re.search(r"\[joy-result\] frame=(\d+) latch=([0-9A-F]+) value=([0-9A-F]+).*bounds=(\S+)", line)
        if match:
            returns.append((int(match[1]), match[2], int(match[3], 16), match[4]))
    positions = []
    frame = -1
    addresses = (0xc86, 0xc8a, 0xc8e, 0xc92)
    for line in (out / "tennis_state.txt").read_text().splitlines():
        match = re.search(r"========== frame (\d+)", line)
        if match:
            frame = int(match[1])
        match = re.fullmatch(r"([0-9A-F]{4}): ((?:[0-9A-F]{2} ){16})", line)
        if match:
            base = int(match[1], 16)
            values = [int(v, 16) for v in match[2].split()]
            for address in addresses:
                if base <= address < base + 16:
                    positions.append((frame, address, values[address - base]))

    def value_range(values):
        return f"{min(values):02X}-{max(values):02X}" if values else None

    report = []
    for phase in phases:
        phase = {k: v if k == "name" else int(v) for k, v in phase.items()}
        start, end = phase["start"], phase["end"]
        samples = [r for r in returns if start <= r[0] <= end]
        phase["returns"] = {}
        for latch in sorted({r[1] for r in samples}):
            rows = [r for r in samples if r[1] == latch]
            phase["returns"][latch] = {
                "count": len(rows), "range": value_range([r[2] for r in rows]),
                "bounds": sorted({r[3] for r in rows})}
        phase["positions"] = {}
        for address in addresses:
            values = [v for f, a, v in positions if start <= f <= end and a == address]
            phase["positions"][f"{address:04X}"] = {
                "count": len(values), "range": value_range(values)}
        report.append(phase)
    result = {"timing": [2580, 6], "phases": report,
              "note": "Provisional. Check monotonic vertical travel, controller isolation, and return to neutral. Horizontal control can affect play. No hardware fidelity claim."}
    text = json.dumps(result, indent=2) + "\n"
    (out / "tennis_analog_summary.json").write_text(text)
    print(text, end="")


if __name__ == "__main__":
    summarize(Path(sys.argv[1]))
