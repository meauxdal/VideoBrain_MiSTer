"""Independent small-waveform checks for the streaming capture extractor."""
import csv
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


EXE = str(Path(sys.argv.pop(1)).resolve())


class ExtractorTests(unittest.TestCase):
    def run_capture(self, header, points):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        source = root/"capture.csv"
        with source.open("w") as f:
            f.write(header+"\n")
            for t, state, n in points:
                stamp = f"{t//10**12}.{t%10**12:012d}000"
                f.write(stamp+", "+", ".join(str(state >> ch & 1) for ch in range(n))+"\n")
        subprocess.run([EXE, str(source), str(root/"out")], check=True, capture_output=True)
        return root

    def test_request_gap_and_reset_exclusion(self):
        points = [(0, 0, 8), (1000000, 8, 8), (1250000, 14, 8),
                  (1500000, 8, 8), (1750000, 14, 8), (2000000, 8, 8),
                  (2080000, 104, 8), (3200000, 8, 8), (3250000, 14, 8),
                  (3500000, 8, 8), (3600000, 0, 8), (5000000, 8, 8),
                  (5250000, 14, 8), (5500000, 8, 8)]
        root = self.run_capture("Time [s],202-7 clock,xtal,phi,reset,dma,rq0,rq1,io", points)
        with (root/"out-gaps.csv").open() as f:
            rows = list(csv.DictReader(f))
        phi = [r for r in rows if r["channel"] == "2" and r["edge"] == "0"]
        self.assertEqual(len(phi), 1)
        self.assertEqual(int(phi[0]["duration_ps"]), 1500000)
        self.assertEqual(int(phi[0]["request_codes_seen"]), 9)
        self.assertEqual(int(phi[0]["dma_levels_seen"]), 1)

    def test_logic1_cycle_count_and_half_nanosecond(self):
        points = []
        for t in range(0, 2500001, 62500):
            xtal = int((t//125000) % 2 == 0)
            phi = int((t//250000) % 2 == 0)
            write = int(t < 125000 or 1875000 <= t < 2125000)
            points.append((t, xtal | phi << 1 | write << 2 | 0x2C << 8, 16))
        header = "Time[s], xtl, phi, write, romc0, romc1, romc2, romc3, romc4, d0, d1, d2, d3, d4, d5, d6, d7"
        root = self.run_capture(header, points)
        with (root/"out-cycles.csv").open() as f:
            rows = list(csv.DictReader(f))
        self.assertEqual(len(rows), 1)
        r = rows[0]
        self.assertEqual(int(r["end_ps"])-int(r["start_ps"]), 2000000)
        self.assertEqual(int(r["phi_falls"]), 4)
        self.assertEqual(int(r["xtal_falls"]), 8)
        self.assertEqual(int(r["data_end"]), 0x2C)
        self.assertEqual(int(r["data_write_rise"]), 0x2C)
        self.assertIn("off_grid 0", (root/"out-meta.txt").read_text())

    def test_bad_time_order_rejected(self):
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_capture("Time [s],clock,xtal,phi,reset,dma,rq0,rq1,io",
                             [(80000, 0, 8), (0, 0, 8)])


if __name__ == "__main__":
    unittest.main()
