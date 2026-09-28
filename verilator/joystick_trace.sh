#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
make headless

out=out/joystick
mkdir -p "$out"

run_case() {
    local name=$1
    local cart=$2
    local trace_start=$3
    local up_start=$4
    local down_start=$5

    ./obj_dir_headless/Vtop \
        --cart "$cart" \
        --frames 320 \
        --press SPACE@140:8 \
        --joy "UP@${up_start}:12" \
        --joy "DOWN@${down_start}:12" \
        --joy-trace "$trace_start" \
        --dump 130,139,140,150,160,170,179,185,190,195,199,200,210,219,230,249,250,261,269,270,279,280,291,300,311,319 \
        --dump-file "$out/${name}_state.txt" \
        --shot 130,139,140,150,160,170,179,185,190,195,199,200,210,219,230,249,250,261,269,270,279,280,291,300,311,319 \
        --outdir "$out" \
        --prefix "$name" \
        --quiet > "$out/${name}_trace.txt"
}

run_case tennis "../software/Tennis (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN03].bin" 130 270 300
run_case gladiator "../software/Gladiator (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN01].bin" 145 190 220

printf 'Joystick logs and frames: %s\n' "$out"
