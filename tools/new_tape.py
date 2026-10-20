"""Create an empty VideoBrain tape image without replacing an existing file."""

import argparse
from datetime import datetime
from pathlib import Path
import struct


def create(path):
    with path.open("xb") as image:
        image.write(struct.pack("<4sII", b"VBT1", 14318180, 0))
        image.truncate(8 * 1024 * 1024)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", type=Path,
                        default=Path(datetime.now().strftime("Tape_%Y%m%d_%H%M%S_%f.vbt")))
    args = parser.parse_args()
    try:
        create(args.path)
    except OSError as error:
        parser.error(str(error))
    print(args.path)
