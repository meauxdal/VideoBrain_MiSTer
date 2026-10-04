#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
make headless

out=out/joystick/sweep
mkdir -p "$out"
cart="../software/Gladiator (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN01].bin"

if (($# == 0)); then
    set -- 2580:18 2560:18 2600:18 2580:16 2580:20
fi

candidates=
for candidate in "$@"; do
    if [[ ! $candidate =~ ^[0-9]+:[0-9]+$ ]]; then
        printf 'Usage: %s [base:step ...]\n' "$0" >&2
        exit 2
    fi
    candidates+="${candidates:+,}$candidate"
done

./obj_dir_headless/Vtop \
    --cart "$cart" \
    --frames 217 \
    --press SPACE@140:8 \
    --joy UP@157:12 \
    --joy DOWN@169:12 \
    --joy LEFT@181:12 \
    --joy RIGHT@193:12 \
    --joy-trace 140 \
    --joy-timer-sweep "$candidates" \
    --quiet > "$out/gladiator_sweep.txt"

printf 'Joystick logs: %s\n' "$out"
