"""Check APL/S extraction against the hardware-tested cassette."""

from pathlib import Path
from contextlib import redirect_stdout
from io import StringIO
import sys
from tempfile import TemporaryDirectory
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from apl_tape import PROGRAMS, collection, dump_records, encode_records, read_records


class AplTapeTests(unittest.TestCase):
    def test_hardware_recording(self):
        path = ROOT / "refs/tape-observations/apls-test3.vbt"
        records = read_records(path.read_bytes())
        self.assertEqual([len(record) for record in records], [67, 1001] * 3)
        self.assertEqual(records[:2], records[2:4])
        self.assertEqual(records[:2], records[4:6])
        self.assertEqual(records[1][18:26], bytes.fromhex("41 70 00 00 42 7b 00 00"))
        self.assertEqual(read_records(encode_records(records[:2])), records[:2])

        dump = bytearray(16384)
        # Model SAVE's in-memory buffers, including their length prefixes.
        dump[0x0E4E:0x0E93] = b"\x00\x43" + records[0]
        dump[0x1C00:0x1FEB] = b"\x03\xe9" + records[1]
        dump[0x2C00:0x3000] = dump[0x0C00:0x1000]
        self.assertEqual(dump_records(dump), records[:2])

    def test_save_ranges(self):
        records = [bytes(range(67)), bytes(index % 251 for index in range(1001))]
        dump = bytearray(16384)
        dump[0x0E50:0x0E93] = records[0]
        dump[0x1C02:0x1FEB] = records[1]
        dump[0x2C00:0x3000] = dump[0x0C00:0x1000]
        self.assertEqual(dump_records(dump), records)
        dump[0x1FEB:] = b"\x55" * (len(dump) - 0x1FEB)
        dump[0x2C00:0x3000] = dump[0x0C00:0x1000]
        self.assertEqual(dump_records(dump), records)
        dump[0x2C00] ^= 1
        with self.assertRaisesRegex(ValueError, "mirrors"):
            dump_records(dump)

    def test_truncation(self):
        image = encode_records([b"APL/S"])
        with self.assertRaisesRegex(ValueError, "truncated"):
            read_records(image[:512])
        with self.assertRaisesRegex(ValueError, "16K"):
            dump_records(bytes(2048))

    def test_collection(self):
        dumps = ROOT / "software/3 MAME (vidbrain)/21 games for apl_s"
        with TemporaryDirectory() as directory, redirect_stdout(StringIO()):
            output = Path(directory)
            collection(dumps, output)
            for title, stem, launch in PROGRAMS:
                path = output / f"APL-S - {title} [{launch}].vbt"
                self.assertFalse(set(path.name) & set('<>:"/\\|?*'))
                self.assertEqual(read_records(path.read_bytes()),
                                 dump_records((dumps / f"{stem}.bin").read_bytes()))
            self.assertEqual(len(list(output.glob("*.vbt"))), 22)
            collection(dumps, output)
            path.write_bytes(b"preserve existing file")
            with self.assertRaisesRegex(ValueError, "existing image differs"):
                collection(dumps, output)
            self.assertEqual(path.read_bytes(), b"preserve existing file")


if __name__ == "__main__":
    unittest.main()
