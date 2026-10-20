#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

cart="$root/software/1 Cartridges/Money Minder (1978.09.01)(VideoBrain Computer Company)(VideoBrain)(Cart)[VB-1000].bin"
res1="$root/software/0 BIOS/uvres1.bin"
res2="$root/software/0 BIOS/uvres2.bin"
for file in "$cart" "$res1" "$res2"; do
    [[ -f "$file" ]] || { printf 'Missing file: %s\n' "$file" >&2; exit 1; }
done

out="$root/verilator/out/money-load-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$out"
make -C "$root/verilator" headless 2>&1 | tee "$out/build.log"

"$root/verilator/obj_dir_headless/Vtop" \
    --res1 "$res1" --res2 "$res2" --cart "$cart" \
    --frames 600 --press SPACE@120:8 --press SHIFT@420:8 --press P@450:8 \
    --money-trace --shot 400,440,570 --dump 400,440,570 \
    --outdir "$out" --prefix money-load \
    2>&1 | tee "$out/trace.log"

printf '\nResults: %s\n' "$out"
if ! grep -q '\[money\]' "$out/trace.log"; then
    printf 'No dispatch checkpoints reached; return trace.log and the screenshots.\n' >&2
    exit 1
fi
printf 'Return trace.log and the final screenshot.\n'
