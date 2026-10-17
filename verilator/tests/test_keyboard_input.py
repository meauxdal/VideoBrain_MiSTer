from pathlib import Path
from contextlib import redirect_stderr
import io
import struct
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from apl_source import encode
from keyboard_input import MUSIC_RECORD, MUSIC_REPLAY, keyboard_text, music, physical_keys


def events(data):
    assert data[:4] == b"VBK2"
    assert struct.unpack("<H", data[4:6])[0] == len(data) - 8
    crc = 0xffff
    for byte in data[8:]:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ (0x1021 if crc & 0x8000 else 0)) & 0xffff
    assert struct.unpack("<H", data[6:8])[0] == crc
    return list(zip(*[iter(data[8:])] * 3))


def music_pitches(body):
    # ED01 ROM $1616 key table; BIOS $4361 key codes; $1255 bank offsets.
    table = bytes.fromhex("00 0d 0f 11 f2 14 16 f0 f0 18 f0 0c 0e 10 12 13 15 17 "
                          "f3 0a 0b 19 1b 1d f1 20 22 23 09 f0 f0 1a f4 1c 1e 1f 21")
    bank = 0
    pitches = []
    for key, _, _ in body:
        if key in (33, 19, 22):
            bank = {33: 12, 19: 0, 22: -12}[key]
        elif key != 255:
            index = table[(key % 4) * 9 + key // 4 + 1]
            assert index < 0x80 and 0 <= index + bank <= 47
            pitches.append(83 - index - bank)
    return pitches


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
        self.assertEqual(a[:5], [(11, 8, 8), (19, 8, 64), (MUSIC_RECORD, 8, 8), (11, 8, 8), (19, 8, 8)])
        self.assertEqual([key for key, _, _ in a[5:-4]], [29, 25, 21, 17, 13, 9, 5, 6])
        self.assertEqual(a[5][1:], (22, 8))
        self.assertEqual(a[-4:-1], [(11, 8, 8), (7, 8, 8), (11, 8, 8)])
        self.assertEqual(a[-1], (MUSIC_REPLAY, 8, 8))

    def test_music_accidentals_banks_rests_and_page_wait(self):
        a = events(music('O2 C C# D- R4 O5 B', 'symbols', page_notes=2))
        self.assertIn((33, 8, 8), a)
        self.assertIn((22, 8, 8), a)
        self.assertEqual([key for key, hold, gap in a if hold == 22], [34, 30, 30, 5])
        self.assertIn((255, 64, 0), a)
        self.assertIn((255, 30, 0), a)
        self.assertEqual(events(music('C4.', 'letters'))[-4][1:], (37, 8))

    def test_music_range_boundaries(self):
        for text, pitch in (('O2 C', 36), ('O2 D-', 37),
                            ('O5 C', 72), ('O5 A#', 82), ('O5 B', 83),
                            ('O6 C-', 83), ('O5 > C-', 83)):
            with self.subTest(text=text):
                self.assertEqual(music_pitches(events(music(text, 'letters'))[5:-3]), [pitch])
        for text in ('O2 C-', 'O5 B#', 'O5 B+', 'O6 C', 'O6 C#', 'O6 D-',
                     'O6 D', 'O5 > C', 'O6 C- C'):
            with self.subTest(text=text), self.assertRaisesRegex(ValueError, r'range is C2\.\.B5'):
                music(text, 'letters')

    def test_music_retains_bank_in_overlap(self):
        a = events(music('O2 C O3 C O4 C O5 C O4 C O5 B O4 C', 'letters'))
        body = a[5:-3]
        self.assertEqual(music_pitches(body), [36, 48, 60, 72, 60, 83, 60])
        self.assertEqual([key for key, _, _ in body if key in (33, 19, 22)], [33, 19, 22])

    def test_music_range_example_packets(self):
        directory = Path(__file__).resolve().parents[2] / 'examples' / 'music-tests'
        for name, expected in (('scale', list(range(36, 84))),
                               ('octaves', [36, 48, 60, 72, 83, 36])):
            with self.subTest(name=name):
                data = (directory / f'{name}.vbk').read_bytes()
                a = events(data)
                self.assertEqual(a[:5], [(11, 8, 8), (19, 8, 64), (MUSIC_RECORD, 8, 8), (11, 8, 8), (19, 8, 8)])
                self.assertEqual(a[-4:], [(11, 8, 8), (7, 8, 8), (11, 8, 8), (MUSIC_REPLAY, 8, 8)])
                self.assertEqual(music_pitches(a[5:-4]), expected)
                self.assertEqual(data, music((directory / f'{name}.mml').read_text(), 'letters', replay=True))

    def test_music_rejects_unsupported_or_unsafe_timing(self):
        for text in ('C,E,G', 'O7 C', 'O6 E', 'T120 C64', 'L0 C', 'R4'):
            with self.assertRaises(ValueError, msg=text):
                music(text, 'letters')
        with self.assertRaises(ValueError):
            music('C', None)

    def test_music_playback_capacity(self):
        warning = io.StringIO()
        with redirect_stderr(warning):
            music('C ' * 79, 'letters')
            music('C R ' * 79, 'letters')
        self.assertEqual(warning.getvalue(), '')
        with redirect_stderr(warning):
            a = events(music('C ' * 80, 'letters'))
        self.assertEqual(len(a), 5 + 80 + 3)
        self.assertIn('80 notes; Record will truncate', warning.getvalue())
        self.assertIn('79-note limit', warning.getvalue())
        self.assertIn('Use Playback', warning.getvalue())
        with redirect_stderr(io.StringIO()):
            self.assertEqual(len(events(music('C ' * 1357, 'letters'))), 1365)
        with self.assertRaisesRegex(ValueError, '1365'):
            music('C ' * 1358, 'letters')


if __name__ == '__main__':
    unittest.main()
