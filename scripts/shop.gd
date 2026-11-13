class_name Shop
extends Node2D
## Parcel shop: has a parcel waiting that the van collects (onto the top of its stack) as it
## drives past. A warehouse (stock > 1) holds several: a little stack of them sits on the roof with a
## "×N" for how many are left, and they all come aboard as the van passes. Origin at the building's base,
## like House.

var color := Color.RED
var size := 180.0
var base_pos := Vector2.ZERO
## Parcels it starts with, and how many are still waiting.
var stock := 1
var left := 1:
	set(v):
		left = v
		queue_redraw()
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
	left = maxi(left - 1, 0)
	if left == 0:
		var tw := create_tween()
		tw.tween_property(self, "parcel_t", 0.0, 0.12)


func restore() -> void:
	_pop()
	left = mini(left + 1, stock)
	if parcel_t < 1.0:
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
	# A big shop window with the parcel(s) bouncing about inside, and a door.
	var win := Rect2(-w / 2 + s * 0.05, -h * 0.72, w * 0.62, h * 0.62)
	DrawUtil.rrect(self, win.grow(s * 0.012), Palette.VAN_CAB, s * 0.03)
	DrawUtil.rrect(self, win, Color("e6f3fc") if not empty else Color("d9dee3"), s * 0.025)
	if not empty:
		var n := mini(left, 3)
		for i in n:
			var ph := _t * 4.2 + i * 2.1
			var hop := absf(sin(ph))
			var ms := s * 0.15 * (1.0 if i == 0 else 0.82)
			var mx := win.position.x + win.size.x * (0.5 + 0.28 * sin(_t * 1.3 + i * 2.4)) 
			var floor_y := win.end.y - s * 0.012
			var sq := 1.0 - 0.22 * (1.0 - hop) * (1.0 - hop)
			var py := floor_y - ms * 0.5 * sq - hop * win.size.y * 0.42
			draw_set_transform(Vector2(mx, py), sin(ph * 0.5) * 0.3, Vector2(1.0 / sq, sq))
			DrawUtil.package(self, Vector2.ZERO, ms, color.darkened(0.05 * i), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	DrawUtil.rrect(self, Rect2(w / 2 - s * 0.2, -s * 0.19, s * 0.13, s * 0.19), Palette.VAN_CAB, s * 0.03)
	if parcel_t > 0.0:
		var bob := -absf(sin(_t * 2.6)) * s * 0.045
		var c := Vector2(0, -h - s * 0.21 + bob)
		if stock > 1 and left > 1:
			# A warehouse: a little pile on the roof, and how many are left.
			DrawUtil.package(self, c + Vector2(-s * 0.1, s * 0.05), s * 0.2 * parcel_t, color.darkened(0.08))
			DrawUtil.package(self, c + Vector2(s * 0.1, s * 0.05), s * 0.2 * parcel_t, color.darkened(0.04))
			DrawUtil.package(self, c + Vector2(0, -s * 0.07), s * 0.22 * parcel_t, color)
			DrawUtil.count_badge(self, Vector2(s * 0.27, -s * 0.6), s, left, color)
		else:
			DrawUtil.package(self, c, s * 0.24 * parcel_t, color)
