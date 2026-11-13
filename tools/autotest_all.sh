#!/bin/zsh
# Plays every level headlessly with injected input in several modes and summarises.
#   tools/autotest_all.sh [first] [last] [modes...]
# Default: all levels, modes autodrag autoseg autoundo autohint autodpad autobrake autoside. Needs Godot at $GODOT or the default path.
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
cd "$(dirname $0)/.."
first=${1:-1}; last=${2:-$(python3 -c "import json;print(len(json.load(open('levels/levels.json'))['levels']))")}
shift 2 2>/dev/null
if [ $# -eq 0 ]; then modes=(autodrag autoseg autoundo autohint autodpad autobrake autoside); else modes=("$@"); fi
out=$(mktemp -d)
for mode in $modes; do
  for L in $(seq $first $last); do
    $G --headless --path . --quit-after 30000 -- --level=$L --$mode > $out/$mode-$L.txt 2>&1 &
  done
  wait
done
grep -h "SCRIPT ERROR\|mismatch\|synced=false\|view_matches=false\|x_shown=false\|line_stopped=false\|nothing_lost=false\|braked_ok=false" $out/*.txt | head -20
for mode in $modes; do
  n=$((last - first + 1))
  won=$(cat $out/$mode-*.txt | grep -c 'state=WON')
  echo "$mode: $won/$n won"
  [ $won -lt $n ] && grep -h "AUTOTEST $mode" $out/$mode-*.txt | grep -v "state=WON"
done
# The ten daily puzzles (as if it were each of the next ten days), dragged in one go each.
if [ $first -eq 1 ]; then
  for k in $(seq 0 9); do
    $G --headless --path . --quit-after 6000 -- --daily --autodrag --day=+$k > $out/daily-$k.txt 2>&1 &
  done
  wait
  won=$(cat $out/daily-*.txt | grep -c 'state=WON')
  echo "daily puzzles: $won/10 won"
  grep -h "SCRIPT ERROR" $out/daily-*.txt | head -5
fi
# The side roads: each driven in one go (it must win), and its twist checked (it must bite).
if [ $first -eq 1 ]; then
  ids=($(python3 -c "import json;print(' '.join(d['id'] for d in json.load(open('levels/side.json'))['side']))"))
  for id in $ids; do
    $G --headless --path . --quit-after 30000 -- --side=$id --autoplay > $out/side-$id.txt 2>&1 &
    $G --headless --path . --quit-after 30000 -- --side=$id --autotwist > $out/twist-$id.txt 2>&1 &
  done
  wait
  won=$(cat $out/side-*.txt | grep -c 'AUTOTEST autoplay.*state=WON')
  bites=$(cat $out/twist-*.txt | grep -c 'ok=true')
  echo "side roads: $won/${#ids} won, $bites/${#ids} twists bite"
  grep -h "SCRIPT ERROR" $out/side-*.txt $out/twist-*.txt | head -5
fi
rm -rf $out
