#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
make headless

out=out/joystick/stability
mkdir -p "$out"
target=${1:-gladiator}

run_case() {
    local name=$1
    local cart=$2
    local samples=$3
    local -a presses=()
    local keypress
    local frames=213
    local trace_start=205

    shift 3

    if [[ $name == gladiator ]]; then
        frames=161
        trace_start=135
        samples=145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160
    fi

    for keypress in "$@"; do
        presses+=(--press "$keypress")
    done

    ./obj_dir_headless/Vtop \
        --cart "$cart" \
        --frames "$frames" \
        "${presses[@]}" \
        --joy-trace "$trace_start" \
        --dump "$samples" \
        --ram \
        --dump-file "$out/${name}_state.txt" \
        --shot "$samples" \
        --outdir "$out" \
        --prefix "$name" \
        --quiet > "$out/${name}_trace.txt"
}

case "$target" in
    vice_versa)
        run_case vice_versa "../software/Vice Versa (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN06].bin" 210,211,212 SPACE@140:8 Y@200:8
        ;;
    gladiator)
        run_case gladiator "../software/Gladiator (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)[EN01].bin" 210,211,212 SPACE@140:8
        ;;
    *)
        printf 'Usage: %s [gladiator|vice_versa]\n' "$0" >&2
        exit 2
        ;;
esac

printf 'Joystick stability logs and frames: %s\n' "$out"
