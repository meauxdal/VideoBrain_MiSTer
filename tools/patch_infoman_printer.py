#!/usr/bin/env python3
"""Create an experimental Information Manager cartridge with printer corrections."""
import argparse
import hashlib
from pathlib import Path


INFOMAN_SHA256 = "9b580726ad5d899a316901ad4513622a9e66e8131da3d6ac3de40180a2200d8f"

# 36C6 scrolls R0 rows before formatting the next printer buffer.
# Preserve its cursor clear; save that row count in the printer's 0C28.
# The two stubs occupy padding and return through PI's hardware link.
PATCHES = (
    (0x36CA, "70 2a 0f df 17", "28 17 f8 2b 2b"),
    # LR A,R0 / DCI 0C28 / ST / JMP 3FF9
    (0x17F8, "bd bd bd bd bd bd bd bd", "40 2a 0c 28 17 29 3f f9"),
    # CLR / DCI 0FDF / ST / POP
    (0x3FF9, "f0 f0 f0 f0 f0 f0", "70 2a 0f df 17 1c"),
)

# 3DEC already selects callback 3E17. Its final routing bit leaves R2=0.
# Wait 256 DS/BNZ iterations for that bit to be sampled, then drive mark
# before the first 300-baud timer copy. Later bytes end with R2=1 and wait
# one iteration. Keep the original start, eight data bits and two stop bits.
SERIAL_IDLE_PATCH = (
    0x3E31, "20 3e 06 20 17 07", "32 94 fe 20 20 b1",
)


def rom_offset(address):
    if 0x1000 <= address < 0x1800:
        return address - 0x1000
    if 0x3000 <= address < 0x4000:
        return address - 0x2000
    raise ValueError(f"address outside cartridge ROM: {address:04X}")


def patch_rom(data, serial_idle=False):
    if len(data) != 8192 or hashlib.sha256(data).hexdigest() != INFOMAN_SHA256:
        raise ValueError("expected the original 8192-byte Information Manager ROM")
    patched = bytearray(data)
    patches = PATCHES + ((SERIAL_IDLE_PATCH,) if serial_idle else ())
    for address, before, after in patches:
        offset = rom_offset(address)
        expected, replacement = bytes.fromhex(before), bytes.fromhex(after)
        if (len(expected) != len(replacement)
                or data[offset:offset + len(expected)] != expected):
            raise ValueError(f"unexpected bytes at ${address:04X}")
        patched[offset:offset + len(replacement)] = replacement
    return bytes(patched)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="original cartridge image")
    parser.add_argument("output", type=Path, help="new experimental cartridge image")
    parser.add_argument("--serial-idle", action="store_true",
                        help="also prime serial idle after the 300-baud setup command")
    args = parser.parse_args()
    try:
        patched = patch_rom(args.source.read_bytes(), args.serial_idle)
        with args.output.open("xb") as output:
            output.write(patched)
    except (OSError, ValueError) as error:
        parser.exit(1, f"error: {error}\n")
    print(f"{args.output}: {len(patched)} bytes, "
          f"SHA256 {hashlib.sha256(patched).hexdigest()}")


if __name__ == "__main__":
    main()
