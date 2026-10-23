#!/usr/bin/env python3
"""Run the standard-library tool checks without an HDL toolchain or ROMs."""
from pathlib import Path
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
            "test_apl_next_sweep.py",
            "test_tape_convert.py",
            "test_trim_tape.py",
        )
    )
    return not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful()


if __name__ == "__main__":
    sys.exit(main())
