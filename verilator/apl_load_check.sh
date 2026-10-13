#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

name=${1:-clocknye2026}
mode=${2:-rtl}
frames=${3:-360}
case "$mode" in
  direct) load_option=--apl ;;
  rtl) load_option=--apl-rtl ;;
  *) printf 'Usage: %s [name] [direct|rtl] [frames]\n' "$0" >&2; exit 1 ;;
esac
if [[ ! "$frames" =~ ^[0-9]+$ ]] || (( frames < 360 )); then
  printf 'frames must be an integer >= 360\n' >&2
  exit 1
fi
image="../software/21 games for apl_s/$name.bin"
outdir="out/apl/load_check/${name}_${mode}_trace"
shots=199,211,223,249,299,359
if (( frames > 360 )); then
  outdir="${outdir}_${frames}"
  shots+=",$(( (360 + frames) / 2 )),$(( frames - 1 ))"
fi
mkdir -p "$outdir"

./obj_dir_headless/Vtop \
  --cart "../software/converted/The Computational Language (APL-S).bin" \
  "$load_option" "$image@210" --press NEXT@224:8 \
  --trace-from "$(( frames - 10 ))" --trace-cpu 4096 \
  --frames "$frames" --shot "$shots" --dump "$shots" --ram \
  --dump-file "$outdir/state.txt" --outdir "$outdir" --prefix "$name" \
  > "$outdir/run.log" 2>&1

printf 'Captures and logs: %s\n' "$outdir"
