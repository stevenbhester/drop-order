class_name PackageBox
extends Node2D
## A single package sprite (the chute's load and flying deliveries): `size` tall, `aspect` times as wide.
## `fogged`: lost in the fog (a side road's twist): a plain grey crate with a "?".
## `plan`: only a preview, while a route is planned (the real load is untouched until it's driven):
## "gone", the plan delivers it (washed out, with the houses' outlined ghost tick); "new", the plan picks it
## up (a see-through outline with a "+"); "park", the plan leaves it in a parking locker (washed out, a "P").
## Solid parcels and solid green ticks are the real thing.

var color := Color.WHITE
var size := 64.0
var aspect := 1.0
var fogged := false
var plan := "":
	set(v):
		if plan != v:
			plan = v
			queue_redraw()


func _draw() -> void:
	var sz := Vector2(size * aspect, size)
	if plan == "new":
		# Not aboard yet: a see-through outline of it, and a "+".
		var m := minf(sz.x, sz.y)
		var r := Rect2(-sz / 2.0, sz)
		DrawUtil.rrect(self, r, Color(color, 0.85), m * 0.2)
		DrawUtil.rrect(self, r.grow(-m * 0.09), Color(color.lerp(Color.WHITE, 0.72), 0.85), m * 0.13)
		_badge(sz, "+")
		return
	if fogged:
		var m := minf(sz.x, sz.y)
		var r := Rect2(-sz / 2.0, sz)
		DrawUtil.rrect(self, Rect2(r.position + Vector2(0, m * 0.09), r.size), Color(0, 0, 0, 0.14), m * 0.2)
		DrawUtil.rrect(self, r, Color("a9a3b5"), m * 0.2)
		DrawUtil.rrect(self, Rect2(r.position, Vector2(sz.x, sz.y - m * 0.1)), Color("c4bfce"), m * 0.2)
		var f := UiTheme.font()
		var px := int(m * 0.5)
		var w := f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(f, Vector2(-w / 2.0, px * 0.3), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 1, 1, 0.9))
		_plan_mark(sz)
		return
	DrawUtil.parcel(self, Vector2.ZERO, sz, color)
	_plan_mark(sz)


## The plan delivers it: washed out, and the houses' ghost tick (an outlined one; the real one's solid).
func _plan_mark(sz: Vector2) -> void:
	if plan != "gone" and plan != "park":
		return
	var m := minf(sz.x, sz.y)
	DrawUtil.rrect(self, Rect2(-sz / 2.0, sz).grow(1.0), Color(1, 1, 1, 0.55), m * 0.2)
	_badge(sz, "tick" if plan == "gone" else "P")


## A little round badge on its top-right corner: the ghost tick, or a "+".
func _badge(sz: Vector2, what: String) -> void:
	var m := minf(sz.x, sz.y)
	var c := Vector2(sz.x * 0.38, -sz.y * 0.36)
	var r := m * 0.3
	if what == "P":
		# Left in a parking locker: its sign.
		draw_circle(c, r, Color.WHITE)
		draw_circle(c, r * 0.8, Color("6f7a90"))
		var f := UiTheme.font()
		var px := int(r * 1.3)
		var w := f.get_string_size("P", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(f, c + Vector2(-w / 2.0, px * 0.36), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
	elif what == "tick":
		draw_circle(c, r, Color(1, 1, 1, 0.95))
		draw_arc(c, r * 0.86, 0, TAU, 28, Palette.CHECK, r * 0.2, true)
		draw_polyline(PackedVector2Array([c + Vector2(-0.43, 0.0) * r, c + Vector2(-0.13, 0.3) * r, c + Vector2(0.46, -0.3) * r]),
				Palette.CHECK, r * 0.23, true)
	else:
		draw_circle(c, r, Color.WHITE)
		draw_circle(c, r * 0.8, color)
		draw_line(c - Vector2(r * 0.42, 0), c + Vector2(r * 0.42, 0), Color.WHITE, r * 0.22, true)
		draw_line(c - Vector2(0, r * 0.42), c + Vector2(0, r * 0.42), Color.WHITE, r * 0.22, true)
