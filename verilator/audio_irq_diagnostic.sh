#!/bin/sh
set -eu
cd "$(dirname "$0")"

capture=${1:-out/audio_bus_timing/events.csv}
output=out/audio_irq_diagnostic
if [ ! -f "$capture" ]; then
    echo "Missing saved audio capture: $capture" >&2
    exit 1
fi
mkdir -p "$output"
echo 'Checking the ROM interrupt chain (no full-core build or capture).'
if ! make test-cpu-irq-chain > "$output/cpu.txt" 2>&1; then
    cat "$output/cpu.txt"
    exit 1
fi
tail -n 3 "$output/cpu.txt"
if ! PYTHONDONTWRITEBYTECODE=1 python3 tests/audio_irq_diagnostic.py \
    "$capture" --output "$output" > "$output/comparison.txt" 2>&1; then
    cat "$output/comparison.txt"
    exit 1
fi
cat "$output/comparison.txt"
