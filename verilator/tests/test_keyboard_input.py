import binascii
from pathlib import Path
import struct
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from apl_source import encode
from keyboard_input import keyboard_text, music, physical_keys


def events(data):
    assert data[:4] == b"VBK2"
    assert struct.unpack("<H", data[4:6])[0] == len(data) - 8
    assert struct.unpack("<H", data[6:8])[0] == binascii.crc_hqx(data[8:], 0xffff)
    return list(zip(*[iter(data[8:])] * 3))


class KeyboardTests(unittest.TestCase):
    def test_apl_hold_final(self):
        normal = encode("EDIT DEMO\nA=1\nENDE\nRUN DEMO\n")
        held = encode("EDIT DEMO\nA=1\nENDE\nRUN DEMO\n", hold_final=True)
        self.assertEqual(held[8:], normal[8:-1])
        self.assertEqual(held[-1], 1)

    def test_physical_keys(self):
        self.assertEqual(events(physical_keys("SHIFT 3 4\nBACK\nWAIT 300")),
                         [(11, 3, 4), (35, 8, 8), (255, 255, 0), (255, 45, 0)])
        for text in ("A 0 8", "A 8 256", "WAIT 0", "UNKNOWN"):
            with self.assertRaises(ValueError):
                physical_keys(text)

    def test_standard_symbols_and_initial_mode(self):
        a = events(keyboard_text('A,;?1', 'letters', hold_final=True))
        self.assertEqual([key for key, _, _ in a], [32, 7, 3, 34, 11, 33])
        self.assertEqual(events(keyboard_text('A', 'symbols', hold_final=True))[0], (11, 8, 8))
        with self.assertRaises(ValueError):
            keyboard_text('A', None)

    def test_text_wrap_and_blank_lines(self):
        a = events(keyboard_text('ABCDEFGHIJKLMNOP\n\n1', 'letters', 'text', True))
        self.assertEqual([key for key, _, _ in a].count(27), 1)
        self.assertEqual(a[-2:], [(11, 8, 8), (33, 8, 8)])
        for text in ('A' * 17, '\n' * 8):
            with self.assertRaises(ValueError):
                keyboard_text(text, 'letters', 'text')

    def test_music_scale_record_and_replay(self):
        a = events(music('T120 O4 L4 C D E F G A B > C', 'letters', replay=True))
        self.assertEqual(a[:5], [(11, 8, 8), (19, 8, 64), (33, 8, 8), (11, 8, 8), (19, 8, 8)])
        self.assertEqual([key for key, _, _ in a[5:-4]], [29, 25, 21, 17, 13, 9, 5, 6])
        self.assertEqual(a[5][1:], (22, 8))
        self.assertEqual(a[-4:-1], [(11, 8, 8), (7, 8, 8), (11, 8, 8)])
        self.assertEqual(a[-1], (12, 8, 8))

    def test_music_accidentals_banks_rests_and_page_wait(self):
        a = events(music('O2 C C# D- R4 O6 D', 'symbols', page_notes=2))
        self.assertIn((33, 8, 8), a)
        self.assertIn((22, 8, 8), a)
        self.assertEqual([key for key, hold, gap in a if hold == 22], [34, 30, 30, 3])
        self.assertIn((255, 64, 0), a)
        self.assertIn((255, 30, 0), a)
        self.assertEqual(events(music('C4.', 'letters'))[-4][1:], (37, 8))

    def test_music_rejects_unsupported_or_unsafe_timing(self):
        for text in ('C,E,G', 'O7 C', 'O6 E', 'T120 C64', 'L0 C', 'R4', 'C ' * 81):
            with self.assertRaises(ValueError, msg=text):
                music(text, 'letters')
        with self.assertRaises(ValueError):
            music('C', None)


if __name__ == '__main__':
    unittest.main()
