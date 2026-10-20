"""Check the original-ROM record test's diagnostic edge capture."""

import argparse
import binascii
import csv
from pathlib import Path


def check(path, workspace=False):
    falls = []
    widths = []
    low_start = None
    stopped = False
    with path.open(newline="") as source:
        rows = csv.reader(source)
        first = next(rows)
        cycles = first == ["cycle", "level", "enabled"]
        if not cycles:
            source.seek(0)
        for stamp, level, enabled in rows:
            if cycles:
                time = int(stamp) / 14318.18  # milliseconds
                level, enabled = f"'{level}'", f"'{enabled}'"
            else:
                time, unit = stamp.split()
                assert unit == "fs", stamp
                time = int(time) / 1e12  # milliseconds
            if enabled == "'1'":
                stopped = False
                if level == "'0'":
                    falls.append(time)
                    low_start = time
                elif low_start is not None:
                    widths.append(time - low_start)
                    low_start = None
            elif falls:
                stopped = True
    assert stopped, "Missing remote stop"
    assert falls and len(falls) == len(widths), len(falls)
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
    if workspace:
        offset = 0
        while offset < len(decoded):
            assert decoded[offset:offset + 18] == bytes([0xFF] * 16 + [1, 0xCD]), offset
            start = offset + 18
            size = int.from_bytes(decoded[start:start + 2], "big")
            end = start + 2 + size
            assert end + 3 <= len(decoded), "Truncated record"
            crc = int.from_bytes(decoded[end:end + 2], "little")
            assert binascii.crc_hqx(decoded[start:end], 0) == crc, "CRC mismatch"
            assert decoded[end + 2] == 0, "Missing trailer"
            print(f"Record at {offset}: {size} payload bytes, CRC {crc:04X}")
            offset = end + 3
    else:
        assert len(falls) == 342, len(falls)
        assert decoded == expected, decoded.hex(" ")
    path.with_suffix(".bin").write_bytes(decoded)
    print(f"Record decoded: {len(decoded)} bytes, {len(falls)} pulses")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--workspace", action="store_true",
                        help="check variable-length records using timing index 00")
    args = parser.parse_args()
    check(args.capture, args.workspace)
