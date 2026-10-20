#!/bin/sh
set -eu
cd "$(dirname "$0")"

cart=${1:-'../software/1 Cartridges/Music Teacher 1 - Audio Focus (experimental).bin'}
output=out/music_audio_b5
set --
case ${VB_240P:-0} in
    0) ;;
    1) output=out/music_audio_b5_240p; set -- --240p ;;
    *) echo 'VB_240P must be 0 or 1.' >&2; exit 1 ;;
esac

if [ ! -x obj_dir_headless/Vtop ] || [ ! -f "$cart" ]; then
    echo 'Requires the headless simulator and Music Teacher 1 ROM.' >&2
    exit 1
fi

mkdir -p "$output"
make headless
make test-smi test-cpu-interrupt
./obj_dir_headless/Vtop "$@" --cart "$cart" --frames 430 --max-cycles 110000000 \
    --press Z@120:8 --press Z@180:8 --press V@260:8 --press K@320:100 \
    --audio-log "$output/events.csv" --shot 179,259,319 --shot-last --outdir "$output"
if [ "$(wc -l < "$output/events.csv")" -le 1 ]; then
    echo "No DAC events captured. Check the screenshots in $output." >&2
    exit 1
fi
PYTHONDONTWRITEBYTECODE=1 python3 tests/test_mt1_audio_timing.py "$output/events.csv"
make test-audio
./out/obj_audio/Vvideobrain_audio "$output/events.csv" "$output/samples.csv"
python3 tests/audio_spectrum.py "$output/events.csv" "$output/samples.csv" \
    "$output" B5:340:410 > "$output/spectrum.csv"
cat "$output/spectrum.csv"
