class_name House
extends Node2D
## A customer house. Origin is at the house's base so squash/pop scales from the ground.

var color := Color.RED
var order := 1
var filled := 0
var size := 180.0
var base_pos := Vector2.ZERO
var check_t := 0.0:
	set(v):
		check_t = v
		queue_redraw()

var _scale_tw: Tween
var _pos_tw: Tween


func is_full() -> bool:
	return filled >= order


func deliver() -> void:
	filled += 1
	queue_redraw()
	pop()
	if is_full():
		var tw := create_tween()
		tw.tween_property(self, "check_t", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Undo: take packages back. Checkmark shrinks away if no longer full.
func undeliver(to_filled: int) -> void:
	var was_full := is_full()
	filled = to_filled
	queue_redraw()
	pop()
	if was_full and not is_full():
		var tw := create_tween()
		tw.tween_property(self, "check_t", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func pop() -> void:
	_kill(_scale_tw)
	_scale_tw = create_tween()
	_scale_tw.tween_property(self, "scale", Vector2(1.28, 0.74), 0.06)
	_scale_tw.tween_property(self, "scale", Vector2(0.9, 1.14), 0.08)
	_scale_tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Small horizontal shake: "not my package".
func wobble() -> void:
	_kill(_pos_tw)
	position = base_pos
	_pos_tw = create_tween()
	for off in [14.0, -12.0, 8.0, -5.0, 2.0, 0.0]:
		_pos_tw.tween_property(self, "position:x", base_pos.x + off * size / 180.0, 0.035)


func bounce(delay: float) -> void:
	_kill(_pos_tw)
	position = base_pos
	_pos_tw = create_tween()
	_pos_tw.tween_interval(delay)
	_pos_tw.tween_property(self, "position:y", base_pos.y - size * 0.2, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pos_tw.tween_property(self, "position:y", base_pos.y, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _kill(tw: Tween) -> void:
	if tw and tw.is_valid():
		tw.kill()


func _draw() -> void:
	var s := size
	var w := s * 0.62
	var h := s * 0.4
	var done := is_full()
	var wall := color.lerp(Color.WHITE, 0.72)
	var roof := color
	if done:
		wall = wall.lerp(Color("eeeeee"), 0.5)
		roof = roof.lerp(Color("b9b9b9"), 0.5)

	DrawUtil.rrect(self, Rect2(-w * 0.62, -s * 0.05, w * 1.24, s * 0.11), Color(0, 0, 0, 0.13), s * 0.05)
	DrawUtil.rrect(self, Rect2(-w / 2, -h, w, h), wall, s * 0.05)
	# Roof with rounded corners (fill + thick round outline).
	var eave := s * 0.07
	var pts := PackedVector2Array([
		Vector2(-w / 2 - eave, -h + s * 0.03),
		Vector2(0, -h - s * 0.3),
		Vector2(w / 2 + eave, -h + s * 0.03),
	])
	draw_colored_polygon(pts, roof)
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, roof, s * 0.05, true)
	for p in pts:
		draw_circle(p, s * 0.025, roof)
	# Door and windows.
	DrawUtil.rrect(self, Rect2(-s * 0.07, -s * 0.21, s * 0.14, s * 0.21), roof.darkened(0.28), s * 0.04)
	var glass := Color("e9e9e9") if done else Color("fff1b8")
	DrawUtil.rrect(self, Rect2(-w / 2 + s * 0.07, -h + s * 0.08, s * 0.11, s * 0.11), glass, s * 0.025)
	DrawUtil.rrect(self, Rect2(w / 2 - s * 0.18, -h + s * 0.08, s * 0.11, s * 0.11), glass, s * 0.025)

	if order > 1 and not done:
		var bc := Vector2(w * 0.5, -h - s * 0.16)
		draw_circle(bc, s * 0.12, Color.WHITE)
		var f := UiTheme.font()
		var txt := "×%d" % (order - filled)
		var fs := int(s * 0.15)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, bc + Vector2(-tw / 2, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.TEXT)

	if check_t > 0.0:
		var c := Vector2(w * 0.45, -h - s * 0.17)
		var r := s * 0.15 * check_t
		draw_circle(c + Vector2(0, s * 0.02), r, Color(0, 0, 0, 0.15))
		draw_circle(c, r, Palette.CHECK)
		var k := r / 0.15 / s
		var chk := PackedVector2Array([
			c + Vector2(-0.065, 0.0) * s * k,
			c + Vector2(-0.02, 0.045) * s * k,
			c + Vector2(0.07, -0.045) * s * k,
		])
		draw_polyline(chk, Color.WHITE, s * 0.035 * k, true)
