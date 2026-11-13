class_name Roadworks
extends Node2D
## Roadworks on a road tile: a striped barrier with cones and a sign counting the deliveries still needed
## before it opens. Once enough packages are delivered, the barrier swings aside and the cones scoot off
## (and come back on an undo). Origin at the tile's centre.

var tile := 100.0
var need := 1
var _done := 0
var _open := 0.0
var _tw: Tween


func set_done(done: int) -> void:
	var was_open := _done >= need
	_done = done
	var open := _done >= need
	if open != was_open:
		if _tw and _tw.is_valid():
			_tw.kill()
		_tw = create_tween()
		_tw.tween_property(self, "_open", 1.0 if open else 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if open:
			Sfx.play("swap", 1.2, -6.0)
	queue_redraw()


func _process(_delta: float) -> void:
	if _tw and _tw.is_valid():
		queue_redraw()


func _draw() -> void:
	var t := tile
	var a := 1.0 - 0.75 * _open
	# Cones at the corners (sliding off to the sides as it opens).
	for sx in [-1.0, 1.0]:
		var cc := Vector2(sx * t * (0.3 + 0.18 * _open), t * 0.22)
		var s := t * 0.13 * (1.0 - 0.4 * _open)
		draw_colored_polygon(PackedVector2Array([cc + Vector2(-s, s * 0.7), cc + Vector2(0, -s * 1.3), cc + Vector2(s, s * 0.7)]), Color("ff8a3d", a))
		draw_line(cc + Vector2(-s * 0.5, -s * 0.1), cc + Vector2(s * 0.5, -s * 0.1), Color(1, 1, 1, a), s * 0.35)
	# The barrier: a striped board on two legs, swinging up and away when open.
	draw_set_transform(Vector2(0, -t * 0.02), -_open * 1.2, Vector2.ONE)
	var bw := t * 0.74
	var bh := t * 0.16
	var r := Rect2(-bw / 2.0, -bh / 2.0, bw, bh)
	DrawUtil.rrect(self, Rect2(r.position + Vector2(0, t * 0.03), r.size), Color(0, 0, 0, 0.2 * a), t * 0.04)
	DrawUtil.rrect(self, r, Color(1, 1, 1, a), t * 0.04)
	var k := 0
	var x := r.position.x
	while x < r.end.x:
		if k % 2 == 0:
			var x2 := minf(x + bh, r.end.x)
			draw_colored_polygon(PackedVector2Array([Vector2(x, r.end.y), Vector2(minf(x + bh * 0.5, r.end.x), r.position.y),
				Vector2(minf(x2 + bh * 0.5, r.end.x), r.position.y), Vector2(x2, r.end.y)]), Color("ff6b3d", a))
		x += bh
		k += 1
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# How many more deliveries until it opens.
	var left := maxi(need - _done, 0)
	if left > 0:
		var c := Vector2(0, -t * 0.26)
		draw_circle(c + Vector2(0, t * 0.02), t * 0.15, Color(0, 0, 0, 0.18))
		draw_circle(c, t * 0.15, Color("ffc93c"))
		draw_circle(c, t * 0.12, Color("2b2233"))
		var f := UiTheme.font()
		var txt := str(left)
		var px := int(t * 0.18)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(f, c + Vector2(-tw / 2.0, px * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("ffc93c"))
