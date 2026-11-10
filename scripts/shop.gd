class_name Shop
extends Node2D
## Parcel shop: has a parcel waiting that the van collects (onto the top of its stack) as it
## drives past. Origin at the building's base, like House.

var color := Color.RED
var size := 180.0
var base_pos := Vector2.ZERO
var parcel_t := 1.0:              # 1 = parcel waiting, 0 = collected
	set(v):
		parcel_t = v
		queue_redraw()
var _t := randf() * TAU
var _tw: Tween


func _process(delta: float) -> void:
	if parcel_t > 0.0:
		_t += delta
		queue_redraw()


func parcel_pos() -> Vector2:
	return base_pos + Vector2(0, -size * 0.62)


func collect() -> void:
	_pop()
	var tw := create_tween()
	tw.tween_property(self, "parcel_t", 0.0, 0.12)


func restore() -> void:
	_pop()
	var tw := create_tween()
	tw.tween_property(self, "parcel_t", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pop() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2(1.2, 0.8), 0.06)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var s := size
	var w := s * 0.7
	var h := s * 0.34
	var empty := parcel_t <= 0.0
	var wall := Color("f4efe6") if not empty else Color("e6e2db")
	var trim := color if not empty else color.lerp(Color("b9b9b9"), 0.55)
	DrawUtil.rrect(self, Rect2(-w * 0.58, -s * 0.05, w * 1.16, s * 0.11), Color(0, 0, 0, 0.13), s * 0.05)
	DrawUtil.rrect(self, Rect2(-w / 2, -h, w, h), wall, s * 0.04)
	# flat roof slab
	DrawUtil.rrect(self, Rect2(-w / 2 - s * 0.03, -h - s * 0.07, w + s * 0.06, s * 0.09), Palette.VAN_CAB, s * 0.03)
	# striped awning
	var stripes := 6
	var aw := (w + s * 0.04) / stripes
	for k in stripes:
		var col := trim if k % 2 == 0 else Color.WHITE
		var r := Rect2(-w / 2 - s * 0.02 + k * aw, -h + s * 0.01, aw, s * 0.09)
		draw_rect(r, col)
		draw_circle(Vector2(r.position.x + aw / 2, r.end.y), aw / 2, col)
	# window + door
	DrawUtil.rrect(self, Rect2(-w / 2 + s * 0.06, -h * 0.55, s * 0.24, s * 0.13), Color("cfe6f7"), s * 0.02)
	DrawUtil.rrect(self, Rect2(w / 2 - s * 0.22, -s * 0.19, s * 0.13, s * 0.19), Palette.VAN_CAB, s * 0.03)
	if parcel_t > 0.0:
		var bob := sin(_t * 3.0) * s * 0.025
		var c := Vector2(0, -h - s * 0.21 + bob)
		DrawUtil.package(self, c, s * 0.24 * parcel_t, color)
