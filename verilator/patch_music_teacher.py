#!/usr/bin/env python3
"""Create an experimental ED01 ROM with a static staff for Program 1."""
import argparse
import hashlib
from pathlib import Path


ED01_SHA256 = "6f68d96533795159a18d757629a0fb5d5fa5d228c43361d8565b84cb1ee3d198"

# CPU addresses and expected/replacement bytes from musicteacher1-ed01.asm.
PATCHES = (
    # Keep note decoding through $1367; return before glyph rendering.
    # $136B: CLR; LR R0,A; LR R1,A; POP replaces page redraw at wrap.
    (0x1368, "65 6d 20 10 5c 28 14", "29 13 d5 70 50 51 1c"),
    (0x10DC, "28 13 d9", "28 13 6b"),
    (0x1288, "28 13 d9", "28 13 6b"),
    (0x1540, "28 13 d9", "28 13 6b"),
    # Keep the rest/page counters, then return before rest rendering.
    (0x1546, "65 6d 2a", "29 15 5f"),
)


def patch_rom(data):
    if hashlib.sha256(data).hexdigest() != ED01_SHA256:
        raise ValueError("expected the original 2048-byte Music Teacher 1 ED01 ROM")
    patched = bytearray(data)
    for address, before, after in PATCHES:
        offset = address - 0x1000
        expected, replacement = bytes.fromhex(before), bytes.fromhex(after)
        if len(expected) != len(replacement) or data[offset:offset + len(expected)] != expected:
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
    print(f"{args.output}: {len(patched)} bytes, SHA256 {hashlib.sha256(patched).hexdigest()}")


if __name__ == "__main__":
    main()
