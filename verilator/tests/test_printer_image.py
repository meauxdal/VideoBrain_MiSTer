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
        if not image.exists():
            self.skipTest('run RTL capture first')
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
        if not image.exists():
            self.skipTest('run stock-HPS capture first')
        sessions, fault = vbp.inspect(image)
        self.assertIsNone(fault)
        self.assertEqual(sessions[0]['data'], bytes(i % 256 for i in range(5000)))
        self.assertEqual(sessions[1]['data'], b'\0\x20\xa5\r\n\xff' + bytes(range(256)))

    def test_original_rom(self):
        root = Path(__file__).resolve().parents[1] / 'out/expander1'
        for rate in range(2):
            for route in range(2):
                rom = root / f'printer-rom-{rate}-{route}.vbp'
                if rom.exists():
                    decoded, fault = vbp.inspect(rom)
                    self.assertIsNone(fault)
                    self.assertEqual(decoded[0]['reason'], 'clean')
                    self.assertEqual(decoded[0]['data'], b'\x3c' if route else b'\0\x20\xa5\r\n\xff')


if __name__ == '__main__':
    unittest.main()
