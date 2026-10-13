#!/usr/bin/env python3
import argparse
import csv
import re
import subprocess
from pathlib import Path


CASES = {
    "01-sine": (None, ["BARH(64{MUL}SIN(INDEX 7{MUL}25{MUL}{PI}{DIV}180))"], "Sine bars"),
    "02-fibonacci": (None, ["BARH FLOOR(.5+((1.618*INDEX 7){DIV}(5*.5)))"], "Fibonacci bars"),
    "03-random": (None, ["BARC RAND(15+ARRA 7)", "BARH RAND(63+ARRA 7)"], "Random bar colors and heights"),
    "04-guess": ("guess", ["GUES", "1", "1"], "Completed game; score 1 1"),
    "05-min": (None, ["BARH((Z=INDE 7)MIN(8-Z)){MUL}14"], "Symmetric pyramid bars"),
    "06-factorial": (None, ["EDIT F", "Y", "IF N NE 0", "THEN Y=Y{MUL}N", "N=N-1", "F", "ENDI", "ENDP", "ENDE", "N=5", "Y=1", "F"], "Factorial output ending in 120"),
    "07-slots": ("slots", ["SLOT"], "Bet prompt and slot bars"),
    "08-acey": ("aceyducey", ["ACEY"], "Acey Ducey prompt"),
    "09-lander": ("lunarlander", ["LL"], "Lunar Lander fuel/burn prompt"),
    "10-sphere": ("unicircle", ["UNI"], "Sphere coordinates and bars"),
    "11-gunner": ("gun", ["GUN"], "Target distance and firing prompt"),
    "12-dicejack": ("dicejack", ["D"], "Dicejack prompt"),
    "13-primes": ("primebarchart", ["P"], "Prime numbers and bars"),
    "14-collatz": ("collatz", ["C"], "Collatz number prompt"),
    "15-stats": ("dstats", ["D"], "Data entry prompt"),
    "16-lotto": ("lottochartmethod1", ["L"], "Lottery numbers and bars"),
    "17-pi": ("estimatepibarchart", ["PI", "10"], "Pi estimate and bars"),
    "18-taylor": ("taylorseries", ["T"], "Taylor sequence output"),
    "19-stag": ("stagorharegraph", ["S"], "Stag Hunt prompt"),
    "20-bulls": ("bullsandcows4digits", ["M"], "Four digit Bulls and Cows prompt"),
    "21-clock": ("clocknye2026", ["C"], "Clock output"),
    "22-roulette": ("roulette", ["R"], "Roulette betting prompt"),
    "23-change": ("coinchange", ["Q=D=N=P=0", "X=89", "C"], "Final X Q D N P: 0 3 1 0 4"),
    "02-recursive": ("recursivefib", ["FIB"], "Recursive Fibonacci output"),
    "13-sieve": ("primesieve", ["S"], "Sieve output"),
    "16-method2": ("lottochartmethod2", ["L"], "Lottery numbers and bars"),
    "20-three": ("bullsandcows3digits", ["M"], "Three digit Bulls and Cows prompt"),
}

SYMBOLS = dict(zip("0123456789", ["QUESTION", "Z", "X", "C", "S", "D", "F", "W", "E", "R"]))
SYMBOLS.update({
    ".": "A", "-": "G", "+": "V", "=": "B", "(": "J", ")": "K",
    "*": "QUOTE", "/": "H", ",": "N", ":": "M", '"': "I",
    "{MUL}": "T", "{DIV}": "Y", "{PI}": "SEMI", "{NEG}": "P",
})


def schedule(lines, settle=64, normalize=False, leave_edit=False, symbols=False):
    frame = 224
    presses, shots = [], []

    def press(key):
        nonlocal frame
        presses.extend(["--press", f"{key}@{frame}:8"])
        frame += 16

    if normalize:
        if leave_edit:
            press("SPECIAL")
        press("ERASE")
        frame += 64
        shots.append(frame - 1)
        if leave_edit:
            lines = ["ENDE", *lines]
    for index, line in enumerate(lines):
        for token in re.findall(r"\{[A-Z]+\}|.", line):
            if token == " ":
                press("SPACE")
                continue
            upper = token in SYMBOLS
            if not upper and not (len(token) == 1 and "A" <= token <= "Z"):
                raise ValueError(f"Unsupported input: {token}")
            if upper != symbols:
                press("SHIFT")
                symbols = upper
            press(SYMBOLS[token] if upper else token)
        press("NEXT")
        frame += 64 if leave_edit and index == 0 else settle
        shots.append(frame - 1)
        if leave_edit and index == 0:
            press("ERASE")
            frame += 64
            shots.append(frame - 1)
    return presses, shots, frame


def main():
    parser = argparse.ArgumentParser(description="Capture APL/S reference programs for visual verification.")
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--all", action="store_true")
    selection.add_argument("--case", choices=CASES, action="append")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--settle", type=int, default=64, help="Frames to wait after each submitted line")
    parser.add_argument("--normalize", action="store_true", help="Clear pending snapshot input")
    parser.add_argument("--leave-edit", action="store_true", help="Also leave edit mode; use only for snapshots in edit mode")
    parser.add_argument("--trace-final", type=int, default=0, help="Trace this many CPU memory cycles starting in the final frame")
    parser.add_argument("--outdir", default="out/apl/suite", help="Capture directory relative to verilator")
    args = parser.parse_args()
    if args.settle < 1:
        parser.error("--settle must be positive")
    if args.leave_edit and not args.normalize:
        parser.error("--leave-edit requires --normalize")
    if args.trace_final < 0:
        parser.error("--trace-final must be nonnegative")
    selected = list(CASES) if args.all else args.case or []
    if not selected:
        for name, (_, _, expected) in CASES.items():
            print(f"{name:16} {expected}")
        return

    simdir = Path(__file__).resolve().parent
    software = simdir.parent / "software"
    executable = simdir / "obj_dir_headless/Vtop"
    cartridge = software / "converted/The Computational Language (APL-S).bin"
    planned = []
    for name in selected:
        snapshot, lines, expected = CASES[name]
        normalize = args.normalize and bool(snapshot)
        outdir = simdir / args.outdir / name
        command = [str(executable), "--cart", str(cartridge)]
        symbols = False
        if snapshot:
            image = software / "21 games for apl_s" / f"{snapshot}.bin"
            if not image.is_file():
                parser.error(f"Missing snapshot: {image}")
            data = image.read_bytes()
            if len(data) != 16384:
                parser.error(f"Invalid snapshot size: {image}")
            # APL/S SHIFT latch: 0 = letters, 1 = symbols.
            symbols = bool(data[0x0FE2] & 1)
            command += ["--apl", f"{image}@210"]
        presses, shots, frames = schedule(lines, args.settle, normalize,
                                         normalize and args.leave_edit, symbols)
        captures = ",".join(map(str, [199, 211, *shots]))
        command += presses + ["--frames", str(frames), "--shot", captures,
                              "--dump", captures, "--ram", "--prefix", name,
                              "--outdir", str(outdir), "--dump-file", str(outdir / "state.txt")]
        if args.trace_final:
            command += ["--trace-from", str(frames - 1), "--trace-cpu", str(args.trace_final)]
        planned.append((name, command, outdir, expected))
        print(f"{name}: {frames} frames; expected: {expected}", flush=True)

    if args.dry_run:
        return
    if not executable.is_file() or not cartridge.is_file():
        parser.error("Build the headless simulator and assemble the APL/S cartridge first.")
    summary = simdir / args.outdir / "summary.tsv"
    summary.parent.mkdir(parents=True, exist_ok=True)
    with summary.open("w", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t")
        writer.writerow(["case", "capture", "expected", "directory"])
        for name, command, outdir, expected in planned:
            outdir.mkdir(parents=True, exist_ok=True)
            with (outdir / "run.log").open("w") as log:
                result = subprocess.run(command, cwd=simdir, stdout=log, stderr=subprocess.STDOUT)
            status = "captured" if result.returncode == 0 else f"failed ({result.returncode})"
            writer.writerow([name, status, expected, str(outdir)])
            stream.flush()
            print(f"{name}: {status}", flush=True)
    print(f"Inspect PNGs and logs; captures are not verified passes. Summary: {summary}")


if __name__ == "__main__":
    main()
