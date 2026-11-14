class_name DrawUtil
extends RefCounted
## Small drawing helpers shared by the placeholder-art nodes.

static var _sb: StyleBoxFlat


static func rrect(ci: CanvasItem, r: Rect2, col: Color, radius: float) -> void:
	if _sb == null:
		_sb = StyleBoxFlat.new()
		_sb.anti_aliasing = true
		_sb.anti_aliasing_size = 1.2
	_sb.bg_color = col
	var rad := int(minf(radius, minf(r.size.x, r.size.y) * 0.5))
	_sb.set_corner_radius_all(rad)
	_sb.corner_detail = 10
	ci.draw_style_box(_sb, r)


## How many a stop wants (or a warehouse has left): a chunky white pill with a rim in the stop's colour,
## centred on `c`, sized for a building `s` tall. Big enough to read at a glance on a phone.
static func count_badge(ci: CanvasItem, c: Vector2, s: float, n: int, col: Color, prefix := "×") -> void:
	var f := UiTheme.font()
	var txt := "%s%d" % [prefix, n]
	if prefix == "+":
		# A pickup's "+N": green and white, so it can't be mistaken for a house's "×N".
		var fs2 := int(s * 0.27)
		var tw2 := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var h2 := s * 0.36
		var r2 := Rect2(c - Vector2(maxf(h2, tw2 + s * 0.14), h2) / 2.0, Vector2(maxf(h2, tw2 + s * 0.14), h2))
		rrect(ci, Rect2(r2.position + Vector2(0, s * 0.03), r2.size).grow(s * 0.025), Color(0, 0, 0, 0.18), h2)
		rrect(ci, r2.grow(s * 0.025), Color.WHITE, h2)
		rrect(ci, r2, Palette.GOOD, h2)
		ci.draw_string(f, c + Vector2(-tw2 / 2.0, fs2 * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color.WHITE)
		return
	var fs := int(s * 0.27)
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var h := s * 0.36
	var w := maxf(h, tw + s * 0.14)
	var r := Rect2(c - Vector2(w, h) / 2.0, Vector2(w, h))
	rrect(ci, Rect2(r.position + Vector2(0, s * 0.03), r.size).grow(s * 0.025), Color(0, 0, 0, 0.18), h)
	rrect(ci, r.grow(s * 0.025), col.darkened(0.1), h)
	rrect(ci, r, Color.WHITE, h)
	ci.draw_string(f, c + Vector2(-tw / 2.0, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.TEXT)


## A cardboard-ish package in its colour, centred on `c` (square, `s` across).
static func package(ci: CanvasItem, c: Vector2, s: float, col: Color, shadow := true) -> void:
	parcel(ci, c, Vector2(s, s), col, shadow)


## Colorblind mode ("aka Paul mode"): package marks drawn bold instead of faint. Progress sets it.
static var bold_marks := false


## A gift's bow: two loops and a knot, `u` the box's size.
static func _bow(ci: CanvasItem, top: Vector2, u: float, col: Color) -> void:
	for sx in [-1.0, 1.0]:
		var loop := PackedVector2Array()
		for i in 12:
			var a := TAU * i / 12.0
			loop.append(top + Vector2(sx * u * 0.17, -u * 0.06) + Vector2(cos(a) * u * 0.15, sin(a) * u * 0.09).rotated(sx * 0.35))
		ci.draw_colored_polygon(loop, col)
	ci.draw_circle(top, u * 0.06, col)


## A package class's mark (see Palette.KINDS) centred on `fc`, `k` its size: in `ink`, with cut-outs in `bg`.
## `bold` fills shapes in (the caution triangle, the flame's core) for colorblind mode and signs.
static func mark(ci: CanvasItem, kind: String, fc: Vector2, k: float, ink: Color, bg: Color, bold: bool) -> void:
	match kind:
		"gift":
			# A little wrapped box with its bow (for signs; on a package the ribbon wraps the box itself).
			var bx := Rect2(fc + Vector2(-k * 0.3, -k * 0.1), Vector2(k * 0.6, k * 0.42))
			rrect(ci, bx, ink, k * 0.06)
			ci.draw_rect(Rect2(fc.x - k * 0.06, bx.position.y, k * 0.12, bx.size.y), bg)
			ci.draw_rect(Rect2(bx.position.x, bx.get_center().y - k * 0.05, bx.size.x, k * 0.1), bg)
			_bow(ci, Vector2(fc.x, bx.position.y - k * 0.02), k * 1.1, ink)
		"biohazard":
			# Three hooked lobes round a dot.
			var rr := k * 0.3
			for i in 3:
				var a := -PI / 2.0 + TAU * i / 3.0
				ci.draw_circle(fc + Vector2(cos(a), sin(a)) * rr * 0.5, rr * 0.44, ink)
			for i in 3:
				var a := -PI / 2.0 + TAU * i / 3.0
				ci.draw_circle(fc + Vector2(cos(a), sin(a)) * rr * 0.68, rr * 0.27, bg)
			ci.draw_circle(fc, rr * 0.24, bg)
			ci.draw_circle(fc, rr * 0.12, ink)
		"caution":
			# A warning triangle with a "!" (filled when bold).
			var h := k * 0.5
			var tri := PackedVector2Array([fc + Vector2(0, -h * 0.55), fc + Vector2(h * 0.6, h * 0.45), fc + Vector2(-h * 0.6, h * 0.45)])
			if bold:
				ci.draw_colored_polygon(tri, ink)
				var closed := PackedVector2Array(tri)
				closed.append(tri[0])
				ci.draw_polyline(closed, ink, k * 0.06, true)
				ci.draw_line(fc + Vector2(0, -h * 0.2), fc + Vector2(0, h * 0.1), bg, k * 0.07, true)
				ci.draw_circle(fc + Vector2(0, h * 0.27), k * 0.04, bg)
			else:
				tri.append(tri[0])
				ci.draw_polyline(tri, ink, k * 0.065, true)
				ci.draw_line(fc + Vector2(0, -h * 0.18), fc + Vector2(0, h * 0.1), ink, k * 0.065, true)
				ci.draw_circle(fc + Vector2(0, h * 0.27), k * 0.036, ink)
		"mystery":
			var f := UiTheme.font()
			var px := int(k * (0.62 if bold else 0.55))
			var w := f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			ci.draw_string(f, fc + Vector2(-w / 2.0, px * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)
		"organic":
			# A leaf (with its vein when bold).
			var leaf := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				leaf.append(fc + Vector2(cos(a) * k * 0.26, sin(a) * k * 0.14).rotated(-0.6))
			ci.draw_colored_polygon(leaf, ink)
			if bold:
				ci.draw_line(fc + Vector2(-k * 0.2, k * 0.13), fc + Vector2(k * 0.16, -k * 0.1), bg, k * 0.035, true)
		"hot":
			# A little flame (with a core when bold).
			var fl := PackedVector2Array([fc + Vector2(0, -k * 0.3), fc + Vector2(k * 0.14, -k * 0.06), fc + Vector2(k * 0.18, k * 0.12),
				fc + Vector2(0, k * 0.24), fc + Vector2(-k * 0.18, k * 0.12), fc + Vector2(-k * 0.12, -k * 0.04), fc + Vector2(-k * 0.04, k * 0.02)])
			ci.draw_colored_polygon(fl, ink)
			if bold:
				ci.draw_circle(fc + Vector2(0, k * 0.12), k * 0.07, bg)


## A package `size` across (longer than wide in the chute), in its colour, with its class's mark:
## red is a gift (ribbon and bow), yellow biohazard, blue caution, purple a mystery, green organic, orange hot.
static func parcel(ci: CanvasItem, c: Vector2, size: Vector2, col: Color, shadow := true) -> void:
	var r := Rect2(c - size * 0.5, size)
	var m := minf(size.x, size.y)
	var rad := m * 0.2
	var shape := Looks.pkg
	if shape == "pkg_hatbox" or shape == "pkg_capsule":
		rad = m * 0.5
	elif shape == "pkg_crate":
		rad = m * 0.06
	if shadow:
		rrect(ci, Rect2(r.position + Vector2(0, m * 0.09), r.size), Color(0, 0, 0, 0.18), rad)
	rrect(ci, r, col.darkened(0.12), rad)
	rrect(ci, Rect2(r.position, Vector2(size.x, size.y - m * 0.1)), col, rad)
	var kind := Palette.kind_of(col)
	var face := Rect2(r.position, Vector2(size.x, size.y - m * 0.1))
	var fc := face.get_center()
	# Package shapes (a Looks cosmetic): the same colour and mark, a different container.
	match shape:
		"pkg_hatbox":
			# A round hatbox: a lid band round the top and a cord.
			rrect(ci, Rect2(face.position, Vector2(face.size.x, face.size.y * 0.3)), Color(col.lightened(0.18), col.a), rad)
			ci.draw_arc(fc + Vector2(0, -face.size.y * 0.42), m * 0.16, PI * 1.1, PI * 1.9, 10, Color(col.darkened(0.4), col.a), maxf(1.0, m * 0.04), true)
		"pkg_crate":
			# A wooden crate stained its colour: planks, a frame and a cross brace.
			for k in range(1, 3):
				var y := face.position.y + face.size.y * k / 3.0
				ci.draw_line(Vector2(face.position.x, y), Vector2(face.end.x, y), Color(col.darkened(0.3), col.a * 0.6), maxf(1.0, m * 0.03))
			ci.draw_rect(face.grow(-m * 0.03), Color(col.darkened(0.35), col.a * 0.8), false, maxf(1.0, m * 0.06))
			ci.draw_line(face.position + Vector2(m * 0.06, m * 0.06), face.end - Vector2(m * 0.06, m * 0.06), Color(col.darkened(0.25), col.a * 0.55), maxf(1.0, m * 0.07))
		"pkg_capsule":
			# A capsule: two halves, the far one paler, a seam between.
			var half := Rect2(Vector2(fc.x, face.position.y), Vector2(face.size.x / 2.0, face.size.y))
			rrect(ci, half, Color(col.lightened(0.4), col.a), rad)
			ci.draw_rect(Rect2(half.position, Vector2(half.size.x * 0.5, half.size.y)), Color(col.lightened(0.4), col.a))
			ci.draw_line(Vector2(fc.x, face.position.y), Vector2(fc.x, face.end.y), Color(col.darkened(0.3), col.a), maxf(1.0, m * 0.04))
	# The class mark is just flavour, not a rule: a small, faint stamp in a deeper shade of the box's own
	# colour (the gift's ribbon a paler one), so the colour is still what you read. Colorblind mode makes it
	# bold and white (dark on the yellow), big enough to tell the boxes apart by mark alone.
	var bold := bold_marks
	if (m < 16.0 and not (bold and m >= 9.0)) or kind == "":
		# Too small for a mark (or an odd colour): just tape.
		ci.draw_rect(Rect2(c.x - size.x * 0.09, r.position.y + m * 0.02, size.x * 0.18, size.y - m * 0.14), Color(col.lerp(Color.WHITE, 0.45), col.a))
		return
	var ink := Color(col.darkened(0.32), col.a * 0.42)
	if bold:
		ink = Color(0.12, 0.1, 0.12, col.a * 0.9) if kind == "biohazard" else Color(1, 1, 1, col.a * 0.97)
	if kind == "gift":
		# A ribbon both ways and a bow.
		var rib := Color(1, 1, 1, col.a * 0.92) if bold else Color(col.lightened(0.32), col.a * 0.6)
		var rw := m * (0.15 if bold else 0.09)
		ci.draw_rect(Rect2(fc.x - rw / 2.0, face.position.y, rw, face.size.y), rib)
		ci.draw_rect(Rect2(face.position.x, fc.y - rw / 2.0, face.size.x, rw), rib)
		_bow(ci, Vector2(fc.x, face.position.y + m * 0.03), m * (1.0 if bold else 0.6), rib)
	else:
		mark(ci, kind, fc, m * (1.0 if bold else 0.7), ink, col, bold)
	# Shine on the corner.
	rrect(ci, Rect2(r.position + Vector2(m * 0.1, m * 0.08), Vector2(m * 0.14, m * 0.08)), Color(1, 1, 1, 0.4 * col.a), m * 0.04)
