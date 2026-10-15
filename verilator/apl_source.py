#!/usr/bin/env python3
"""Convert APL/S keyboard input text to a validated VBK stream."""
import argparse
import binascii
from pathlib import Path
import re
import struct


LETTERS = {"I": 0, "O": 1, "P": 2, "U": 4, "K": 5, "L": 6,
           "Y": 8, "J": 9, "M": 10, "T": 12, "H": 13, "N": 14,
           "R": 16, "G": 17, "B": 18, "E": 20, "F": 21, "V": 22,
           "W": 24, "D": 25, "C": 26, "Q": 28, "S": 29, "X": 30,
           "A": 32, "Z": 33, "?": 34}
SYMBOLS = dict(zip("0123456789", [34, 33, 30, 26, 29, 25, 21, 24, 20, 16]))
SYMBOLS.update({".": 32, "-": 17, "+": 22, "=": 18, "(": 9, ")": 5,
                "*": 7, "/": 13, ",": 14, ":": 10, '"': 0, "!": 4, "$": 6, "#": 1,
                "\u00d7": 12, "\u00f7": 8, "\u03c0": 3, "\u00af": 2})
SYMBOLS.update({"{MUL}": 12, "{DIV}": 8, "{PI}": 3, "{NEG}": 2})
NORMALIZE = {"\u201c": '"', "\u201d": '"', "\u2212": "-",
             "\u00a0": " ", "\t": " "}
MAX_KEYS = 4096


def encode(text, hold_final=False):
    if text.startswith("\ufeff"):
        text = text[1:]
    keys = bytearray()
    for line_no, line in enumerate(text.splitlines(), 1):
        offset = len(line) - len(line.lstrip(" \t"))
        line = line.strip(" \t")
        if not line:
            continue
        for match in re.finditer(r"\{[A-Z]+\}|.", line):
            column = offset + match.start() + 1
            char = match.group()
            char = NORMALIZE.get(char, char)
            if char == " ":
                keys.append(0x80 | 19)
            elif char in SYMBOLS:
                keys.append(0x40 | SYMBOLS[char])
            elif char.isascii() and char.upper() in LETTERS:
                keys.append(LETTERS[char.upper()])
            else:
                raise ValueError(f"line {line_no}, column {column}: unsupported character {char!r}")
        keys.append(0x80 | 27)
    if not keys:
        raise ValueError("source contains no input")
    if hold_final:
        keys.pop()
    if len(keys) > MAX_KEYS:
        raise ValueError(f"source needs {len(keys)} keys; limit is {MAX_KEYS}")
    return b"VBK1" + struct.pack("<HH", len(keys), binascii.crc_hqx(keys, 0xffff)) + keys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    parser.add_argument("--hold-final", action="store_true",
                        help="leave the last line unsubmitted (omit its NEXT)")
    args = parser.parse_args()
    try:
        data = encode(args.source.read_text(encoding="utf-8"), args.hold_final)
    except (OSError, UnicodeError, ValueError) as error:
        parser.exit(1, f"error: {error}\n")
    output = args.output or args.source.with_suffix(".vbk")
    if output.resolve() == args.source.resolve():
        parser.exit(1, "error: output would overwrite source\n")
    try:
        output.write_bytes(data)
    except OSError as error:
        parser.exit(1, f"error: {error}\n")
    print(f"{output}: {len(data) - 8} keys")


if __name__ == "__main__":
    main()
