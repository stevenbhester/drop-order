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


## A cardboard-ish package in its colour, centred on `c`.
static func package(ci: CanvasItem, c: Vector2, s: float, col: Color, shadow := true) -> void:
	var r := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
	if shadow:
		rrect(ci, Rect2(r.position + Vector2(0, s * 0.09), r.size), Color(0, 0, 0, 0.18), s * 0.2)
	rrect(ci, r, col.darkened(0.12), s * 0.2)
	rrect(ci, Rect2(r.position, Vector2(s, s * 0.9)), col, s * 0.2)
	# tape
	ci.draw_rect(Rect2(c.x - s * 0.09, r.position.y + s * 0.02, s * 0.18, s * 0.86), col.lerp(Color.WHITE, 0.45))
	# shine
	rrect(ci, Rect2(r.position + Vector2(s * 0.12, s * 0.1), Vector2(s * 0.16, s * 0.1)), Color(1, 1, 1, 0.45), s * 0.05)
