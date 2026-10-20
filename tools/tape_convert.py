"""Convert VideoBrain WAV/VBT waveforms without decoding cassette records."""

import argparse
from contextlib import contextmanager
from itertools import groupby
from pathlib import Path
import struct
import wave


CLOCK = 14318180
MAX_TICKS = 0x7FFFFFFF


def rounded_ratio(value, numerator, denominator):
    return (value * numerator + denominator // 2) // denominator


def append_run(runs, level, duration):
    if duration < 2:
        raise ValueError("interval shorter than two VBT ticks")
    if runs and runs[-1][0] == level:
        duration += runs.pop()[1]
    while duration > MAX_TICKS:
        part = MAX_TICKS if duration != MAX_TICKS + 1 else MAX_TICKS - 1
        runs.append((level, part))
        duration -= part
    runs.append((level, duration))


def read_vbt(path):
    with Path(path).open("rb") as source:
        header = source.read(512)
        if len(header) != 512:
            raise ValueError("truncated VBT header")
        magic, clock, count = struct.unpack_from("<4sII", header)
        if magic != b"VBT1" or clock != CLOCK:
            raise ValueError("expected VBT1 at 14318180 Hz")
        if count == 0xFFFFFFFF:
            raise ValueError("incomplete VBT recording")
        size = source.seek(0, 2)
        if size < 1024 or size % 512 or count > (size - 512) // 4:
            raise ValueError("truncated or non-sector-aligned VBT image")
        source.seek(512)
        runs = []
        for (value,) in struct.iter_unpack("<I", source.read(count * 4)):
            append_run(runs, value >> 31, value & MAX_TICKS)
        return runs


@contextmanager
def new_output(path):
    path = Path(path)
    output = path.open("xb")
    try:
        with output:
            yield output
    except BaseException:
        path.unlink()
        raise


def write_vbt(path, runs):
    if len(runs) >= 0xFFFFFFFF:
        raise ValueError("too many VBT intervals")
    with new_output(path) as output:
        output.write(struct.pack("<4sII", b"VBT1", CLOCK, len(runs)).ljust(512, b"\0"))
        for level, duration in runs:
            output.write(struct.pack("<I", level << 31 | duration))
        size = max(1024, (output.tell() + 511) // 512 * 512)
        output.truncate(size)


def read_wav(path, channel=None, threshold=0.0, hysteresis=0.0, invert=False):
    if not -1 <= threshold <= 1 or not 0 <= hysteresis <= 1:
        raise ValueError("threshold must be -1..1; hysteresis must be 0..1")
    low, high = threshold - hysteresis, threshold + hysteresis
    if low < -1 or high >= 1:
        raise ValueError("threshold +/- hysteresis must be within [-1, 1)")
    with wave.open(str(path), "rb") as source:
        channels, width, rate, frames, compression, _ = source.getparams()
        if compression != "NONE" or width not in (1, 2, 3, 4):
            raise ValueError("expected uncompressed 8/16/24/32-bit PCM WAV")
        if channel is None:
            if channels != 1:
                raise ValueError("select --channel for a multichannel WAV (1-based)")
            channel = 1
        if not 1 <= channel <= channels:
            raise ValueError("channel outside WAV channel count")
        stride = channels * width
        offset = (channel - 1) * width
        scale = 1 << (width * 8 - 1)
        runs = []
        previous = None
        start_tick = index = 0
        while True:
            data = source.readframes(65536)
            if not data:
                break
            if len(data) % stride:
                raise ValueError("truncated WAV frame")
            for position in range(offset, len(data), stride):
                sample = data[position:position + width]
                value = (sample[0] - 128 if width == 1 else
                         int.from_bytes(sample, "little", signed=True)) / scale
                if previous is None:
                    level = int(value >= threshold)
                    previous = level
                elif value > high:
                    level = 1
                elif value < low:
                    level = 0
                else:
                    level = previous
                if level != previous:
                    tick = rounded_ratio(index, CLOCK, rate)
                    append_run(runs, previous ^ bool(invert), tick - start_tick)
                    start_tick = tick
                    previous = level
                index += 1
        if index != frames:
            raise ValueError("truncated WAV data")
        if previous is not None:
            append_run(runs, previous ^ bool(invert),
                       rounded_ratio(index, CLOCK, rate) - start_tick)
        return runs, rate, frames


def wav_spans(runs, rate):
    if not 1 <= rate <= 0xFFFFFFFF:
        raise ValueError("invalid WAV sample rate")
    spans = []
    ticks = last_sample = 0
    for level, group in groupby(runs, key=lambda run: run[0]):
        duration = sum(n for _, n in group)
        ticks += duration
        end = rounded_ratio(ticks, rate, CLOCK)
        if end == last_sample:
            raise ValueError("sample rate erases an interval; use a higher --rate")
        spans.append((level, end - last_sample))
        last_sample = end
    if last_sample * 2 > 0xFFFFFFFF - 36:
        raise ValueError("output exceeds PCM RIFF WAV size limit")
    return spans


def write_wav(path, runs, rate=96000, amplitude=0.8, invert=False):
    if not 0 < amplitude <= 1:
        raise ValueError("amplitude must be greater than 0 and at most 1")
    spans = wav_spans(runs, rate)
    magnitude = max(1, round(amplitude * 32767))
    blocks = [struct.pack("<h", -magnitude) * 65536,
              struct.pack("<h", magnitude) * 65536]
    with new_output(path) as output, wave.open(output, "wb") as target:
        target.setparams((1, 2, rate, sum(n for _, n in spans), "NONE", "not compressed"))
        for level, count in spans:
            block = blocks[level ^ bool(invert)]
            while count:
                size = min(count, 65536)
                target.writeframesraw(block[:size * 2])
                count -= size


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    export = commands.add_parser("to-wav", help="export VBT levels as mono 16-bit PCM")
    export.add_argument("source", type=Path)
    export.add_argument("output", type=Path)
    export.add_argument("--rate", type=int, default=96000)
    export.add_argument("--amplitude", type=float, default=0.8, help="full-scale fraction (default: 0.8)")
    capture = commands.add_parser("to-vbt", help="capture PCM WAV threshold crossings")
    capture.add_argument("source", type=Path)
    capture.add_argument("output", type=Path)
    capture.add_argument("--channel", type=int, help="1-based channel; required for multichannel WAV")
    capture.add_argument("--threshold", type=float, default=0.0, help="normalized PCM level (default: 0)")
    capture.add_argument("--hysteresis", type=float, default=0.0,
                         help="half-width around threshold (default: 0; no filtering)")
    for command in (export, capture):
        command.add_argument("--invert", action="store_true", help="reverse signal polarity")
    args = parser.parse_args()
    try:
        if args.command == "to-wav":
            runs = read_vbt(args.source)
            write_wav(args.output, runs, args.rate, args.amplitude, args.invert)
            frames = sum(n for _, n in wav_spans(runs, args.rate))
            print(f"{len(runs)} intervals -> {frames} frames at {args.rate} Hz")
        else:
            runs, rate, frames = read_wav(args.source, args.channel, args.threshold,
                                         args.hysteresis, args.invert)
            write_vbt(args.output, runs)
            print(f"{frames} frames at {rate} Hz -> {len(runs)} intervals")
        print(f"{sum(n for _, n in runs) / CLOCK:.9f} seconds; {args.output}")
    except (OSError, ValueError, wave.Error, EOFError, struct.error) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
