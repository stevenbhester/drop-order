class_name SymbolCard
extends Control
## "What's this?": tap (or hold) a symbol on the board and this card pops up by it: one punchy line and a
## little looping picture that shows the rule (a van going the way the arrow points, a box landing on top
## of the load...). Simple enough for a kid. Any new touch anywhere closes it (that touch does nothing
## else). Game decides what's on the tile (`kind`, plus a colour / count) and where it is (`target`).
##
## It listens in _input, before the GUI and the game, so nothing can get between it and the tap that
## closes it: the game ignores input while the card is up, so a card that can't hear taps is a soft lock.

signal closed

## oneway, bridge, gate, hub, pickup, warehouse, house, houses, house_done, pickup_done, exit, pitstop,
## gift, key, wreck.
var kind := ""
var col := Color.WHITE
var col_name := ""
var count := 1
var dir := Vector2.RIGHT
var target := Vector2.INF

var _t := 0.0
var _box := Rect2()
var _closing := false
var _text := ""


func _ready() -> void:
	# Cover the screen so nothing underneath takes clicks. (set_anchors_preset alone would keep the size a
	# new Control starts with, 0 x 0, since it's already in the tree here.)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_text = line()
	var v := get_viewport_rect().size
	var w := minf(v.x - 40.0, 960.0)
	var h := 230.0
	var y := v.y * 0.5 - h / 2.0
	if target != Vector2.INF:
		y = target.y + 90.0 if target.y < v.y * 0.5 else target.y - 90.0 - h
	y = clampf(y, 170.0, v.y - h - 30.0)
	_box = Rect2(Vector2((v.x - w) / 2.0, y), Vector2(w, h))
	Sfx.play("pop", 1.15, -6.0)
	Sfx.haptic(10, 0.5)


## The one line for this symbol.
func line() -> String:
	var n := col_name
	match kind:
		"oneway": return "One way! Go the way the arrow points."
		"bridge": return "Bridge: drive straight across. Over once, under once."
		"gate": return "Gate: opens only when your top package is %s." % n
		"hub": return "Spinner: swaps your top two packages."
		"pickup": return "Pickup! Adds a %s package on TOP of your load." % n
		"warehouse": return "Warehouse: adds +%d %s packages on top, all at once." % [count, n]
		"house": return "Wants a %s package. Bring it when it's on top!" % n
		"houses": return "Wants %d %s packages, one at a time, each on top." % [count, n]
		"house_done": return "Delivered! All done here."
		"pickup_done": return "Picked up! Nothing left here."
		"exit": return "The road on! Deliver everything to open the gate, then finish here."
		"pitstop": return "Finish here: park back at the pit stop."
		"gift": return "A present! Drive over it to keep it."
		"key": return "A key! Pick it up and win: it opens a locked detour."
		"ice": return "Ice! No turning on it: slide straight across."
		"locker": return "Locker: takes whatever package is on top." if count <= 1 else "Locker: takes the next %d packages, whatever they are." % count
		"works": return "Roadworks: opens after %d more deliver%s." % [count, "y" if count == 1 else "ies"] if count > 0 else "Roadworks: open now!"
		"wreck": return "Torn-up road. You can't drive here again."
	return ""


## Every touch and click is the card's while it's up (a phone sends both: the touch, and a mouse event made
## from it). A new press closes it, once it's been up a moment, so the tap or hold that opened it can't.
func _input(e: InputEvent) -> void:
	var pointer: bool = e is InputEventMouseButton or e is InputEventMouseMotion or e is InputEventScreenTouch \
			or e is InputEventScreenDrag
	if not pointer:
		return
	get_viewport().set_input_as_handled()
	var press: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if press and _t >= 0.15:
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var k := minf(_t / 0.2, 1.0)
	var r := _box
	var c := r.get_center()
	draw_set_transform(c, 0.0, Vector2.ONE * (0.8 + 0.2 * k + 0.05 * sin(PI * k)))
	var lr := Rect2(-r.size / 2.0, r.size)
	if target != Vector2.INF:
		var tl := target - c
		var d := tl.normalized()
		var side := Vector2(-d.y, d.x)
		var edge := Vector2(clampf(tl.x, lr.position.x + 60.0, lr.end.x - 60.0), lr.end.y if tl.y > 0 else lr.position.y)
		draw_colored_polygon(PackedVector2Array([edge + Vector2(-24, 0), edge + Vector2(24, 0), tl - d * 40.0]), Color.WHITE)
		draw_arc(tl, 46.0 + 6.0 * sin(_t * 5.0), 0, TAU, 32, Color(Palette.ACCENT, 0.9), 6.0, true)
	DrawUtil.rrect(self, Rect2(lr.position + Vector2(0, 10), lr.size), Color(0, 0, 0, 0.2), 36)
	DrawUtil.rrect(self, lr, Color.WHITE, 36)
	# The picture, in its own little panel on the left.
	var pic := Rect2(lr.position + Vector2(18, 18), Vector2(lr.size.y - 36, lr.size.y - 36))
	DrawUtil.rrect(self, pic, Color("eaf6e1"), 26)
	_picture(pic)
	# The line, big, on the right.
	var f := UiTheme.font()
	var tx := pic.end.x + 26.0
	var tw := lr.end.x - 26.0 - tx
	var px := 40
	var words := _text.split(" ")
	var lines := []
	var cur := ""
	for wd in words:
		var tryl := wd if cur == "" else cur + " " + wd
		if f.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > tw and cur != "":
			lines.append(cur)
			cur = wd
		else:
			cur = tryl
	lines.append(cur)
	var y0 := -lines.size() * 48.0 / 2.0 + 34.0
	for i in lines.size():
		draw_string(f, Vector2(tx, y0 + i * 48.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Palette.TEXT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- the pictures

func _van(c: Vector2, s: float, rot: float, top := Color.TRANSPARENT, a := 1.0) -> void:
	var L := s
	var W := s * 0.62
	draw_set_transform(_xf_origin() + c * _xf_scale(), rot, Vector2.ONE * _xf_scale())
	DrawUtil.rrect(self, Rect2(-L / 2, -W / 2, L, W), Color(Palette.VAN_BODY, a), W * 0.28)
	DrawUtil.rrect(self, Rect2(L / 2 - L * 0.3, -W / 2, L * 0.3, W), Color(Palette.VAN_CAB, a), W * 0.28)
	if top.a > 0.0:
		DrawUtil.parcel(self, Vector2(-L * 0.12, 0), Vector2(W * 0.7 * 1.3, W * 0.7), Color(top, a), false)
	draw_set_transform(_xf_origin(), 0.0, Vector2.ONE * _xf_scale())


# The card's own transform (the pop-in scale), so helpers can draw rotated things inside it.
var _org := Vector2.ZERO
var _scl := 1.0


func _xf_origin() -> Vector2:
	return _org


func _xf_scale() -> float:
	return _scl


func _road(a: Vector2, b: Vector2, w: float) -> void:
	draw_line(a, b, Palette.ROAD, w, true)
	draw_circle(a, w / 2.0, Palette.ROAD)
	draw_circle(b, w / 2.0, Palette.ROAD)


func _tick(c: Vector2, r: float, ok := true) -> void:
	draw_circle(c, r, Palette.CHECK if ok else Palette.CRASH)
	if ok:
		draw_polyline(PackedVector2Array([c + Vector2(-0.45, 0.0) * r, c + Vector2(-0.12, 0.32) * r, c + Vector2(0.48, -0.32) * r]), Color.WHITE, r * 0.25, true)
	else:
		draw_line(c + Vector2(-0.35, -0.35) * r, c + Vector2(0.35, 0.35) * r, Color.WHITE, r * 0.25, true)
		draw_line(c + Vector2(0.35, -0.35) * r, c + Vector2(-0.35, 0.35) * r, Color.WHITE, r * 0.25, true)


func _picture(p: Rect2) -> void:
	_org = _box.get_center()
	_scl = 0.8 + 0.2 * minf(_t / 0.2, 1.0) + 0.05 * sin(PI * minf(_t / 0.2, 1.0))
	var c := p.get_center()
	var s := p.size.x
	var loop := fmod(_t, 2.2) / 2.2
	match kind:
		"oneway":
			_road(c + Vector2(-s * 0.4, 0), c + Vector2(s * 0.4, 0), s * 0.3)
			for i in 3:
				var x := -s * 0.2 + i * s * 0.2
				draw_polyline(PackedVector2Array([c + Vector2(x - s * 0.05, -s * 0.08), c + Vector2(x + s * 0.05, 0), c + Vector2(x - s * 0.05, s * 0.08)]), Color(1, 1, 1, 0.85), s * 0.04, true)
			_van(c + Vector2(lerpf(-s * 0.32, s * 0.32, loop), 0), s * 0.28, 0.0)
			_tick(c + Vector2(s * 0.3, -s * 0.3), s * 0.1)
			_tick(c + Vector2(-s * 0.3, s * 0.32), s * 0.08, false)
		"bridge":
			_road(c + Vector2(0, -s * 0.42), c + Vector2(0, s * 0.42), s * 0.26)
			DrawUtil.rrect(self, Rect2(c + Vector2(-s * 0.42, -s * 0.15), Vector2(s * 0.84, s * 0.3)), Color("8a93a5"), s * 0.05)
			draw_line(c + Vector2(-s * 0.42, -s * 0.15), c + Vector2(s * 0.42, -s * 0.15), Color.WHITE, s * 0.02)
			draw_line(c + Vector2(-s * 0.42, s * 0.15), c + Vector2(s * 0.42, s * 0.15), Color.WHITE, s * 0.02)
			if loop < 0.5:
				_van(c + Vector2(lerpf(-s * 0.36, s * 0.36, loop * 2.0), 0), s * 0.26, 0.0)
			else:
				_van(c + Vector2(0, lerpf(-s * 0.36, s * 0.36, (loop - 0.5) * 2.0)), s * 0.26, PI / 2.0, Color.TRANSPARENT, 0.75)
		"gate":
			_road(c + Vector2(-s * 0.42, s * 0.1), c + Vector2(s * 0.42, s * 0.1), s * 0.3)
			var lift := clampf((loop - 0.3) / 0.15, 0.0, 1.0)
			var post := c + Vector2(s * 0.05, -s * 0.12)
			var ang := lerpf(PI / 2.0, -0.3, lift)
			for i in 4:
				var a := post + Vector2(cos(ang), sin(ang)) * s * 0.36 * i / 4.0
				var b := post + Vector2(cos(ang), sin(ang)) * s * 0.36 * (i + 1) / 4.0
				draw_line(a, b, col if i % 2 == 0 else Color.WHITE, s * 0.06, true)
			draw_circle(post, s * 0.05, Palette.VAN_CAB)
			_van(c + Vector2(lerpf(-s * 0.4, s * 0.4, loop), s * 0.1), s * 0.28, 0.0, col)
		"hub":
			draw_circle(c, s * 0.34, Color("c8cdd8"))
			draw_arc(c, s * 0.34, 0, TAU, 32, Color("8a93a5"), s * 0.03, true)
			var u := clampf((loop - 0.25) / 0.5, 0.0, 1.0)
			var a1 := PI * u
			var p1 := c + Vector2(cos(PI + a1), sin(PI + a1) * 0.6) * s * 0.2
			var p2 := c + Vector2(cos(a1), sin(a1) * 0.6) * s * 0.2
			DrawUtil.parcel(self, p1, Vector2(s * 0.26, s * 0.19), Palette.pkg("red"), false)
			DrawUtil.parcel(self, p2, Vector2(s * 0.26, s * 0.19), Palette.pkg("blue"), false)
		"pickup", "warehouse":
			# Boxes hop from the dock onto the top of the load.
			DrawUtil.rrect(self, Rect2(c + Vector2(-s * 0.44, s * 0.12), Vector2(s * 0.34, s * 0.2)), Color("3a3f4d"), s * 0.04)
			var stack_x := c.x + s * 0.24
			DrawUtil.parcel(self, Vector2(stack_x, c.y + s * 0.3), Vector2(s * 0.3, s * 0.13), Palette.pkg("purple"), false)
			DrawUtil.parcel(self, Vector2(stack_x, c.y + s * 0.17), Vector2(s * 0.3, s * 0.13), Palette.pkg("green"), false)
			var n := 1 if kind == "pickup" else mini(count, 3)
			for i in n:
				var u := clampf((loop - 0.15 - i * 0.2) / 0.35, 0.0, 1.0)
				var from := c + Vector2(-s * 0.27, s * 0.02)
				var to := Vector2(stack_x, c.y + s * 0.04 - i * s * 0.13)
				var at := from.lerp(to, u) + Vector2(0, -sin(PI * u) * s * 0.3)
				DrawUtil.parcel(self, at, Vector2(s * 0.3, s * 0.13), col, false)
			draw_string(UiTheme.font(), c + Vector2(s * 0.12, -s * 0.28), "TOP", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.12), Palette.ACCENT)
		"house", "houses", "house_done":
			var hc := c + Vector2(s * 0.14, s * 0.12)
			var wall := col.lerp(Color.WHITE, 0.72)
			DrawUtil.rrect(self, Rect2(hc + Vector2(-s * 0.18, -s * 0.2), Vector2(s * 0.36, s * 0.26)), wall, s * 0.03)
			draw_colored_polygon(PackedVector2Array([hc + Vector2(-s * 0.24, -s * 0.18), hc + Vector2(0, -s * 0.38), hc + Vector2(s * 0.24, -s * 0.18)]), col)
			if kind == "house_done":
				_tick(hc + Vector2(s * 0.16, -s * 0.34), s * 0.1)
			else:
				var u := clampf(loop / 0.5, 0.0, 1.0)
				var at := (c + Vector2(-s * 0.32, s * 0.2)).lerp(hc + Vector2(0, -s * 0.06), u) + Vector2(0, -sin(PI * u) * s * 0.25)
				if u < 1.0:
					DrawUtil.parcel(self, at, Vector2(s * 0.24, s * 0.17), col, false)
				else:
					_tick(hc + Vector2(s * 0.16, -s * 0.34), s * 0.1 * clampf((loop - 0.5) / 0.1, 0.0, 1.0))
				if kind == "houses":
					DrawUtil.count_badge(self, hc + Vector2(-s * 0.2, -s * 0.36), s * 0.6, count, col)
		"pickup_done":
			DrawUtil.rrect(self, Rect2(c + Vector2(-s * 0.3, s * 0.0), Vector2(s * 0.6, s * 0.24)), Color("3a3f4d"), s * 0.05)
			_tick(c + Vector2(0, -s * 0.16), s * 0.14)
		"exit":
			# The van pulls up, the gate swings open, and off it goes down the road out of the map.
			_road(c + Vector2(-s * 0.42, 0), c + Vector2(s * 0.5, 0), s * 0.3)
			var gx := s * 0.12
			var lift := clampf((loop - 0.3) / 0.2, 0.0, 1.0)
			ExitZone.draw_gate(self, c + Vector2(gx, 0), Vector2.RIGHT, s * 0.3, lift, s * 0.4)
			var vx := lerpf(-s * 0.36, -s * 0.06, clampf(loop / 0.3, 0.0, 1.0)) if loop < 0.5 else lerpf(-s * 0.06, s * 0.6, (loop - 0.5) / 0.5)
			_van(c + Vector2(vx, 0), s * 0.28, 0.0)
		"pitstop":
			DrawUtil.rrect(self, Rect2(c + Vector2(-s * 0.3, -s * 0.2), Vector2(s * 0.6, s * 0.4)), Color(Palette.ROAD, 0.9), s * 0.06)
			Icons.finish_flag(self, c + Vector2(s * 0.22, -s * 0.18), s * 0.32, _t)
			_van(c + Vector2(lerpf(-s * 0.5, 0.0, minf(loop * 1.6, 1.0)), 0), s * 0.3, 0.0)
		"gift", "key":
			var u := clampf(loop / 0.6, 0.0, 1.0)
			_road(c + Vector2(-s * 0.42, 0), c + Vector2(s * 0.42, 0), s * 0.3)
			if u < 0.55:
				Icons.draw(self, kind, c + Vector2(s * 0.1, 0), s * 0.3, Color("ff3d9a") if kind == "gift" else Icons.GOLD)
			else:
				Icons.star(self, c + Vector2(s * 0.1, -s * 0.2), s * 0.1 * (1.0 + (u - 0.55)), Palette.STAR_GOLD, _t)
			_van(c + Vector2(lerpf(-s * 0.4, s * 0.4, u), 0), s * 0.28, 0.0)
		"ice":
			_road(c + Vector2(-s * 0.42, 0), c + Vector2(s * 0.42, 0), s * 0.3)
			DrawUtil.rrect(self, Rect2(c + Vector2(-s * 0.18, -s * 0.15), Vector2(s * 0.36, s * 0.3)), Color("d8f0ff"), s * 0.06)
			var u := loop
			_van(c + Vector2(lerpf(-s * 0.4, s * 0.4, u), 0), s * 0.26, sin(u * 18.0) * 0.12 * (1.0 if absf(u - 0.5) < 0.15 else 0.0))
			_tick(c + Vector2(s * 0.3, -s * 0.3), s * 0.09)
		"locker":
			DrawUtil.rrect(self, Rect2(c + Vector2(0, -s * 0.22), Vector2(s * 0.34, s * 0.4)), Color("8f98aa"), s * 0.04)
			for i in 3:
				var cl: Color = [Palette.pkg("red"), Palette.pkg("blue"), Palette.pkg("yellow")][i]
				var u := clampf((loop - i * 0.28) / 0.25, 0.0, 1.0)
				if u > 0.0 and u < 1.0:
					var at := (c + Vector2(-s * 0.32, s * 0.15)).lerp(c + Vector2(s * 0.17, -s * 0.02), u) + Vector2(0, -sin(PI * u) * s * 0.2)
					DrawUtil.parcel(self, at, Vector2(s * 0.2, s * 0.15), cl, false)
			draw_string(UiTheme.font(), c + Vector2(s * 0.12, s * 0.04), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.22), Color.WHITE)
		"works":
			_road(c + Vector2(-s * 0.42, 0), c + Vector2(s * 0.42, 0), s * 0.3)
			var open := loop > 0.55
			draw_set_transform(_org + (c + Vector2(s * 0.05, 0)) * _scl, -1.2 if open else 0.0, Vector2.ONE * _scl)
			DrawUtil.rrect(self, Rect2(Vector2(-s * 0.2, -s * 0.04), Vector2(s * 0.4, s * 0.08)), Color("ff6b3d"), s * 0.02)
			draw_set_transform(_org, 0.0, Vector2.ONE * _scl)
			var dn := mini(int(loop * 4.0), 2)
			for i in 2:
				Icons.star(self, c + Vector2(-s * 0.3 + i * s * 0.15, -s * 0.3), s * 0.06, Palette.STAR_GOLD if i < dn else Color(Palette.TEXT, 0.15))
			if open:
				_van(c + Vector2(lerpf(-s * 0.3, s * 0.4, (loop - 0.55) / 0.45), 0), s * 0.26, 0.0)
		"wreck":
			_road(c + Vector2(-s * 0.42, 0), c + Vector2(s * 0.42, 0), s * 0.3)
			for i in 7:
				var a := i * 2.4
				DrawUtil.rrect(self, Rect2(c + Vector2(s * 0.1 + cos(a) * s * 0.14 - s * 0.05, sin(a * 1.3) * s * 0.09 - s * 0.04), Vector2(s * 0.1, s * 0.08)), Color("2b2f3a"), s * 0.02)
			_van(c + Vector2(lerpf(-s * 0.4, -s * 0.12, minf(loop * 2.0, 1.0)), 0), s * 0.28, 0.0)
			if loop > 0.5:
				_tick(c + Vector2(s * 0.1, -s * 0.26), s * 0.1, false)
