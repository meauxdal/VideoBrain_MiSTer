"""Inspect VBT1 records or extract an APL/S cassette from a 16K memory dump."""

import argparse
import binascii
from pathlib import Path
import struct


CLOCK = 14318180
SYNC = b"\xff" * 16 + b"\x01\xcd"
# SAVE writes a two-byte length before each payload.
SAVE_RANGES = ((0x0E50, 67), (0x1C02, 1001))

PROGRAMS = (
    ("01 Sine Graph", "sinebarchart1liner", "BARH(64\u00d7SIN(INDE 7\u00d725\u00d7\u03c0\u00f7180))"),
    ("02 Fibonacci", "fib1liner", "F"),
    ("04 Guess", "guess", "GUES"),
    ("05 Pyramid", "pyramid", "BARH((Z=INDE 7)MIN(8-Z))\u00d714"),
    ("06 Recursive Factorial", "recursivefactorial", "N=5; Y=1; F"),
    ("07 Slot Machine", "slots", "SLOT"),
    ("08 Acey Ducey", "aceyducey", "ACEY"),
    ("09 Lunar Lander", "lunarlander", "LL"),
    ("10 Uniform Sphere", "unicircle", "UNI"),
    ("11 Gunner", "gun", "GUN"),
    ("12 Dicejack", "dicejack", "D"),
    ("13 Primes", "primebarchart", "P"),
    ("14 Collatz Bounce", "collatz", "C"),
    ("15 Data Stats", "dstats", "D"),
    ("16 Lotto Picker", "lottochartmethod1", "L"),
    ("17 Estimate Pi", "estimatepibarchart", "PI"),
    ("18 Taylor Sequences", "taylorseries", "T"),
    ("19 Stag Hunt", "stagorharegraph", "S"),
    ("20 Bulls and Cows", "bullsandcows4digits", "M"),
    ("21 Clock", "clocknye2026", "C"),
    ("22 Roulette", "roulette", "R"),
    ("23 Coin Change", "coinchange", "Q=D=N=P=0; X=89; C"),
)


def read_records(image):
    if len(image) < 512:
        raise ValueError("truncated VBT1 header")
    magic, rate, count = struct.unpack_from("<4sII", image)
    if magic != b"VBT1" or rate != CLOCK:
        raise ValueError("expected VBT1 at 14318180 Hz")
    if count == 0xFFFFFFFF or count > (len(image) - 512) // 4:
        raise ValueError("incomplete or truncated recording")
    falls = []
    ticks = 0
    previous = None
    for (value,) in struct.iter_unpack("<I", image[512:512 + count * 4]):
        level, duration = value >> 31, value & 0x7FFFFFFF
        if duration < 2:
            raise ValueError("invalid interval")
        if level == 0 and previous != 0:
            falls.append(ticks)
        ticks += duration
        previous = level
    # Timing index 1: zero is one 2 ms pulse cell; one has two 1 ms pulses.
    bits = []
    index = 0
    while index < len(falls):
        one = index + 1 < len(falls) and falls[index + 1] - falls[index] < CLOCK * .0014
        bits.append(int(one))
        index += 2 if one else 1
    if len(bits) % 8:
        raise ValueError("partial byte (expected timing index 1)")
    data = bytes(sum(bits[i + j] << (7 - j) for j in range(8))
                 for i in range(0, len(bits), 8))
    records = []
    offset = 0
    while offset < len(data):
        if data[offset:offset + 18] != SYNC or offset + 23 > len(data):
            raise ValueError(f"invalid record at byte {offset}")
        start = offset + 18
        size = int.from_bytes(data[start:start + 2], "big")
        end = start + 2 + size
        if end + 3 > len(data):
            raise ValueError("truncated record")
        crc = int.from_bytes(data[end:end + 2], "little")
        if binascii.crc_hqx(data[start:end], 0) != crc:
            raise ValueError(f"CRC mismatch at byte {offset}")
        if data[end + 2] != 0:
            raise ValueError("missing trailer")
        records.append(data[start + 2:end])
        offset = end + 3
    return records


def encode_records(records):
    intervals = []

    def interval(level, duration):
        if intervals and intervals[-1] >> 31 == level:
            intervals[-1] += duration
        else:
            intervals.append((level << 31) | duration)

    for payload in records:
        interval(1, CLOCK * 2)
        body = len(payload).to_bytes(2, "big") + payload
        record = SYNC + body + struct.pack("<H", binascii.crc_hqx(body, 0)) + b"\0"
        for value in record:
            for shift in range(7, -1, -1):
                interval(0, 2144)
                if value & (1 << shift):
                    interval(1, 12112)
                    interval(0, 2144)
                    interval(1, 12512)
                else:
                    interval(1, 26768)
    header = struct.pack("<4sII", b"VBT1", CLOCK, len(intervals)).ljust(512, b"\0")
    image = header + struct.pack(f"<{len(intervals)}I", *intervals)
    return image.ljust((len(image) + 511) // 512 * 512, b"\0")


def dump_records(dump):
    if len(dump) != 16384:
        raise ValueError("expected a 16K CPU-address-space dump")
    if dump[0x0C00:0x1000] != dump[0x2C00:0x3000]:
        raise ValueError("system RAM mirrors differ")
    return [dump[start:start + size] for start, size in SAVE_RANGES]


def collection(dumps, output):
    pending = []
    for title, stem, launch in PROGRAMS:
        records = dump_records((dumps / f"{stem}.bin").read_bytes())
        image = encode_records(records)
        if read_records(image) != records:
            raise ValueError(f"encoded payload differs: {stem}")
        path = output / f"APL-S - {title} [{launch}].vbt"
        if path.exists() and path.read_bytes() != image:
            raise ValueError(f"existing image differs: {path}")
        pending.append((path, image))
    output.mkdir(parents=True, exist_ok=True)
    for path, image in pending:
        if not path.exists():
            with path.open("xb") as target:
                target.write(image)
        print(path.name)
    print(f"{len(pending)} tapes checked; NEXT submits each filename input")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    batch = commands.add_parser("collection")
    batch.add_argument("dumps", type=Path)
    batch.add_argument("output", type=Path)
    inspect = commands.add_parser("inspect")
    inspect.add_argument("image", type=Path)
    regenerate = commands.add_parser("regenerate")
    regenerate.add_argument("image", type=Path)
    regenerate.add_argument("output", type=Path)
    convert = commands.add_parser("convert")
    convert.add_argument("dump", type=Path)
    convert.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "collection":
            collection(args.dumps, args.output)
        elif args.command == "inspect":
            records = read_records(args.image.read_bytes())
            print("Payload sizes: " + ", ".join(str(len(record)) for record in records))
            print("All record CRCs passed")
        else:
            records = (dump_records(args.dump.read_bytes()) if args.command == "convert"
                       else read_records(args.image.read_bytes()))
            image = encode_records(records)
            if read_records(image) != records:
                raise ValueError("encoded payload differs from source")
            with args.output.open("xb") as output:
                output.write(image)
            print(f"{args.output}: {len(records)} records; hardware validation required")
    except (OSError, ValueError, struct.error) as error:
        parser.exit(1, f"error: {error}\n")


if __name__ == "__main__":
    main()
