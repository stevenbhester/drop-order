class_name ExitZone
extends Node2D
## The way on to the next part of a mega route (or speedrun zone): a pad on its edge tile with chevrons
## pointing off the map. Dim until everything in this part is delivered; then it lights up and the chevrons
## run, calling the van over. (Tap it for what it is.) Origin at the tile's centre.

var tile := 100.0
var dir := Vector2i(1, 0)
## Everything in this part's delivered: drive here to go on.
var open := false:
	set(v):
		if v != open:
			open = v
			queue_redraw()
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
