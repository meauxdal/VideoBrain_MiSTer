#!/usr/bin/env python3
"""Independent Gladiator timing runs with calibrated center checks."""

import argparse
import concurrent.futures
import csv
import json
import os
from pathlib import Path
import re
import subprocess
import time


CHANNELS = (1, 2, 4, 8)
PHASES = ((155, 163, "UP"), (163, 171, "DOWN"),
          (171, 179, "LEFT"), (179, 187, "RIGHT"))
RESULT = re.compile(r"\[joy-result\] frame=(\d+) latch=([0-9A-F]+) value=([0-9A-F]+)")
FRAME = re.compile(r"========== frame (\d+)")
OBJECT = re.compile(r"\s*([34]): ((?:[0-9A-F]{2}\s+){8}[0-9A-F]{2})")


def summarize(trace, state):
    center = {ch: [] for ch in CHANNELS}
    low = {ch: [] for ch in CHANNELS}
    high = {ch: [] for ch in CHANNELS}
    bounds = {ch: set() for ch in CHANNELS}
    for line in Path(trace).read_text().splitlines():
        match = RESULT.search(line)
        if not match:
            continue
        frame, ch, value = (int(match[1]), int(match[2], 16), int(match[3], 16))
        if ch not in center:
            continue
        if 193 <= frame <= 289:
            center[ch].append(value)
            bound = re.search(r"bounds=([0-9A-F]{4}),([0-9A-F]{4})", line)
            if bound:
                bounds[ch].add((int(bound[1], 16), int(bound[2], 16)))
        for start, end, direction in PHASES:
            if not start + 1 <= frame < end:
                continue
            vertical = ch in (1, 4)
            if (vertical and direction == "UP") or (not vertical and direction == "LEFT"):
                low[ch].append(value)
            if (vertical and direction == "DOWN") or (not vertical and direction == "RIGHT"):
                high[ch].append(value)

    positions = {3: [], 4: []}
    frame = -1
    for line in Path(state).read_text().splitlines():
        match = FRAME.search(line)
        if match:
            frame = int(match[1])
        match = OBJECT.fullmatch(line)
        if match and 193 <= frame <= 289:
            row = [int(v, 16) for v in match[2].split()]
            positions[int(match[1])].append((row[4], row[5] | ((row[6] & 128) << 1),
                                            row[7] | ((row[8] & 128) << 1)))

    drift = [max(p[i] for p in samples) - min(p[i] for p in samples)
             for samples in positions.values() for i in range(3)] if all(positions.values()) else []
    covered = all(len(center[ch]) >= 8 and low[ch] and high[ch] for ch in CHANNELS)
    response = covered and all(max(low[ch]) < min(center[ch]) and
                               max(center[ch]) < min(high[ch]) for ch in CHANNELS)
    # Search preference only; position checks determine drift.
    centered = covered and all(0x50 <= v <= 0x70 for values in center.values() for v in values)
    fixed = bool(drift) and max(drift) == 0 and all(len(p) >= 4 for p in positions.values())
    calibrated = all(len(bounds[ch]) == 1 and next(iter(bounds[ch]))[0] >
                     next(iter(bounds[ch]))[1] for ch in CHANNELS)
    error = max((abs(v - 0x60) for values in center.values() for v in values), default=255)
    return {
        "status": "STABLE" if fixed and response and calibrated else "FAIL",
        "preferred_band": bool(centered),
        "center": "/".join(f"{min(v):02X}-{max(v):02X}" if v else "missing" for v in center.values()),
        "reads": "/".join(str(len(v)) for v in center.values()),
        "low": "/".join(f"{min(v):02X}-{max(v):02X}" if v else "missing" for v in low.values()),
        "high": "/".join(f"{min(v):02X}-{max(v):02X}" if v else "missing" for v in high.values()),
        "center_error": error,
        "drift": "/".join(map(str, drift)) or "missing",
        "response": bool(response), "calibrated": calibrated,
        "bounds": "/".join(";".join(f"{a:04X},{b:04X}" for a, b in sorted(v)) or "missing"
                           for v in bounds.values()),
        "samples": "/".join(str(len(v)) for v in positions.values()),
    }


def run(candidate, out):
    base, step = candidate
    case = out / f"{base}_{step}"
    case.mkdir(parents=True, exist_ok=True)
    command = ["./obj_dir_headless/Vtop", "--cart",
               "../software/Gladiator (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN01].bin",
               "--frames", "290", "--press", "SPACE@140:8", "--joy-results", "150",
               "--joy-timer-base", str(base), "--joy-timer-step", str(step),
               "--dump-every", "1", "--dump-file", str(case / "state.txt"), "--quiet"]
    for start, end, direction in PHASES:
        for player in ("--joy", "--joy2"):
            command += [player, f"{direction}@{start}:{end - start}"]
    (case / "command.json").write_text(json.dumps(command, indent=2) + "\n")
    started = time.monotonic()
    with (case / "trace.txt").open("w") as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
    return {"base": base, "step": step, **summarize(case / "trace.txt", case / "state.txt"),
            "seconds": round(time.monotonic() - started, 1)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidates", nargs="*", help="base:step pairs")
    parser.add_argument("--bases", default="184,1280,2580", help="comma-separated bases")
    parser.add_argument("--steps", default="6,12,18,19", help="comma-separated steps")
    parser.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 1))
    parser.add_argument("--out", type=Path, default=Path("out/joystick/stability_sweep"))
    args = parser.parse_args()
    try:
        candidates = [tuple(map(int, item.split(":"))) for item in args.candidates] if args.candidates else [
            (int(base), int(step)) for base in args.bases.split(",") for step in args.steps.split(",")]
        if args.jobs < 1 or any(len(pair) != 2 or min(pair) < 0 or pair[1] > 127 or
                               pair[0] + pair[1] * 255 > 16383 for pair in candidates):
            raise ValueError
    except ValueError:
        parser.error("use base:step values fitting 0..16383 MCLK and jobs >= 1")
    os.chdir(Path(__file__).resolve().parent)
    subprocess.run(["make", "headless"], check=True)
    args.out.mkdir(parents=True, exist_ok=True)
    rows = []
    print("Channels: P1 Y/X, P2 Y/X. Drift: P1 X/YA/YB, P2 X/YA/YB.", flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(run, candidate, args.out): candidate for candidate in dict.fromkeys(candidates)}
        for future in concurrent.futures.as_completed(futures):
            row = future.result()
            rows.append(row)
            print(f"{row['base']}:{row['step']} {row['status']} center={row['center']} "
                  f"drift={row['drift']} response={row['response']} {row['seconds']}s", flush=True)
            ranked = sorted(rows, key=lambda r: (r["status"] != "STABLE", r["center_error"], r["base"], r["step"]))
            with (args.out / "summary.csv").open("w", newline="") as file:
                writer = csv.DictWriter(file, fieldnames=list(row))
                writer.writeheader()
                writer.writerows(ranked)
    print(f"Results: {args.out / 'summary.csv'}")


if __name__ == "__main__":
    main()
