"""Check that trimming only removes unused VBT sectors."""

from pathlib import Path
import struct
import sys
from tempfile import TemporaryDirectory
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from tape_convert import CLOCK
from trim_tape import trim


class TrimTapeTests(unittest.TestCase):
    def test_sector_boundaries_and_exact_prefix(self):
        with TemporaryDirectory() as directory:
            source = Path(directory) / "source.vbt"
            destination = Path(directory) / "trimmed.vbt"
            for count, expected in ((0, 1024), (1, 1024), (128, 1024),
                                     (129, 1536), (16385, 66560)):
                with self.subTest(count=count):
                    header = struct.pack("<4sII", b"VBT1", CLOCK, count).ljust(512, b"H")
                    # Equal levels and nonzero padding must survive byte-for-byte.
                    image = header + struct.pack("<I", 0x80001234) * count
                    image = image.ljust(128 * 1024, b"P")
                    source.write_bytes(image)
                    self.assertEqual(trim(source, destination), (len(image), expected))
                    self.assertEqual(destination.read_bytes(), image[:expected])
                    self.assertEqual(source.read_bytes(), image)
                    destination.unlink()

    def test_invalid_input_leaves_no_output(self):
        with TemporaryDirectory() as directory:
            source = Path(directory) / "source.vbt"
            destination = Path(directory) / "trimmed.vbt"
            inputs = [b"VBT1", bytes(1024),
                      struct.pack("<4sII", b"VBT1", 1, 0).ljust(1024, b"\0"),
                      struct.pack("<4sII", b"VBT1", CLOCK, 0xFFFFFFFF).ljust(1024, b"\0"),
                      struct.pack("<4sII", b"VBT1", CLOCK, 129).ljust(1024, b"\0"),
                      struct.pack("<4sII", b"VBT1", CLOCK, 1).ljust(1024, b"\0"),
                      struct.pack("<4sII", b"VBT1", CLOCK, 0).ljust(1025, b"\0")]
            for image in inputs:
                source.write_bytes(image)
                with self.assertRaises(ValueError):
                    trim(source, destination)
                self.assertFalse(destination.exists())

    def test_no_overwrite_or_in_place_changes(self):
        with TemporaryDirectory() as directory:
            source = Path(directory) / "source.vbt"
            destination = Path(directory) / "trimmed.vbt"
            image = struct.pack("<4sII", b"VBT1", CLOCK, 0).ljust(1024, b"\0")
            source.write_bytes(image)
            destination.write_bytes(b"keep")
            with self.assertRaises(FileExistsError):
                trim(source, destination)
            with self.assertRaises(FileExistsError):
                trim(source, source)
            self.assertEqual(source.read_bytes(), image)
            self.assertEqual(destination.read_bytes(), b"keep")


if __name__ == "__main__":
    unittest.main()
