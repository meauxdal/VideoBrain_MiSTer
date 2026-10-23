"""Check waveform conversion, quantization bounds, and preservation fixtures."""

from itertools import accumulate
from pathlib import Path
import random
import struct
import sys
from tempfile import TemporaryDirectory
import unittest
import wave

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from tape_convert import (CLOCK, MAX_TICKS, append_run, read_vbt, read_wav,
                          rounded_ratio, wav_spans, write_vbt, write_wav)


class TapeConvertTests(unittest.TestCase):
    def setUp(self):
        self.directory = TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def pcm(self, values, width=2, channels=1, rate=48000, name="input.wav"):
        path = self.root / name
        with wave.open(str(path), "wb") as output:
            output.setparams((channels, width, rate, 0, "NONE", "not compressed"))
            output.writeframes(b"".join((v + 128).to_bytes(1, "little") if width == 1 else
                                       v.to_bytes(width, "little", signed=True) for v in values))
        return path

    def assert_edges(self, before, after, rate):
        self.assertEqual([v for v, _ in before], [v for v, _ in after])
        bound = CLOCK / (2 * rate) + 0.5
        for first, second in zip(accumulate(n for _, n in before),
                                 accumulate(n for _, n in after)):
            self.assertLessEqual(abs(first - second), bound)

    def round_trip(self, runs, rate):
        wav = self.root / "roundtrip.wav"
        write_wav(wav, runs, rate)
        result, actual_rate, _ = read_wav(wav)
        wav.unlink()
        self.assertEqual(actual_rate, rate)
        self.assert_edges(runs, result, rate)
        return result

    def test_arbitrary_waveform_no_drift(self):
        rng = random.Random(1977)
        runs = [(i % 2, rng.randrange(1800, 100000)) for i in range(4000)]
        for rate in (22050, 44100, 48000, 96000, 192000):
            with self.subTest(rate=rate):
                self.round_trip(runs, rate)

    def test_pcm_widths_and_polarity(self):
        for width in (1, 2, 3, 4):
            scale = 1 << (width * 8 - 1)
            values = [-scale // 2] * 3 + [scale // 2] * 7 + [-scale // 2] * 4
            path = self.pcm(values, width, name=f"pcm{width}.wav")
            runs, rate, count = read_wav(path)
            self.assertEqual(count, 14)
            edges = [rounded_ratio(n, CLOCK, rate) for n in (3, 10, 14)]
            self.assertEqual(runs, [(0, edges[0]), (1, edges[1] - edges[0]),
                                    (0, edges[2] - edges[1])])
            inverted, _, _ = read_wav(path, invert=True)
            self.assertEqual(inverted, [(1 - v, n) for v, n in runs])

    def test_channel_selection_no_mixing(self):
        path = self.pcm([-10000, 10000] * 12, channels=2)
        with self.assertRaisesRegex(ValueError, "select --channel"):
            read_wav(path)
        self.assertEqual(read_wav(path, channel=1)[0][0][0], 0)
        self.assertEqual(read_wav(path, channel=2)[0][0][0], 1)
        with self.assertRaisesRegex(ValueError, "channel outside"):
            read_wav(path, channel=3)

    def test_gain_offset_noise_and_hysteresis(self):
        rng = random.Random(1977)
        levels = [0] * 40 + [1] * 80 + [0] * 60 + [1] * 20
        clean = self.pcm([16000 if v else -16000 for v in levels])
        expected = read_wav(clean)[0]
        for gain in (0.08, 0.25, 0.8):
            values = [round(32768 * ((gain if v else -gain) + 0.03 +
                                     rng.uniform(-0.01, 0.01))) for v in levels]
            noisy = self.pcm(values, name=f"noise{gain}.wav")
            self.assertEqual(read_wav(noisy, hysteresis=0.02)[0], expected)
        # The dead band holds the previous level, including exact zero samples.
        path = self.pcm([-16000, 0, 300, -300, 16000, 0, -300], name="band.wav")
        self.assertEqual(len(read_wav(path, hysteresis=0.02)[0]), 2)

    def test_export_levels_and_inversion(self):
        path = self.root / "inverted.wav"
        write_wav(path, [(0, CLOCK), (1, CLOCK)], rate=1000, amplitude=0.5, invert=True)
        with wave.open(str(path)) as source:
            self.assertEqual(source.getparams()[:4], (1, 2, 1000, 2000))
            values = struct.unpack("<2000h", source.readframes(2000))
        self.assertEqual(values, (16384,) * 1000 + (-16384,) * 1000)

    def test_filtered_analog_edges(self):
        rng = random.Random(1977)
        lengths = [rng.randrange(8, 100) for _ in range(200)]
        filtered = []
        state = -0.2
        for index, length in enumerate(lengths):
            target = 0.2 if index % 2 else -0.2
            for _ in range(length):
                state += 0.5 * (target - state)
                filtered.append(round(32768 * (state + 0.04 + rng.uniform(-0.01, 0.01))))
        path = self.pcm(filtered)
        runs, rate, _ = read_wav(path, threshold=0.04, hysteresis=0.02)
        self.assertEqual([v for v, _ in runs], [i % 2 for i in range(len(lengths))])
        for edge, expected in zip(accumulate(n for _, n in runs), accumulate(lengths)):
            self.assertLessEqual(abs(edge - rounded_ratio(expected, CLOCK, rate)),
                                 2 * CLOCK / rate)

    def test_no_implicit_filter_or_silence_trim(self):
        path = self.pcm([0] * 100 + [-1000, 1000] * 20 + [0] * 100)
        runs, rate, count = read_wav(path)
        self.assertEqual(len(runs), 41)
        self.assertEqual(sum(n for _, n in runs), rounded_ratio(count, CLOCK, rate))

    def test_long_constant_and_same_level_intervals(self):
        runs = []
        append_run(runs, 1, MAX_TICKS + 1)
        self.assertEqual(runs, [(1, MAX_TICKS - 1), (1, 2)])
        path = self.root / "long.vbt"
        write_vbt(path, runs)
        self.assertEqual(read_vbt(path), runs)
        self.assertTrue(all(2 <= n <= MAX_TICKS for _, n in runs))
        self.assertEqual(wav_spans(runs, 1000)[-1][0], 1)

    def test_empty_and_sector_padding(self):
        for runs in ([], [(1, 20), (0, 50)]):
            path = self.root / f"{len(runs)}.vbt"
            write_vbt(path, runs)
            self.assertEqual(path.stat().st_size, 1024)
            self.assertEqual(read_vbt(path), runs)
        wav = self.root / "empty.wav"
        write_wav(wav, [])
        self.assertEqual(read_wav(wav), ([], 96000, 0))

    def test_invalid_vbt(self):
        path = self.root / "bad.vbt"
        for magic, clock, count, duration in ((b"BAD!", CLOCK, 0, 2),
                                              (b"VBT1", 1, 0, 2),
                                              (b"VBT1", CLOCK, 0xFFFFFFFF, 2),
                                              (b"VBT1", CLOCK, 129, 2),
                                              (b"VBT1", CLOCK, 1, 1)):
            path.write_bytes(struct.pack("<4sII", magic, clock, count).ljust(512, b"\0") +
                             struct.pack("<I", duration).ljust(512, b"\0"))
            with self.assertRaises(ValueError):
                read_vbt(path)
        path.write_bytes(b"VBT1")
        with self.assertRaisesRegex(ValueError, "truncated"):
            read_vbt(path)

    def test_truncated_wav(self):
        path = self.pcm([10000] * 100)
        path.write_bytes(path.read_bytes()[:-2])
        with self.assertRaisesRegex(ValueError, "truncated"):
            read_wav(path)

    def test_refuse_erased_intervals_and_overwrite(self):
        path = self.root / "output.wav"
        with self.assertRaisesRegex(ValueError, "erases"):
            write_wav(path, [(0, 2), (1, 10000)])
        self.assertFalse(path.exists())
        path.write_bytes(b"preserve")
        with self.assertRaises(FileExistsError):
            write_wav(path, [(0, CLOCK)])
        self.assertEqual(path.read_bytes(), b"preserve")
        with self.assertRaises(FileExistsError):
            write_vbt(path, [])
        self.assertEqual(path.read_bytes(), b"preserve")

    def test_invalid_options(self):
        path = self.pcm([10000] * 10)
        for threshold, hysteresis in ((2, 0), (0, -1), (0.9, 0.2), (float("nan"), 0)):
            with self.assertRaises(ValueError):
                read_wav(path, threshold=threshold, hysteresis=hysteresis)
        for amplitude in (0, -1, 2, float("nan")):
            with self.assertRaises(ValueError):
                write_wav(self.root / "bad.wav", [], amplitude=amplitude)

    def test_sean_reference_exact_intervals(self):
        path = ROOT / "refs/seanriddle.com/moneymindersave.wav"
        if not path.exists():
            self.skipTest("local Sean Riddle WAV unavailable")
        if not (ROOT / "refs/tape-observations/moneymindersave.vbt").exists():
            self.skipTest("local Money Minder VBT unavailable")
        runs, rate, frames = read_wav(path)
        reference = read_vbt(ROOT / "refs/tape-observations/moneymindersave.vbt")
        self.assertEqual((rate, frames), (12780, 707172))
        self.assertEqual(runs, reference[1:-1])

    def test_reference_round_trip(self):
        paths = [ROOT / "refs/tape-observations/moneymindersave.vbt",
                 ROOT / "refs/tape-observations/moneymindersave-modified.vbt",
                 ROOT / "refs/tape-observations/Tape_20261017_173621_187880.vbt",
                 ROOT / "refs/tape-observations/apls-test3.vbt"]
        paths = [path for path in paths if path.exists()]
        if not paths:
            self.skipTest("local reference recordings unavailable")
        for path in paths:
            runs = read_vbt(path)
            for rate in (22050, 44100, 48000, 96000):
                with self.subTest(path=path.name, rate=rate):
                    result = self.round_trip(runs, rate)
                    vbt = self.root / "records.vbt"
                    write_vbt(vbt, result)
                    self.assertEqual(read_vbt(vbt), result)
                    vbt.unlink()

    def test_reference_speed_changes(self):
        path = ROOT / "refs/tape-observations/moneymindersave.vbt"
        if not path.exists():
            self.skipTest("local Money Minder VBT unavailable")
        runs = read_vbt(path)
        # Deliberately vary time in test inputs; the converter never normalizes it.
        for percent in (90, 95, 105, 110):
            ticks = previous = 0
            scaled = []
            for level, duration in runs:
                ticks += duration
                end = rounded_ratio(ticks, percent, 100)
                scaled.append((level, end - previous))
                previous = end
            result = self.round_trip(scaled, 48000)
            vbt = self.root / f"speed{percent}.vbt"
            write_vbt(vbt, result)
            self.assertEqual(read_vbt(vbt), result)


if __name__ == "__main__":
    unittest.main()
