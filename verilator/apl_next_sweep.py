#!/usr/bin/env python3
"""Sweep post-NEXT key response; retain passive traces for acceptance diagnosis."""
import argparse
import binascii
import csv
import json
from pathlib import Path
import struct
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from apl_source import encode


ROOT = Path(__file__).resolve().parents[1]
CART = ROOT / "software/1 Cartridges/APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin"
CLOCK = ROOT / "examples/21-apl_s-games-james-price/21-clock.txt"
CONDITION = "IF (D EQ 29) AND (O EQ 2) AND ((Y MOD 4) NE 0)"


def cases(families, lengths):
    for family in families:
        if family in ("clock", "clock-context"):
            lines = CLOCK.read_text(encoding="utf-8").splitlines()
            prefix = lines[:lines.index(CONDITION)] if family == "clock-context" else ["EDIT TEST"]
            yield family, prefix, CONDITION
            continue
        seen = set()
        for limit in lengths:
            if family == "sum":
                line = "A=1" + "+1" * max(0, (limit - 3) // 2)
            elif family == "paren":
                if limit < 5:
                    continue
                line = "A=(1)" + "+(1)" * ((limit - 5) // 4)
            else:
                if limit < 11:
                    continue
                line = "IF (A EQ 0)" + " AND (A EQ 0)" * ((limit - 11) // 13)
            if line not in seen:
                seen.add(line)
                yield f"{family}-{len(line)}", ["EDIT TEST"], line


def trial(prefix, line, delay, probe, hold=8, settle=512, observe=512):
    events = []

    def idle(fields):
        while fields:
            chunk = min(fields, 255)
            events.append((255, chunk, 0))
            fields -= chunk

    symbols = 0
    tokens = encode("\n".join(prefix + [line]))[8:]
    target = None
    setup_modes = {}
    for index, token in enumerate(tokens):
        key = token & 63
        if not token & 128 and (token >> 6) != symbols:
            events.append((11, hold, hold))
            symbols ^= 1
        if index == len(tokens) - 1:
            target = len(events)
            events.append((27, hold, min(delay, 255)))
            idle(max(0, delay - 255))
        else:
            if not token & 128:
                setup_modes[str(len(events) * 3 + 2)] = symbols
            events.append((key, hold, hold))
            if token == 155:
                idle(settle)
    probe_event = len(events)
    key = 11 if probe == "SHIFT" else (34 if symbols else 32) if probe == "CHAR" else 255
    events.append((key, hold, hold))
    idle(observe)
    payload = bytes(value for event in events for value in event)
    if len(payload) > 4096:
        raise ValueError("trial exceeds VBK payload limit")
    data = b"VBK2" + struct.pack("<HH", len(payload), binascii.crc_hqx(payload, 65535)) + payload
    return data, {"target_pos": target * 3 + 2, "probe_pos": probe_event * 3 + 2,
                  "probe_key": key, "symbols": symbols,
                  "setup_modes": setup_modes,
                  "budget_fields": 400 + sum(h + g for _, h, g in events)}


def write_csv(path, rows, fields):
    with path.open("w", newline="", encoding="ascii") as stream:
        writer = csv.DictWriter(stream, fields)
        writer.writeheader()
        writer.writerows(rows)


def analyze(out):
    rows = []
    for manifest in sorted(out.glob("*/trial.json")):
        meta = json.loads(manifest.read_text())
        row = {key: meta[key] for key in ("case", "length", "delay", "probe", "repeat")}
        row.update(status="incomplete", actual_delay="", response_fields="", polls="", ram_writes="", trace=str(manifest.parent / "snoop.csv"))
        trace = manifest.parent / "snoop.csv"
        release = pressed = response = probe_symbols = None
        polls = writes = 0
        if trace.exists():
            with trace.open(newline="") as stream:
                for event in csv.DictReader(stream):
                    frame, pos, keys = int(event["frame"]), int(event["pos"]), int(event["keys"])
                    if event["event"] == "key" and pos == meta["target_pos"] and keys == 0:
                        release = frame
                    if event["event"] == "key" and pos == meta["probe_pos"] and keys == 1 << meta["probe_key"]:
                        pressed = frame
                        probe_symbols = int(event["symbols"])
                    if pressed is not None or (meta["probe"] == "NONE" and release is not None and pos >= meta["probe_pos"]):
                        polls += event["event"] == "io-read" and int(event["addr"]) == 1
                        writes += event["event"] == "ram"
                        if (event["event"] == "mode" and int(event["symbols"]) != meta["symbols"] and response is None):
                            response = frame
        log_path = manifest.parent / "run.log"
        log = log_path.read_text(errors="replace") if log_path.exists() else ""
        observed_modes = {}
        for entry in log.splitlines():
            if entry.startswith("[source-key]"):
                values = dict(field.split("=", 1) for field in entry.split()[1:])
                if int(values["keys"], 16) != 1 << 11:
                    observed_modes[values["pos"]] = int(values["symbols"])
        setup_ok = all(observed_modes.get(pos) == value for pos, value in meta["setup_modes"].items())
        success = (meta.get("exit_code") == 0 and "entry finished" in log and
                   "NOTE: stopped on --max-cycles" not in log and setup_ok)
        if success and release is not None and (pressed is not None or meta["probe"] == "NONE"):
            row["actual_delay"] = pressed - release if pressed is not None else ""
            row["status"] = ("responded" if response is not None else "missed") if meta["probe"] == "SHIFT" else "unclassified"
            row["response_fields"] = response - release if response is not None else ""
            if pressed is not None and probe_symbols != meta["symbols"]:
                row["status"] = "invalid-mode"
        elif log and not setup_ok:
            row["status"] = "invalid-setup-mode"
        row.update(polls=polls, ram_writes=writes)
        rows.append(row)
    write_csv(out / "results.csv", rows, ["case", "length", "delay", "probe", "repeat", "status", "actual_delay", "response_fields", "polls", "ram_writes", "trace"])
    curve = []
    for name in sorted({row["case"] for row in rows}):
        tests = [row for row in rows if row["case"] == name and row["probe"] == "SHIFT"]
        if not tests:
            continue
        delays = sorted({row["delay"] for row in tests})
        tail = [delay for delay in delays if all(row["status"] == "responded" for row in tests if row["delay"] >= delay)]
        curve.append(dict(case=name, length=tests[0]["length"], tested_tail_fields=tail[0] if tail else "",
                          tested_ceiling_fields=max(delays)))
    write_csv(out / "shift_curve.csv", curve, ["case", "length", "tested_tail_fields", "tested_ceiling_fields"])
    points = [point for point in curve if point["tested_tail_fields"] != ""]
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="900" height="520" viewBox="0 0 900 520">',
           '<rect width="900" height="520" fill="white"/>',
           '<g font-family="sans-serif" font-size="14" fill="black">',
           '<text x="60" y="25">SHIFT response: smallest all-passing tested delay tail</text>',
           '<path d="M60 50V450H870" stroke="black" fill="none"/>',
           '<text x="300" y="505">Logical line length (characters)</text>',
           '<text x="60" y="475">Delay in video fields after NEXT release; no extrapolation</text>']
    ceiling = max([point["tested_ceiling_fields"] for point in curve] + [1])
    for y in range(0, 5):
        value = ceiling * y / 4
        svg.append(f'<text x="5" y="{450 - 380 * y / 4:.1f}">{value:g}</text>')
    for length in (0, 16, 32, 46, 64, 96, 125):
        svg.append(f'<text x="{60 + length * 6:.1f}" y="468">{length}</text>')
    colors = dict(sum="#2374ab", paren="#b5446e", condition="#39833b", clock="#a66100")
    for point in points:
        x, y = 60 + point["length"] * 6, 450 - point["tested_tail_fields"] * 380 / ceiling
        color = colors[point["case"].split("-")[0]]
        svg.append(f'<circle cx="{x}" cy="{y}" r="5" fill="{color}"><title>{point["case"]}: {point["tested_tail_fields"]} fields</title></circle>')
    svg.extend(['</g>', '</svg>'])
    (out / "shift_curve.svg").write_text("\n".join(svg), encoding="ascii")
    print(f"{out}: {len(rows)} trials; results.csv, shift_curve.csv, shift_curve.svg")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path("out/next-sweep"))
    parser.add_argument("--sim", type=Path, default=Path("obj_dir_headless/Vtop"))
    parser.add_argument("--families", default="sum,paren,condition,clock,clock-context")
    parser.add_argument("--lengths", default="3,15,31,47,63,95,125")
    parser.add_argument("--delays", default="0,16,32,48,64,72,96,128,192,256")
    parser.add_argument("--probes", default="SHIFT,CHAR,NONE")
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument("--hold", type=int, default=8)
    parser.add_argument("--settle", type=int, default=512)
    parser.add_argument("--observe", type=int, default=512)
    parser.add_argument("--prepare", action="store_true", help="write inputs and commands without running simulations")
    parser.add_argument("--analyze", action="store_true", help="summarize existing traces only")
    args = parser.parse_args()
    if args.analyze:
        analyze(args.out)
        return
    try:
        lengths = [int(value) for value in args.lengths.split(",")]
        delays = [int(value) for value in args.delays.split(",")]
        families, probes = args.families.split(","), args.probes.split(",")
        if not set(families) <= {"sum", "paren", "condition", "clock", "clock-context"} or not set(probes) <= {"SHIFT", "CHAR", "NONE"}:
            raise ValueError("unknown family or probe")
        if not all(3 <= n <= 125 for n in lengths) or not all(0 <= n <= 4096 for n in delays):
            raise ValueError("lengths must be 3..125; delays must be 0..4096")
        if not 1 <= args.hold <= 255 or min(args.repeat, args.settle, args.observe) < 1:
            raise ValueError("hold must be 1..255; repeat, settle and observe must be positive")
        trials = list(cases(families, lengths))
    except (ValueError, OSError) as error:
        parser.error(str(error))
    args.out.mkdir(parents=True, exist_ok=True)
    for name, prefix, line in trials:
        for delay in delays:
            for probe in probes:
                for repeat in range(args.repeat):
                    folder = args.out / f"{name}-{delay:04d}-{probe}-{repeat}"
                    folder.mkdir(exist_ok=True)
                    data, meta = trial(prefix, line, delay, probe, args.hold, args.settle, args.observe)
                    (folder / "input.vbk").write_bytes(data)
                    (folder / "input.txt").write_text("\n".join(prefix + [line]) + "\n", encoding="ascii")
                    meta.update(case=name, length=len(line), delay=delay, probe=probe, repeat=repeat)
                    command = [str(args.sim.resolve()), "--cart", str(CART), "--source", f"{(folder / 'input.vbk').resolve()}@210",
                               "--source-trace", "--source-snoop", str((folder / "snoop.csv").resolve()),
                               "--source-snoop-from", str(max(0, meta["target_pos"] - 3)),
                               "--frames", str(meta["budget_fields"]), "--max-cycles", str(meta["budget_fields"] * 400000),
                               "--shot-last", "--outdir", str(folder.resolve()), "--prefix", "final", "--quiet"]
                    meta["command"] = command
                    manifest = folder / "trial.json"
                    manifest.write_text(json.dumps(meta, indent=2) + "\n", encoding="ascii")
                    if not args.prepare:
                        if not args.sim.is_file() or not CART.is_file():
                            parser.error("simulator or cartridge missing; build headless first")
                        print(folder, flush=True)
                        with (folder / "run.log").open("w") as log:
                            meta["exit_code"] = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=False).returncode
                    manifest.write_text(json.dumps(meta, indent=2) + "\n", encoding="ascii")
    if args.prepare:
        print(f"Prepared {len(trials) * len(delays) * len(probes) * args.repeat} trials in {args.out}")
    else:
        analyze(args.out)


if __name__ == "__main__":
    main()
