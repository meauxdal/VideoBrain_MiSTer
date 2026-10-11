#!/usr/bin/env python3
"""One fixed-timing calibration and stationary-input run."""

import argparse
import json
import math
import os
from pathlib import Path
import re
import subprocess


GAMES = {
    "gladiator": ("Gladiator (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN01].bin", 150, 180, 0x22BE),
    "checkers": ("Checkers (197x)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN04].bin", 260, 280, 0x22BE),
    "tennis": ("Tennis (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN03].bin", 230, 270, 0x1FCB),
}


def summarize(out):
    plan = json.loads((out / "plan.json").read_text())
    returns = []
    for line in (out / "trace.txt").read_text().splitlines():
        m = re.search(r"\[joy-result\] frame=(\d+) latch=([0-9A-F]+) value=([0-9A-F]+).*bounds=(\S+)", line)
        if m:
            returns.append((int(m[1]), m[2], int(m[3], 16), m[4]))
    states = {}
    frame = -1
    for line in (out / "state.txt").read_text().splitlines():
        m = re.search(r"========== frame (\d+)", line)
        if m:
            frame = int(m[1])
            states[frame] = {}
        m = re.fullmatch(r"([0-9A-F]{4}): ((?:[0-9A-F]{2} ){16})", line)
        if m:
            base = int(m[1], 16)
            states[frame].update((f"{base + i:04X}", int(v, 16)) for i, v in enumerate(m[2].split()))
        m = re.fullmatch(r"\s*([34]): ((?:[0-9A-F]{2}\s+){8}[0-9A-F]{2})", line)
        if m:
            row = [int(v, 16) for v in m[2].split()]
            states[frame].update({f"object{m[1]}.x": row[4],
                                 f"object{m[1]}.ya": row[5] | ((row[6] & 128) << 1),
                                 f"object{m[1]}.yb": row[7] | ((row[8] & 128) << 1)})
    addresses = {"checkers": ["0F0C", "0F0D", "0F0E", "0F0F"],
                 "tennis": ["0C86", "0C8A", "0C8E", "0C92"],
                 "gladiator": [f"object{o}.{a}" for o in (3, 4) for a in ("x", "ya", "yb")]}[plan["game"]]
    report = []
    for phase in plan["phases"]:
        start, end = phase["start"], phase["end"]
        samples = [r for r in returns if start <= r[0] <= end]
        rows = [s for f, s in states.items() if start <= f <= end]
        entry = {**phase, "expected_samples": end - start + 1, "samples": len(rows), "returns": {}}
        for latch in sorted({r[1] for r in samples}):
            values = [r for r in samples if r[1] == latch]
            entry["returns"][latch] = {"count": len(values),
                                       "range": [min(r[2] for r in values), max(r[2] for r in values)],
                                       "bounds": sorted({r[3] for r in values})}
        entry["positions"] = {a: [min(s[a] for s in rows), max(s[a] for s in rows)] for a in addresses} if rows else {}
        # Include bounds before gameplay resumes, when there may be no returns.
        entry["ram_bounds"] = sorted({" ".join(f"{s[f'{a:04X}']:02X}" for a in range(0xC00, 0xC10)) for s in rows})
        report.append(entry)
    result = {"game": plan["game"], "procedure": plan["procedure"], "timing": plan["timing"],
              "phases": report,
              "note": "Compare extrema, travel and stationary holds. Fixed positions can reflect obstruction. Identify Checkers cursor in screenshots. Missing reads are inconclusive."}
    (out / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"Summary: {out / 'summary.json'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("game", choices=GAMES)
    parser.add_argument("--procedure", choices=("circle", "endpoints"), default="circle")
    parser.add_argument("--base", type=int, default=2580)
    parser.add_argument("--step", type=int, default=6)
    parser.add_argument("--curve", action="store_true", help="use shared 1620:23/53 timer curve")
    parser.add_argument("--focus", type=int, help="trace BIOS operands in one frame")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--prepare", action="store_true", help="write plan and command without building or running")
    parser.add_argument("--summarize", action="store_true", help="summarize an existing run")
    args = parser.parse_args()
    if args.base < 0 or not 0 <= args.step <= 127 or args.base + args.step * 255 > 16383:
        parser.error("timer range must fit 0..16383 MCLK ticks")
    os.chdir(Path(__file__).resolve().parent)
    if args.summarize:
        summarize(args.out)
        return
    args.out.mkdir(parents=True, exist_ok=True)
    cart, startup, frame, return_pc = GAMES[args.game]
    command = ["./obj_dir_headless/Vtop", "--cart", f"../software/{cart}", "--press", "SPACE@140:8",
               "--joy-results", str(startup), "--joy-return-pc", f"{return_pc:X}",
               "--joy-timer-base", str(args.base), "--joy-timer-step", str(args.step),
               "--dump-every", "1", "--ram", "--dump-file", str(args.out / "state.txt"),
               "--outdir", str(args.out), "--prefix", args.game, "--quiet"]
    if args.focus is not None:
        command += ["--joy-focus", str(args.focus)]
    if args.curve:
        command += ["--joy-timer-curve"]
    if args.game == "checkers":
        command += ["--press", "Y@250:8"]
    phases = [{"name": "startup", "start": startup, "end": frame - 1, "pots": [128, 128]}]
    shots = [frame - 1]

    def hold(name, vertical, horizontal, length, settle=0):
        nonlocal frame
        for channel, pot in enumerate((vertical, horizontal, vertical, horizontal)):
            command.extend(["--joy-pot", f"{channel}:{pot}@{frame}:{length}"])
        phases.append({"name": name, "start": frame + settle, "end": frame + length - 1,
                       "pots": [vertical, horizontal]})
        shots.append(frame + length - 1)
        frame += length

    if args.procedure == "circle":
        hold("forward", 0, 128, 16)
        for i in range(1, 17):
            angle = 2 * math.pi * i / 16
            hold(f"circle{i}", round(127.5 - 127.5 * math.cos(angle)),
                 round(127.5 + 127.5 * math.sin(angle)), 8)
    else:
        for name, v, h in (("up", 0, 128), ("down", 255, 128), ("left", 128, 0), ("right", 128, 255)):
            hold(name, v, h, 8)
    hold("calibrated128", 128, 128, 40, 16)
    for pot in (112, 144, 128):
        hold(f"region{pot}", pot, pot, 32, 8)
    command += ["--frames", str(frame), "--shot", ",".join(map(str, shots))]
    plan = {"game": args.game, "procedure": args.procedure, "timing": [args.base, args.step],
            "phases": phases, "command": command}
    if args.curve:
        plan["timing"] = {"base": 1620, "low_step": 23, "high_step": 53, "split": 128}
    (args.out / "plan.json").write_text(json.dumps(plan, indent=2) + "\n")
    print(f"Plan: {args.out / 'plan.json'} ({frame} frames)", flush=True)
    if not args.prepare:
        subprocess.run(["make", "headless"], check=True)
        with (args.out / "trace.txt").open("w") as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
        summarize(args.out)


if __name__ == "__main__":
    main()
