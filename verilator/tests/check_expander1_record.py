"""Check the original-ROM record test's diagnostic edge capture."""

import csv
from pathlib import Path
import sys


def check(path):
    falls = []
    widths = []
    low_start = None
    stopped = False
    with path.open(newline="") as source:
        for stamp, level, enabled in csv.reader(source):
            time, unit = stamp.split()
            assert unit == "fs", stamp
            time = int(time) / 1e12  # milliseconds
            if enabled == "'1'":
                if level == "'0'":
                    falls.append(time)
                    low_start = time
                elif low_start is not None:
                    widths.append(time - low_start)
                    low_start = None
            elif falls:
                stopped = True
    assert stopped, "Missing remote stop"
    assert len(falls) == len(widths) == 342, len(falls)
    assert all(0.149 < width < 0.151 for width in widths), widths

    # Each bit has one pulse; a second pulse about 2 ms later encodes 1.
    bits = []
    index = 0
    while index < len(falls):
        one = index + 1 < len(falls) and falls[index + 1] - falls[index] < 2.3
        if one:
            gap = falls[index + 1] - falls[index]
            assert 1.99 < gap < 2.02, gap
        bits.append(int(one))
        index += 2 if one else 1
    assert len(bits) % 8 == 0, len(bits)
    decoded = bytes(sum(bits[i + j] << (7 - j) for j in range(8))
                    for i in range(0, len(bits), 8))
    expected = bytes([0xFF] * 16 + [0x01, 0xCD, 0, 1, 0xA5, 0x7E, 0xD6, 0])
    assert decoded == expected, decoded.hex(" ")
    path.with_suffix(".bin").write_bytes(decoded)
    print(f"Record decoded: {len(decoded)} bytes, 342 pulses, firmware CRC 7E D6")


if __name__ == "__main__":
    check(Path(sys.argv[1]))
