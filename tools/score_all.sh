#!/bin/zsh
# Scores every level side by side (10 at a time) and prints one JSON object per level, in order.
#   tools/score_all.sh [file] > scores.jsonl
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
cd "$(dirname $0)/.."
file=${1:-res://levels/levels.json}
n=$(python3 -c "import json,sys;d=json.load(open('${file#res://}'));print(len(d['levels'] if isinstance(d,dict) else d))")
out=$(mktemp -d)
per=$(( (n + 9) / 10 ))
for k in $(seq 0 9); do
  a=$((k * per + 1)); b=$(((k + 1) * per))
  [ $a -gt $n ] && break
  $G --headless --path . --script res://tools/level_report.gd -- --file=$file --from=$a --to=$b --json > $out/$k.txt 2>&1 &
done
wait
cat $out/*.txt | grep '^JSON ' | sed 's/^JSON //' | python3 -c "
import sys,json
rows=[json.loads(l) for l in sys.stdin]
rows.sort(key=lambda r:r['n'])
for r in rows: print(json.dumps(r))"
grep -h "SCRIPT ERROR" $out/*.txt | head -5 >&2
rm -rf $out
