import binascii
from pathlib import Path
import struct
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from apl_source import encode


class SourceTests(unittest.TestCase):
    def test_arithmetic(self):
        data = encode("1+1\n2+3\n")
        self.assertEqual(data[8:], bytes([0x61, 0x56, 0x61, 0x9b, 0x5e, 0x56, 0x5a, 0x9b]))
        self.assertEqual(data[:6], b"VBK1\x08\x00")
        self.assertEqual(struct.unpack("<H", data[6:8])[0], binascii.crc_hqx(data[8:], 0xffff))

    def test_input_normalization(self):
        self.assertEqual(encode("\ufeff\r\n  barh 10 20 30\r\n\r\n"), encode("BARH 10 20 30"))
        self.assertEqual(encode('"HI"'), encode('\u201cHI\u201d'))
        self.assertEqual(encode("1-1"), encode("1\u22121"))

    def test_apl_symbols(self):
        self.assertEqual(encode("!$#")[8:], bytes([0x44, 0x46, 0x41, 0x9b]))
        self.assertEqual(encode("\u00d7\u00f7\u03c0\u00af")[8:], bytes([0x4c, 0x48, 0x43, 0x42, 0x9b]))
        self.assertNotEqual(encode("*")[8], encode("\u00d7")[8])
        self.assertEqual(encode("{MUL}{DIV}{PI}{NEG}"), encode("\u00d7\u00f7\u03c0\u00af"))
        with self.assertRaisesRegex(ValueError, "column 6"):
            encode("{MUL}@")
        with self.assertRaises(ValueError):
            encode("{UNKNOWN}")

    def test_reject_with_position(self):
        with self.assertRaisesRegex(ValueError, "line 2, column 5"):
            encode("1+1\n  A=@")
        with self.assertRaises(ValueError):
            encode("\u017f")

    def test_limits(self):
        with self.assertRaises(ValueError):
            encode(" \n\t\n")
        self.assertEqual(len(encode("A" * 4095)), 4104)
        with self.assertRaises(ValueError):
            encode("A" * 4096)


if __name__ == "__main__":
    unittest.main()
