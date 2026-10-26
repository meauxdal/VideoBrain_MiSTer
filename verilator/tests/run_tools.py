#!/usr/bin/env python3
"""Run the standard-library tool checks without an HDL toolchain or ROMs."""
from pathlib import Path
import os
import sys
import unittest


def main():
    directory = Path(__file__).resolve().parent
    loader = unittest.TestLoader()
    suite = unittest.TestSuite(
        loader.discover(str(directory), pattern=pattern)
        for pattern in (
            "test_apl_source.py",
            "test_keyboard_input.py",
            "test_examples.py",
            "test_music_teacher_patch.py",
            "test_regressions.py",
            "test_tape_convert.py",
            "test_trim_tape.py",
        )
    )
    sys.path.insert(0, str(directory))
    for name in ("test_roundtrip_and_faults", "test_holes_and_superblock"):
        suite.addTests(loader.loadTestsFromName(
            "test_printer_image.PrinterImageTests." + name))
    if os.name == "posix":
        suite.addTests(loader.discover(str(directory), pattern="test_capture_printer.py"))
    else:
        print("SKIP test_capture_printer.py: requires POSIX tty support", file=sys.stderr)
    return not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful()


if __name__ == "__main__":
    sys.exit(main())
