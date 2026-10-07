#!/usr/bin/env python3
"""Summarize centered input and game state without whole-frame hashes."""

import json
from pathlib import Path
import re
import sys


def summarize(game, out):
    start, end = (365, 464) if game == "checkers" else (340, 419)
    channels = {}
    for line in (out / f"{game}_trace.txt").read_text().splitlines():
        match = re.search(r"\[joy-result\] frame=(\d+) latch=([0-9A-F]+) value=([0-9A-F]+).*bounds=(\S+)", line)
        if match and start <= int(match[1]) <= end:
            channel = channels.setdefault(match[2], {"values": [], "bounds": set()})
            channel["values"].append(int(match[3], 16))
            channel["bounds"].add(match[4])
    reads = {ch: {"count": len(v["values"]),
                  "range": f"{min(v['values']):02X}-{max(v['values']):02X}",
                  "bounds": sorted(v["bounds"])} for ch, v in sorted(channels.items())}

    addresses = [0xf0c, 0xf0d, 0xf0e, 0xf0f] if game == "checkers" else [
        0xfa5, 0xfa6, 0xfa7, 0xfa8, 0xc86, 0xc8a, 0xc8e, 0xc92]
    snapshots = []
    frame, ram = -1, {}
    for line in (out / f"{game}_state.txt").read_text().splitlines():
        match = re.search(r"========== frame (\d+)", line)
        if match:
            if start <= frame <= end:
                snapshots.append(tuple(ram[a] for a in addresses))
            frame, ram = int(match[1]), {}
        match = re.fullmatch(r"([0-9A-F]{4}): ((?:[0-9A-F]{2} ){16})", line)
        if match:
            base = int(match[1], 16)
            ram.update((base + i, int(v, 16)) for i, v in enumerate(match[2].split()))
    if start <= frame <= end:
        snapshots.append(tuple(ram[a] for a in addresses))
    expected = end - start + 1
    report = {"game": game, "interval": [start, end], "reads": reads,
              "samples": len(snapshots), "expected_samples": expected,
              "state_ranges": {f"{a:04X}": f"{min(s[i] for s in snapshots):02X}-{max(s[i] for s in snapshots):02X}"
                               for i, a in enumerate(addresses)} if snapshots else {},
              "state_fixed": len(snapshots) == expected and len(set(snapshots)) == 1}
    report["note"] = ("0F0C..0F0E cursor mask; 0F0F cursor index. Verify interior position in screenshots."
                      if game == "checkers" else
                      "0C86/0C8A/0C8E/0C92 player positions. 0FA5..0FA8 stores horizontal control state. Ball motion is independent.")
    text = json.dumps(report, indent=2) + "\n"
    (out / f"{game}_summary.json").write_text(text)
    print(text, end="")


if __name__ == "__main__":
    summarize(sys.argv[1], Path(sys.argv[2]))
