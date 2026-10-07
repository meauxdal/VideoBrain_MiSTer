#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
target=${1:-both}
base=${2:-2580}
step=${3:-6}
out=${4:-out/joystick/games2}

case "$target" in
    both|checkers|tennis) ;;
    *) printf 'Usage: %s [both|checkers|tennis] [base] [step] [out]\n' "$0" >&2; exit 2 ;;
esac

make headless
mkdir -p "$out"

if [[ $target == both || $target == checkers ]]; then
    ./obj_dir_headless/Vtop \
        --cart "../software/Checkers (197x)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN04].bin" \
        --frames 470 --press SPACE@140:8 --press Y@250:8 \
        --joy UP@265:16 --joy DOWN@285:16 \
        --joy LEFT@305:16 --joy RIGHT@325:16 \
        --joy DOWN@345:8 \
        --joy-results 245 --joy-focus 399 --joy-timer-base "$base" --joy-timer-step "$step" \
        --dump-every 1 --ram --dump-file "$out/checkers_state.txt" \
        --shot 249,250,259,260,261,264,284,304,324,344,364,384,404,424,444,464 \
        --outdir "$out" --prefix checkers --quiet > "$out/checkers_trace.txt"
    printf 'Checkers: center interval 365..464; cursor state at 0F0C..0F0F.\n'
    python3 joystick_games_summary.py checkers "$out"
fi

if [[ $target == both || $target == tennis ]]; then
    ./obj_dir_headless/Vtop \
        --cart "../software/Tennis (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN03].bin" \
        --frames 420 --press SPACE@140:8 \
        --joy UP@260:24 --joy2 UP@260:24 \
        --joy DOWN@300:24 --joy2 DOWN@300:24 \
        --joy-results 180 --joy-return-pc 1FCB --joy-focus 350 \
        --joy-timer-base "$base" --joy-timer-step "$step" \
        --dump-every 1 --ram --dump-file "$out/tennis_state.txt" \
        --shot 199,229,230,239,259,279,299,319,339,359,379,399,419 \
        --outdir "$out" --prefix tennis --quiet > "$out/tennis_trace.txt"
    printf 'Tennis: center interval 340..419; player positions at 0C86/0C8A/0C8E/0C92.\n'
    python3 joystick_games_summary.py tennis "$out"
fi

printf 'Game logs and frames: %s\n' "$out"
