#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
make headless

out=out/joystick/diag14
mkdir -p "$out"

./obj_dir_headless/Vtop \
    --cart ../../VideoBrain-Tests/JoystickDiag.bin \
    --frames 265 \
    --joy UP@145:24 --joy2 UP@145:24 \
    --joy DOWN@169:24 --joy2 DOWN@169:24 \
    --joy LEFT@193:24 --joy2 LEFT@193:24 \
    --joy RIGHT@217:24 --joy2 RIGHT@217:24 \
    --joy-trace 140 \
    --joy-timer-base 2580 \
    --joy-timer-step 6 \
    --shot 144,168,192,216,240,264 \
    --dump 144,168,192,216,240,264 --ram \
    --dump-file "$out/diag_state.txt" \
    --outdir "$out" --prefix diag \
    --quiet > "$out/diag_trace.txt"

printf 'Joystick diagnostic logs and frames: %s\n' "$out"
