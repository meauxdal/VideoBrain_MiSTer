"""Audit saved full-ROM instruction chains without rebuilding the simulator."""

import argparse
import csv
from pathlib import Path
import re


MCLK = 14_318_181
HALF_HZ = 4_000_000
ROOT = Path(__file__).resolve().parents[2]


def tail(op):
    # PC telemetry advances at phase 7, including long DS fetches.
    return 6 if 0x30 <= op <= 0x3E else 2


def clocks(op):
    # Fairchild F3850 Table 3, printed pp. 3-21..3-25.
    if op in (0x08, 0x0C):
        return 16
    if op in (0x1A, 0x1C, 0x1D, 0xB1):
        return 8
    if op == 0x16:
        return 10
    if op == 0x28:
        return 26
    if 0x30 <= op <= 0x3E:
        return 6
    if op <= 7 or op in (0x0A, 0x0B, 0x1F) or 0x40 <= op <= 0x7F:
        return 4
    raise ValueError(f"No independent timing for opcode {op:02X}")


def inhibited(op):
    return op in (0x0C, 0x1B, 0x1C, 0x1D, 0x27, 0x28, 0x29) or 0xB4 <= op <= 0xBF


def buffered(address):
    return (address & 0x3FFF) >= 0x0800


def read_trace(path):
    rows = []
    for line in path.read_text().splitlines():
        if re.match(r"^\d+  PC0=", line):
            fields = dict(re.findall(r"(\w+)=([0-9A-F]+)", line))
            row = {k: int(v, 10 if k == "cycle" else 16) for k, v in fields.items()}
            rows.append(row)
    if not rows:
        raise ValueError("No CPU trace")
    origin = rows[0]["cycle"]
    for row in rows:
        # All rows were sampled on the same free-running CPU half-clock.
        # MCLK quantization is < 1 tick, or < 0.28 half clocks.
        row["n"] = round((row["cycle"] - origin) * HALF_HZ / MCLK)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", nargs="?", type=Path,
                        default=ROOT / "verilator/out/audio_bus_timing")
    args = parser.parse_args()
    trace = read_trace(args.capture / "cpu.txt")
    with (args.capture / "events.csv").open(newline="") as source:
        events = list(csv.DictReader(source))
    bios_dir = ROOT / "software/0 BIOS"
    res1 = next(bios_dir.glob("*uvres-1n*.bin")).read_bytes()
    cart = next((ROOT / "software/1 Cartridges").glob("Music Teacher 1 *[[]ED01].bin")).read_bytes()
    starts = []
    for row in trace:
        if row["romc"] == 0 and row["ph"] == 7:
            pc = (row["PC0"] - 1) & 0xFFFF
            physical = pc & 0x3FFF
            if physical < len(res1):
                expected = res1[physical]
            elif 0x1000 <= physical < 0x1000 + len(cart):
                expected = cart[physical - 0x1000]
            else:
                raise ValueError(f"Unverified opcode address {pc:04X}")
            if row["rdata"] != expected:
                raise ValueError(f"ROM fetch mismatch at {pc:04X}")
            starts.append(dict(row, pc=pc, code=expected, start=row["n"] + tail(row["op"])))
    print(f"Verified {len(starts)} opcode fetches against unmodified RES1/ED01 ROMs.")
    print(f"Trace coverage: MCLK {trace[0]['cycle']}..{trace[-1]['cycle']}.")
    print("PC labels below are opcode addresses; CSV irq_pc is a live counter.")
    covered = [r for r in events if trace[0]["cycle"] < int(r["irq_cycle"]) <
               int(r["ack_cycle"]) <= trace[-1]["cycle"]]
    delayed = [r for r in covered if int(r["ack_cycle"]) - int(r["irq_cycle"]) > 40 * MCLK / 1e6]
    if not delayed:
        raise ValueError("No covered delayed requests")
    for event in delayed:
        irq, ack = int(event["irq_cycle"]), int(event["ack_cycle"])
        accepts = [r for r in trace if irq <= r["cycle"] < ack and r["romc"] == 0x10 and r["ph"] == 1]
        if len(accepts) != 1:
            raise ValueError("Missing or repeated acceptance")
        accept = accepts[0]
        anchors = [r for r in starts if r["pc"] in (0x43AA, 0x40A9) and r["start"] < accept["n"]]
        if not anchors:
            raise ValueError("Missing DI entry")
        anchor = anchors[-1]
        if any(r["romc"] == 0x10 and r["ph"] == 1 and anchor["start"] <= r["n"] < accept["n"] for r in trace):
            raise ValueError("DI anchor crosses an earlier interrupt")
        chain = [r for r in starts if anchor["start"] <= r["start"] <= accept["n"]]
        active = lost = accesses = 0
        print(f"\nIRQ {irq}: live PC={event['irq_pc']}, ack={ack}, delay={(ack-irq)*1e6/MCLK:.3f} us")
        print("opcode   op   active clocks   lost half clocks")
        for i, row in enumerate(chain):
            last = i == len(chain) - 1
            end = accept["n"] if last else chain[i + 1]["start"]
            duration = clocks(row["code"]) - ((6 if tail(row["code"]) == 6 else 4) if last else 0)
            extra = end - row["start"] - 2 * duration
            if extra < 0:
                raise ValueError(f"Instruction too short at {row['pc']:04X}")
            bus_reads = int(not last and buffered(chain[i + 1]["pc"]))
            if row["code"] == 0x16:
                bus_reads += buffered(row["DC0"])
            if row["code"] == 0x28:
                bus_reads += buffered(row["pc"] + 1) + buffered(row["pc"] + 2)
            if not bus_reads and extra:
                raise ValueError(f"Unexplained delay without a buffered access at {row['pc']:04X}")
            active += duration
            lost += extra
            accesses += bus_reads
            print(f"{row['pc']:04X}     {row['code']:02X}       {duration:3}                {extra:2}")
        # Explicit fetch entries plus implicit single-ROMC instructions.
        boundaries = [r for r in trace if irq <= r["cycle"] <= accept["cycle"] and
                      r["ph"] == 1 and r["romc"] in (0, 0x10)]
        missed = [r for r in boundaries if r["romc"] == 0 and r["flags"] & 0x10 and not inhibited(r["op"])]
        for row in chain:
            if clocks(row["code"]) == (6 if tail(row["code"]) == 6 else 4):
                cycle = trace[0]["cycle"] + row["start"] * MCLK / HALF_HZ
                if irq + 1 < cycle < accept["cycle"] - 1 and row["flags"] & 0x10 and not inhibited(row["code"]):
                    missed.append(row)
        if missed:
            raise ValueError(f"Unexplained skipped fetches: {missed}")
        if not accept["flags"] & 0x10 or inhibited(accept["op"]):
            raise ValueError("Acceptance at a forbidden fetch")
        for row in boundaries:
            if row["op"] == 0x1A and row["flags"] & 0x10:
                raise ValueError("DI did not mask its final fetch")
            if row["op"] == 0x1D and row["flags"] != (row["j"] & 0x1F):
                raise ValueError("LR W,J did not restore the saved flags")
        ack_rows = [r for r in trace if accept["cycle"] < r["cycle"] < ack and r["romc"] == 0x0F and r["ph"] == 1]
        if len(ack_rows) != 1 or ack - ack_rows[0]["cycle"] != 1:
            raise ValueError("CSV acknowledgement does not match ROMC 0F")
        if ack_rows[0]["n"] - accept["n"] != 20:
            raise ValueError("Entry-to-ack differs from S + L")
        print(f"DI entry to acceptance: {active} active clocks + {lost} lost half clocks; {accesses} buffered reads.")
        print(f"First permitted fetch: live PC {accept['PC0']:04X}, op {accept['op']:02X}; no skipped permitted fetch found.")
        print(f"CSV mask/stall wall ticks: {event['masked_ticks']}/{event['stall_ticks']} (overlap; do not add).")
    print(f"\nAudited {len(delayed)} delays >40 us among {len(covered)} covered requests.")
    print("Sparse trace: inferred lost clocks are residuals, not independent arbiter validation.")
    print("The maximum delay in the complete CSV may be outside trace coverage.")


if __name__ == "__main__":
    main()
