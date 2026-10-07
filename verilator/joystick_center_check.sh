#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
make headless

out=out/joystick/center1
mkdir -p "$out"

./obj_dir_headless/Vtop \
    --cart "../software/Checkers (197x)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN04].bin" \
    --frames 410 \
    --press SPACE@140:8 \
    --press Y@250:8 \
    --joy UP@265:16 \
    --joy DOWN@285:16 \
    --joy LEFT@305:16 \
    --joy RIGHT@325:16 \
    --joy-trace 341 \
    --joy-timer-base 2580 \
    --joy-timer-step 6 \
    --dump 351,369,389,409 --ram \
    --dump-file "$out/checkers_state.txt" \
    --shot 351,369,389,409 \
    --outdir "$out" \
    --prefix checkers \
    --quiet > "$out/checkers_trace.txt"

printf 'Joystick center logs and frames: %s\n' "$out"
