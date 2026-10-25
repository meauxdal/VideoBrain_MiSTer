#!/usr/bin/env python3
"""Create, inspect and export append-only VBP1 printer images."""
import argparse
import json
import os
from pathlib import Path
import struct
import sys
import zlib

SECTOR = 512
PAYLOAD = 480
START, DATA, STOP = 1, 2, 3
CLEAN, RESET, FRAMING, OVERFLOW, FULL = range(5)
REASONS = ('clean', 'reset', 'framing', 'overflow', 'full')
HEADER = struct.Struct('<4sII BB H Q I I')


def checksum(block):
    b = bytearray(block)
    b[28:32] = bytes(4)
    return zlib.crc32(b)


def superblock(sectors):
    b = bytearray(SECTOR)
    struct.pack_into('<4sIIII', b, 0, b'VBP1', 1, SECTOR, 32, sectors)
    struct.pack_into('<I', b, 28, checksum(b))
    return bytes(b)


def record(sequence, session, kind, baud, offset, payload=b'', reason=CLEAN):
    if len(payload) > PAYLOAD:
        raise ValueError('record payload too large')
    b = bytearray(SECTOR)
    HEADER.pack_into(b, 0, b'VPR1', sequence, session, kind, baud,
                     len(payload), offset, reason, 0)
    b[32:32 + len(payload)] = payload
    struct.pack_into('<I', b, 28, checksum(b))
    return bytes(b)


def create(path, size=1024 * 1024):
    if size % SECTOR or not 4 * SECTOR <= size <= 16 * 1024 * 1024:
        raise ValueError('size must be 512-byte aligned, 2048 bytes..16 MiB')
    with open(path, 'xb') as f:
        f.write(superblock(size // SECTOR))
        zero = bytes(SECTOR)
        for _ in range(size // SECTOR - 1):
            f.write(zero)
        f.flush()
        os.fsync(f.fileno())


def inspect(path):
    raw = Path(path).read_bytes()
    if len(raw) % SECTOR or not 2048 <= len(raw) <= 16 * 1024 * 1024:
        raise ValueError('invalid image size')
    if raw[:SECTOR] != superblock(len(raw) // SECTOR):
        raise ValueError('invalid VBP1 superblock')
    sessions = []
    current = None
    offset = 0
    next_session = 1
    sequence = 1
    fault = None
    zero_seen = False
    for lba in range(1, len(raw) // SECTOR):
        b = raw[lba * SECTOR:(lba + 1) * SECTOR]
        if b == bytes(SECTOR):
            zero_seen = True
            continue
        if fault:
            continue
        try:
            if zero_seen:
                raise ValueError('nonzero record after zero hole')
            magic, seq, sid, kind, baud, count, pos, reason, crc = HEADER.unpack_from(b)
            if magic != b'VPR1' or seq != sequence or pos != offset:
                raise ValueError('record magic, sequence or offset mismatch')
            if crc != checksum(b) or count > PAYLOAD or any(b[32 + count:]):
                raise ValueError('record CRC, length or padding mismatch')
            if baud not in (0, 1):
                raise ValueError('unknown baud')
            if kind == START:
                if current is not None or sid != next_session or count or reason:
                    raise ValueError('invalid START')
                current = {'id': sid, 'baud': 110 if baud else 300,
                           'data': bytearray(), 'reason': 'interrupted', 'counters': None}
                sessions.append(current)
            else:
                if current is None or sid != current['id'] or baud != (current['baud'] == 110):
                    raise ValueError('session mismatch')
                if kind == DATA:
                    if not count or reason:
                        raise ValueError('invalid DATA')
                    current['data'].extend(b[32:32 + count])
                    offset += count
                elif kind == STOP:
                    if count != 16 or reason >= len(REASONS):
                        raise ValueError('invalid STOP')
                    current['reason'] = REASONS[reason]
                    current['counters'] = struct.unpack_from('<4I', b, 32)
                    current = None
                    next_session += 1
                else:
                    raise ValueError('unknown record type')
            sequence += 1
        except ValueError as e:
            fault = f'sector {lba}: {e}'
    return sessions, fault


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='command', required=True)
    new = sub.add_parser('new')
    new.add_argument('image')
    new.add_argument('--size', type=int, default=1024 * 1024, help='allocated bytes')
    for command in ('inspect', 'export'):
        a = sub.add_parser(command)
        a.add_argument('image')
        if command == 'export':
            a.add_argument('output')
            a.add_argument('--session', type=int)
            a.add_argument('--recover', action='store_true')
            a.add_argument('--text', help='separate readable output path')
            a.add_argument('--remove-nul', action='store_true')
            a.add_argument('--normalize-crlf', action='store_true')
    args = p.parse_args(argv)
    try:
        if args.command == 'new':
            create(args.image, args.size)
            return 0
        sessions, fault = inspect(args.image)
        if args.command == 'export' and args.session is not None:
            sessions = [s for s in sessions if s['id'] == args.session]
            if not sessions:
                raise ValueError('session not found')
        summary = {'sessions': [{k: v for k, v in s.items() if k != 'data'} |
                                {'bytes': len(s['data'])} for s in sessions], 'error': fault}
        print(json.dumps(summary, indent=2))
        incomplete = bool(fault) or any(s['reason'] != 'clean' for s in sessions)
        if args.command == 'export':
            if incomplete and not args.recover:
                raise ValueError('incomplete/error capture; use --recover for verified prefix')
            paths = [Path(args.output)] + ([Path(args.text)] if args.text else [])
            if len(set(paths)) != len(paths) or any(x.exists() for x in paths):
                raise ValueError('output paths must be distinct new files')
            data = b''.join(s['data'] for s in sessions)
            with open(args.output, 'xb') as f:
                f.write(data)
            if args.text:
                text = data.replace(b'\0', b'') if args.remove_nul else data
                if args.normalize_crlf:
                    text = text.replace(b'\r\n', b'\n')
                with open(args.text, 'xb') as f:
                    f.write(text)
            if incomplete:
                print('WARNING: exported verified prefix of incomplete/error capture', file=sys.stderr)
        return 2 if incomplete else 0
    except (OSError, ValueError) as e:
        print(f'printer_image: {e}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
