"""Check patch write bounds and ROM invariants; no full-machine emulation."""
import hashlib
from pathlib import Path
import sys
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import patch_music_teacher as patch


class PageWrapTests(unittest.TestCase):
    def test_execute_clear_routine(self):
        # Execute the injected F8 instructions, including the signed branch,
        # so a wrong loop count or operand-relative branch cannot silently pass.
        code = bytes.fromhex(patch.PAGE_WRAP)
        memory = bytearray([0xA5] * 65536)
        registers = list(range(12))
        a, dc, pc, zero = 0xFF, 0, 0, False
        writes = []
        for _ in range(1000):
            op = code[pc]
            pc += 1
            if op == 0x70:  # LIS 0
                a = 0
            elif op in (0x50, 0x51, 0x58):
                registers[op - 0x50] = a
            elif op == 0x2A:  # DCI
                dc = int.from_bytes(code[pc:pc + 2], "big")
                pc += 2
            elif op == 0x20:  # LI
                a = code[pc]
                pc += 1
            elif op == 0x17:  # ST (A unchanged)
                memory[dc] = a
                writes.append(dc)
                dc += 1
            elif op == 0x38:  # DS R8 (A unchanged)
                registers[8] = (registers[8] - 1) & 255
                zero = registers[8] == 0
            elif op == 0x94:  # BF 4, relative to displacement byte
                offset = code[pc]
                pc += 1 if zero else offset - 256 if offset > 127 else offset
            elif op == 0x1C:  # POP
                break
            else:
                self.fail(f"unexpected opcode {op:02x}")
        else:
            self.fail("clear routine did not return")
        self.assertEqual(writes, list(range(0x0EC4, 0x0F00)))
        self.assertEqual(memory[0x0EC4:0x0F00], bytes(60))
        self.assertEqual(memory[:0x0EC4], bytes([0xA5]) * 0x0EC4)
        self.assertEqual(memory[0x0F00:], bytes([0xA5]) * (65536 - 0x0F00))
        self.assertEqual(registers[:2], [0, 0])
        self.assertEqual(registers[2:8], list(range(2, 8)))
        self.assertEqual(registers[9:], list(range(9, 12)))

    def test_reject_wrong_rom(self):
        for data in (b"", bytes(2048), bytes(4096)):
            with self.assertRaises(ValueError):
                patch.patch_rom(data)


class OriginalRomTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Original cartridge is deliberately not distributed with the tests.
        paths = (ROOT / "software" / "1 Cartridges").glob("*ED01*.bin")
        for path in paths:
            data = path.read_bytes()
            if hashlib.sha256(data).hexdigest() == patch.ED01_SHA256:
                cls.original = data
                cls.patched = patch.patch_rom(data)
                return
        raise unittest.SkipTest("original ED01 cartridge not installed")

    def test_changes_are_confined_to_declared_ranges(self):
        expected = bytearray(self.original)
        for address, before, after in patch.PATCHES:
            start = address - 0x1000
            self.assertEqual(self.original[start:start + len(bytes.fromhex(before))],
                             bytes.fromhex(before))
            expected[start:start + len(bytes.fromhex(after))] = bytes.fromhex(after)
        self.assertEqual(self.patched, bytes(expected))
        self.assertEqual(len(self.patched), 2048)
        self.assertEqual(self.original[0x4EE:0x500], self.patched[0x4EE:0x500])
        self.assertEqual(self.original[0x4C8:0x4E8], self.patched[0x4C8:0x4E8])
        self.assertEqual(self.original[0x14E:0x16B], self.patched[0x14E:0x16B])

    def test_core_recognizes_output(self):
        crc = f'{zlib.crc32(self.patched):08X}'
        self.assertIn(f'x"{crc}"', (ROOT / "rtl" / "sys_bus.vhd").read_text())

    def test_reject_already_patched_rom(self):
        with self.assertRaises(ValueError):
            patch.patch_rom(self.patched)


if __name__ == "__main__":
    unittest.main()
