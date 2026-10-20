#!/bin/sh
set -eu
cd "$(dirname "$0")"

cart='../software/1 Cartridges/Music Teacher 1 (1978.03.28)(VideoBrain Computer Company)(VideoBrain)(Cart)[ED01].bin'
output=out/audio_timing_audit
if [ ! -x obj_dir_headless/Vtop ] || [ ! -f "$cart" ]; then
    echo 'Requires the headless simulator and original Music Teacher 1 ED01 ROM.' >&2
    exit 1
fi

mkdir -p "$output"
echo "Capturing original-cartridge audio timing. This takes over five minutes."
echo "Progress and CPU trace: $output/cpu.txt"
./obj_dir_headless/Vtop --cart "$cart" --frames 342 --max-cycles 83000000 \
    --press Z@120:8 --press Z@180:8 --press V@260:8 --press K@320:100 \
    --audio-log "$output/events.csv" --trace-from 340 --trace-cpu 12000 \
    --outdir "$output" > "$output/cpu.txt" 2>&1
echo "Saved $output/cpu.txt and $output/events.csv"
