"""Measure Sean's 2 MHz sample-index cassette CSV and compare tone symbols."""
import argparse
from collections import Counter
import csv
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/"tools"))
from tape_convert import CLOCK, read_vbt


def summarize(source, reference):
    with source.open(newline="") as f:
        rows = csv.reader(f)
        if [x.strip() for x in next(rows)] != ["Sample", "Data[binary]"]:
            raise ValueError("expected Logic sample-index export")
        edges = [(int(t), int(level)) for t, level in rows]
    if any(b[0] <= a[0] or a[1] == b[1] or b[1] not in (0, 1)
           for a, b in zip(edges, edges[1:])):
        raise ValueError("unordered or nonalternating transitions")
    runs = [(a[1], b[0]-a[0]) for a, b in zip(edges, edges[1:])]
    # Separate long idle gaps before classifying the 1/2 ms tone intervals.
    high = [ticks/2e6 for level, ticks in runs if level == 1]
    symbols = [int(seconds > .00135) for seconds in high if seconds < .1]
    blocks, current = [], []
    for seconds in high:
        if seconds >= .1:
            if current: blocks.append(current); current = []
        else: current.append(int(seconds > .00135))
    if current: blocks.append(current)
    ref = read_vbt(reference)
    ref_symbols = [int(ticks/CLOCK > .00135) for level, ticks in ref
                   if level == 1 and ticks/CLOCK < .1]
    result = {
        "input": str(source), "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "sample_rate_hz": 2000000, "transitions": len(edges),
        "first_sample": edges[0][0], "last_sample": edges[-1][0],
        "observed_span_s": (edges[-1][0]-edges[0][0])/2e6,
        "low_pulse_modes_us": {str(ticks/2): n for ticks,n in Counter(ticks for level,ticks in runs if level == 0).most_common(5)},
        "high_interval_modes_us": {str(ticks/2): n for ticks,n in Counter(ticks for level,ticks in runs if level == 1 and ticks<200000).most_common(8)},
        "idle_gaps_s": [x for x in high if x >= .1],
        "symbols": len(symbols), "symbols_by_block": list(map(len, blocks)),
        "first_three_blocks_identical": len(blocks)>=3 and blocks[0]==blocks[1]==blocks[2],
        "next_three_blocks_identical": len(blocks)>=6 and blocks[3]==blocks[4]==blocks[5],
        "reference": str(reference), "reference_symbols": len(ref_symbols),
        "symbol_length_difference": len(symbols)-len(ref_symbols),
        "symbol_mismatches": sum(a != b for a,b in zip(symbols,ref_symbols)),
        "limitations": "Tone classifications only; not record/checksum decoding. No assumption about level before the first sample or duration after the final transition. No timing normalization or polarity change.",
    }
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=Path)
    parser.add_argument("reference", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = summarize(args.csv, args.reference)
    args.output.write_text(json.dumps(result, indent=2)+"\n")
    print(json.dumps(result, indent=2))
