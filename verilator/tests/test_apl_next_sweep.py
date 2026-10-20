import binascii
import contextlib
import csv
import io
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from apl_next_sweep import analyze, cases, trial


class NextSweepTests(unittest.TestCase):
    def test_real_clock_and_delay_boundaries(self):
        for name, prefix, line in cases(["clock", "clock-context"], [46]):
            self.assertEqual(len(line), 46)
            for delay in (0, 72, 255, 256, 512):
                data, meta = trial(prefix, line, delay, "SHIFT")
                length, crc = struct.unpack("<HH", data[4:8])
                self.assertEqual(data[:4], b"VBK2")
                self.assertEqual(length, len(data) - 8)
                self.assertLessEqual(length, 4096)
                self.assertEqual(crc, binascii.crc_hqx(data[8:], 65535))
                payload = data[8:]
                target = meta["target_pos"] - 2
                probe = meta["probe_pos"] - 2
                self.assertEqual(payload[target:target + 2], bytes([27, 8]))
                self.assertEqual(payload[probe:probe + 2], bytes([11, 8]))
                elapsed = payload[target + 2]
                for offset in range(target + 3, probe, 3):
                    self.assertEqual(payload[offset], 255)
                    elapsed += payload[offset + 1] + payload[offset + 2]
                self.assertEqual(elapsed, delay, name)

    def test_curve_does_not_hide_later_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            out = Path(temporary)
            for delay, response in ((32, True), (64, False), (96, True)):
                folder = out / str(delay)
                folder.mkdir()
                _, meta = trial(["EDIT TEST"], "A=1", delay, "SHIFT")
                meta.update(case="sum-3", length=3, delay=delay, probe="SHIFT", repeat=0, exit_code=0)
                (folder / "trial.json").write_text(json.dumps(meta))
                log = [f"[source-key] pos={pos} keys=000000001 symbols={value}" for pos, value in meta["setup_modes"].items()]
                (folder / "run.log").write_text("\n".join(log + ["[source] entry finished"]))
                fields = ["frame", "pos", "keys", "event", "symbols", "addr"]
                with (folder / "snoop.csv").open("w", newline="") as stream:
                    writer = csv.DictWriter(stream, fields)
                    writer.writeheader()
                    writer.writerow(dict(frame=100, pos=meta["target_pos"], keys=0, event="key", symbols=1, addr=0))
                    writer.writerow(dict(frame=100 + delay, pos=meta["probe_pos"], keys=2048, event="key", symbols=1, addr=0))
                    if response:
                        writer.writerow(dict(frame=102 + delay, pos=meta["probe_pos"], keys=2048, event="mode", symbols=0, addr=4066))
            with contextlib.redirect_stdout(io.StringIO()):
                analyze(out)
            with (out / "shift_curve.csv").open(newline="") as stream:
                curve = list(csv.DictReader(stream))
            self.assertEqual(curve[0]["tested_tail_fields"], "96")
            self.assertTrue((out / "shift_curve.svg").is_file())


if __name__ == "__main__":
    unittest.main()
