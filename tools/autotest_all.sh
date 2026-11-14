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
  # In batches of 50 at a time (100 Godots at once is a lot of memory).
  for L in $(seq $first $last); do
    $G --headless --path . --quit-after 30000 -- --level=$L --$mode > $out/$mode-$L.txt 2>&1 &
    if (( (L - first + 1) % 50 == 0 )); then wait; fi
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
  nd=$(python3 -c "import json;print(len(json.load(open('levels/daily.json'))['levels']))")
  for k in $(seq 0 $((nd - 1))); do
    $G --headless --path . --quit-after 6000 -- --daily --autodrag --day=+$k > $out/daily-$k.txt 2>&1 &
  done
  wait
  won=$(cat $out/daily-*.txt | grep -c 'state=WON')
  echo "daily puzzles: $won/$nd won"
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
  # Speedrun courses: every zone, driven in one go each.
  cids=($(python3 -c "import json;print(' '.join(d['id'] for d in json.load(open('levels/speedrun.json'))['courses']))"))
  for id in $cids; do
    $G --headless --path . --quit-after 30000 -- --speedrun=$id --autoplay > $out/speed-$id.txt 2>&1 &
  done
  wait
  sw=$(cat $out/speed-*.txt | grep -c 'AUTOTEST autoplay.*state=WON')
  echo "speedrun courses: $sw/${#cids} finished"
  grep -h "SCRIPT ERROR" $out/side-*.txt $out/twist-*.txt | head -5
fi
# The symbol card, opened and closed with real touches (as a phone sends them) and mouse clicks: a tap, a
# hold, a tap on the card, a double tap and a drag must each close it and hand the game its input back.
# A level from each part of the road, and one played sideways.
if [ $first -eq 1 ]; then
  for L in 9 25 45 70 95; do
    $G --headless --path . --quit-after 30000 -- --level=$L --autotouch > $out/touch-$L.txt 2>&1 &
  done
  $G --headless --path . --quit-after 30000 -- --level=30 --autotouch --landscape > $out/touch-side30.txt 2>&1 &
  wait
  tok=$(cat $out/touch-*.txt | grep -c 'AUTOTEST touch .* ok:')
  echo "symbol card by touch and mouse: $tok/6 levels ok"
  # The level's hints (none counted with the option on; asking twice without a move costs one), the tip, a
  # video ad skipped straight away, unlimited hints.
  $G --headless --path . --quit-after 100000 -- --level=12 --autohintad > $out/hintad.txt 2>&1
  grep -h "AUTOTEST hintad\|SCRIPT ERROR" $out/hintad.txt | head -3
  # Dragging a route into the crusher: a quick pass keeps it, holding there and letting go scraps it.
  # (The zone sits partly over the Hint and Undo buttons: a few levels, so the drag comes in from different places.)
  for L in 12 45 95; do
    $G --headless --path . --quit-after 100000 -- --level=$L --autocancel > $out/cancel-$L.txt 2>&1 &
  done
  wait
  cok=$(cat $out/cancel-*.txt | grep -c 'AUTOTEST cancel L[0-9]* ok')
  echo "scrap a route in the crusher: $cok/3 levels ok"
  grep -h "AUTOTEST cancel .*FAILED\|SCRIPT ERROR" $out/cancel-*.txt | head -3
  # Replay ghost path: a try, Retry, and the next try shows it with arrowheads at its turns.
  $G --headless --path . --quit-after 100000 -- --level=30 --autoghost --save=gas:5 > $out/ghost.txt 2>&1
  grep -h "AUTOTEST ghost\|SCRIPT ERROR" $out/ghost.txt | head -3
  # Keys: each level with one, won the way round that picks it up.
  for L in $(python3 -c "import json;print(' '.join(str(i+1) for i,l in enumerate(json.load(open('levels/levels.json'))['levels']) if l.get('gift',{}).get('item')=='key'))"); do
    $G --headless --path . --quit-after 100000 -- --level=$L --autogift --save=gas:5 > $out/key-$L.txt 2>&1 &
  done
  wait
  kok=$(cat $out/key-*.txt | grep -c 'AUTOTEST gift L[0-9]* ok: key')
  echo "keys: $kok/$(ls $out/key-*.txt | wc -l | tr -d ' ') picked up on a win"
  grep -h "AUTOTEST gift .*FAILED\|SCRIPT ERROR" $out/key-*.txt | head -3
  grep -h "AUTOTEST touch .* FAILED\|SCRIPT ERROR" $out/touch-*.txt | head -5
fi
rm -rf $out
