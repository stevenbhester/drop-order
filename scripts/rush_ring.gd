class_name RushRing
extends Control
## A rush (Progress.rush_*: free undos or free hints against a clock) shown on its button, Undo or Hint. A child
## of that button, the same size; it draws round it and takes no taps. Game sets what's so each frame:
##
##   armed    a charge is in hand: a gold stopwatch sits on the button's top edge, to the left (clear of
##            the next button's badge), bobbing
##   charge   0..1 while the button's held to start it: a gold line runs round the button
##   left     seconds left of one that's running (of `full`): the line round the button runs down with them,
##            and goes red and throbs for the last ten
##
## The time itself is the button's badge (Game._update_undo). draw_watch is the stopwatch, for anyone.

const GOLD := Color("ffc53d")
const HOT := Color("ef4034")
const INK := Color("2b2233")
const LAST := 10.0                 # seconds from the end it turns red

var kind := "undos"
var armed := false
var charge := 0.0
var left := 0.0
var full := 1.0

var _t := 0.0
var _nudge := 0.0
var _burst := 0.0
var _drew := false
var _under: Control                # the line round the button: behind it, so its badge (the clock) stays on top


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_under = Control.new()
	_under.show_behind_parent = true
	_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_under.draw.connect(_draw_under)
	(func():
		get_parent().add_child(_under)
		_under.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)).call_deferred()


## "Hold me": the stopwatch shakes (a tap where a hold starts the rush).
func nudge() -> void:
	_nudge = 1.0


## The rush just started: a ring of light off the button.
func burst() -> void:
	_burst = 1.0


func _process(delta: float) -> void:
	_t += delta
	_nudge = maxf(0.0, _nudge - delta * 2.2)
	_burst = maxf(0.0, _burst - delta * 1.6)
	var on := armed or charge > 0.0 or left > 0.0 or _burst > 0.0
	if on or _drew:
		queue_redraw()
		_under.queue_redraw()
	_drew = on


func _draw_under() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(9.0)
	var rad := minf(r.size.y / 2.0, 46.0)
	if left > 0.0:
		var hot := left <= LAST
		var col := HOT.lerp(Color.WHITE, 0.35 * (0.5 + 0.5 * sin(_t * 12.0))) if hot else GOLD
		var w := 10.0 + (3.0 * (0.5 + 0.5 * sin(_t * 12.0)) if hot else 0.0)
		_line(r, rad, 1.0, Color(col, 0.22), w)
		_line(r, rad, clampf(left / maxf(full, 0.01), 0.0, 1.0), col, w)
	elif charge > 0.0:
		_line(r, rad, 1.0, Color(GOLD, 0.25), 10.0)
		_line(r, rad, clampf(charge, 0.0, 1.0), GOLD, 10.0)


func _draw() -> void:
	if _burst > 0.0:
		var r := Rect2(Vector2.ZERO, size).grow(9.0)
		var k := 1.0 - _burst
		_line(r.grow(k * 70.0), minf(r.size.y / 2.0, 46.0) + k * 70.0, 1.0, Color(GOLD, _burst * 0.8), 10.0 * _burst + 2.0, self)
	if armed and left <= 0.0:
		# The charge in hand: a stopwatch on the corner across from the badge.
		var c := Vector2(48.0, -4.0) + Vector2(sin(_t * 30.0) * 7.0 * _nudge, sin(_t * 2.6) * 3.0)
		var s := 31.0 * (1.0 + 0.06 * sin(_t * 2.6) + 0.25 * _nudge)
		draw_circle(c, s * 1.35, Color(GOLD, 0.16 + 0.1 * sin(_t * 2.6)))
		draw_watch(self, c, s, GOLD, INK, _t * 2.2)


## A line round the rounded box `r`, clockwise from the middle of its top, as far round as `frac`.
func _line(r: Rect2, rad: float, frac: float, col: Color, w: float, ci: CanvasItem = null) -> void:
	if ci == null:
		ci = _under
	var pts := PackedVector2Array([Vector2(r.get_center().x, r.position.y)])
	var cs := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for q in 4:
		for k in 9:
			var a := -PI / 2.0 + q * PI / 2.0 + (PI / 2.0) * k / 8.0
			pts.append(cs[q] + Vector2(cos(a), sin(a)) * rad)
	pts.append(pts[0])
	if frac < 1.0:
		var total := 0.0
		for i in range(1, pts.size()):
			total += pts[i - 1].distance_to(pts[i])
		var want := total * frac
		var cut := PackedVector2Array([pts[0]])
		for i in range(1, pts.size()):
			var d := pts[i - 1].distance_to(pts[i])
			if d >= want:
				cut.append(pts[i - 1].lerp(pts[i], want / maxf(d, 0.001)))
				break
			cut.append(pts[i])
			want -= d
		pts = cut
	if pts.size() >= 2:
		ci.draw_polyline(pts, col, w, true)
		ci.draw_circle(pts[pts.size() - 1], w / 2.0, col)
		ci.draw_circle(pts[0], w / 2.0, col)


## A stopwatch: a round face of `body` with an `ink` rim, a crown on top, a button on its shoulder, and one
## hand at `hand` radians (0: straight up, clockwise). `s` is the face's radius.
static func draw_watch(ci: CanvasItem, c: Vector2, s: float, body: Color, ink: Color, hand: float) -> void:
	ci.draw_rect(Rect2(c + Vector2(-s * 0.2, -s * 1.42), Vector2(s * 0.4, s * 0.5)), ink)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.36, -s * 1.56), Vector2(s * 0.72, s * 0.24)), ink)
	var sh := Vector2(cos(-PI / 4.0), sin(-PI / 4.0))
	ci.draw_line(c + sh * s * 0.9, c + sh * s * 1.32, ink, s * 0.26)
	ci.draw_circle(c, s, ink)
	ci.draw_circle(c, s * 0.8, body)
	ci.draw_circle(c, s * 0.62, Color.WHITE)
	for k in 4:
		var d := Vector2(cos(k * PI / 2.0), sin(k * PI / 2.0))
		ci.draw_line(c + d * s * 0.46, c + d * s * 0.6, ink, s * 0.09)
	var h := Vector2(sin(hand), -cos(hand))
	ci.draw_line(c, c + h * s * 0.48, ink, s * 0.13, true)
	ci.draw_circle(c, s * 0.12, ink)
