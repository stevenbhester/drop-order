class_name DailyRibbon
extends Control
## The daily, as a ribbon sticking out from the right edge of the map, just under the options button
## (in easy reach of a right thumb), its notched end pointing in. On it, a little calendar with a 3x3 of
## days: a race car on the day your streak's reached (the first, with no streak; left to right, then down),
## and the days behind it burning. What it looks like says where today's daily stands:
##   locked   (before job Daily.UNLOCK_AT) grey, the calendar dull and blurred under a padlock; a tap says when
##   fresh    not opened today: a bright, shifting colour, bobbing, a red dot on the calendar's corner
##   opened   opened today but not solved: plain white, no dot
##   done     solved today: it slides back into the edge, leaving just its notched end (a tap still opens it)
## A tap (unless it's locked) emits `pressed`. The map places it (its right edge on the screen's).

signal pressed

const H := 124.0               # how tall it is
const FULL := 210.0            # how far it sticks out, in full
const SHORT := 70.0            # ...and pulled back (done)
const NOTCH := 26.0
const CAL := Vector2(92, 96)

var _t := 0.0
var _tip := -10.0          # when a tap on the locked ribbon said why
var _out := 1.0            # how far out it is, eased (0: pulled back, 1: all the way)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_out = 0.0 if state() == "done" else 1.0
	size = Vector2(_len(), H)


## Where today's daily stands (see the top).
static func state() -> String:
	if not Daily.unlocked():
		return "locked"
	var r := Progress.daily_record(Daily.today())
	if r.get("done", false):
		return "done"
	if Progress.daily_seen == Daily.today():
		return "opened"
	return "fresh"


## How far it sticks out now.
func _len() -> float:
	return lerpf(SHORT, FULL, _out)


func _process(delta: float) -> void:
	_t += delta
	var want := 0.0 if state() == "done" else 1.0
	_out = lerpf(_out, want, 1.0 - exp(-8.0 * delta))
	# Only as big as it is (and its tip, under it), so the map round a pulled-back one still takes taps.
	size = Vector2(_len(), H + (64.0 if _t - _tip < 2.2 else 0.0))
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and e.position.y <= H:
		accept_event()
		if state() == "locked":
			Sfx.play("bonk", 1.1, -6.0)
			_tip = _t
		else:
			Sfx.play("click")
			pressed.emit()


func _draw() -> void:
	var st := state()
	var L := _len()
	var bob := sin(_t * 2.2) * 4.0 if st == "fresh" else 0.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)
	# The ribbon: from its notched end (left) to past the screen's edge (right).
	var body := PackedVector2Array([Vector2(0, 0), Vector2(L + 40.0, 0), Vector2(L + 40.0, H), Vector2(0, H), Vector2(NOTCH, H / 2.0)])
	var shadow := PackedVector2Array()
	for p in body:
		shadow.append(p + Vector2(-4, 8))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.18))
	match st:
		"fresh":
			# A bright colour that keeps shifting, bands sliding along it, a shine now and then.
			var hue := fmod(_t * 0.06, 1.0)
			draw_colored_polygon(body, Color.from_hsv(hue, 0.62, 1.0))
			for k in 4:
				var bx := fmod(_t * 80.0 + k * 70.0, L + 160.0) - 80.0
				var band := PackedVector2Array([Vector2(bx, 0), Vector2(bx + 34, 0), Vector2(bx - 6, H), Vector2(bx - 40, H)])
				for piece in Geometry2D.intersect_polygons(band, body):
					draw_colored_polygon(piece, Color.from_hsv(fmod(hue + 0.12 + k * 0.08, 1.0), 0.55, 1.0, 0.85))
			var shine := fmod(_t * 0.5, 2.0)
			if shine < 1.0:
				var sx := -60.0 + (L + 120.0) * shine
				var sh := PackedVector2Array([Vector2(sx, 0), Vector2(sx + 22, 0), Vector2(sx - 18, H), Vector2(sx - 40, H)])
				for piece in Geometry2D.intersect_polygons(sh, body):
					draw_colored_polygon(piece, Color(1, 1, 1, 0.45))
		"opened":
			draw_colored_polygon(body, Color("fffaf2"))
		"done":
			draw_colored_polygon(body, Palette.GOOD)
		_:
			draw_colored_polygon(body, Color("b9b6bd"))
	var edge := body.duplicate()
	edge.append(body[0])
	draw_polyline(edge, Color(0, 0, 0, 0.12), 3.0, true)
	if st == "done":
		# Just the end: a tick on it.
		var c := Vector2(NOTCH + 20.0, H / 2.0)
		draw_polyline(PackedVector2Array([c + Vector2(-12, 0), c + Vector2(-3, 10), c + Vector2(15, -12)]), Color.WHITE, 6.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# The calendar, near the notched end.
	var cal := Rect2(Vector2(NOTCH + 14.0, (H - CAL.y) / 2.0 + 4.0), CAL)
	if st == "locked":
		# Dull and blurred (drawn a few times, offset and faint), a padlock over it.
		for off in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			_calendar(Rect2(cal.position + off, cal.size), 0.28, true)
		Icons.draw(self, "lock", cal.get_center() + Vector2(0, 6), 58.0, Color("6e6a75"))
	else:
		_calendar(cal, 1.0, false)
		if st == "fresh":
			# The red dot: today's is waiting.
			var p := 1.0 + 0.15 * sin(_t * 5.0)
			var dc := cal.position + Vector2(cal.size.x - 4, 4)
			draw_circle(dc, 15.0 * p, Color.WHITE)
			draw_circle(dc, 12.0 * p, Color("ff3b30"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if st == "locked" and _t - _tip < 2.2:
		# Why it won't open: a little note under it, against the screen's edge.
		var a := clampf(2.2 - (_t - _tip), 0.0, 1.0)
		var f := UiTheme.font()
		var msg := "The daily opens after job %d" % Daily.UNLOCK_AT
		var tw := f.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var at := Vector2(L - tw - 44.0, H + 8.0)
		DrawUtil.rrect(self, Rect2(at, Vector2(tw + 28.0, 50)), Color(Palette.BUBBLE, 0.95 * a), 18)
		draw_string(f, at + Vector2(14, 34), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(Palette.TEXT, a))


## The calendar in `r`: two rings on top, a red header, a 3x3 of days. `a` is how solid; `dull` greys it.
func _calendar(r: Rect2, a: float, dull: bool) -> void:
	var paper := Color(1, 1, 1, a) if not dull else Color(0.9, 0.89, 0.92, a)
	var head := Color("e8473c") if not dull else Color("9a96a0")
	DrawUtil.rrect(self, Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.15 * a), 14)
	DrawUtil.rrect(self, r, paper, 14)
	DrawUtil.rrect(self, Rect2(r.position, Vector2(r.size.x, 24)), Color(head, a), 14)
	draw_rect(Rect2(r.position + Vector2(0, 12), Vector2(r.size.x, 12)), Color(head, a))
	for x in [0.3, 0.7]:
		DrawUtil.rrect(self, Rect2(r.position + Vector2(r.size.x * x - 5, -8), Vector2(10, 20)), Color(0.25, 0.22, 0.3, a), 5)
	# The days: the car on the streak's day, the ones before it on fire.
	var streak := Progress.streak(Daily.today()) if not dull else 0
	var car := mini(streak, 8)
	var gap := 24.0
	var g0 := r.position + Vector2(r.size.x / 2.0 - gap, 24.0 + (r.size.y - 24.0) / 2.0 - gap)
	for i in 9:
		var p := g0 + Vector2((i % 3) * gap, (i / 3) * gap)
		if i < car:
			AnimeFire.draw_flame(self, p + Vector2(0, 7), 13.0, 20.0, _t, i * 1.3, AnimeFire.palette(mini(streak, 8) + 1))
			draw_circle(p, 4.0, Color("ffb347"))
		elif i == car and not dull:
			draw_circle(p, 9.0, Color(1, 0.85, 0.3, 0.35 + 0.2 * sin(_t * 4.0)))
			_car(p)
		else:
			draw_circle(p, 5.0, Color(0.6, 0.58, 0.64, 0.45 * a))


## A tiny race car at `p`, facing right.
func _car(p: Vector2) -> void:
	DrawUtil.rrect(self, Rect2(p + Vector2(-11, -5), Vector2(22, 10)), Color("e8473c"), 4)
	DrawUtil.rrect(self, Rect2(p + Vector2(-2, -3.5), Vector2(7, 7)), Color("23325c"), 2)
	for wx in [-7.0, 7.0]:
		for wy in [-6.0, 6.0]:
			draw_rect(Rect2(p + Vector2(wx - 3, wy - 1.5), Vector2(6, 3)), Color("1d1b22"))
	draw_rect(Rect2(p + Vector2(10, -6), Vector2(3, 12)), Color("ffd166"))
