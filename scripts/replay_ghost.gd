class_name ReplayGhost
extends Node2D
## Option "Replay ghost path": after a restart, the route the last attempt took, drawn faint on the board so
## you can see what didn't work. It writes itself out from the van like a ghost drifting along the road,
## then little arrowheads bloom at every turn it made (so the order of the turns is never in doubt), and the
## whole thing keeps up a slow, wobbly hover. Translucent, and under the route you're drawing now.
## Game.last_attempt holds the route between attempts.

const FORM := 1.1           # seconds to write the route out
const ARROW_POP := 0.28     # each turn's arrowhead blooming in

var board: Board
var pts: Array = []         # tiles, Vector2i, first = the start
var _t := 0.0
var _turns: Array = []      # [index into pts, direction out of the turn]
var _len := 0.0             # tiles along the route


func setup(b: Board, tiles: Array) -> void:
	board = b
	pts = tiles.duplicate()
	_turns.clear()
	for i in range(1, pts.size() - 1):
		var a: Vector2i = pts[i] - pts[i - 1]
		var o: Vector2i = pts[i + 1] - pts[i]
		if a != o:
			_turns.append([i, Vector2(o)])
	_len = float(pts.size() - 1)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## A point `v` tiles along the route, wobbling: a slow sideways sway that travels along it like a breath.
func _at(v: float) -> Vector2:
	var n := pts.size()
	var i := clampi(int(floor(v)), 0, n - 2)
	var u := clampf(v - i, 0.0, 1.0)
	var a := board.center(pts[i])
	var b := board.center(pts[i + 1])
	var p := a.lerp(b, u)
	var side := (b - a).normalized().orthogonal()
	var amp := board.tile * 0.05
	return p + side * amp * sin(_t * 2.6 - v * 1.7) + Vector2(0, -board.tile * 0.03 * sin(_t * 1.3 + v * 0.6))


func _draw() -> void:
	if board == null or pts.size() < 2:
		return
	var tile := board.tile
	var shown := _len * clampf(_t / FORM, 0.0, 1.0)
	var settle := clampf((_t - FORM) / 0.6, 0.0, 1.0)
	var breath := 0.5 + 0.5 * sin(_t * 2.0)
	var col := Color(0.93, 0.96, 1.0)
	# The trail: sampled finely so the wobble reads as a soft body, wider and fainter underneath.
	var line := PackedVector2Array()
	var steps := maxi(2, int(shown * 8.0))
	for k in steps + 1:
		line.append(_at(shown * k / float(steps)))
	if line.size() >= 2:
		draw_polyline(line, Color(col, 0.10 + 0.04 * breath), tile * 0.34, true)
		draw_polyline(line, Color(col, 0.22 + 0.06 * breath), tile * 0.12, true)
		# Little dashes drifting along it, the way the last attempt went.
		var dash_n := int(shown * 2.0)
		for k in dash_n:
			var v := fmod(k * 0.5 + _t * 0.9, shown)
			var p0 := _at(v)
			var p1 := _at(minf(v + 0.14, shown))
			draw_line(p0, p1, Color(1, 1, 1, 0.32 * (0.6 + 0.4 * breath)), tile * 0.06, true)
	# The head while it's still being written: a little wisp.
	if _t < FORM:
		var h := _at(shown)
		draw_circle(h, tile * 0.16, Color(col, 0.18))
		draw_circle(h, tile * 0.08, Color(col, 0.35))
	# Arrowheads at the turns, in order, as the trail passes each one.
	for k in _turns.size():
		var i: int = _turns[k][0]
		var dir: Vector2 = _turns[k][1]
		var born := FORM * i / maxf(_len, 1.0)
		var age := _t - born
		if age < 0.0:
			continue
		var pop := clampf(age / ARROW_POP, 0.0, 1.0)
		var s := (1.0 - pow(1.0 - pop, 3.0)) * (1.0 + 0.35 * sin(PI * pop)) * (1.0 + 0.06 * sin(_t * 3.0 + k))
		var at := _at(float(i)) + dir * tile * 0.22
		var fwd := dir * tile * 0.24 * s
		var wide := dir.orthogonal() * tile * 0.2 * s
		var tri := PackedVector2Array([at + fwd, at - fwd * 0.5 + wide, at - fwd * 0.2, at - fwd * 0.5 - wide])
		var a := 0.42 + 0.12 * breath * settle
		draw_colored_polygon(tri, Color(col, a))
		var outline := tri.duplicate()
		outline.append(tri[0])
		draw_polyline(outline, Color(1, 1, 1, a * 0.9), tile * 0.025, true)
	# Where it ended: a faint ✕.
	if _t >= FORM:
		var e := _at(_len)
		var r := tile * 0.12 * clampf((_t - FORM) / 0.25, 0.0, 1.0)
		var a := 0.35 + 0.1 * breath
		draw_line(e + Vector2(-r, -r), e + Vector2(r, r), Color(col, a), tile * 0.05, true)
		draw_line(e + Vector2(-r, r), e + Vector2(r, -r), Color(col, a), tile * 0.05, true)
