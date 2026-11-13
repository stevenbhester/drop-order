class_name ExitZone
extends Node2D
## The way on to the next part of a mega route: a pad on its edge tile with chevrons pointing off the map
## and a little "NEXT PART" tag. Dim until everything in this part is delivered; then it lights up and the
## chevrons run, calling the van over. Origin at the tile's centre.

var tile := 100.0
var dir := Vector2i(1, 0)
## Everything in this part's delivered: drive here to go on.
var open := false:
	set(v):
		if v != open:
			open = v
			queue_redraw()
var label := "NEXT PART"
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var d := Vector2(dir)
	var side := Vector2(-d.y, d.x)
	var col := Color("38d9a9")
	var a := 0.9 if open else 0.4
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	var r := Rect2(Vector2(-tile, -tile) * 0.42, Vector2(tile, tile) * 0.84)
	if open:
		DrawUtil.rrect(self, r.grow(tile * 0.06 * pulse), Color(col, 0.25), tile * 0.2)
	DrawUtil.rrect(self, r, Color(col, 0.22 * a + 0.1), tile * 0.16)
	# Chevrons pointing off the edge; running while it's open.
	var run := fmod(_t * 1.6, 1.0) if open else 0.0
	for k in 3:
		var u := fmod(k / 3.0 + run / 3.0, 1.0)
		var c := d * tile * (-0.3 + u * 0.6)
		var fade := sin(PI * u) if open else 0.8
		var w := tile * 0.2
		draw_polyline(PackedVector2Array([c - d * w * 0.5 + side * w, c + d * w * 0.5, c - d * w * 0.5 - side * w]),
			Color(Color.WHITE, a * fade), tile * 0.07, true)
	# The tag, on the inside of the tile.
	var f := UiTheme.font()
	var px := int(tile * 0.15)
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := -d * tile * 0.62
	if dir.y != 0:
		at = -d * tile * 0.6
	var tag := Rect2(at - Vector2(tw / 2.0 + tile * 0.06, px * 0.7), Vector2(tw + tile * 0.12, px * 1.4))
	DrawUtil.rrect(self, tag, Color(col.darkened(0.25), 0.55 + 0.4 * a), px * 0.7)
	draw_string(f, at + Vector2(-tw / 2.0, px * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
