#!/usr/bin/env python3
"""Produce a local Information Manager listing with MAME unidasm."""

import argparse
import hashlib
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
CHIPS = (
    (0x1000, "vb1200a_1000-17ff_9_25_78_51", "39c2821f73c86c3e368fe5429628672cfe594306"),
    (0x3000, "vb1200c_3000-37ff_9_25_78_51", "d98b94ae1cce2ce6e6ae933180a7bf001b73932f"),
    (0x3800, "vb-1200_3800-3fff_9_26_78", "3a38a889b552acaa1a284e2ca7447f142b494737"),
)
DATA = (
    (0x1000, 0x1012), (0x1094, 0x10AD), (0x117D, 0x1189),
    (0x11D5, 0x11E1), (0x1222, 0x1228), (0x12F1, 0x130F),
    (0x16F9, 0x16FD), (0x174B, 0x1800), (0x3000, 0x3036),
    (0x3115, 0x317C), (0x3259, 0x3267), (0x3782, 0x37BD),
    (0x3A71, 0x3A77), (0x3C32, 0x3C36),
    (0x3C9B, 0x3C9F), (0x3F47, 0x4000),
)
NOTES = {
    0x1000: "Cartridge signature AA 55; color 02; title 'INFO MANAGER'.",
    0x1012: "Cartridge entry: initialize video and workspace, then peripheral setup.",
    0x1068: "Menu selection: EN -> 10AD, ED -> 11E1, R -> 119D (BIOS glyph codes).",
    0x1094: "Bitmap data; followed by six-byte input descriptors at 10A1 and 10A7.",
    0x10AD: "EN menu path: clear field count, then collect field definitions.",
    0x117D: "Six-byte input descriptors: NAME and LENGTH.",
    0x1189: "Field length lookup: code 11 uses stored length; other types use 8 bytes.",
    0x119D: "R menu path: record processing through interpreter requests at 11DB/11DE.",
    0x11D5: "Six-byte input descriptor; two three-byte interpreter requests follow.",
    0x11E1: "ED menu path: record processing through interpreter requests at 1222/1225.",
    0x1222: "Three-byte interpreter requests.",
    0x123F: "Display selected total/sort fields and numeric totals.",
    0x12F1: "Input/display descriptors; not F8 instructions.",
    0x1641: "Interpret table entries; dispatch through 3000 and 16F9.",
    0x16DC: "Computed subroutine call through K; execution continues at 16DD.",
    0x16F9: "Big-endian parser callback addresses: 3036, 317C.",
    0x16FD: "Dispatch nonzero operation through table 3000 (one-based index).",
    0x171D: "Computed handler call; handlers rejoin at 171E.",
    0x1741: "H = 1748 + 3 * R1: locate a three-byte interpreter entry.",
    0x174B: "Interpreter tables; three-byte entries, not F8 instructions.",
    0x3000: "27 big-endian command-handler addresses, indexed from one.",
    0x3036: "Parse next token from input buffer; command keyword lookup at 3115.",
    0x3115: "Keyword records: operation byte, glyph string, 00; final 7F sentinel.",
    0x317C: "Parser callback for buffered numeric/field input.",
    0x31C5: "Prompt for each field name/type/length.",
    0x3259: "Field input descriptors: TYPE, LENGTH and field text.",
    0x33DD: "Copy six-byte input descriptor to 0C10, then enter input routine.",
    0x33F1: "Build input descriptor using H as buffer pointer.",
    0x3782: "BIOS glyph -> printer/ASCII lookup, indexed at 3755.",
    0x3839: "Convert unsigned byte R0 to three decimal glyphs at DC.",
    0x3888: "Convert three decimal glyphs at DC to binary value.",
    0x38AD: "Decimal digit -> BIOS glyph, using reverse table ending at 2467.",
    0x391E: "Increment byte at DC.",
    0x3922: "Decrement byte at DC.",
    0x3934: "Load pointer from memory at DC.",
    0x3986: "Clear R0 bytes starting at DC.",
    0x39E5: "Unreferenced entry: select alternate eight-byte arithmetic path at 39CA.",
    0x3A71: "Three-byte interpreter requests for field input.",
    0x3AF5: "Initialize Expander link; send 05, 00 and mode byte from 1BCE.",
    0x3C32: "Four-byte peripheral transfer descriptor.",
    0x3C9B: "Four-byte peripheral transfer descriptor.",
    0x3C9F: "Unreferenced entry: port status and register/flag restoration.",
    0x3CB5: "Interrupt-driven byte transfer through host port 1.",
    0x3D25: "Compute two-byte checksum over a length-prefixed block.",
    0x3DEC: "Send eight bits, MSB first, via timed callback 3E17.",
    0x3E17: "Output bit on port 1 bit 5; check peripheral response.",
    0x3E2D: "Serial byte output with framing through callback 3E17.",
    0x3E64: "Sample peripheral status through timed callback 3E6E.",
    0x3EB5: "Save context and install interrupt transfer state.",
    0x3EE6: "Expander interrupt service continuation.",
    0x3F2A: "Display message selected by HU through pointer table 3F47.",
    0x3F47: "Five big-endian message pointers; glyph strings follow.",
    0x3F51: "Menu and prompt text in BIOS glyph encoding; F0 padding at 3FF9.",
}
GLYPHS = {
    0x00: ' ', **dict(zip(range(1, 0x35, 2), 'IUYTREWQAOKJHGFDSZPLMNBVCX')),
    0x35: '?', 0x36: '0', 0x37: ';', 0x39: ',', 0x3A: '*',
    0x0A: '9', 0x0C: '8', 0x0E: '7', 0x1E: '6', 0x20: '5',
    0x22: '4', 0x24: '1', 0x32: '3', 0x34: '2',
    0x12: '.', 0x16: ')', 0x18: '(', 0x1A: '/', 0x1C: '-',
    0x28: '$', 0x2A: ':', 0x2C: "'", 0x2E: '=', 0x30: '+',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--unidasm', required=True, type=Path)
    parser.add_argument('--rom', type=Path, default=ROOT / 'software/3 MAME (vidbrain)/infoman.zip')
    parser.add_argument('--output', type=Path, default=ROOT / 'refs/infoman/infoman.lst')
    args = parser.parse_args()
    memory = {}
    with zipfile.ZipFile(args.rom) as archive:
        for base, name, digest in CHIPS:
            data = archive.read(name)
            if len(data) != 2048 or hashlib.sha1(data).hexdigest() != digest:
                raise ValueError(f'Unexpected ROM: {name}')
            memory.update(enumerate(data, base))

    def word(pc):
        return memory[pc] * 256 + memory[pc + 1]

    def is_data(pc):
        return any(start <= pc < end for start, end in DATA)

    notes = dict(NOTES)
    pc = 0x3115
    while memory[pc] != 0x7F:
        start = pc
        token = memory[pc]
        pc += 1
        text = ''
        while memory[pc]:
            text += GLYPHS[memory[pc]]
            pc += 1
        pc += 1
        notes[start] = f"Keyword '{text}', interpreter index {token:02X}; 00 terminator."
    notes[pc] = 'Keyword table sentinel.'
    for pc in range(0x3000, 0x3036, 2):
        notes[pc] = f'Operation {(pc - 0x3000) // 2 + 1:02X} -> L{word(pc):04X}.'
    for start, end in ((0x3F51, 0x3F58), (0x3F59, 0x3F5E), (0x3F5F, 0x3F65),
                       (0x3F66, 0x3F6A), (0x3F75, 0x3F7D), (0x3F7E, 0x3F80),
                       (0x3F80, 0x3F86), (0x3F87, 0x3F8C), (0x3F8D, 0x3F94),
                       (0x3F95, 0x3FA0), (0x3FA1, 0x3FA7), (0x3FA9, 0x3FB1),
                       (0x3FB1, 0x3FB8), (0x3FB9, 0x3FC5), (0x3FC6, 0x3FD1),
                       (0x3FD2, 0x3FD8), (0x3FD9, 0x3FDF), (0x3FDF, 0x3FE5),
                       (0x3FE6, 0x3FF2), (0x3FF3, 0x3FF8)):
        text = ''.join(GLYPHS[memory[a]] for a in range(start, end))
        notes[start] = f"Glyph text: '{text}'."

    decoded = {}
    code = {}
    targets = {0x1012, 0x16DD, 0x171E, 0x39E5, 0x3C36, 0x3C9F, 0x3CB5,
               0x3E17, 0x3E6E, 0x3EB5, 0x3EE6}
    targets.update(word(pc) for pc in range(0x3000, 0x3036, 2))
    targets.update(word(pc) for pc in (0x16F9, 0x16FB))
    pending = list(targets)
    pattern = re.compile(r"^([0-9A-F]+):\s+((?:[0-9A-F]{2} )*[0-9A-F]{2})\s{2,}(.+)$")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='decode-', dir=args.output.parent) as directory:
        while pending:
            pc = pending.pop()
            if pc not in memory or is_data(pc) or pc in code:
                continue
            if pc not in decoded:
                end = 0x1800 if pc < 0x1800 else 0x4000
                binary = Path(directory) / 'decode.bin'
                binary.write_bytes(bytes(memory[a] for a in range(pc, end)))
                result = subprocess.run(
                    [str(args.unidasm), str(binary), '-arch', 'f8', '-basepc', f'{pc:X}', '-upper'],
                    check=True, capture_output=True, text=True)
                for line in result.stdout.splitlines():
                    match = pattern.match(line)
                    if match:
                        address = int(match[1], 16)
                        raw = bytes.fromhex(match[2])
                        decoded.setdefault(address, (raw, match[3].strip()))
            raw, instruction = decoded[pc]
            if any(is_data(pc + n) for n in range(len(raw))):
                raise ValueError(f'Instruction overlaps data at {pc:04X}')
            if '(?)' in instruction:
                raise ValueError(f'Invalid reachable instruction at {pc:04X}: {instruction}')
            code[pc] = raw, instruction
            op = raw[0]
            branch = re.search(r"H'([0-9A-F]{4})'$", instruction)
            if op in (0x28, 0x29) or 0x80 <= op <= 0x87 or 0x8F <= op <= 0x9F:
                if branch:
                    target = int(branch[1], 16)
                    targets.add(target)
                    pending.append(target)
            if op not in (0x29, 0x90, 0x0C, 0x0D, 0x1C):
                pending.append(pc + len(raw))

    covered = {}
    for pc, (raw, _) in code.items():
        for n, value in enumerate(raw):
            address = pc + n
            if address in covered or memory[address] != value:
                raise ValueError(f'Code overlap or byte mismatch at {address:04X}')
            covered[address] = value

    lines = ['; Information Manager VB-1200 prototype, September 25/26, 1978.',
             '; MAME unidasm F8 syntax. Address and raw bytes retained.',
             '; Static analysis; DB outside confirmed data ranges may be untraced code.',
             '; This is a listing, not an assembler source. See docs/INFOMAN.md.', '']
    for base, name, digest in CHIPS:
        lines += [f'; {name}', f'; SHA1 {digest}', '']
        pc = base
        while pc < base + 2048:
            if pc in notes:
                lines += ['', '; ' + notes[pc]]
            if pc in targets and pc in code:
                lines.append(f'L{pc:04X}:')
            if pc in code:
                raw, instruction = code[pc]
            else:
                end = pc + 1
                while (end < base + 2048 and end - pc < 8 and end not in code
                       and end not in notes and end not in targets
                       and is_data(end) == is_data(pc)):
                    end += 1
                raw = bytes(memory[a] for a in range(pc, end))
                instruction = 'DB   ' + ','.join(f"H'{v:02X}'" for v in raw)
                if not is_data(pc):
                    instruction += ' ; untraced'
                for n, value in enumerate(raw):
                    covered[pc + n] = value
            lines.append(f'{pc:04X}: {raw.hex(" ").upper():<23} {instruction}')
            pc += len(raw)
    if covered != memory:
        raise ValueError('Listing does not reproduce the ROM bytes')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text('\n'.join(lines) + '\n', encoding='ascii')
    print(f'{args.output}: {len(memory)} bytes verified, {sum(len(v[0]) for v in code.values())} decoded as code')


if __name__ == '__main__':
    main()
