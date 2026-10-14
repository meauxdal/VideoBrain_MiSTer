#!/usr/bin/env python3
"""Convert APL/S keyboard input text to a validated VBK stream."""
import argparse
import binascii
from pathlib import Path
import struct


LETTERS = dict(zip("IOP;UKL,YJMT HNRGBE FVWDCQSXAZ?".replace(" ", ""),
                   [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14,
                    16, 17, 18, 20, 21, 22, 24, 25, 26, 28, 29, 30, 32, 33, 34]))
SYMBOLS = dict(zip("0123456789", [34, 33, 30, 26, 29, 25, 21, 24, 20, 16]))
SYMBOLS.update({".": 32, "-": 17, "+": 22, "=": 18, "(": 9, ")": 5,
                "*": 7, "/": 13, ",": 14, ":": 10, '"': 0,
                "\u00d7": 12, "\u00f7": 8, "\u03c0": 3, "\u00af": 2})
NORMALIZE = {"\u201c": '"', "\u201d": '"', "\u2212": "-",
             "\u00a0": " ", "\t": " "}
MAX_KEYS = 4096


def encode(text):
    if text.startswith("\ufeff"):
        text = text[1:]
    keys = bytearray()
    for line_no, line in enumerate(text.splitlines(), 1):
        line = line.strip(" \t")
        if not line:
            continue
        for column, char in enumerate(line, 1):
            char = NORMALIZE.get(char, char)
            if char == " ":
                keys.append(0x80 | 19)
            elif char in SYMBOLS:
                keys.append(0x40 | SYMBOLS[char])
            elif char.upper() in LETTERS:
                keys.append(LETTERS[char.upper()])
            else:
                raise ValueError(f"line {line_no}, column {column}: unsupported character {char!r}")
        keys.append(0x80 | 27)
    if not keys:
        raise ValueError("source contains no input")
    if len(keys) > MAX_KEYS:
        raise ValueError(f"source needs {len(keys)} keys; limit is {MAX_KEYS}")
    return b"VBK1" + struct.pack("<HH", len(keys), binascii.crc_hqx(keys, 0xffff)) + keys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    try:
        data = encode(args.source.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError) as error:
        parser.exit(1, f"error: {error}\n")
    output = args.output or args.source.with_suffix(".vbk")
    if output.resolve() == args.source.resolve():
        parser.exit(1, "error: output would overwrite source\n")
    output.write_bytes(data)
    print(f"{output}: {len(data) - 8} keys")


if __name__ == "__main__":
    main()
