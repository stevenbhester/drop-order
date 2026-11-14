#!/bin/zsh
# Fills slots of the plan side by side (10 at a time). Candidates land in build/levelgen/slot_NNN.<seed>.txt.
#   tools/gen_all.sh <secs per slot> <seed> [slots...]      (no slots: every slot that isn't "keep")
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
cd "$(dirname $0)/.."
secs=${1:-120}; seed=${2:-1}; shift 2 2>/dev/null
mkdir -p build/levelgen
if [ $# -eq 0 ]; then
  slots=($(python3 -c "import json;print(' '.join(str(s['n']) for s in json.load(open('tools/level_plan.json'))['slots'] if not s.get('keep')))"))
else
  slots=("$@")
fi
k=0
for s in $slots; do
  f=build/levelgen/slot_$(printf %03d $s).$seed.txt
  $G --headless --path . --script res://tools/gen_levels.gd -- --slot=$s --seed=$seed --tries=100000 --secs=$secs --keep=8 --current 2>&1 | grep -E "^#|^CAND|SCRIPT ERROR|at: " > $f &
  k=$((k + 1))
  if (( k % 10 == 0 )); then wait; fi
done
wait
