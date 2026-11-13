class_name PackageBox
extends Node2D
## A single package sprite (the chute's load and flying deliveries): `size` tall, `aspect` times as wide.
## `fogged`: lost in the fog (a side road's twist): a plain grey crate with a "?".

var color := Color.WHITE
var size := 64.0
var aspect := 1.0
var fogged := false


func _draw() -> void:
	var sz := Vector2(size * aspect, size)
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
		return
	DrawUtil.parcel(self, Vector2.ZERO, sz, color)
