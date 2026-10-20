#!/bin/sh
set -eu
cd "$(dirname "$0")"

output=out/audio_note_phase
cart='../software/1 Cartridges/Music Teacher 1 (1978.03.28)(VideoBrain Computer Company)(VideoBrain)(Cart)[ED01].bin'
if [ ! -f "$cart" ]; then
    echo 'Requires the original Music Teacher 1 ED01 ROM.' >&2
    exit 1
fi
if [ -e "$output/events.csv" ] || [ -e "$output/trace.csv" ]; then
    echo "Preserve or remove $output before repeating the capture." >&2
    exit 1
fi
mkdir -p "$output"
echo "Building the simulator. Log: $output/build.log"
if ! make -j"${JOBS:-4}" headless > "$output/build.log" 2>&1; then
    tail -n 60 "$output/build.log"
    exit 1
fi
echo "Long full-ROM capture; progress: $output/cpu.txt"
./obj_dir_headless/Vtop --cart "$cart" --frames 490 --max-cycles 119000000 \
    --press Z@120:8 --press Z@180:8 --press V@260:8 \
    --press K@320:24:0 --press K@364:24:59850 \
    --press K@408:24:119700 --press K@452:24:179550 \
    --audio-log "$output/events.csv" --audio-trace "$output/trace.csv" \
    --outdir "$output" > "$output/cpu.txt" 2>&1
PYTHONDONTWRITEBYTECODE=1 python3 tests/audio_note_phase.py "$output" \
    --expected-notes 4 > "$output/comparison.txt"
cat "$output/comparison.txt"
