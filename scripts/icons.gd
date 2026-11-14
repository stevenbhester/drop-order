class_name Icons
extends RefCounted
## Little icons drawn in code, so buttons and chips need no image files.
## Icons.draw(canvas, "gas", centre, size, colour): `size` is the icon's full width.

const GOLD := Color("ffc53d")
const GOLD_DARK := Color("e0941a")
const GOLD_INK := Color("a8650a")


static func draw(ci: CanvasItem, icon: String, c: Vector2, s: float, col: Color) -> void:
	match icon:
		"gas":
			# A jerrycan: body, spout, handle and a white drop.
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.4, -0.5) * s, Vector2(0.3, 0.24) * s), col.darkened(0.15), s * 0.05)
			ci.draw_arc(c + Vector2(0.14, -0.26) * s, s * 0.15, PI, TAU, 14, col.darkened(0.15), s * 0.09, true)
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.4, -0.3) * s, Vector2(0.8, 0.8) * s), col, s * 0.14)
			var d := c + Vector2(0, 0.14) * s
			ci.draw_circle(d, s * 0.15, Color.WHITE)
			ci.draw_colored_polygon(PackedVector2Array([d + Vector2(-0.135, -0.06) * s, d + Vector2(0, -0.3) * s, d + Vector2(0.135, -0.06) * s]), Color.WHITE)
		"coin":
			ci.draw_circle(c + Vector2(0, s * 0.04), s * 0.5, GOLD_DARK)
			ci.draw_circle(c, s * 0.48, GOLD)
			ci.draw_arc(c, s * 0.36, 0, TAU, 28, Color(1, 1, 1, 0.55), s * 0.05, true)
			var f := UiTheme.font()
			var fs := int(s * 0.56)
			var w := f.get_string_size("D", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			ci.draw_string(f, c + Vector2(-w / 2.0, fs * 0.35), "D", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD_INK)
		"bulb":
			ci.draw_circle(c + Vector2(0, -0.1) * s, s * 0.3, col)
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.15, 0.16) * s, Vector2(0.3, 0.24) * s), col, s * 0.07)
			ci.draw_line(c + Vector2(-0.12, 0.3) * s, c + Vector2(0.12, 0.3) * s, Color(1, 1, 1, 0.7), s * 0.05)
			for a in [-2.2, -1.57, -0.94]:
				var dir := Vector2(cos(a), sin(a))
				ci.draw_line(c + Vector2(0, -0.1) * s + dir * s * 0.38, c + Vector2(0, -0.1) * s + dir * s * 0.5, col, s * 0.07, true)
		"undo":
			_arrow_arc(ci, c + Vector2(0.04, 0.04) * s, s * 0.32, 0.4 * PI, -1.0 * PI, s * 0.13, col)
		"retry":
			_arrow_arc(ci, c, s * 0.33, -0.3 * PI, 1.25 * PI, s * 0.13, col)
		"grid":
			for gx in 2:
				for gy in 2:
					DrawUtil.rrect(ci, Rect2(c + Vector2(-0.42 + gx * 0.46, -0.42 + gy * 0.46) * s, Vector2(0.38, 0.38) * s), col, s * 0.1)
		"star":
			star(ci, c, s * 0.5, col)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.28, -0.36) * s, c + Vector2(0.4, 0) * s, c + Vector2(-0.28, 0.36) * s]), col)
		"ad":
			# A little screen with a play triangle.
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.5, -0.36) * s, Vector2(1.0, 0.72) * s), col, s * 0.14)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.13, -0.2) * s, c + Vector2(0.24, 0) * s, c + Vector2(-0.13, 0.2) * s]), Color(0, 0, 0, 0.55))
		"plus":
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.42, -0.1) * s, Vector2(0.84, 0.2) * s), col, s * 0.1)
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.1, -0.42) * s, Vector2(0.2, 0.84) * s), col, s * 0.1)
		"next":
			var pts := PackedVector2Array([c + Vector2(-0.16, -0.34) * s, c + Vector2(0.2, 0) * s, c + Vector2(-0.16, 0.34) * s])
			ci.draw_polyline(pts, col, s * 0.16, true)
			for p in pts:
				ci.draw_circle(p, s * 0.08, col)
		"share":
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.36, -0.1) * s, Vector2(0.72, 0.56) * s), col, s * 0.1)
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.26, 0.0) * s, Vector2(0.52, 0.36) * s), Color(0, 0, 0, 0.0) if col.a == 0.0 else Color(1, 1, 1, 0.0), s * 0.06)
			ci.draw_line(c + Vector2(0, 0.12) * s, c + Vector2(0, -0.44) * s, col, s * 0.12, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.22, -0.26) * s, c + Vector2(0, -0.52) * s, c + Vector2(0.22, -0.26) * s]), col)
		"calendar":
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.42, -0.34) * s, Vector2(0.84, 0.76) * s), col, s * 0.12)
			ci.draw_rect(Rect2(c + Vector2(-0.42, -0.14) * s, Vector2(0.84, 0.06) * s), Color(1, 1, 1, 0.8))
			for sx in [-0.2, 0.2]:
				DrawUtil.rrect(ci, Rect2(c + Vector2(sx - 0.05, -0.46) * s, Vector2(0.1, 0.2) * s), col, s * 0.04)
			Icons.star(ci, c + Vector2(0, 0.16) * s, s * 0.16, Color(1, 1, 1, 0.9))
		"paint":
			# A paint roller.
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.42, -0.42) * s, Vector2(0.7, 0.28) * s), col, s * 0.1)
			ci.draw_polyline(PackedVector2Array([c + Vector2(0.28, -0.28) * s, c + Vector2(0.42, -0.28) * s, c + Vector2(0.42, 0.0) * s, c + Vector2(0.0, 0.06) * s, c + Vector2(0.0, 0.22) * s]), col, s * 0.08, true)
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.08, 0.2) * s, Vector2(0.16, 0.3) * s), col, s * 0.06)
		"gift":
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.42, -0.2) * s, Vector2(0.84, 0.66) * s), col, s * 0.12)
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.48, -0.34) * s, Vector2(0.96, 0.24) * s), col.lightened(0.15), s * 0.08)
			ci.draw_rect(Rect2(c + Vector2(-0.08, -0.34) * s, Vector2(0.16, 0.8) * s), Color.WHITE)
			for sx in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(sx * 0.16, -0.44) * s, s * 0.13, Color.WHITE)
		"dpad":
			# A little cross pad.
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.17, -0.48) * s, Vector2(0.34, 0.96) * s), col, s * 0.1)
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.48, -0.17) * s, Vector2(0.96, 0.34) * s), col, s * 0.1)
			ci.draw_circle(c, s * 0.09, Color(1, 1, 1, 0.55))
		"up", "down", "left", "right":
			# A chunky arrowhead.
			var d: Vector2 = {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}[icon]
			var side := Vector2(-d.y, d.x)
			var pts := PackedVector2Array([c + d * s * 0.36, c - d * s * 0.2 + side * s * 0.4, c - d * s * 0.2 - side * s * 0.4])
			ci.draw_colored_polygon(pts, col)
			ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), col, s * 0.1, true)
			for q in pts:
				ci.draw_circle(q, s * 0.05, col)
		"finger":
			# A pointing finger tracing a dotted path.
			for k in 3:
				ci.draw_circle(c + Vector2(-0.4 + k * 0.17, 0.36 - k * 0.06) * s, s * 0.05, col)
			DrawUtil.rrect(ci, Rect2(c + Vector2(0.02, -0.46) * s, Vector2(0.18, 0.5) * s), col, s * 0.09)
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.06, -0.06) * s, Vector2(0.48, 0.42) * s), col, s * 0.14)
		"gear":
			# A cog: teeth round a ring, a hole in the middle.
			for k in 8:
				var a := TAU * k / 8.0
				var d := Vector2(cos(a), sin(a))
				var side := Vector2(-d.y, d.x)
				ci.draw_colored_polygon(PackedVector2Array([c + d * s * 0.3 + side * s * 0.1, c + d * s * 0.48 + side * s * 0.075,
					c + d * s * 0.48 - side * s * 0.075, c + d * s * 0.3 - side * s * 0.1]), col)
			ci.draw_circle(c, s * 0.34, col)
			ci.draw_circle(c, s * 0.13, Color(1, 1, 1, 0.0) if col.a == 0.0 else Color(Palette.SURFACE, 1.0))
		"moon":
			ci.draw_circle(c, s * 0.38, col)
			ci.draw_circle(c + Vector2(0.18, -0.14) * s, s * 0.3, Color(Palette.CARD, 1.0))
		"turn":
			# A phone turning on its side.
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.22, -0.4) * s, Vector2(0.44, 0.8) * s), col, s * 0.08)
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.15, -0.31) * s, Vector2(0.3, 0.6) * s), Color(Palette.CARD, 1.0), s * 0.04)
			_arrow_arc(ci, c, s * 0.46, -0.85 * PI, -0.35 * PI, s * 0.07, col)
		"sound":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.42, -0.14) * s, c + Vector2(-0.2, -0.14) * s, c + Vector2(0.04, -0.36) * s,
				c + Vector2(0.04, 0.36) * s, c + Vector2(-0.2, 0.14) * s, c + Vector2(-0.42, 0.14) * s]), col)
			for k in 2:
				ci.draw_arc(c + Vector2(0.06, 0) * s, s * (0.18 + k * 0.16), -0.9, 0.9, 12, col, s * 0.07, true)
		"buzz":
			# A phone with buzz marks.
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.18, -0.36) * s, Vector2(0.36, 0.72) * s), col, s * 0.08)
			for sx in [-1.0, 1.0]:
				ci.draw_polyline(PackedVector2Array([c + Vector2(sx * 0.3, -0.2) * s, c + Vector2(sx * 0.4, -0.1) * s,
					c + Vector2(sx * 0.3, 0.0) * s, c + Vector2(sx * 0.4, 0.1) * s, c + Vector2(sx * 0.3, 0.2) * s]), col, s * 0.06, true)
		"steer":
			# A steering wheel.
			ci.draw_arc(c, s * 0.38, 0, TAU, 28, col, s * 0.1, true)
			ci.draw_circle(c, s * 0.1, col)
			for a in [PI * 0.5, PI * 1.17, PI * 1.83]:
				ci.draw_line(c, c + Vector2(cos(a), sin(a)) * s * 0.36, col, s * 0.08, true)
		"hand":
			# An open hand.
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.24, -0.02) * s, Vector2(0.48, 0.44) * s), col, s * 0.16)
			for k in 4:
				DrawUtil.rrect(ci, Rect2(c + Vector2(-0.24 + k * 0.125, -0.38 + absf(k - 1.5) * 0.06) * s, Vector2(0.1, 0.46) * s), col, s * 0.05)
			ci.draw_colored_polygon(_thumb(c, s, 1.0), col)
		"chute":
			# A tube with a parcel dropping out of the bottom.
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.2, -0.42) * s, c + Vector2(-0.2, 0.12) * s]), col, s * 0.08, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(0.2, -0.42) * s, c + Vector2(0.2, -0.02) * s, c + Vector2(0.34, 0.08) * s]), col, s * 0.08, true)
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.14, -0.34) * s, Vector2(0.28, 0.2) * s), col, s * 0.05)
			DrawUtil.rrect(ci, Rect2(c + Vector2(0.0, 0.16) * s, Vector2(0.3, 0.22) * s), col, s * 0.05)
		"side_auto":
			# A phone with the chute's spot to the side or along the top (dotted: either).
			var ph2 := Rect2(c + Vector2(-0.24, -0.42) * s, Vector2(0.48, 0.84) * s)
			DrawUtil.rrect(ci, ph2, col, s * 0.09)
			var in2 := ph2.grow(-s * 0.06)
			DrawUtil.rrect(ci, in2, Color(Palette.CARD, 1.0) if col.a > 0.0 else col, s * 0.05)
			for k in 4:
				DrawUtil.rrect(ci, Rect2(in2.position + Vector2(s * 0.04, s * 0.16 + k * s * 0.13), Vector2(s * 0.08, s * 0.08)), col, s * 0.02)
				if k < 3:
					DrawUtil.rrect(ci, Rect2(in2.position + Vector2(s * 0.16 + k * s * 0.07, s * 0.04), Vector2(s * 0.05, s * 0.07)), col, s * 0.02)
		"side_left", "side_right", "side_top", "side_bottom":
			# A phone with the chute's bar where it'd go.
			var ph := Rect2(c + Vector2(-0.24, -0.42) * s, Vector2(0.48, 0.84) * s)
			DrawUtil.rrect(ci, ph, col, s * 0.09)
			var inner := ph.grow(-s * 0.06)
			DrawUtil.rrect(ci, inner, Color(Palette.CARD, 1.0) if col.a > 0.0 else col, s * 0.05)
			var bar := inner.grow(-s * 0.04)
			match icon:
				"side_left": bar.size.x = s * 0.1
				"side_right": bar = Rect2(bar.end.x - s * 0.1, bar.position.y, s * 0.1, bar.size.y)
				"side_top": bar.size.y = s * 0.1
				"side_bottom": bar = Rect2(bar.position.x, bar.end.y - s * 0.1, bar.size.x, s * 0.1)
			DrawUtil.rrect(ci, bar, col, s * 0.03)
		"trail":
			# A van with three little packages trailing behind it.
			DrawUtil.rrect(ci, Rect2(c + Vector2(0.06, -0.15) * s, Vector2(0.38, 0.3) * s), col, s * 0.08)
			for k in 3:
				var r := s * (0.11 - k * 0.022)
				var x := 0.0 - k * 0.2 - 0.02
				DrawUtil.rrect(ci, Rect2(c + Vector2(x * s - r, -r * 0.8), Vector2(r * 2.0, r * 1.6)), col, r * 0.4)
		"eye":
			# An eye.
			var lid := PackedVector2Array()
			for k in 24:
				var a := TAU * k / 24.0
				lid.append(c + Vector2(cos(a) * 0.44, sin(a) * 0.26 * (1.0 - 0.35 * absf(cos(a)))) * s)
			ci.draw_colored_polygon(lid, col)
			ci.draw_circle(c, s * 0.16, Color(Palette.CARD, 1.0) if col.a > 0.0 else col)
			ci.draw_circle(c, s * 0.08, col)
		"lock":
			# A padlock.
			ci.draw_arc(c + Vector2(0, -0.12) * s, s * 0.2, PI, TAU, 14, col, s * 0.09, true)
			ci.draw_line(c + Vector2(-0.2, -0.12) * s, c + Vector2(-0.2, 0.0) * s, col, s * 0.09)
			ci.draw_line(c + Vector2(0.2, -0.12) * s, c + Vector2(0.2, 0.0) * s, col, s * 0.09)
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.32, -0.04) * s, Vector2(0.64, 0.48) * s), col, s * 0.1)
			ci.draw_circle(c + Vector2(0, 0.17) * s, s * 0.06, Color(Palette.CARD, 1.0) if col.a > 0.0 else col)
		"key":
			# A key lying sideways: a round bow with a hole, the shaft, two teeth.
			var bow := c + Vector2(-0.26, 0) * s
			ci.draw_circle(bow + Vector2(0, s * 0.03), s * 0.24, col.darkened(0.25))
			ci.draw_circle(bow, s * 0.24, col)
			ci.draw_circle(bow, s * 0.1, col.darkened(0.45))
			ci.draw_rect(Rect2(c + Vector2(-0.06, -0.06) * s, Vector2(0.5, 0.12) * s), col)
			ci.draw_rect(Rect2(c + Vector2(0.28, 0.04) * s, Vector2(0.08, 0.14) * s), col)
			ci.draw_rect(Rect2(c + Vector2(0.38, 0.04) * s, Vector2(0.06, 0.1) * s), col)
			ci.draw_circle(bow + Vector2(-0.08, -0.1) * s, s * 0.05, Color(1, 1, 1, 0.5 * col.a))
		"ghost":
			# A little ghost: round head, wavy hem, two eyes.
			var body := PackedVector2Array()
			for k in 13:
				var a := PI + PI * k / 12.0
				body.append(c + Vector2(cos(a) * 0.36, -0.06 + sin(a) * 0.36) * s)
			for k in 7:
				var x := 0.36 - 0.72 * k / 6.0
				body.append(c + Vector2(x, 0.42 - (0.1 if k % 2 == 1 else 0.0)) * s)
			ci.draw_colored_polygon(body, col)
			var hole := Color(Palette.CARD, 1.0) if col.a > 0.0 else col
			ci.draw_circle(c + Vector2(-0.13, -0.08) * s, s * 0.07, hole)
			ci.draw_circle(c + Vector2(0.13, -0.08) * s, s * 0.07, hole)
		"peek":
			# A thought bubble.
			DrawUtil.rrect(ci, Rect2(c + Vector2(-0.4, -0.36) * s, Vector2(0.8, 0.5) * s), col, s * 0.22)
			ci.draw_circle(c + Vector2(-0.16, 0.24) * s, s * 0.08, col)
			ci.draw_circle(c + Vector2(-0.28, 0.38) * s, s * 0.05, col)
			for k in 3:
				ci.draw_circle(c + Vector2(-0.18 + k * 0.18, -0.11) * s, s * 0.055, Color(Palette.CARD, 1.0) if col.a > 0.0 else col)
		"x":
			for sx in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(-0.3 * sx, -0.3) * s, c + Vector2(0.3 * sx, 0.3) * s, col, s * 0.15, true)
				ci.draw_circle(c + Vector2(-0.3 * sx, -0.3) * s, s * 0.075, col)
				ci.draw_circle(c + Vector2(0.3 * sx, 0.3) * s, s * 0.075, col)


static func _thumb(c: Vector2, s: float, side: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var a := TAU * k / 10.0
		pts.append(c + (Vector2(0.3 * side, 0.12) + Vector2(cos(a) * 0.08, sin(a) * 0.17).rotated(-0.7 * side)) * s)
	return pts


## A checkered finish flag on a pole, waving: `s` is its height.
static func finish_flag(ci: CanvasItem, c: Vector2, s: float, t := 0.0) -> void:
	var base := c + Vector2(-s * 0.28, s * 0.5)
	var top := base + Vector2(0, -s)
	ci.draw_line(base, top, Color("3b3346"), s * 0.07, true)
	ci.draw_circle(top, s * 0.06, Color("ffc53d"))
	var cols := 4
	var rows := 3
	var w := s * 0.62
	var h := s * 0.42
	for i in cols:
		for j in rows:
			var u0 := float(i) / cols
			var u1 := float(i + 1) / cols
			var wave := func(u: float) -> float: return sin(t * 6.0 + u * 5.0) * s * 0.05 * u
			var x0 := top.x + u0 * w
			var x1 := top.x + u1 * w
			var y0 := top.y + s * 0.06 + float(j) / rows * h
			var y1 := top.y + s * 0.06 + float(j + 1) / rows * h
			var col := Color("1d1f26") if (i + j) % 2 == 0 else Color.WHITE
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, y0 + wave.call(u0)), Vector2(x1, y0 + wave.call(u1)),
				Vector2(x1, y1 + wave.call(u1)), Vector2(x0, y1 + wave.call(u0))]), col)


## A five-pointed star with softened points.
static func star(ci: CanvasItem, c: Vector2, r: float, col: Color, spin := 0.0) -> void:
	if r < 1.5:
		return
	var pts := star_points(c, r * 0.94, r * 0.46, spin)
	ci.draw_colored_polygon(pts, col)
	var loop := PackedVector2Array(pts)
	loop.append(pts[0])
	ci.draw_polyline(loop, col, r * 0.14, true)
	for p in pts:
		ci.draw_circle(p, r * 0.07, col)


## A star from a level that's been redesigned since: the gold outline, only a smaller star filled inside
## it, breathing.
static func star_stale(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	var outline := star_points(c, r, r * 0.45)
	outline.append(outline[0])
	ci.draw_polyline(outline, Palette.STAR_GOLD, maxf(1.5, r * 0.14), true)
	var k := 0.5 + 0.5 * sin(t * 3.0)
	ci.draw_colored_polygon(star_points(c, r * 0.5, r * 0.22), Color(Palette.STAR_GOLD, 0.45 + 0.35 * k))


static func star_points(c: Vector2, outer: float, inner: float, spin := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := spin - PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (outer if i % 2 == 0 else inner))
	return pts


## An arc from angle a0 to a1 with an arrowhead at a1.
static func _arrow_arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, w: float, col: Color) -> void:
	ci.draw_arc(c, r, a0, a1, 28, col, w, true)
	ci.draw_circle(c + Vector2(cos(a0), sin(a0)) * r, w * 0.5, col)
	var end := c + Vector2(cos(a1), sin(a1)) * r
	var fwd := Vector2(-sin(a1), cos(a1)) * signf(a1 - a0)
	var side := Vector2(cos(a1), sin(a1))
	ci.draw_colored_polygon(PackedVector2Array([end + fwd * w * 1.7, end + side * w * 1.45 - fwd * w * 0.2, end - side * w * 1.45 - fwd * w * 0.2]), col)
