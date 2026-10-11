#!/usr/bin/env python3
"""Run the existing BIOS gain path with controlled span and delta inputs."""

import argparse
import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parent
THRESHOLDS = (1333, 1599, 1867, 2399)
BIOS = ROOT.parent / "software"


def gain(span):
    return next((g for t, g in zip(THRESHOLDS, (8, 6, 4, 3)) if span < t), 2)


def prepare(out):
    cases = [(t + offset, 192) for t in THRESHOLDS for offset in (-1, 0, 1)]
    cases += [(1147, delta) for delta in (0, 255, 256, 398, 400, 511, 576)]
    cart = bytearray(bytes.fromhex("AA5500") + bytes(15))

    def emit(*data):
        cart.extend(data)

    def address(op, value):
        emit(op, value >> 8, value & 255)

    address(0x28, 0x40D0)
    emit(0x1A)
    calls = []
    for i in range(len(cases)):
        calls.append(len(cart))
        address(0x28, 0)
        address(0x2A, 0xC00 + i * 3)
        emit(0x17, 0x02, 0x17, 0x03, 0x17)
    address(0x2A, 0xC80)
    emit(0x20, 0xA5, 0x17)
    address(0x29, 0x1000 + len(cart))
    for call, (span, delta) in zip(calls, cases):
        target = 0x1000 + len(cart)
        cart[call + 1:call + 3] = target.to_bytes(2, "big")
        emit(0x08)
        address(0x28, 0x40A9)  # PI PUSHK, for the BIOS POPK return.
        emit(0x62, 0x69, 0x20, delta >> 8, 0x5D,
             0x20, delta & 255, 0x5E)
        address(0x2A, span)
        emit(0x0E)
        address(0x29, 0x225E)
    assert len(cart) <= 2048
    out.mkdir(parents=True, exist_ok=True)
    (out / "cart.bin").write_bytes(cart + bytes(2048 - len(cart)))
    res1 = bytearray((BIOS / "VideoBrain BIOS (1977)(VideoBrain Computer Company)(VideoBrain)(ROM)[uvres-1n-2129-7802].bin").read_bytes())
    res1[:3] = bytes.fromhex("291012")  # Skip game startup; retain stack helpers.
    (out / "res1.bin").write_bytes(res1)
    plan = [{"span": span, "delta": delta, "gain": gain(span),
             "product": delta * gain(span), "result": min(199, delta * gain(span) >> 4)}
            for span, delta in cases]
    (out / "plan.json").write_text(json.dumps(plan, indent=2) + "\n")
    return plan


def check(out, plan):
    trace = (out / "trace.txt").read_text()
    # PC telemetry can precede LIS completion; count the actual add-loop calls.
    selected = [block.count("pc=2297 ") for block in re.split(r"\[joy-bios\][^\n]*pc=228D ", trace)[1:]]
    memory = {}
    for base, values in re.findall(r"^\s*([0-9A-F]{4}): ((?:[0-9A-F]{2} ?){16})", (out / "state.txt").read_text(), re.M):
        memory.update((int(base, 16) + i, int(v, 16)) for i, v in enumerate(values.split()))
    assert memory.get(0xC80) == 0xA5, "diagnostic did not complete"
    assert len(selected) == len(plan), f"expected {len(plan)} gain selections, got {len(selected)}"
    for i, case in enumerate(plan):
        result = memory[0xC00 + i * 3]
        product = memory[0xC01 + i * 3] * 256 + memory[0xC02 + i * 3]
        assert (selected[i], product, result) == (case["gain"], case["product"], case["result"]), (case, selected[i], product, result)
    print(f"PASS: {len(plan)} BIOS gain/product/clamp cases")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / "out/joystick/gain_check")
    parser.add_argument("--run", action="store_true", help="run the existing headless binary; no build")
    args = parser.parse_args()
    out = args.out.resolve()
    plan = prepare(out)
    if args.run:
        with (out / "trace.txt").open("w") as log:
            subprocess.run([str(ROOT / "obj_dir_headless/Vtop"), "--res1", str(out / "res1.bin"),
                            "--cart", str(out / "cart.bin"), "--frames", "3", "--max-cycles", "2000000",
                            "--joy-trace", "0", "--dump", "2", "--ram", "--dump-file", str(out / "state.txt"),
                            "--quiet"], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
        check(out, plan)
    else:
        print(f"Prepared {len(plan)} cases: {out}")


if __name__ == "__main__":
    main()
