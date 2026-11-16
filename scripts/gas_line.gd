class_name GasLine
extends Control
## Holding Hint or Undo when it costs a tank: a fuel line runs out of the gas gauge, up onto a rail over the
## buttons, and down into BOTH Hint and Undo (a tank makes both unlimited, whichever was pressed), filling
## with fuel marbled like the Door Bowl's soup. The near branch fills first; both are full at TIME. Full: the
## tank's spent (`filled`), a thump, a flash, and it's gone. Let go sooner and the fuel runs back into the
## gauge: nothing spent.

signal filled

const TIME := 0.6                 # how long the hold takes
const TUBE := 30.0
const BORE := 18.0
const CORNER := 28.0
## The Door Bowl's juice (StudioCard.JUICE): the fuel, marbled through these.
const JUICE: Array[Color] = [Color(0.68, 0.24, 0.47), Color(0.14, 0.53, 0.55), Color(0.76, 0.58, 0.2), Color(0.43, 0.31, 0.72),
		Color(0.77, 0.38, 0.2)]

var from := Vector2.ZERO          # the gauge's can, on screen
var buttons: Array = []           # the buttons it fills (Hint and Undo)

var _t := 0.0
var _k := 0.0                     # how full, 0..1 (of the longest branch)
var _let_go := false
var _done := 0.0                  # seconds since it filled (0: not yet)
var _paths := []                  # per button: [points (PackedVector2Array), distances along (PackedFloat32Array)]
var _longest := 1.0
var _tick := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := from.y - 30.0
	for b in buttons:
		top = minf(top, (b as Control).get_global_rect().position.y)
	top -= 44.0                    # in the gap between the board and the buttons
	for b in buttons:
		var p := _path_to(b, top)
		_paths.append(p)
		_longest = maxf(_longest, (p[1] as PackedFloat32Array)[(p[1] as PackedFloat32Array).size() - 1])
	Sfx.haptic(10, 0.4)
	Sfx.play("tick", 0.8, -10.0)


## Let go before it's full: the fuel runs back.
func let_go() -> void:
	if _done == 0.0:
		_let_go = true


func is_full() -> bool:
	return _done > 0.0


## The fuel's color at `at`: marbled bands, turning over (as StudioCard._juice). Also the turbo buttons'.
static func juice(at: Vector2, t: float) -> Color:
	var swirl: float = sin(at.x * 0.019 + t * 3.0) + 0.8 * sin(at.y * 0.043 - t * 4.0 + sin(at.x * 0.012) * 2.0) \
			+ 0.7 * sin((at.x + at.y) * 0.014 + t * 2.0)
	var place: float = fposmod(swirl * 1.7, JUICE.size())
	var band: int = floori(place)
	return JUICE[band].lerp(JUICE[(band + 1) % JUICE.size()], smoothstep(0.28, 0.72, place - band))


## Out of the top of the can, up to the rail at `top`, across, and down into the top of `b`: straight runs
## with rounded corners. [points, distances along].
func _path_to(b: Control, top: float) -> Array:
	var r := b.get_global_rect()
	var start := from + Vector2(0, -30)
	var end := Vector2(r.get_center().x, r.position.y + 10.0)
	var corners := [start, Vector2(start.x, top), Vector2(end.x, top), end]
	var pts := PackedVector2Array([start])
	for i in range(1, corners.size() - 1):
		var a: Vector2 = corners[i - 1]
		var m: Vector2 = corners[i]
		var c: Vector2 = corners[i + 1]
		var rad := minf(CORNER, minf(a.distance_to(m), m.distance_to(c)) / 2.0)
		var p0 := m + (a - m).normalized() * rad
		var p1 := m + (c - m).normalized() * rad
		_run(pts, p0)
		for s in range(1, 7):
			var u := s / 6.0
			pts.append(p0.lerp(m, u).lerp(m.lerp(p1, u), u))
	_run(pts, end)
	var lens := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		lens.append(lens[i - 1] + pts[i - 1].distance_to(pts[i]))
	return [pts, lens]


func _run(pts: PackedVector2Array, p: Vector2) -> void:
	var a := pts[pts.size() - 1]
	if a.distance_to(p) < 0.5:
		return
	var n := maxi(1, int(a.distance_to(p) / 14.0))
	for s in range(1, n + 1):
		pts.append(a.lerp(p, float(s) / n))


func _process(delta: float) -> void:
	_t += delta
	if _done > 0.0:
		_done += delta
		if _done > 0.45:
			queue_free()
	elif _let_go:
		_k -= delta * 3.5
		if _k <= 0.0:
			queue_free()
	else:
		_k = clampf(_t / TIME, 0.0, 1.0)
		# Haptic ticks as it fills, harder as it gets there.
		_tick += delta
		if _tick >= 0.08 and _k < 1.0:
			_tick = 0.0
			Sfx.haptic(6 + int(10.0 * _k), 0.25 + 0.5 * _k)
			Sfx.play("tick", 0.9 + 0.7 * _k, -14.0 + 4.0 * _k)
		if _k >= 1.0:
			_done = 0.0001
			Sfx.haptic(30, 1.0)
			Sfx.play("pop", 1.2, -3.0)
			for b in buttons:
				if is_instance_valid(b) and b.has_method("pop"):
					b.pop()
			filled.emit()
	queue_redraw()


## The samples of `path` up to `dist` along it (the last one cut to land exactly there).
func _upto(path: Array, dist: float) -> PackedVector2Array:
	var pts: PackedVector2Array = path[0]
	var lens: PackedFloat32Array = path[1]
	var out := PackedVector2Array()
	for i in pts.size():
		if lens[i] <= dist:
			out.append(pts[i])
		else:
			if i > 0:
				out.append(pts[i - 1].lerp(pts[i], (dist - lens[i - 1]) / maxf(lens[i] - lens[i - 1], 0.001)))
			break
	return out


func _draw() -> void:
	if _paths.is_empty():
		return
	var fade := 1.0 - clampf(_done / 0.45, 0.0, 1.0) if _done > 0.0 else (clampf(_k * 4.0, 0.0, 1.0) if _let_go else 1.0)
	var flash := clampf(1.0 - _done / 0.2, 0.0, 1.0) if _done > 0.0 else 0.0
	# The tubes run out ahead of the fuel (all of them in the first moment), glassy white on a soft shadow;
	# then the fuel, on top of all of them.
	var tubes := []
	for p in _paths:
		tubes.append(_upto(p, _longest * clampf(_t / 0.12, 0.0, 1.0)))
	for tube: PackedVector2Array in tubes:
		if tube.size() >= 2:
			var shadow := PackedVector2Array()
			for q in tube:
				shadow.append(q + Vector2(0, 5))
			draw_polyline(shadow, Color(0.2, 0.12, 0.2, 0.18 * fade), TUBE, true)
	for tube: PackedVector2Array in tubes:
		if tube.size() >= 2:
			draw_polyline(tube, Color(1, 1, 1, 0.96 * fade), TUBE, true)
			draw_circle(tube[0], TUBE / 2.0, Color(1, 1, 1, 0.96 * fade))
			draw_circle(tube[tube.size() - 1], TUBE / 2.0, Color(1, 1, 1, 0.96 * fade))
	for tube: PackedVector2Array in tubes:
		if tube.size() >= 2:
			draw_polyline(tube, Color(0.85, 0.82, 0.88, 0.9 * fade), BORE, true)
	for p in _paths:
		var fuel := _upto(p, _longest * _k)
		if fuel.size() < 2:
			continue
		var cols := PackedColorArray()
		for q in fuel:
			cols.append(Color(juice(q, _t).lerp(Color.WHITE, 0.6 * flash), fade))
		draw_polyline_colors(fuel, cols, BORE, true)
		draw_circle(fuel[0], BORE / 2.0, cols[0])
		draw_circle(fuel[fuel.size() - 1], BORE / 2.0 + 2.0, cols[cols.size() - 1])
		var glint := PackedVector2Array()
		for i in range(0, fuel.size(), 2):
			glint.append(fuel[i] + Vector2(-3, -4))
		if glint.size() >= 2:
			draw_polyline(glint, Color(1, 1, 1, 0.35 * fade), 3.0, true)
	# Full: the "−1" pops up off the gauge.
	if _done > 0.0:
		var k := clampf(_done / 0.45, 0.0, 1.0)
		var f := UiTheme.font()
		var at := from + Vector2(22.0, -44.0 - 60.0 * k)
		draw_string_outline(f, at, "−1", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, 12, Color(1, 1, 1, 1.0 - k * k))
		draw_string(f, at, "−1", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(GasChip.FUEL, 1.0 - k * k))
