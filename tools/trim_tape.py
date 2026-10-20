"""Remove unused trailing VBT sectors without changing recorded intervals."""

import argparse
from pathlib import Path
import struct

from tape_convert import CLOCK, MAX_TICKS, new_output


def trim(source, destination):
    with Path(source).open("rb") as image:
        header = image.read(512)
        if len(header) != 512:
            raise ValueError("truncated VBT header")
        magic, clock, count = struct.unpack_from("<4sII", header)
        if magic != b"VBT1" or clock != CLOCK:
            raise ValueError("expected VBT1 at 14318180 Hz")
        if count == 0xFFFFFFFF:
            raise ValueError("incomplete VBT recording")
        original_size = image.seek(0, 2)
        if original_size < 1024 or original_size % 512 or count > (original_size - 512) // 4:
            raise ValueError("truncated or non-sector-aligned VBT image")
        size = max(1024, 512 + (count + 127) // 128 * 512)
        image.seek(512)
        with new_output(destination) as output:
            output.write(header)
            remaining = size - 512
            active = count * 4
            while remaining:
                data = image.read(min(65536, remaining))
                if not data:
                    raise ValueError("truncated VBT data")
                for (value,) in struct.iter_unpack("<I", data[:min(active, len(data))]):
                    if value & MAX_TICKS < 2:
                        raise ValueError("invalid VBT interval")
                active = max(0, active - len(data))
                output.write(data)
                remaining -= len(data)
        return original_size, size


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        before, after = trim(args.source, args.output)
    except (OSError, ValueError, struct.error) as error:
        parser.error(str(error))
    print(f"{before} -> {after} bytes; removed {before - after} bytes; {args.output}")
