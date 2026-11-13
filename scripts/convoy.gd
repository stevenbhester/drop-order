class_name Convoy
extends Node2D
## The package trail: the next few packages after the one on the van's roof, each carried by a little
## drone that follows the van along the road it's driven, like a short snake's tail. It's only a glance
## at what's coming (the chute has the whole queue); they hover, so there's nothing to run into, and the
## trail is short and tight enough never to fold back over itself. When the van delivers, the drones
## slide up a place; a pickup pushes them back.
## Lives in the board's space, under the van. Game feeds it the van and the load (`set_colors`).

const SHOW := 3
## Distance between drones, and from the van to the first, in tiles.
const GAP := 0.34
const FIRST := 0.6

var van: Node2D
var tile := 100.0
var _colors: Array = []          # Colors of the packages after the top one, next first
var _trail := PackedVector2Array() # where the van has been, newest first
var _shift := 0.0                # eases to 0: drones sliding up (or back) a place
var _t := 0.0


## The load (Sim order: index 0 = bottom, last = on the van now).
func set_colors(stack: Array) -> void:
	var cols := []
	for k in range(stack.size() - 2, maxi(stack.size() - 2 - SHOW, -1), -1):
		cols.append(Palette.pkg(stack[k]))
	if cols == _colors:
		return
	# One delivered: everyone moves up a place. One collected: everyone drops back one.
	var n := mini(cols.size(), _colors.size() - 1)
	if n > 0 and cols.slice(0, n) == _colors.slice(1, 1 + n):
		_shift = 1.0
	elif n > 0 and _colors.slice(0, mini(_colors.size(), cols.size() - 1)) == cols.slice(1, 1 + mini(_colors.size(), cols.size() - 1)):
		_shift = -1.0
	_colors = cols
	queue_redraw()


func _process(delta: float) -> void:
	if van == null:
		return
	_t += delta
	_shift = move_toward(_shift, 0.0, delta * 4.0)
	var p := van.position
	if _trail.is_empty() or _trail[0].distance_to(p) > tile * 0.04:
		_trail.insert(0, p)
		if _trail.size() > 120:
			_trail.resize(120)
	queue_redraw()


## The point `dist` back along where the van's been (past the start of the trail: straight on behind it).
func _back_along(dist: float) -> Array:
	var pts := PackedVector2Array([van.position])
	pts.append_array(_trail)
	var left := dist
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if seg >= left and seg > 0.001:
			var at := pts[i - 1].lerp(pts[i], left / seg)
			return [at, (pts[i - 1] - pts[i]).angle()]
		left -= seg
	var last: Vector2 = pts[pts.size() - 1]
	# Past the start of the trail: straight on behind, the way the van (or the trail's start) faces.
	var dir := Vector2.RIGHT.rotated(van.rotation)
	if pts.size() >= 2 and pts[pts.size() - 2].distance_to(last) > 0.5:
		dir = (pts[pts.size() - 2] - last).normalized()
	return [last - dir * left, dir.angle()]


func _draw() -> void:
	if van == null or _colors.is_empty():
		return
	var spots := []
	for k in _colors.size():
		var d := tile * (FIRST + (k + _shift) * GAP)
		spots.append(_back_along(maxf(d, tile * 0.2)))
	# A faint tow line from the van through the drones.
	var line := PackedVector2Array([van.position])
	for s in spots:
		line.append(s[0])
	for i in range(line.size() - 1):
		var a := line[i]
		var b := line[i + 1]
		var n := 4
		for j in n:
			if j % 2 == 0:
				draw_line(a.lerp(b, float(j) / n), a.lerp(b, float(j + 1) / n), Color(1, 1, 1, 0.45), tile * 0.018, true)
	for k in range(_colors.size() - 1, -1, -1):
		var at: Vector2 = spots[k][0]
		var s := tile * (0.24 - 0.035 * k)
		var bob := sin(_t * 4.0 + k * 1.3) * tile * 0.02
		var alpha := 1.0 - 0.18 * k
		# The drone's shadow on the road, then its rotors, then the package it carries.
		draw_circle(at + Vector2(0, tile * 0.1), s * 0.55, Color(0, 0, 0, 0.14 * alpha))
		var c := at + Vector2(0, -tile * 0.06 + bob)
		var spin := _t * 30.0
		for r in 2:
			var rc := c + Vector2(s * 0.62 * (r * 2 - 1), -s * 0.42)
			draw_line(rc - Vector2(cos(spin + r), sin(spin + r) * 0.3) * s * 0.3, rc + Vector2(cos(spin + r), sin(spin + r) * 0.3) * s * 0.3, Color(1, 1, 1, 0.7 * alpha), tile * 0.016, true)
			draw_circle(rc, tile * 0.012, Color(0.25, 0.25, 0.3, alpha))
		DrawUtil.parcel(self, c, Vector2(s * StackView.ASPECT, s), Color(_colors[k], alpha), false)
