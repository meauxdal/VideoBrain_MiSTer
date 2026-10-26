#!/usr/bin/env python3
"""Create an experimental static-staff Music Teacher 1 ED01 cartridge.

Keep pitch decoding, sound, recording, keyboard polling and rest timing intact.
Suppress staff glyphs and clear the five-row note-name strip at page wrap.
See docs/MUSIC-TEACHER-PATCH.md for scope and timing limitations.
"""
import argparse
import hashlib
from pathlib import Path


ED01_SHA256 = "6f68d96533795159a18d757629a0fb5d5fa5d228c43361d8565b84cb1ee3d198"

# $1388 is unreachable after bypassing the staff renderer at $1368.
# No nested PI calls: POP returns directly to the page-wrap caller.
#   LIS 0 / LR R0,A / LR R1,A     reset the original page counters
#   DCI $0EC4 / LI 60 / LR R8,A   five scanlines, twelve bytes each
#   LIS 0
# loop: ST / DS R8 / BF 4,loop
#   POP
PAGE_WRAP = "70 50 51 2a 0e c4 20 3c 58 70 17 38 94 fd 1c"

PATCHES = (
    # Preserve decoding and the PUSHK/POPK pairing in A1341.
    # $136B remains the page-wrap entry used by the original static patch.
    (0x1368, "65 6d 20 10 5c 28 14", "29 13 d5 29 13 88 2b"),
    (0x1388, "2a 0c 00 40 18 1f 24 03 58 84 10 20 54 8e 8e", PAGE_WRAP),
    (0x10DC, "28 13 d9", "28 13 6b"),  # live note page wrap
    (0x1288, "28 13 d9", "28 13 6b"),  # replay page wrap
    (0x1540, "28 13 d9", "28 13 6b"),  # rest page wrap
    # Preserve rest slots/counters; bypass only the rest glyph.
    (0x1546, "65 6d 2a", "29 15 5f"),
)


def patch_rom(data):
    if len(data) != 2048 or hashlib.sha256(data).hexdigest() != ED01_SHA256:
        raise ValueError("expected the original 2048-byte Music Teacher 1 ED01 ROM")
    patched = bytearray(data)
    for address, before, after in PATCHES:
        offset = address - 0x1000
        expected, replacement = bytes.fromhex(before), bytes.fromhex(after)
        if (len(expected) != len(replacement)
                or data[offset:offset + len(expected)] != expected):
            raise ValueError(f"unexpected instructions at ${address:04X}")
        patched[offset:offset + len(replacement)] = replacement
    return bytes(patched)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="original ED01 cartridge image")
    parser.add_argument("output", type=Path, help="new experimental cartridge image")
    args = parser.parse_args()
    try:
        patched = patch_rom(args.source.read_bytes())
        with args.output.open("xb") as output:
            output.write(patched)
    except (OSError, ValueError) as error:
        parser.exit(1, f"error: {error}\n")
    print(f"{args.output}: {len(patched)} bytes, "
          f"SHA256 {hashlib.sha256(patched).hexdigest()}")


if __name__ == "__main__":
    main()
