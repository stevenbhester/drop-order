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


## A cardboard-ish package in its colour, centred on `c` (square, `s` across).
static func package(ci: CanvasItem, c: Vector2, s: float, col: Color, shadow := true) -> void:
	parcel(ci, c, Vector2(s, s), col, shadow)


## A package `size` across (wider than tall in the chute), in its colour, with its class's mark:
## red is a gift (ribbon and bow), yellow biohazard, blue caution, purple a mystery, green organic, orange hot.
static func parcel(ci: CanvasItem, c: Vector2, size: Vector2, col: Color, shadow := true) -> void:
	var r := Rect2(c - size * 0.5, size)
	var m := minf(size.x, size.y)
	var rad := m * 0.2
	if shadow:
		rrect(ci, Rect2(r.position + Vector2(0, m * 0.09), r.size), Color(0, 0, 0, 0.18), rad)
	rrect(ci, r, col.darkened(0.12), rad)
	rrect(ci, Rect2(r.position, Vector2(size.x, size.y - m * 0.1)), col, rad)
	var kind := Palette.kind_of(col)
	var face := Rect2(r.position, Vector2(size.x, size.y - m * 0.1))
	var fc := face.get_center()
	var ink := Color(1, 1, 1, col.a * 0.95)
	if m < 16.0 or kind == "":
		# Too small for a mark (or an odd colour): just tape.
		ci.draw_rect(Rect2(c.x - size.x * 0.09, r.position.y + m * 0.02, size.x * 0.18, size.y - m * 0.14), Color(col.lerp(Color.WHITE, 0.45), col.a))
		return
	match kind:
		"gift":
			# Ribbon both ways, and a bow on top.
			var rib := Color(1, 1, 1, col.a * 0.9)
			ci.draw_rect(Rect2(fc.x - m * 0.08, face.position.y, m * 0.16, face.size.y), rib)
			ci.draw_rect(Rect2(face.position.x, fc.y - m * 0.08, face.size.x, m * 0.16), rib)
			var top := Vector2(fc.x, face.position.y + m * 0.04)
			for sx in [-1.0, 1.0]:
				var loop := PackedVector2Array()
				for k in 12:
					var a := TAU * k / 12.0
					loop.append(top + Vector2(sx * m * 0.17, -m * 0.06) + Vector2(cos(a) * m * 0.15, sin(a) * m * 0.09).rotated(sx * 0.35))
				ci.draw_colored_polygon(loop, rib)
			ci.draw_circle(top, m * 0.07, Color(col.lightened(0.25), col.a))
		"biohazard":
			# A black trefoil in a ring.
			# Three hooked lobes (each a disc with a bite out of its outer side), a gap round the middle and a dot.
			var k := Color(0.12, 0.1, 0.12, col.a * 0.88)
			var bg := Color(col, col.a)
			var rr := m * 0.32
			for i in 3:
				var a := -PI / 2.0 + TAU * i / 3.0
				ci.draw_circle(fc + Vector2(cos(a), sin(a)) * rr * 0.5, rr * 0.44, k)
			for i in 3:
				var a := -PI / 2.0 + TAU * i / 3.0
				ci.draw_circle(fc + Vector2(cos(a), sin(a)) * rr * 0.68, rr * 0.27, bg)
			ci.draw_circle(fc, rr * 0.24, bg)
			ci.draw_circle(fc, rr * 0.13, k)
		"caution":
			# A warning triangle with a "!".
			var h := m * 0.56
			var tri := PackedVector2Array([fc + Vector2(0, -h * 0.55), fc + Vector2(h * 0.58, h * 0.45), fc + Vector2(-h * 0.58, h * 0.45)])
			ci.draw_colored_polygon(tri, ink)
			ci.draw_line(fc + Vector2(0, -h * 0.22), fc + Vector2(0, h * 0.12), Color(col.darkened(0.2), col.a), m * 0.07, true)
			ci.draw_circle(fc + Vector2(0, h * 0.28), m * 0.04, Color(col.darkened(0.2), col.a))
		"mystery":
			# A big "?".
			var f := UiTheme.font()
			var px := int(m * 0.62)
			var w := f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			ci.draw_string(f, fc + Vector2(-w / 2.0, px * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)
		"organic":
			# A leaf with its vein.
			var leaf := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				leaf.append(fc + Vector2(cos(a) * m * 0.26, sin(a) * m * 0.14).rotated(-0.6))
			ci.draw_colored_polygon(leaf, ink)
			ci.draw_line(fc + Vector2(-m * 0.2, m * 0.13), fc + Vector2(m * 0.16, -m * 0.1), Color(col.darkened(0.15), col.a), m * 0.035, true)
		"hot":
			# A little flame.
			var fl := PackedVector2Array([fc + Vector2(0, -m * 0.3), fc + Vector2(m * 0.14, -m * 0.06), fc + Vector2(m * 0.18, m * 0.12),
				fc + Vector2(0, m * 0.24), fc + Vector2(-m * 0.18, m * 0.12), fc + Vector2(-m * 0.12, -m * 0.04), fc + Vector2(-m * 0.04, m * 0.02)])
			ci.draw_colored_polygon(fl, ink)
			ci.draw_circle(fc + Vector2(0, m * 0.12), m * 0.07, Color(col, col.a))
	# Shine on the corner.
	rrect(ci, Rect2(r.position + Vector2(m * 0.1, m * 0.08), Vector2(m * 0.14, m * 0.08)), Color(1, 1, 1, 0.4 * col.a), m * 0.04)
