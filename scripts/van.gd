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
## What it's wearing: a Cosmetics paint id and topper id. Empty paint = whatever Progress says.
var paint := ""
var topper := ""
## A whole other vehicle (Cosmetics "ride" id), or "" for the van.
var ride := ""
## Wear what Progress says (and follow changes in the garage).
var follow_progress := true
var _top_color := Color.WHITE
var _has_top := false
var _t := 0.0
var _scale_tw: Tween
var _pos_tw: Tween
## Seconds into a win celebration (RideWins), or -1.
var _win_t := -1.0
var _win_ride := ""
var _fx: Node2D
var _fx_under: Node2D


func _ready() -> void:
	# The celebration's ground effects go under the ride (smoke, splashes), its words and flourishes over.
	_fx_under = Node2D.new()
	_fx_under.draw.connect(func():
		if _win_t >= 0.0:
			RideWins.overlay(_fx_under, _win_ride, _win_t, size, global_rotation, true))
	add_child(_fx_under)
	body = Node2D.new()
	add_child(body)
	body.draw.connect(_draw_body)
	_fx = Node2D.new()
	_fx.draw.connect(func():
		if _win_t >= 0.0:
			RideWins.overlay(_fx, _win_ride, _win_t, size, global_rotation))
	add_child(_fx)
	rotation = target_rotation
	if follow_progress:
		_wear()
		Progress.changed.connect(_wear)


func _wear() -> void:
	paint = Progress.paint
	topper = Progress.topper
	ride = Progress.ride
	if body:
		body.queue_redraw()


func set_top(color_name: String) -> void:
	_has_top = color_name != ""
	if _has_top:
		_top_color = Palette.pkg(color_name)
	if body:
		body.queue_redraw()


func _process(delta: float) -> void:
	rotation = lerp_angle(rotation, target_rotation, 1.0 - exp(-24.0 * delta))
	_t += delta
	if _win_t >= 0.0:
		_celebration(delta)
	if inviting:
		queue_redraw()
	if topper == "sprout" or topper == "rivet" or topper == "puffball" or ride != "":
		body.queue_redraw()
	if ride == "pillow_tower":
		# It stacks up the screen, whichever way it's facing.
		body.queue_redraw()


## The win celebration for whatever it's riding (RideWins): its moves, its sounds, its effects.
func celebrate() -> void:
	_win_ride = ride
	_win_t = 0.0
	for tw in [_scale_tw, _pos_tw]:
		if tw and tw.is_valid():
			tw.kill()


func celebrating() -> bool:
	return _win_t >= 0.0


func _celebration(delta: float) -> void:
	var before := _win_t
	_win_t += delta
	for c in RideWins.cues(_win_ride):
		if float(c[0]) >= before and float(c[0]) < _win_t:
			Sfx.play(c[1], c[2], c[3])
	if _win_t > RideWins.time(_win_ride) + 0.15:
		_win_t = -1.0
		body.position = Vector2.ZERO
		body.rotation = 0.0
		body.scale = Vector2.ONE
	else:
		var p := RideWins.pose(_win_ride, _win_t, size)
		body.position = p["pos"]
		body.rotation = p["rot"]
		body.scale = p["scale"]
	body.queue_redraw()
	_fx.queue_redraw()
	_fx_under.queue_redraw()


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
	if ride != "":
		var up := Vector2.UP.rotated(-(global_rotation + b.rotation))
		var at := Cosmetics.draw_ride(b, ride, L, W, _top_color if _has_top else null, _t, paint if paint != "" else "classic", _win_t if _win_ride == ride else -1.0, up)
		if topper != "":
			Cosmetics.draw_topper(b, topper, at, W, _t)
		return
	DrawUtil.rrect(b, Rect2(-L / 2 - 4, -W / 2 - 2, L + 8, W + 12), Color(0, 0, 0, 0.2), W * 0.32)
	# wheels
	for sx in [-0.28, 0.28]:
		for sy in [-1.0, 1.0]:
			DrawUtil.rrect(b, Rect2(Vector2(L * sx - L * 0.1, sy * W * 0.5 - W * 0.09), Vector2(L * 0.2, W * 0.18)), Palette.WHEEL, W * 0.06)
	var p := paint if paint != "" else "classic"
	DrawUtil.rrect(b, Rect2(-L / 2, -W / 2, L, W), Cosmetics.body_color(p), W * 0.28)
	Cosmetics.draw_pattern(b, p, Rect2(-L / 2 + W * 0.12, -W / 2 + W * 0.1, L * 0.7 - W * 0.12, W * 0.8))
	# cab at the front (+x)
	var cab := L * 0.3
	DrawUtil.rrect(b, Rect2(L / 2 - cab, -W / 2, cab, W), Cosmetics.cab_color(p), W * 0.28)
	DrawUtil.rrect(b, Rect2(L / 2 - cab + W * 0.06, -W * 0.36, cab * 0.42, W * 0.72), Palette.VAN_GLASS, W * 0.1)
	for sy in [-1.0, 1.0]:
		b.draw_circle(Vector2(L / 2 - W * 0.06, sy * W * 0.32), W * 0.07, Color("ffe28a"))
	# cargo bay shows the current top package
	var cargo_c := Vector2(-L * 0.13, 0)
	if _has_top:
		DrawUtil.package(b, cargo_c, W * 0.66, _top_color, false)
	else:
		DrawUtil.rrect(b, Rect2(cargo_c - Vector2(W, W) * 0.33, Vector2(W, W) * 0.66), Color("ece4d6"), W * 0.12)
	if topper != "":
		Cosmetics.draw_topper(b, topper, Vector2(L / 2 - cab * 0.62, 0), W, _t)
