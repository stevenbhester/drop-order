class_name Shop
extends Node2D
## A pickup: a loading dock with parcels waiting that the van collects (onto the top of its stack) as it
## drives past. A warehouse (stock > 1) holds several, with a green "+N" for how many it'll hand over; they
## all come aboard as the van passes. Pickups look nothing like the places that want packages: a plain dark
## dock inside a chunky dashed outline in its parcels' colour, and big bouncing parcels out front, one for
## each it gives. Once emptied it shows a tick. Origin at the building's base, like House.

var color := Color.RED
var size := 180.0
var base_pos := Vector2.ZERO
## Parcels it starts with, and how many are still waiting.
var stock := 1
var left := 1:
	set(v):
		left = v
		queue_redraw()
var parcel_t := 1.0:              # 1 = parcel waiting, 0 = collected
	set(v):
		parcel_t = v
		queue_redraw()
## The route being planned will collect these: they hold still and fade.
var planned := false:
	set(v):
		if v != planned:
			planned = v
			queue_redraw()
var _t := randf() * TAU
## Draw its own loading-zone frame (off: something else draws the ground under it).
var zone := true
var _tw: Tween


func _process(delta: float) -> void:
	if parcel_t > 0.0:
		_t += delta
		queue_redraw()


func parcel_pos() -> Vector2:
	return base_pos + Vector2(0, -size * 0.5)


func collect() -> void:
	_pop()
	left = maxi(left - 1, 0)
	if left == 0:
		var tw := create_tween()
		tw.tween_property(self, "parcel_t", 0.0, 0.12)


func restore() -> void:
	_pop()
	left = mini(left + 1, stock)
	if parcel_t < 1.0:
		var tw := create_tween()
		tw.tween_property(self, "parcel_t", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pop() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2(1.2, 0.8), 0.06)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var s := size
	var empty := parcel_t <= 0.0
	var w := s * 0.74
	var h := s * 0.2
	# The loading zone: a chunky dashed outline in its parcels' colour (only pickups have one).
	if zone:
		var zr := Rect2(-s * 0.44, -s * 0.74, s * 0.88, s * 0.82)
		var rim := color if not empty else Color(0.6, 0.6, 0.62)
		DrawUtil.rrect(self, zr.grow(s * 0.045), Color(rim, 0.95), s * 0.16)
		DrawUtil.rrect(self, zr, Color(0.97, 0.96, 0.93, 0.92) if not empty else Color(0.92, 0.92, 0.9, 0.9), s * 0.12)
		var dash := s * 0.09
		var x := zr.position.x + s * 0.06
		while x < zr.end.x - s * 0.06:
			draw_line(Vector2(x, zr.position.y - s * 0.022), Vector2(minf(x + dash * 0.5, zr.end.x - s * 0.06), zr.position.y - s * 0.022), Color.WHITE, s * 0.03)
			draw_line(Vector2(x, zr.end.y + s * 0.022), Vector2(minf(x + dash * 0.5, zr.end.x - s * 0.06), zr.end.y + s * 0.022), Color.WHITE, s * 0.03)
			x += dash
	# The dock itself: plain and dark, so the parcels stand out.
	var dock := Rect2(-w / 2, -h - s * 0.02, w, h)
	DrawUtil.rrect(self, Rect2(dock.position + Vector2(0, s * 0.03), dock.size), Color(0, 0, 0, 0.18), s * 0.05)
	DrawUtil.rrect(self, dock, Color("3a3f4d"), s * 0.05)
	for k in 2:
		draw_line(Vector2(-w * 0.32, dock.position.y + s * 0.06 + k * s * 0.06), Vector2(w * 0.32, dock.position.y + s * 0.06 + k * s * 0.06), Color(1, 1, 1, 0.12), s * 0.02)
	if empty:
		# Collected: empty, with a tick.
		var c := Vector2(0, -h * 0.5 - s * 0.02)
		draw_circle(c, s * 0.15, Palette.CHECK)
		draw_polyline(PackedVector2Array([c + Vector2(-0.065, 0.0) * s, c + Vector2(-0.02, 0.045) * s, c + Vector2(0.07, -0.045) * s]), Color.WHITE, s * 0.035, true)
		return
	# Its parcels, big and bouncing, out front: one for each it'll hand over (up to five shown). While the
	# route being planned is going to take them, they hold still and fade, like a ghost tick.
	var n := clampi(left, 1, 5)
	var rows := [n] if n <= 2 else [mini(n, 3), n - mini(n, 3)]
	var ph := s * (0.44 if n == 1 else (0.34 if n == 2 else 0.25))
	var pw := ph * StackView.ASPECT
	var a := 0.45 if planned else 1.0
	var k := 0
	for r in rows.size():
		var cnt: int = rows[r]
		for i in cnt:
			var hop := 0.0 if planned else absf(sin(_t * 4.0 + k * 1.7))
			var cx := (i - (cnt - 1) / 2.0) * (pw * 0.86) + (r * pw * 0.2 if rows.size() > 1 and cnt < rows[0] else 0.0)
			var cy := -h * 0.55 - ph * 0.5 - r * ph * 0.82 - hop * s * 0.07
			var sq := 1.0 - 0.18 * (1.0 - hop) * (1.0 - hop) if not planned else 1.0
			draw_set_transform(Vector2(cx, cy + ph * 0.5 * (1.0 - sq)), 0.0, Vector2(1.0 / sq, sq) * parcel_t)
			DrawUtil.parcel(self, Vector2.ZERO, Vector2(pw, ph), Color(color, a), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			k += 1
	# How many it gives: a green "+N".
	if left > 1:
		DrawUtil.count_badge(self, Vector2(s * 0.3, -s * 0.66), s, left, Palette.GOOD, "+")
	if planned:
		var gc := Vector2(-s * 0.28, -s * 0.62)
		draw_circle(gc, s * 0.12, Color(1, 1, 1, 0.85))
		draw_polyline(PackedVector2Array([gc + Vector2(-0.05, 0.0) * s, gc + Vector2(-0.015, 0.035) * s, gc + Vector2(0.055, -0.035) * s]), Color(Palette.CHECK, 0.9), s * 0.03, true)
