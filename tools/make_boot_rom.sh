#!/bin/sh
set -e
[ $# -eq 3 ] || { echo "usage: $0 <res1.bin> <res2.bin> <out>"; exit 1; }
for f in "$1" "$2"; do
  n=$(wc -c < "$f")
  [ "$n" -eq 2048 ] || { echo "error: $f is $n bytes, expected 2048"; exit 1; }
done
cat "$1" "$2" > "$3"
echo "wrote $3 ($(wc -c < "$3") bytes)"
