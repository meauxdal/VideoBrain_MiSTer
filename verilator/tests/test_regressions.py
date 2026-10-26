"""Check runner reporting and ensure absent producer outputs cannot pass."""
import contextlib
import io
import os
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

import run_regressions as runner
import test_music_teacher_patch as music_tests
import test_printer_image as printer_tests


class RunnerTests(unittest.TestCase):
    def run_suite(self, arguments=(), make_code=0, missing_tool=None, rom_code=0):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder) / "verilator"
            commands = []

            def execute(command, **options):
                commands.append(command)
                if options.get("stdout") == subprocess.PIPE:
                    if command[:2] == ["git", "rev-parse"]:
                        output = "0123456789abcdef\n"
                    elif command[:2] == ["git", "status"]:
                        output = " M rtl/example.vhd\n?? new-code.py\n"
                    else:
                        output = "version 1.2.3\n"
                    return subprocess.CompletedProcess(command, 0, output)
                code = rom_code if "check-regression-roms" in command else make_code
                options["stdout"].write("test subprocess output\n")
                return subprocess.CompletedProcess(command, code)

            with mock.patch.object(runner, "__file__", str(directory / "tests/run_regressions.py")), \
                    mock.patch.object(runner, "os", SimpleNamespace(name="posix", environ=os.environ)), \
                    mock.patch.object(runner.shutil, "which", side_effect=lambda tool: None if tool == missing_tool else "/bin/" + tool), \
                    mock.patch.object(runner.importlib.util, "find_spec", return_value=object()), \
                    mock.patch.object(runner.subprocess, "run", side_effect=execute), \
                    contextlib.redirect_stdout(io.StringIO()):
                code = runner.main(list(arguments))
            logs = list((directory / "out/regressions").glob("*.log"))
            self.assertEqual(len(logs), 1)
            return code, logs[0].read_text(), commands

    def test_success_log_identifies_source_plan_tools_and_result(self):
        code, log, commands = self.run_suite()
        self.assertEqual(code, 0)
        for expected in ("UTC start:", "UTC end:", "0123456789abcdef",
                         " M rtl/example.vhd", "?? new-code.py", "Git status",
                         "GHDL:", "Verilator:", "Icarus Verilog:", "NumPy:",
                         "Bus waits: measurement-only", "Long runs excluded:",
                         "Hardware validation excluded:", "ROM checks excluded",
                         "Command: make --jobs=1 --keep-going",
                         "test subprocess output", "Final status: PASS; exit code: 0; duration:"):
            self.assertIn(expected, log)
        self.assertEqual(commands[-1][-len(runner.TARGETS):], list(runner.TARGETS))
        self.assertIn("BUS_WAIT_ARGS=-gcheck_documented=false", commands[-1])

    def test_test_failure_is_logged_and_returned(self):
        code, log, unused = self.run_suite(make_code=7)
        self.assertEqual(code, 7)
        self.assertIn("Final status: FAIL; exit code: 7", log)
        self.assertIn("UTC end:", log)

    def test_missing_tool_has_a_log_without_starting_make(self):
        code, log, commands = self.run_suite(missing_tool="ghdl")
        self.assertEqual(code, 2)
        self.assertIn("missing required tools: ghdl", log)
        self.assertIn("Final status: ERROR; exit code: 2", log)
        self.assertFalse(any("--keep-going" in command for command in commands))

    def test_rom_preflight_failure_stops_regressions_and_keeps_output(self):
        code, log, commands = self.run_suite(("--roms",), rom_code=3)
        self.assertEqual(code, 3)
        self.assertEqual(commands[-1][-1], "check-regression-roms")
        self.assertIn("ROM preflight failed; regressions were not run.", log)
        self.assertIn("Final status: FAIL; exit code: 3", log)

    def test_missing_printer_outputs_fail_instead_of_skipping(self):
        for method in ("test_rtl_capture", "test_hps_capture", "test_original_rom",
                       "test_timeshare", "test_tape_contention", "test_infoman"):
            with self.subTest(method=method), \
                    mock.patch("test_printer_image.Path.exists", return_value=False):
                with self.assertRaisesRegex(AssertionError, "missing"):
                    getattr(printer_tests.PrinterImageTests(method), method)()

    def test_music_rom_is_optional_but_an_explicit_invalid_path_fails(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(unittest.SkipTest):
                music_tests.OriginalRomTests.setUpClass()
        with tempfile.TemporaryDirectory() as folder:
            filename = Path(folder) / "ed01.bin"
            with mock.patch.dict(os.environ, {"MT1_ROM": str(filename)}):
                with self.assertRaises(FileNotFoundError):
                    music_tests.OriginalRomTests.setUpClass()
                filename.write_bytes(bytes(2048))
                with self.assertRaisesRegex(ValueError, "not the original ED01"):
                    music_tests.OriginalRomTests.setUpClass()


if __name__ == "__main__":
    unittest.main()
