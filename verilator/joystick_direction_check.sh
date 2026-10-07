#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
make headless

out=out/joystick/directions9
mkdir -p "$out"

run_checkers() {
    local cart="../software/Checkers (197x)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN04].bin"
    ./obj_dir_headless/Vtop \
        --cart "$cart" \
        --frames 350 \
        --press SPACE@140:8 \
        --press Y@250:8 \
        --joy UP@265:16 \
        --joy DOWN@285:16 \
        --joy LEFT@305:16 \
        --joy RIGHT@325:16 \
        --joy-trace 245 \
        --joy-timer-base 2580 \
        --joy-timer-step 6 \
        --dump 264,281,284,301,304,321,324,341,344 \
        --ram \
        --dump-file "$out/checkers_state.txt" \
        --shot 264,281,284,301,304,321,324,341,344 \
        --outdir "$out" \
        --prefix checkers \
        --quiet > "$out/checkers_trace.txt"
}

run_gladiator() {
    local cart="../software/Gladiator (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN01].bin"
    local name=$1
    ./obj_dir_headless/Vtop \
        --cart "$cart" \
        --frames 250 \
        --press SPACE@140:8 \
        --joy UP@165:16 \
        --joy DOWN@185:16 \
        --joy LEFT@205:16 \
        --joy RIGHT@225:16 \
        --joy-trace 145 \
        --joy-timer-base 2580 \
        --joy-timer-step 6 \
        --dump 164,181,184,201,204,221,224,241,244 \
        --ram \
        --dump-file "$out/${name}_state.txt" \
        --shot 164,181,184,201,204,221,224,241,244 \
        --outdir "$out" \
        --prefix "$name" \
        --quiet > "$out/${name}_trace.txt"
}

run_checkers
run_gladiator gladiator

printf 'Joystick direction logs and frames: %s\n' "$out"
