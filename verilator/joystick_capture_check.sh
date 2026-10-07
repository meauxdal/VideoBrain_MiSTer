#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
make headless

out=out/joystick/capture15
mkdir -p "$out"

./obj_dir_headless/Vtop \
    --cart "../software/Checkers (197x)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN04].bin" \
    --frames 280 \
    --press SPACE@140:8 \
    --press Y@250:8 \
    --joy-trace 261 \
    --joy-timer-base 2580 \
    --joy-timer-step 6 \
    --dump 262,280 --ram \
    --dump-file "$out/checkers_state.txt" \
    --outdir "$out" \
    --quiet > "$out/checkers_trace.txt"

printf 'Joystick capture logs: %s\n' "$out"
