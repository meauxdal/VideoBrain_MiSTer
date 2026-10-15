# #!/usr/bin/env bash
# set -euo pipefail
# cd "$(dirname "$0")"

# mode=${1:-direct}
# case "$mode" in
#   direct) load_option=--apl; outdir=out/apl/guess_check ;;
#   rtl) load_option=--apl-rtl; outdir=out/apl/guess_check_rtl ;;
#   *) printf 'Usage: %s [direct|rtl]\n' "$0" >&2; exit 1 ;;
# esac
# mkdir -p "$outdir"

# ./obj_dir_headless/Vtop \
#   --cart "../software/converted/APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin" \
#   "$load_option" "../software/21 games for apl_s/guess.bin@210" \
#   --press G@224:8 --press U@240:8 --press E@256:8 --press S@272:8 \
#   --press NEXT@288:8 \
#   --press SHIFT@336:8 --press Z@352:8 --press NEXT@368:8 \
#   --press Z@416:8 --press NEXT@432:8 \
#   --frames 475 --shot 199,211,287,329,399,474 --dump 199,211,287,329,399,474 --ram \
#   --dump-file "$outdir/state.txt" --outdir "$outdir" --prefix guess \
#   > "$outdir/run.log" 2>&1

# printf 'Captures and logs: %s\n' "$outdir"
