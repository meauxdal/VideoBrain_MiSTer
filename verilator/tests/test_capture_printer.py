"""Exercise the real Linux tty/file path without MiSTer hardware."""
import os
from pathlib import Path
import pty
import signal
import subprocess
import sys
import tempfile
import termios
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "tools" / "capture_printer.py"


class CapturePrinterTest(unittest.TestCase):
    def test_raw_capture_and_restore(self):
        for baud in (110, 300):
            with self.subTest(baud=baud), tempfile.TemporaryDirectory() as folder:
                master, slave = pty.openpty()
                previous = termios.tcgetattr(slave)
                output = Path(folder) / "report.bin"
                process = subprocess.Popen(
                    [sys.executable, str(SCRIPT), str(output), "--device",
                     os.ttyname(slave), "--baud", str(baud)],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                try:
                    self.assertIn("Capturing", process.stdout.readline())
                    # Includes printer NUL, CR/LF, parity-bearing bytes, flow
                    # controls and every byte value; transport must be lossless.
                    payload = b"\0     REPORT\r\n" + bytes(range(256)) * 20
                    os.write(master, payload)
                    # File growth is an observable completion condition.
                    import time
                    deadline = time.monotonic() + 5
                    while output.stat().st_size != len(payload) and time.monotonic() < deadline:
                        time.sleep(0.01)
                    process.send_signal(signal.SIGINT)
                    stdout, stderr = process.communicate(timeout=5)
                    self.assertEqual(process.returncode, 0, stderr)
                    self.assertEqual(output.read_bytes(), payload)
                    self.assertIn(f"Saved {len(payload)} bytes", stdout)
                    self.assertEqual(termios.tcgetattr(slave), previous)
                    # Refuse an existing report and restore the UART on error.
                    result = subprocess.run(
                        [sys.executable, str(SCRIPT), str(output), "--device", os.ttyname(slave)],
                        capture_output=True, timeout=5)
                    self.assertEqual(result.returncode, 1)
                    self.assertEqual(output.read_bytes(), payload)
                    self.assertEqual(termios.tcgetattr(slave), previous)
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait()
                    process.stdout.close()
                    process.stderr.close()
                    os.close(master)
                    os.close(slave)


if __name__ == "__main__":
    unittest.main()
