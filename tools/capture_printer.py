#!/usr/bin/env python3
"""Capture VideoBrain printer bytes through MiSTer's HPS UART (Linux)."""
import argparse
import fcntl
import os
from pathlib import Path
import select
import signal
import sys
import termios


def capture(device, output, baud, idle_timeout=None):
    """Preserve all eight bits, NULs and CR/LF; restore tty settings on exit."""
    fd = os.open(device, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    previous = None
    total = 0
    try:
        # Cooperating capture processes cannot share the UART. Existing MiSTer
        # UART services must still be stopped by selecting connection None.
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        previous = termios.tcgetattr(fd)
        speed = {110: termios.B110, 300: termios.B300}[baud]
        attrs = termios.tcgetattr(fd)
        attrs[0] = 0  # No parity stripping, CR/LF conversion or XON/XOFF.
        attrs[1] = 0
        attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
        attrs[3] = 0
        attrs[4] = attrs[5] = speed
        attrs[6][termios.VMIN] = 1
        attrs[6][termios.VTIME] = 0
        termios.tcsetattr(fd, termios.TCSANOW, attrs)
        termios.tcflush(fd, termios.TCIFLUSH)  # Discard traffic from the prior UART source.
        # Exclusive creation prevents accidentally replacing a previous report.
        with Path(output).open("xb", buffering=0) as destination:
            print(f"Capturing {device} at {baud} baud to {output}; Ctrl+C stops.",
                  flush=True)
            try:
                while select.select([fd], [], [], idle_timeout)[0]:
                    data = os.read(fd, 4096)
                    if not data:
                        raise OSError("UART disconnected")
                    remaining = memoryview(data)
                    while remaining:
                        remaining = remaining[destination.write(remaining):]
                    total += len(data)
            except KeyboardInterrupt:
                pass
            finally:
                os.fsync(destination.fileno())
    finally:
        try:
            if previous is not None:
                termios.tcsetattr(fd, termios.TCSANOW, previous)
        finally:
            os.close(fd)
    return total


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", help="new raw output file (must not exist)")
    parser.add_argument("--device", default="/dev/ttyS1")
    parser.add_argument("--baud", type=int, choices=(110, 300), default=300)
    parser.add_argument("--idle-timeout", type=float,
                        help="stop after this many seconds without bytes (including before first byte)")
    args = parser.parse_args()
    if args.idle_timeout is not None and args.idle_timeout <= 0:
        parser.error("--idle-timeout must be positive")
    def stop(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, stop)
    try:
        total = capture(args.device, args.output, args.baud, args.idle_timeout)
    except (OSError, termios.error) as exc:
        print(f"Capture failed: {exc}", file=sys.stderr)
        return 1
    print(f"Saved {total} bytes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
