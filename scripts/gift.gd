class_name Gift
extends Node2D
## A cosmetic lying on the road: a little ribboned present that bobs and twinkles. Drive over it to pick it up
## (it's yours once you finish the level).

var item := ""
var tile := 100.0
var taken := false:
	set(v):
		taken = v
		visible = not v

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := tile * 0.36
	var bob := sin(_t * 3.0) * tile * 0.04
	var col := Cosmetics.tint(item)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2(0, tile * 0.5), s * 0.62, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Glow.
	draw_circle(Vector2(0, bob), s * (0.95 + 0.08 * sin(_t * 4.0)), Color(1, 0.95, 0.6, 0.28))
	var c := Vector2(0, bob)
	var tilt := sin(_t * 2.0) * 0.12
	draw_set_transform(c, tilt, Vector2.ONE)
	DrawUtil.rrect(self, Rect2(Vector2(-0.5, -0.38) * s, Vector2(1.0, 0.86) * s), col.darkened(0.15), s * 0.16)
	DrawUtil.rrect(self, Rect2(Vector2(-0.5, -0.42) * s, Vector2(1.0, 0.8) * s), col, s * 0.16)
	draw_rect(Rect2(Vector2(-0.09, -0.42) * s, Vector2(0.18, 0.8) * s), Color.WHITE)
	draw_rect(Rect2(Vector2(-0.5, -0.06) * s, Vector2(1.0, 0.14) * s), Color.WHITE)
	for sx in [-1.0, 1.0]:
		draw_circle(Vector2(sx * 0.17, -0.5) * s, s * 0.14, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Twinkles.
	for k in 3:
		var a := _t * 1.3 + k * TAU / 3.0
		var tw := 0.5 + 0.5 * sin(_t * 6.0 + k * 2.0)
		Icons.star(self, c + Vector2(cos(a), sin(a) * 0.6) * s * 0.9, s * 0.13 * tw, Color(1, 1, 1, tw))
