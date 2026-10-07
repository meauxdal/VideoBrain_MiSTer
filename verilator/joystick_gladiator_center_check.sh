#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
make headless

base=${1:-2580}
step=${2:-6}
out=${3:-out/joystick/gladiator_center1}
mkdir -p "$out"

./obj_dir_headless/Vtop \
    --cart "../software/Gladiator (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN01].bin" \
    --frames 290 \
    --press SPACE@140:8 \
    --joy UP@155:8 --joy2 UP@155:8 \
    --joy DOWN@163:8 --joy2 DOWN@163:8 \
    --joy LEFT@171:8 --joy2 LEFT@171:8 \
    --joy RIGHT@179:8 --joy2 RIGHT@179:8 \
    --joy-trace 150 \
    --joy-timer-base "$base" --joy-timer-step "$step" \
    --dump 154,186,193,213,233,253,273,289 --ram \
    --dump-file "$out/gladiator_state.txt" \
    --shot 154,186,193,213,233,253,273,289 \
    --outdir "$out" --prefix gladiator \
    --quiet > "$out/gladiator_trace.txt"

printf 'Gladiator center logs and frames: %s\n' "$out"
