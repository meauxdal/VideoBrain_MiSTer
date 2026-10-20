#!/bin/sh
set -eu
cd "$(dirname "$0")"

baseline=out/audio_timing_audit/events.csv
output=out/audio_bus_timing
cart='../software/1 Cartridges/Music Teacher 1 (1978.03.28)(VideoBrain Computer Company)(VideoBrain)(Cart)[ED01].bin'
if [ ! -f "$baseline" ] || [ ! -f "$cart" ]; then
    echo 'Requires the saved original timing capture and Music Teacher 1 ED01 ROM.' >&2
    exit 1
fi

mkdir -p "$output"
echo "Building the updated headless simulator. Log: $output/build.log"
if ! make -j"${JOBS:-4}" headless > "$output/build.log" 2>&1; then
    tail -n 60 "$output/build.log"
    exit 1
fi
echo 'Capturing the same original-ROM held note. This takes over five minutes.'
echo "Progress and CPU trace: $output/cpu.txt"
./obj_dir_headless/Vtop --cart "$cart" --frames 342 --max-cycles 83000000 \
    --press Z@120:8 --press Z@180:8 --press V@260:8 --press K@320:100 \
    --audio-log "$output/events.csv" --trace-from 340 --trace-cpu 12000 \
    --outdir "$output" > "$output/cpu.txt" 2>&1
PYTHONDONTWRITEBYTECODE=1 python3 tests/compare_audio_timing.py \
    "$baseline" "$output/events.csv" > "$output/comparison.txt"
cat "$output/comparison.txt"
