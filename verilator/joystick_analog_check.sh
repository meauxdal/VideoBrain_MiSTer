#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
out=${1:-out/joystick/analog1}
make headless
mkdir -p "$out"

args=()
shots=(419)
frame=420
printf 'name\tchannel\tpot\tstart\tend\n' > "$out/tennis_phases.tsv"
phase() {
    local name=$1 channel=$2 pot=$3
    args+=(--joy-pot "$channel:$pot@$frame:64")
    shots+=($((frame + 63)))
    printf '%s\t%d\t%d\t%d\t%d\n' "$name" "$channel" "$pot" "$((frame + 16))" "$((frame + 63))" >> "$out/tennis_phases.tsv"
    frame=$((frame + 64))
}

for channel in 0 2; do
    for pot in 0 32 64 96 128 160 192 224 255 128; do
        phase vertical "$channel" "$pot"
    done
done
for channel in 1 3; do
    for pot in 0 255 128; do
        phase horizontal "$channel" "$pot"
    done
done
shot_list=$(IFS=,; printf '%s' "${shots[*]}")

./obj_dir_headless/Vtop \
    --cart "../software/Tennis (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN03].bin" \
    --frames "$frame" --press SPACE@140:8 \
    --joy UP@260:24 --joy2 UP@260:24 \
    --joy DOWN@300:24 --joy2 DOWN@300:24 \
    "${args[@]}" \
    --joy-results 230 --joy-return-pc 1FCB --joy-focus 350 \
    --joy-timer-base 2580 --joy-timer-step 6 \
    --dump-every 1 --ram --dump-file "$out/tennis_state.txt" \
    --shot "$shot_list" --outdir "$out" --prefix tennis \
    --quiet > "$out/tennis_trace.txt"
python3 joystick_analog_summary.py "$out"
printf 'Analog logs and frames: %s\n' "$out"
