#!/bin/zsh
# Plays every level headlessly with injected input in several modes and summarises.
#   tools/autotest_all.sh [first] [last] [modes...]
# Default: all levels, modes autodrag autoseg autoundo. Needs Godot at $GODOT or the default path.
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
cd "$(dirname $0)/.."
first=${1:-1}; last=${2:-$(python3 -c "import json;print(len(json.load(open('levels/levels.json'))['levels']))")}
shift 2 2>/dev/null
if [ $# -eq 0 ]; then modes=(autodrag autoseg autoundo); else modes=("$@"); fi
out=$(mktemp -d)
for mode in $modes; do
  for L in $(seq $first $last); do
    $G --headless --path . --quit-after 6000 -- --level=$L --$mode > $out/$mode-$L.txt 2>&1 &
  done
  wait
done
grep -h "SCRIPT ERROR\|mismatch\|synced=false\|view_matches=false" $out/*.txt | head -20
for mode in $modes; do
  n=$((last - first + 1))
  won=$(cat $out/$mode-*.txt | grep -c 'state=WON')
  echo "$mode: $won/$n won"
  [ $won -lt $n ] && grep -h "AUTOTEST $mode" $out/$mode-*.txt | grep -v "state=WON"
done
rm -rf $out
