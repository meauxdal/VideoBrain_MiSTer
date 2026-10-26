#!/usr/bin/env python3
import contextlib
import io
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
import printer_image as vbp


class PrinterImageTests(unittest.TestCase):
    def test_roundtrip_and_faults(self):
        with tempfile.TemporaryDirectory() as d:
            image = Path(d) / 'test.vbp'
            vbp.create(image, 8192)
            with self.assertRaises(FileExistsError):
                vbp.create(image)
            raw = bytearray(image.read_bytes())
            data = bytes(range(256)) * 3 + b'\0\r\n\xff'
            blocks = [vbp.record(1, 1, vbp.START, 0, 0)]
            offset = 0
            for i in range(0, len(data), 480):
                part = data[i:i + 480]
                blocks.append(vbp.record(len(blocks) + 1, 1, vbp.DATA, 0, offset, part))
                offset += len(part)
            blocks.append(vbp.record(len(blocks) + 1, 1, vbp.STOP, 0, offset, bytes(16)))
            raw[512:512 + 512 * len(blocks)] = b''.join(blocks)
            image.write_bytes(raw)
            sessions, fault = vbp.inspect(image)
            self.assertIsNone(fault)
            self.assertEqual(sessions[0]['data'], data)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(vbp.main(['export', str(image), str(Path(d) / 'raw.bin')]), 0)
            self.assertEqual((Path(d) / 'raw.bin').read_bytes(), data)
            raw[512 * 3 + 40] ^= 1
            image.write_bytes(raw)
            sessions, fault = vbp.inspect(image)
            self.assertIn('CRC', fault)
            self.assertEqual(sessions[0]['data'], data[:480])
            self.assertEqual(sessions[0]['reason'], 'interrupted')

    def test_holes_and_superblock(self):
        with tempfile.TemporaryDirectory() as d:
            image = Path(d) / 'test.vbp'
            vbp.create(image, 4096)
            raw = bytearray(image.read_bytes())
            raw[1024:1536] = vbp.record(1, 1, vbp.START, 1, 0)
            image.write_bytes(raw)
            self.assertIn('hole', vbp.inspect(image)[1])
            raw[28] ^= 1
            image.write_bytes(raw)
            with self.assertRaises(ValueError):
                vbp.inspect(image)

    def test_rtl_capture(self):
        root = Path(__file__).resolve().parents[1] / 'out/expander1'
        image = root / 'printer.vbp'
        self.assertTrue(image.exists(), f'missing RTL capture: {image}')
        sessions, fault = vbp.inspect(image)
        self.assertIsNone(fault)
        self.assertEqual([s['reason'] for s in sessions], ['clean', 'clean'])
        self.assertEqual(sessions[0]['data'], bytes(i % 256 for i in range(5000)))
        self.assertEqual(sessions[1]['data'], b'\0\x20\xa5\r\n\xff' + bytes(range(256)))
        for name, reason, count in [('latency', 'clean', 1800), ('overflow', 'overflow', None), ('reset', 'reset', 1)]:
            extra, fault = vbp.inspect(root / f'printer-{name}.vbp')
            self.assertIsNone(fault)
            self.assertEqual(extra[0]['reason'], reason)
            payload = bytes(extra[0]['data'])
            if count is not None:
                self.assertEqual(len(payload), count)
            self.assertEqual(payload, b'\xa5' if name == 'reset' else bytes(i % 256 for i in range(len(payload))))
        broken = root / 'printer-framing.vbp'
        sessions, fault = vbp.inspect(broken)
        self.assertIsNone(fault)
        self.assertEqual(sessions[0]['reason'], 'framing')
        self.assertEqual(sessions[0]['data'], b'\xa5')

    def test_hps_capture(self):
        image = Path(__file__).resolve().parents[1] / 'out/expander1/printer-hps.vbp'
        self.assertTrue(image.exists(), f'missing stock-HPS capture: {image}')
        sessions, fault = vbp.inspect(image)
        self.assertIsNone(fault)
        self.assertEqual(sessions[0]['data'], bytes(i % 256 for i in range(5000)))
        self.assertEqual(sessions[1]['data'], b'\0\x20\xa5\r\n\xff' + bytes(range(256)))

    def test_original_rom(self):
        root = Path(__file__).resolve().parents[1] / 'out/expander1'
        for rate in range(2):
            for route in range(2):
                rom = root / f'printer-rom-{rate}-{route}.vbp'
                self.assertTrue(rom.exists(), f'missing original-ROM capture: {rom}')
                decoded, fault = vbp.inspect(rom)
                self.assertIsNone(fault)
                self.assertEqual(decoded[0]['reason'], 'clean')
                self.assertEqual(decoded[0]['data'], b'\x3c' if route else b'\0\x20\xa5\r\n\xff')

    def test_timeshare(self):
        root = Path(__file__).resolve().parents[1] / 'out/expander1'
        images = [root / f'printer-timeshare-{rate}-{mode}.vbp'
                  for rate in range(2) for mode in range(4)]
        for image in images:
            self.assertTrue(image.exists(), f'missing Timeshare capture: {image}')
        for i, image in enumerate(images):
            sessions, fault = vbp.inspect(image)
            self.assertIsNone(fault)
            self.assertEqual(len(sessions), 1)
            self.assertEqual(sessions[0]['reason'], 'clean')
            self.assertEqual(sessions[0]['baud'], 300 if i < 4 else 110)
            self.assertEqual(sessions[0]['data'], b'\x41\x8d\x58' if i % 2 else b'\x58')

    def test_tape_contention(self):
        image = Path(__file__).resolve().parents[1] / 'out/expander1/printer-tapes.vbp'
        self.assertTrue(image.exists(), f'missing printer/tape capture: {image}')
        sessions, fault = vbp.inspect(image)
        self.assertIsNone(fault)
        self.assertEqual(sessions[0]['reason'], 'clean')
        payload = sessions[0]['data']
        self.assertGreater(len(payload), 0)
        self.assertEqual(payload, bytes(i % 16 for i in range(len(payload))))

    def test_infoman(self):
        root = Path(__file__).resolve().parents[1] / 'out/expander1'
        labels = ['desc', 'records', 'total']
        for label in labels:
            image = root / f'printer-infoman-{label}.vbp'
            self.assertTrue(image.exists(), f'missing Information Manager capture: {image}')
        reports = []
        for i, label in enumerate(labels):
            sessions, fault = vbp.inspect(root / f'printer-infoman-{label}.vbp')
            self.assertIsNone(fault)
            self.assertEqual(len(sessions), i + 1)
            self.assertTrue(all(s['reason'] == 'clean' for s in sessions))
            data = bytes(sessions[-1]['data'])
            self.assertEqual(data, (root / f'printer-infoman-{label}.bin').read_bytes())
            self.assertGreater(len(data), 0)
            self.assertEqual(len(data) % 24, 0)
            for j in range(0, len(data), 24):
                self.assertEqual(data[j:j + 6], b'\0     ')
                self.assertEqual(data[j + 22:j + 24], b'\r\n')
            reports.append(b'\n'.join(data[j + 6:j + 22] for j in range(0, len(data), 24)))
        self.assertIn(b'ITEM', reports[0])
        self.assertIn(b'2', reports[1])
        self.assertIn(b'3', reports[1])
        self.assertIn(b'5', reports[2])


if __name__ == '__main__':
    unittest.main()
