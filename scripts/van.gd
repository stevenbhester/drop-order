class_name Van
extends Node2D
## The delivery van (top-down, drawn facing +x). Rotation follows travel direction;
## squash/bounce live on a child `body` so they stay aligned with the van.

var size := 180.0
var target_rotation := 0.0
var inviting := false:
	set(v):
		inviting = v
		queue_redraw()

var body: Node2D
var _top_color := Color.WHITE
var _has_top := false
var _t := 0.0
var _scale_tw: Tween
var _pos_tw: Tween


func _ready() -> void:
	body = Node2D.new()
	add_child(body)
	body.draw.connect(_draw_body)
	rotation = target_rotation


func set_top(color_name: String) -> void:
	_has_top = color_name != ""
	if _has_top:
		_top_color = Palette.pkg(color_name)
	if body:
		body.queue_redraw()


func _process(delta: float) -> void:
	rotation = lerp_angle(rotation, target_rotation, 1.0 - exp(-24.0 * delta))
	if inviting:
		_t += delta
		queue_redraw()


func squash() -> void:
	_scale_to([[Vector2(0.84, 1.14), 0.06], [Vector2.ONE, 0.18]])


func stop_bounce() -> void:
	_scale_to([[Vector2(1.18, 0.86), 0.07], [Vector2(0.94, 1.06), 0.1], [Vector2.ONE, 0.14]])


func nudge() -> void:
	_scale_to([[Vector2(1.15, 1.15), 0.07], [Vector2.ONE, 0.2]])


func shake() -> void:
	if _pos_tw and _pos_tw.is_valid():
		_pos_tw.kill()
	_pos_tw = create_tween()
	for off in [10.0, -9.0, 6.0, -3.0, 0.0]:
		_pos_tw.tween_property(body, "position:y", off * size / 180.0, 0.04)


func _scale_to(steps: Array) -> void:
	if _scale_tw and _scale_tw.is_valid():
		_scale_tw.kill()
	_scale_tw = create_tween()
	for st in steps:
		var pt := _scale_tw.tween_property(body, "scale", st[0], st[1])
		if st[0] == Vector2.ONE:
			pt.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if not inviting:
		return
	for k0 in [0.0, 0.5]:
		var k := fmod(_t / 1.3 + k0, 1.0)
		var r := size * (0.36 + 0.22 * k)
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(1, 1, 1, 0.75 * (1.0 - k)), size * 0.04, true)


func _draw_body() -> void:
	var b := body
	var L := size * 0.74
	var W := size * 0.46
	DrawUtil.rrect(b, Rect2(-L / 2 - 4, -W / 2 - 2, L + 8, W + 12), Color(0, 0, 0, 0.2), W * 0.32)
	# wheels
	for sx in [-0.28, 0.28]:
		for sy in [-1.0, 1.0]:
			DrawUtil.rrect(b, Rect2(Vector2(L * sx - L * 0.1, sy * W * 0.5 - W * 0.09), Vector2(L * 0.2, W * 0.18)), Palette.WHEEL, W * 0.06)
	DrawUtil.rrect(b, Rect2(-L / 2, -W / 2, L, W), Palette.VAN_BODY, W * 0.28)
	# cab at the front (+x)
	var cab := L * 0.3
	DrawUtil.rrect(b, Rect2(L / 2 - cab, -W / 2, cab, W), Palette.VAN_CAB, W * 0.28)
	DrawUtil.rrect(b, Rect2(L / 2 - cab + W * 0.06, -W * 0.36, cab * 0.42, W * 0.72), Palette.VAN_GLASS, W * 0.1)
	for sy in [-1.0, 1.0]:
		b.draw_circle(Vector2(L / 2 - W * 0.06, sy * W * 0.32), W * 0.07, Color("ffe28a"))
	# cargo bay shows the current top package
	var cargo_c := Vector2(-L * 0.13, 0)
	if _has_top:
		DrawUtil.package(b, cargo_c, W * 0.66, _top_color, false)
	else:
		DrawUtil.rrect(b, Rect2(cargo_c - Vector2(W, W) * 0.33, Vector2(W, W) * 0.66), Color("ece4d6"), W * 0.12)
