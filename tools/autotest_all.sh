#!/bin/zsh
# Plays the game headlessly with injected input and sums up. Every test is one Godot run; they all go through
# one shared queue, JOBS at a time, so nothing waits on the slowest of a batch, and the game's clock runs
# TEST_SPEED times as fast (Engine.time_scale and Game's own clock: --test-speed).
#
#   tools/autotest_all.sh                      the full suite (for TestFlight builds)
#   tools/autotest_all.sh --quick              a couple of minutes: drag and queue on every job, the other
#                                              modes on a sample of jobs, a few of the extras (phone builds)
#   tools/autotest_all.sh FIRST LAST [modes]   just those jobs in those modes (default: the eight below)
#
# Modes on the main road: autodrag autoseg autoundo autohint autodpad autobrake autoside autoqueue autoradio
# (autoqueue: the chute's preview at every tile of a planned route, and with the headlights on while the van
# really drives it, against the sim; autoradio: the Radio's answer on and one step off the way that works,
# against the full solver, and what a call costs), and autosight / autoundo with the headlights as earned
# (--foresight=-1).
# Extras: the daily puzzles, side roads and their twists, speedrun courses, the symbol card by touch, the
# garage, the hint ad, the crusher, the ghost path, keys.
#
# Env: JOBS (runs at once, default 40), TEST_SPEED (default 4; 1 is real time), GODOT.
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
cd "$(dirname $0)/.."
JOBS=${JOBS:-40}
TS=${TEST_SPEED:-4}
MODES=(autodrag autoseg autoundo autohint autodpad autobrake autoside autoqueue autoradio)
SAMPLE=(1 2 5 6 7 11 13 20 28 35 50 75 100)
nlev=$(python3 -c "import json;print(len(json.load(open('levels/levels.json'))['levels']))")
out=$(mktemp -d)
list=$out/jobs.txt
t0=$(date +%s)

kind=full
if [ "$1" = "--quick" ]; then
  kind=quick
elif [ $# -ge 2 ]; then
  kind=range; first=$1; last=$2; shift 2
  (( $# > 0 )) && MODES=("$@")
fi

# One line per run: the name its output is kept under, then its arguments for the game.
add() { echo "$*" >> $list; }
main_road() {   # mode, levels...
  local m=$1; shift
  local extra=""
  [ $m = autoradio ] && extra=" --radio"      # (the Radio on every job, whatever the test save has reached)
  for L in "$@"; do add "$m-$L --level=$L --$m$extra"; done
}
case $kind in
  range)
    for m in $MODES; do main_road $m $(seq $first $last); done ;;
  quick)
    main_road autodrag $(seq 1 $nlev)
    main_road autoqueue $(seq 1 $nlev)
    for m in autoseg autoundo autohint autodpad autobrake autoside autoradio; do main_road $m $SAMPLE; done
    for L in $SAMPLE; do add "earned_autosight-$L --level=$L --autosight --foresight=-1"; done ;;
  full)
    for m in $MODES; do main_road $m $(seq 1 $nlev); done
    for m in autosight autoundo; do
      for L in $(seq 1 $nlev); do add "earned_$m-$L --level=$L --$m --foresight=-1"; done
    done ;;
esac
if [ $kind != range ]; then
  nd=$(python3 -c "import json;print(len(json.load(open('levels/daily.json'))['levels']))")
  [ $kind = quick ] && nd=3
  for k in $(seq 0 $((nd - 1))); do add "daily-$k --daily --autodrag --day=+$k"; done
  for id in $(python3 -c "import json;print(' '.join(d['id'] for d in json.load(open('levels/side.json'))['side']))"); do
    add "side-$id --side=$id --autoplay"
    [ $kind = full ] && add "twist-$id --side=$id --autotwist"
  done
  add "hintad --level=12 --autohintad"
  add "ghost --level=30 --autoghost --save=gas:5"
  if [ $kind = full ]; then
    for id in $(python3 -c "import json;print(' '.join(d['id'] for d in json.load(open('levels/speedrun.json'))['courses']))"); do
      add "speed-$id --speedrun=$id --autoplay"
    done
    for L in 9 25 45 70 95; do add "touch-$L --level=$L --autotouch"; done
    add "touch-side30 --level=30 --autotouch --landscape"
    add "garage --garage --autogarage --autotest"
    for L in 12 45 95; do add "cancel-$L --level=$L --autocancel"; done
    for L in $(python3 -c "import json;print(' '.join(str(i+1) for i,l in enumerate(json.load(open('levels/levels.json'))['levels']) if l.get('gift',{}).get('item')=='key'))"); do
      add "key-$L --level=$L --autogift --save=gas:5"
    done
  fi
fi

echo "$(wc -l < $list | tr -d ' ') runs, $JOBS at a time, at ${TS}x ($kind)"
export G out TS
# (A run that crashes mustn't stop the queue: the shell outlives it and always says it's fine.)
xargs -P $JOBS -L 1 zsh -c 'n=$1; shift; "$G" --headless --path . --quit-after 100000 -- "$@" --test-speed=$TS > "$out/$n.txt" 2>&1; echo "EXIT $?" >> "$out/$n.txt"; exit 0' _ < $list

# Runs that crashed, or ended without saying how they went.
for f in $out/*.txt(N); do
  [ "$(basename $f)" = jobs.txt ] && continue
  ex=$(grep -h '^EXIT ' $f | tail -1 | cut -d' ' -f2)
  if [ "$ex" != 0 ] || ! grep -q 'AUTOTEST' $f; then
    echo "   crashed or no result: $(basename $f .txt) (exit ${ex:-?}) $(grep -h 'ERROR\|Abort\|signal' $f | head -1 | cut -c1-150)"
  fi
done | head -10

# What went wrong anywhere.
grep -h "SCRIPT ERROR\|queue L[0-9]* FAILED\|mismatch\|synced=false\|view_matches=false\|x_shown=false\|line_stopped=false\|nothing_lost=false\|braked_ok=false" $out/*.txt | sort | uniq -c | head -20
# Each kind of run: how many came through.
tally() {   # label, file glob, pattern that means it passed
  local files=($~2)
  (( ${#files} == 0 )) && return
  local ok=$(cat $files | grep -c "$3")
  echo "$1: $ok/${#files}"
  (( ok < ${#files} )) && for f in $files; do grep -q "$3" $f || echo "   not ok: $(basename $f .txt) $(grep -h 'AUTOTEST' $f | head -1 | cut -c1-200)"; done | head -8
}
for m in $MODES autosight; do tally "$m won" "$out/$m-*.txt(N)" 'state=WON'; done
tally "queue checks ok" "$out/autoqueue-*.txt(N)" 'AUTOTEST queue L[0-9]* ok'
tally "radio checks ok" "$out/autoradio-*.txt(N)" 'AUTOTEST radio L[0-9]* ok'
for m in autosight autoundo; do tally "$m (headlights as earned) won" "$out/earned_$m-*.txt(N)" 'state=WON'; done
tally "daily puzzles won" "$out/daily-*.txt(N)" 'state=WON'
tally "side roads won" "$out/side-*.txt(N)" 'AUTOTEST autoplay.*state=WON'
tally "side road twists bite" "$out/twist-*.txt(N)" 'ok=true'
tally "speedrun courses finished" "$out/speed-*.txt(N)" 'AUTOTEST autoplay.*state=WON'
tally "symbol card by touch and mouse" "$out/touch-*.txt(N)" 'AUTOTEST touch .* ok:'
tally "garage" "$out/garage.txt(N)" 'AUTOTEST garage ok'
tally "hint ad" "$out/hintad.txt(N)" 'AUTOTEST hintad L[0-9]* ok'
tally "crusher" "$out/cancel-*.txt(N)" 'AUTOTEST cancel L[0-9]* ok'
tally "ghost path" "$out/ghost.txt(N)" 'AUTOTEST ghost L[0-9]* ok'
tally "keys picked up on a win" "$out/key-*.txt(N)" 'AUTOTEST gift L[0-9]* ok: key'
echo "took $(( $(date +%s) - t0 ))s"
rm -rf "${out:?}"
