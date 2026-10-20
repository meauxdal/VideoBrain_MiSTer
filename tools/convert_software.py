#!/usr/bin/env python3
"""Assemble local MAME cartridge dumps without duplicating existing images."""

import hashlib
from pathlib import Path
import sys
import zipfile
import zlib


APL_NAME = "APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin"
INFO_NAME = "Information Manager (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)(prototype)[VB-1200].bin"


APL_CHIPS = [
    ("0310_apls-a.u1", "e0b883c8"),
    ("0311_apls-b.u4", "93c869d2"),
    ("0312_apls-c.u3", "98fbf99c"),
    ("0313_apls-d.u6", "31adadcc"),
    ("0314_apls-e.u2", "47048589"),
    ("0315_apls-f.u5", "b74e799e"),
    ("0316_apls-g.u11", "6d5773fa"),
]
INFO_CHIPS = [
    ("vb1200a_1000-17ff_9_25_78_51", "7fc58830"),
    ("vb1200c_3000-37ff_9_25_78_51", "e5d18447"),
    ("vb-1200_3800-3fff_9_26_78", "df9d9437"),
]


def crc(data):
    return f"{zlib.crc32(data):08x}"


def read_chips(archive, chips):
    with zipfile.ZipFile(archive) as source:
        result = [source.read(name) for name, _ in chips]
    for data, (name, expected) in zip(result, chips):
        if len(data) != 2048 or crc(data) != expected:
            raise ValueError(f"Unexpected chip dump: {archive.name}/{name}")
    return result


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / "software"
    archives = root / "vidbrain (MAME)"
    output = root / "converted"
    output.mkdir(exist_ok=True)
    rows = []

    def write(name, data):
        target = output / name
        if target.exists() and target.read_bytes() != data:
            raise ValueError(f"Output already exists with different bytes: {target}")
        target.write_bytes(data)
        rows.append(f"{name}\t{len(data)}\t{crc(data)}\t{hashlib.sha1(data).hexdigest()}")

    apl_parts = read_chips(archives / "complang.zip", APL_CHIPS)
    apl = b"".join(apl_parts) + bytes(2048)
    write(APL_NAME, apl)
    older = archives / "complang (older).zip"
    if older.exists():
        old = b"".join(read_chips(older, APL_CHIPS)) + bytes(2048)
        if old != apl:
            write(APL_NAME.replace("(Cart)", "(Cart)(older)"), old)
        else:
            print("Older APL archive is identical; skipped.")
    info = read_chips(archives / "infoman.zip", INFO_CHIPS)
    write(INFO_NAME, info[0] + bytes(2048) + info[1] + info[2])

    existing = {hashlib.sha1(p.read_bytes()).digest() for p in root.glob("*.bin")}
    matched = 0
    for archive in sorted(archives.glob("*.zip")):
        if archive.stem.startswith("complang") or archive.stem == "infoman":
            continue
        with zipfile.ZipFile(archive) as source:
            names = source.namelist()
            if len(names) != 1:
                raise ValueError(f"Unknown split cartridge: {archive}")
            data = source.read(names[0])
        if hashlib.sha1(data).digest() in existing:
            matched += 1
        else:
            write(f"{archive.stem} (MAME).bin", data)
    (output / "checksums.tsv").write_text("file\tbytes\tcrc32\tsha1\n" + "\n".join(rows) + "\n", encoding="ascii")
    print(f"{matched} existing cartridges match MAME; {len(rows)} images written to {output}.")


if __name__ == "__main__":
    main()
