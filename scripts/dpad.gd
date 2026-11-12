class_name DPad
extends Control
## A big thumb pad: four arrow keys in a cross (up over left/down/right) and a small clear key in the
## inner top corner, the side toward the middle of the screen. Each key is a chunky keycap on a lip: it
## sinks when pressed (the arrow nudges the way it points, a ring ripples out, the phone ticks) and springs
## back up. Hold a key to keep going; slide the thumb onto another arrow to turn without lifting it, like a
## real pad. A key that can't go that way shakes and buzzes.
## Game listens to `step` and `clear`; `mirrored` puts the clear key on the other side (left-hand mode).

signal step(dir: Vector2i)
signal clear

const HOLD_DELAY := 0.32
const REPEAT := 0.13
const ARROWS := {Vector2i(0, -1): "up", Vector2i(0, 1): "down", Vector2i(-1, 0): "left", Vector2i(1, 0): "right"}
const CLEAR := Vector2i(9, 9)

## The clear key sits on the side toward the screen's middle: top-left for a right thumb, top-right for a left.
var mirrored := false:
	set(v):
		mirrored = v
		queue_redraw()

var _held := Vector2i.ZERO       # the key under the thumb (an arrow, CLEAR, or zero)
var _wait := 0.0
var _press := {}                 # key -> 0..1, how far down it is (springs back on release)
var _vel := {}
var _shake := {}                 # key -> seconds of "no" left
var _ripples: Array = []         # {key, t}
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for k in _keys():
		_press[k] = 0.0
		_vel[k] = 0.0
		_shake[k] = 0.0


func _keys() -> Array:
	return ARROWS.keys() + [CLEAR]


## A key's cell in a 3 x 2 grid.
func _cell_of(k: Vector2i) -> Vector2i:
	match k:
		Vector2i(0, -1): return Vector2i(1, 0)
		Vector2i(-1, 0): return Vector2i(0, 1)
		Vector2i(0, 1): return Vector2i(1, 1)
		Vector2i(1, 0): return Vector2i(2, 1)
	return Vector2i(2 if mirrored else 0, 0)


func _rect(k: Vector2i) -> Rect2:
	var cw := size.x / 3.0
	var ch := size.y / 2.0
	var c := _cell_of(k)
	var r := Rect2(Vector2(c) * Vector2(cw, ch), Vector2(cw, ch)).grow(-7.0)
	if k == CLEAR:
		# Smaller, so it's not hit by accident.
		r = r.grow(-r.size.x * 0.17)
	return r


## Where on the pad a point is: the key under it (generous for arrows), or zero.
func _key_at(p: Vector2) -> Vector2i:
	if _rect(CLEAR).grow(4.0).has_point(p):
		return CLEAR
	var best := Vector2i.ZERO
	var best_d := INF
	for k in ARROWS:
		var r := _rect(k)
		var d := r.get_center().distance_to(p)
		if r.grow(14.0).has_point(p) and d < best_d:
			best = k
			best_d = d
	return best


func button(dir: Vector2i) -> Control:
	return self


## Where a key is on screen (for tests and the tutorial): its centre in this control's space.
func key_center(dir: Vector2i) -> Vector2:
	return _rect(dir).get_center()


## That way's blocked: the key shakes and the phone buzzes twice.
func deny(dir: Vector2i) -> void:
	if not _shake.has(dir):
		return
	_shake[dir] = 0.3
	Sfx.haptic(26, 0.9)
	var tw := create_tween()
	tw.tween_interval(0.09)
	tw.tween_callback(Sfx.haptic.bind(18, 0.7))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if e.pressed:
			_touch(_key_at(e.position))
		else:
			_touch(Vector2i.ZERO)
	elif e is InputEventMouseMotion and _held != Vector2i.ZERO:
		accept_event()
		var k := _key_at(e.position)
		# Rolling the thumb from one arrow to another turns; sliding off onto nothing keeps the last one.
		if k != Vector2i.ZERO and k != CLEAR and k != _held and _held != CLEAR:
			_touch(k)


func _touch(k: Vector2i) -> void:
	if k == _held:
		return
	_held = k
	if k == Vector2i.ZERO:
		return
	_vel[k] = 9.0
	_ripples.append({"key": k, "t": 0.0})
	Sfx.haptic(16, 0.55)
	if k == CLEAR:
		clear.emit()
		return
	_wait = HOLD_DELAY
	step.emit(k)


func _process(delta: float) -> void:
	_t += delta
	# Keys: the held one sinks fast; the rest spring back up with a little overshoot.
	for k in _press:
		var target := 1.0 if k == _held else 0.0
		var p: float = _press[k]
		var v: float = _vel[k]
		v += ((target - p) * 420.0 - v * 26.0) * delta
		p += v * delta
		_press[k] = clampf(p, -0.25, 1.15)
		_vel[k] = v
		_shake[k] = maxf(0.0, _shake[k] - delta)
	for r in _ripples:
		r["t"] += delta
	_ripples = _ripples.filter(func(r): return r["t"] < 0.35)
	if _held != Vector2i.ZERO and _held != CLEAR and is_visible_in_tree():
		_wait -= delta
		if _wait <= 0.0:
			_wait = REPEAT
			Sfx.haptic(10, 0.35)
			step.emit(_held)
	queue_redraw()


func _draw() -> void:
	# The pad's base plate.
	var plate := Rect2(Vector2.ZERO, size).grow(-2.0)
	DrawUtil.rrect(self, Rect2(plate.position + Vector2(0, 8), plate.size), Color(0, 0, 0, 0.12), 46)
	for k in _keys():
		_draw_key(k)
	for r in _ripples:
		var rect := _rect(r["key"])
		var u: float = r["t"] / 0.35
		var rad := rect.size.x * (0.42 + 0.35 * u)
		draw_arc(rect.get_center() + Vector2(0, 8), rad, 0, TAU, 40, Color(Palette.ACCENT, 0.55 * (1.0 - u)), 8.0 * (1.0 - u) + 2.0, true)


func _draw_key(k: Vector2i) -> void:
	var r := _rect(k)
	var lip := 14.0
	var p: float = _press[k]
	var sink := lip * clampf(p, 0.0, 1.0)
	var shake: float = _shake[k]
	var off := Vector2(sin(shake * 70.0) * 9.0 * (shake / 0.3), sink)
	var face := Palette.SURFACE
	var edge := face.darkened(0.22)
	var ink := Palette.TEXT
	if k == CLEAR:
		face = Palette.SURFACE_DIM
		edge = face.darkened(0.2)
		ink = Palette.TEXT_SOFT
	if p > 0.05 and k != CLEAR:
		face = face.lerp(Palette.ACCENT, 0.18 * clampf(p, 0.0, 1.0))
	if shake > 0.0:
		face = face.lerp(Palette.CRASH, 0.35 * shake / 0.3)
	var cap := Rect2(r.position + off, Vector2(r.size.x, r.size.y - lip))
	var rad := minf(r.size.x, r.size.y) * 0.26
	# Lip (the key's side), then the cap on top of it.
	DrawUtil.rrect(self, Rect2(r.position + Vector2(off.x, lip), Vector2(r.size.x, r.size.y - lip)), edge, rad)
	DrawUtil.rrect(self, cap, face, rad)
	DrawUtil.rrect(self, Rect2(cap.position + Vector2(rad * 0.4, 6), Vector2(cap.size.x - rad * 0.8, 6)), Color(1, 1, 1, 0.22 * (1.0 - p)), 3)
	var c := cap.get_center()
	if k == CLEAR:
		Icons.draw(self, "x", c, minf(cap.size.x, cap.size.y) * 0.42, ink)
		return
	var dir := Vector2(k)
	var s := minf(cap.size.x, cap.size.y) * 0.5 * (1.0 - 0.08 * clampf(p, 0.0, 1.0))
	Icons.draw(self, ARROWS[k], c + dir * 7.0 * clampf(p, 0.0, 1.0), s, ink if p < 0.3 else Palette.ACCENT.darkened(0.15))
