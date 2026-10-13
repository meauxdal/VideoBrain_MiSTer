#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

name=${1:-clocknye2026}
image="../software/21 games for apl_s/$name.bin"
outdir="out/apl/load_check/$name"
mkdir -p "$outdir"

./obj_dir_headless/Vtop \
  --cart "../software/converted/The Computational Language (APL-S).bin" \
  --apl-rtl "$image@210" --press NEXT@224:8 \
  --frames 360 --shot 199,211,223,249,299,359 --dump 199,211,223,249,299,359 --ram \
  --dump-file "$outdir/state.txt" --outdir "$outdir" --prefix "$name" \
  > "$outdir/run.log" 2>&1

printf 'Captures and logs: %s\n' "$outdir"
