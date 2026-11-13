class_name Gate
extends Node2D
## Colour gate on a straight road: the barrier lifts while the van's top package matches.
## Drawn in a local frame where traffic runs along +x; rotated 90° for vertical roads.

var color := Color.RED
var tile := 180.0
var road_w := 140.0
var open_t := 0.0:
	set(v):
		open_t = v
		queue_redraw()
var is_open := false
var _tw: Tween
var _shake := 0.0:
	set(v):
		_shake = v
		queue_redraw()


func set_open(o: bool, instant := false) -> void:
	if o == is_open and not instant:
		return
	is_open = o
	if _tw and _tw.is_valid():
		_tw.kill()
	if instant:
		open_t = 1.0 if o else 0.0
		return
	Sfx.play("gate", 1.0 if o else 0.8, -8)
	_tw = create_tween()
	if o:
		_tw.tween_property(self, "open_t", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_tw.tween_property(self, "open_t", 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Tried to drive into it while closed.
func deny() -> void:
	var tw := create_tween()
	for v in [1.0, -0.8, 0.5, -0.2, 0.0]:
		tw.tween_property(self, "_shake", v, 0.04)


func _draw() -> void:
	var half := road_w / 2.0
	# Coloured band across the road so the gate colour reads from afar.
	draw_rect(Rect2(-tile * 0.13, -half, tile * 0.26, road_w), Color(color, 0.28 + 0.12 * (1.0 - open_t)))
	var post := Vector2(0, -half - tile * 0.04)
	# Booth on the verge.
	var booth := Rect2(post + Vector2(-tile * 0.13, -tile * 0.2), Vector2(tile * 0.26, tile * 0.17))
	DrawUtil.rrect(self, Rect2(booth.position + Vector2(0, tile * 0.025), booth.size), Color(0, 0, 0, 0.18), tile * 0.05)
	DrawUtil.rrect(self, booth, color, tile * 0.05)
	DrawUtil.rrect(self, booth.grow(-tile * 0.04), color.lerp(Color.WHITE, 0.55), tile * 0.03)
	# Colorblind mode: the class mark of the package it lets through, on the booth.
	if DrawUtil.bold_marks and Palette.kind_of(color) != "":
		DrawUtil.rrect(self, booth.grow(-tile * 0.03), Color.WHITE, tile * 0.03)
		DrawUtil.mark(self, Palette.kind_of(color), booth.get_center(), tile * 0.22, Color("2b2233"), Color.WHITE, true)
	# Arm: hangs across the road when closed, swings up along the verge when open.
	var ang := lerpf(PI / 2.0, 0.08, open_t) + _shake * 0.12
	var length := road_w + tile * 0.04
	var dir := Vector2(cos(ang), sin(ang))
	var segs := 6
	for k in segs:
		var a := post + dir * length * k / segs
		var b := post + dir * length * (k + 1) / segs
		draw_line(a, b, color if k % 2 == 0 else Color.WHITE, tile * 0.075, true)
	draw_circle(post + dir * length, tile * 0.04, color)
	draw_circle(post, tile * 0.06, Palette.VAN_CAB)
