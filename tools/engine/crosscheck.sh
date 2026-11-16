#!/bin/zsh
# Does the C engine agree with the game's solver? Compares winning routes, search size and shortest route
# on every level file (or the files given). Any difference is printed; no output but the summary means
# they agree.
#   tools/engine/crosscheck.sh [levels/x.json ...]
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
cd "${0:A:h}/../.."
files=("$@")
[ $# -eq 0 ] && files=(levels/levels.json levels/og.json levels/daily.json levels/side.json)
tmp=$(mktemp -d)
bad=0; total=0
for f in $files; do
  python3 tools/engine/lv.py $f | build/lm solve > $tmp/c.txt
  $G --headless --path . --script res://tools/engine/reference.gd -- res://$f 2>/dev/null | grep -v "^Godot\|^$" > $tmp/g.txt
  n=$(wc -l < $tmp/g.txt | tr -d ' ')
  d=$(diff $tmp/c.txt $tmp/g.txt | grep -c '^[<>]')
  total=$((total + n)); bad=$((bad + d / 2))
  [ $d -gt 0 ] && { echo "$f: differences (C engine <, game >):"; diff $tmp/c.txt $tmp/g.txt | head -20; }
done
echo "crosscheck: $total levels, $bad differ"
rm -rf $tmp
