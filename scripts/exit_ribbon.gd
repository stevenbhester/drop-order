class_name ExitRibbon
extends Control
## The way out of a job, on a ribbon end sticking out of the screen's left edge (where the levels button
## was: that left at a touch, with no word of what it cost). Put away it's just the end: a back arrow, and
## under it (on the main road's jobs) the jump jets' row, which is one of three things (`row`):
##   "locked"  before job `locked_until`: a padlock, and pulled out, a parcel label: DO NOT OPEN TILL JOB 13
##   "gift"    from then until it's opened: a bow, bobbing. A tap on it (put away or pulled out) is
##             `gift_tapped`: Dispatch sent help your way (Game shows what: the jump jets)
##   "jets"    the jets themselves: their arcing arrow
## A tap pulls it out into the whole banner:
##   Give up        hold it (a moment is plenty: GIVE_HOLD) and you're back at the map. `give_up`.
##   Jump jets -1   hold it and the fuel line fills it from the gas gauge (Game does that: `jets_down`,
##                  `jets_up`, with `jets_row` as the thing to fill); full, the job's skipped for a tank.
##                  On a boss job the Baron's tape is across it (`jets_blocked`): no jumping those.
## A tap anywhere else, or a few seconds left alone, and it slides back. With `instant` (the job's won) a
## tap just leaves.

signal give_up
signal jets_down
signal jets_up
signal gift_tapped

const ROW_H := 104.0
const TAB_W := 132.0
const FULL_W := 620.0
const NOTCH := 30.0
const GIVE_HOLD := 0.3
const BODY := Color("fffaf2")
const INK := Color("2b2233")

var row := ""                   # the second row: "" (none), "locked", "gift" or "jets"
var locked_until := 13          # "locked": the job it opens at
var jets: bool:                 # (the jets themselves are on it)
	get:
		return row == "jets"
var jets_blocked := false       # ...with the Baron's tape across it
var jets_waiting := 0           # jobs jumped and not delivered yet (the row says how many of jets_max)
var jets_max := 3
var jets_full := false          # ...and that's as many as may wait: no more jumps till one's delivered
var give_label := "Give up"
var instant := false
var jets_row: Control           # the jets' row, as a thing to point a fuel line at

var _out := 0.0                 # 0 put away, 1 pulled out
var _want := 0.0
var _idle := 0.0
var _give := -1.0               # seconds Give up's been held (-1: not)
var _jets_held := false
var _jets_t := 0.0              # how long the jets have been held (the row fills at once, before the fuel line gets there)
var _jets_no := -10.0           # when a quick tap on the jets was last told to hold
var _t := 0.0
var _pulse := -10.0             # when the jets' icon was last told to wave (nudge)
var _no := -10.0                # when the locked row was last tapped (it shakes its head)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	jets_row = Control.new()
	jets_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(jets_row)
	_fit()


func is_open() -> bool:
	return _want > 0.5


## "Over here": the jets' arrow hops and glows for a bit (when the player looks stuck).
func nudge() -> void:
	_pulse = _t


func open() -> void:
	_want = 1.0
	_idle = 0.0


func close() -> void:
	_want = 0.0
	_give = -1.0


func _rows() -> int:
	return 2 if row != "" else 1


func _fit() -> void:
	var w := lerpf(TAB_W, FULL_W, _ease(_out))
	size = Vector2(w, ROW_H * _rows())
	if jets_row:
		jets_row.position = Vector2(0, ROW_H)
		jets_row.size = Vector2(maxf(w - NOTCH - 10.0, 10.0), ROW_H)


static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


func _process(delta: float) -> void:
	_t += delta
	_out = move_toward(_out, _want, delta * 5.5)
	if is_open() and _give < 0.0 and not _jets_held:
		_idle += delta
		if _idle > 5.0:
			close()
	_jets_t = (_jets_t + delta) if _jets_held else 0.0
	if _give >= 0.0:
		_give += delta
		if _give >= GIVE_HOLD:
			_give = -1.0
			close()
			Sfx.haptic(20)
			give_up.emit()
	_fit()
	queue_redraw()


## A press anywhere off the ribbon puts it away.
func _input(e: InputEvent) -> void:
	if is_open() and e is InputEventMouseButton and e.pressed and not get_global_rect().has_point(e.position):
		close()


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	_idle = 0.0
	if e.pressed:
		if instant:
			Sfx.play("click")
			give_up.emit()
		elif row == "gift" and e.position.y >= ROW_H:
			# The bow, tapped (put away or pulled out): open it.
			Sfx.play("click")
			gift_tapped.emit()
		elif not is_open() or _out < 0.8:
			_want = 1.0
			Sfx.play("whoosh", 1.4, -10.0)
			Sfx.haptic(8, 0.4)
		elif e.position.y < ROW_H or row == "":
			_give = 0.0
			Sfx.play("tick", 0.9, -6.0)
		elif row == "locked":
			_no = _t
			Sfx.play("bonk", 1.2, -8.0)
			Sfx.haptic(10, 0.5)
		else:
			_jets_held = true
			jets_down.emit()
	else:
		if _give >= 0.0:
			# Let go too soon: it says what it wants ("hold" jumps out).
			_give = -1.0
			_no = _t
			Sfx.play("bonk", 1.3, -12.0)
		if _jets_held:
			if _jets_t < GasLine.TIME:
				_jets_no = _t        # (let go too soon: "press and hold!")
				Sfx.play("bonk", 1.3, -12.0)
			_jets_held = false
			jets_up.emit()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var k := _ease(_out)
	var f := UiTheme.font()
	# The ribbon: off the screen's edge to its notched end.
	var body := PackedVector2Array([Vector2(-60, 0), Vector2(w, 0), Vector2(w - NOTCH, h / 2.0), Vector2(w, h), Vector2(-60, h)])
	var shadow := PackedVector2Array()
	for p in body:
		shadow.append(p + Vector2(4, 8))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.16))
	draw_colored_polygon(body, BODY)
	# Give up, held: it fills from the left.
	if _give >= 0.0:
		draw_rect(Rect2(0, 0, (w - NOTCH) * clampf(_give / GIVE_HOLD, 0.0, 1.0), ROW_H), Color(Palette.ACCENT, 0.45))
	var edge := body.duplicate()
	edge.append(body[0])
	draw_polyline(edge, Color(0, 0, 0, 0.14), 3.0, true)
	var end_x := w - NOTCH - 50.0
	# Row 1: the back arrow on the end, and (pulled out) what it does.
	var c1 := Vector2(end_x, ROW_H / 2.0)
	draw_polyline(PackedVector2Array([c1 + Vector2(12, -22), c1 + Vector2(-12, 0), c1 + Vector2(12, 22)]), INK, 10.0, true)
	for p in [c1 + Vector2(12, -22), c1 + Vector2(-12, 0), c1 + Vector2(12, 22)]:
		draw_circle(p, 5.0, INK)
	if k > 0.05:
		draw_string(f, Vector2(40, ROW_H / 2.0 + 16), give_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(INK, k))
		var told := maxf(0.0, 1.0 - (_t - _no) / 0.9) if row != "locked" else 0.0
		draw_string(f, Vector2(40 + f.get_string_size(give_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x + 18, ROW_H / 2.0 + 12 + 4.0 * told), "hold" if told <= 0.0 else "press and hold!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 + 12 * told), Color(INK, 0.45 * k).lerp(Color(Palette.ACCENT, k), told))
	if row == "":
		return
	draw_line(Vector2(0, ROW_H), Vector2(w - NOTCH * 0.4, ROW_H), Color(0, 0, 0, 0.1), 3.0)
	var hop := maxf(0.0, 1.0 - (_t - _pulse) / 2.4)
	if row == "locked":
		# Not yet: a padlock on the end, and pulled out, a parcel label saying when (it shakes its head if tapped).
		var c2 := Vector2(end_x, ROW_H * 1.5)
		Icons.draw(self, "lock", c2, 50.0, Color(INK, 0.4))
		if k > 0.05:
			var shake := sin((_t - _no) * 40.0) * 10.0 * maxf(0.0, 1.0 - (_t - _no) / 0.4)
			draw_set_transform(Vector2(40 + shake, ROW_H * 1.5), -0.03, Vector2.ONE)
			var words := "DO NOT OPEN TILL JOB %d" % locked_until
			var tw := f.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			draw_rect(Rect2(-12, -30, tw + 44, 62), Color(0, 0, 0, 0.12 * k))
			draw_rect(Rect2(-16, -34, tw + 44, 62), Color("e8c98c", k))
			draw_rect(Rect2(-16, -34, tw + 44, 62), Color("b8935a", k), false, 3.0)
			draw_circle(Vector2(0, -3), 7.0, Color("fffaf2", k))
			draw_string(f, Vector2(16, 8), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("6b4a22", k))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_string(f, Vector2(40, ROW_H * 2.0 - 8), "signed, Dispatch", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(INK, 0.4 * k))
		return
	if row == "gift":
		# It's here: the row's wrapped, a bow on the end, bobbing; pulled out it says who it's from.
		draw_rect(Rect2(0, ROW_H + 2, w - NOTCH, ROW_H - 4), Color(1.0, 0.86, 0.45, 0.35))
		draw_rect(Rect2(end_x - 14, ROW_H + 2, 28, ROW_H - 4), Color("e8473c", 0.85))
		var bob := 6.0 * sin(_t * 4.0) + 10.0 * absf(sin((_t - _pulse) * 9.0)) * hop
		_bow(Vector2(end_x, ROW_H * 1.5 - bob), 1.0 + 0.06 * sin(_t * 6.0))
		for sp in 3:
			var a := _t * 2.0 + sp * TAU / 3.0
			draw_colored_polygon(Icons.star_points(Vector2(end_x, ROW_H * 1.5 - bob) + Vector2(cos(a), sin(a)) * 44.0, 7.0, 3.0, _t), Color(1, 0.95, 0.6, 0.9))
		if k > 0.05:
			draw_string(f, Vector2(40, ROW_H * 1.5 + 6), "From Dispatch!", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(INK, k))
			draw_string(f, Vector2(40, ROW_H * 2.0 - 12), "tap to open", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(INK, 0.5 * k))
		return
	# The jump jets themselves.
	var dim := 0.4 if jets_blocked or jets_full else 1.0
	var c2 := Vector2(end_x, ROW_H * 1.5 - 10.0 * absf(sin((_t - _pulse) * 9.0)) * hop)
	if hop > 0.0:
		draw_circle(c2, 44.0, Color(GasChip.FUEL, 0.25 * hop))
	_arc_arrow(c2, 30.0, Color(INK, dim))
	# Held: the row fills from the left straight away, so a hold plainly does something.
	if _jets_held and not jets_blocked and not jets_full:
		draw_rect(Rect2(0, ROW_H + 2, (w - NOTCH) * clampf(_jets_t / GasLine.TIME, 0.0, 1.0), ROW_H - 4), Color(GasChip.FUEL, 0.4))
	if k > 0.05:
		var jtold := maxf(0.0, 1.0 - (_t - _jets_no) / 1.2)
		draw_string(f, Vector2(40, ROW_H * 1.5 + 6), "Jump jets", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(INK, k * dim))
		var under := "deliver a waiting job first" if jets_full else ("hold to skip this job" if jtold <= 0.0 else "press and hold!")
		draw_string(f, Vector2(40, ROW_H * 2.0 - 12), under, HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 + 8 * jtold),
			Color(INK, (0.8 if jets_full else 0.5 * dim) * k).lerp(Color(Palette.ACCENT, k), jtold))
		# What it costs: nothing but a place on the map. How many jobs are waiting there, of how many may.
		var cx := 40 + f.get_string_size("Jump jets", HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x + 26.0
		var tag := "%d/%d waiting" % [jets_waiting, jets_max]
		var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		var tcol := Palette.ACCENT if jets_full else GasChip.FUEL
		DrawUtil.rrect(self, Rect2(cx, ROW_H * 1.5 - 36, tw + 36, 52), Color(tcol, (0.3 if jets_full else 0.18) * k), 26)
		draw_string(f, Vector2(cx + 18, ROW_H * 1.5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(tcol.darkened(0.3), k))
	if jets_blocked:
		# The Baron's tape across it: no jumping his jobs.
		var a := Vector2(-20, ROW_H * 1.5 + 22)
		var b := Vector2(w - NOTCH * 0.6, ROW_H * 1.5 - 22)
		_tape(a, b, 38.0, "HOARDLY INC. · NO JUMPING · " if k > 0.5 else "")


## A bow: two loops, two tails and a knot.
func _bow(c: Vector2, s: float) -> void:
	var red := Color("e8473c")
	for sx in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(34 * sx, -24) * s, c + Vector2(40 * sx, 0) * s, c + Vector2(34 * sx, 22) * s]), red)
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(26 * sx, -12) * s, c + Vector2(28 * sx, 10) * s]), red.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(10 * sx, 34) * s, c + Vector2(24 * sx, 30) * s]), red.darkened(0.1))
	draw_circle(c, 11.0 * s, red.lightened(0.15))


## An arrow arcing up and over, left to right (the jump).
func _arc_arrow(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.95 + r * 0.45))
	draw_polyline(pts, col, 9.0, true)
	draw_circle(pts[0], 4.5, col)
	var tip := pts[pts.size() - 1]
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-17, -6), tip + Vector2(15, -6), tip + Vector2(0, 18)]), col)


func _tape(a: Vector2, b: Vector2, wd: float, words: String) -> void:
	var dir := b - a
	var ln := dir.length()
	if ln < 4.0:
		return
	draw_set_transform(a, dir.angle(), Vector2.ONE)
	draw_rect(Rect2(0, -wd / 2.0 + 4, ln, wd), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(0, -wd / 2.0, ln, wd), Color("ffc93c"))
	var x := 0.0
	while x < ln:
		draw_colored_polygon(PackedVector2Array([Vector2(x, -wd / 2.0), Vector2(minf(x + 14, ln), -wd / 2.0), Vector2(minf(x + 6, ln), -wd / 2.0 + 8), Vector2(maxf(x - 8, 0), -wd / 2.0 + 8)]), INK)
		draw_colored_polygon(PackedVector2Array([Vector2(x, wd / 2.0 - 8), Vector2(minf(x + 14, ln), wd / 2.0 - 8), Vector2(minf(x + 6, ln), wd / 2.0), Vector2(maxf(x - 8, 0), wd / 2.0)]), INK)
		x += 30.0
	if words != "":
		var f := UiTheme.font()
		var ww := f.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var tx := 8.0
		while tx < ln - 30.0:
			draw_string(f, Vector2(tx, 6), words, HORIZONTAL_ALIGNMENT_LEFT, ln - tx, 18, INK)
			tx += ww
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
