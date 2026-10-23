#!/bin/sh
set -eu
cd "$(dirname "$0")"

cart=${1:-'../software/1 Cartridges/Music Teacher 1 - Audio Focus (experimental).bin'}
output=out/music_bank_check
if [ ! -x obj_dir_headless/Vtop ] || [ ! -f "$cart" ]; then
    echo 'Requires the rebuilt headless simulator and Music Teacher 1 ROM.' >&2
    exit 1
fi
mkdir -p "$output"
PYTHONDONTWRITEBYTECODE=1 python3 - "$output/input.vbk" <<'PY'
from pathlib import Path
import sys
sys.path.insert(0, str(Path("../tools").resolve()))
from keyboard_input import packet

# Wait for Program 1 input before selecting No-Record.
events = [(0xfb, 1, 0), (11, 8, 8), (7, 8, 8), (11, 8, 8), (29, 12, 2),
          (0xfa, 1, 0), (34, 12, 2), (0xfc, 1, 0), (5, 12, 2),
          (0xfb, 1, 0), (29, 12, 2)]
Path(sys.argv[1]).write_bytes(packet(events))
PY

echo "Capturing live octave changes. This takes several minutes."
echo "Progress and key trace: $output/run.log"
./obj_dir_headless/Vtop --cart "$cart" --frames 480 --max-cycles 120000000 \
    --press Z@120:8 --press Z@180:8 --source "$output/input.vbk@260" --source-trace \
    --audio-log "$output/events.csv" --shot-last --outdir "$output" \
    > "$output/run.log" 2>&1
PYTHONDONTWRITEBYTECODE=1 python3 - "$output/run.log" "$output/events.csv" <<'PY'
import csv
from pathlib import Path
import re
import sys

log = Path(sys.argv[1]).read_text()
presses = [(int(frame), int(key, 16)) for frame, key in
           re.findall(r'\[source-key\] frame=(\d+).*keys=([0-9A-F]+)', log)]
keys = [key for _, key in presses]
expected = [19, 11, 7, 11, 29, 33, 34, 22, 5, 19, 29]
if keys != [1 << key for key in expected] or 'entry finished' not in log:
    raise SystemExit('Octave playback did not complete; inspect ' + sys.argv[1])
with Path(sys.argv[2]).open(newline='') as source:
    events = list(csv.DictReader(source))
for index in (4, 6, 8, 10):
    start = presses[index][0]
    codes = {event['code'] for event in events if start + 2 <= int(event['frame']) < start + 12}
    if len(codes) < 2:
        raise SystemExit(f'No note DAC transitions after key at frame {start}')
print('All three octave changes acknowledged; all four notes produced DAC transitions.')
gaps = [presses[index + 1][0] - presses[index][0] for index in (5, 7, 9)]
print('Bank key to next note key (fields): ' + ', '.join(map(str, gaps)))
PY
