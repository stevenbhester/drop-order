class_name StackView
extends Node2D
## The van's load as a vertical stack: last package on top, labelled NEXT.
## Origin is the bottom-centre of the stack.

var box := 70.0
var gap := 10.0
var boxes: Array = []        # PackageBox, index 0 = bottom
var _capacity := 1


func setup(colors: Array, box_size: float) -> void:
	box = box_size
	gap = box * 0.14
	_capacity = maxi(colors.size(), 1)
	for i in colors.size():
		var b := PackageBox.new()
		b.color = Palette.pkg(colors[i])
		b.size = box
		b.position = _slot(i)
		add_child(b)
		boxes.append(b)
	queue_redraw()


func height() -> float:
	return _capacity * (box + gap) + gap + box * 0.55


func _slot(i: int) -> Vector2:
	return Vector2(0, -box * 0.5 - gap - i * (box + gap))


func pop_top() -> void:
	if boxes.is_empty():
		return
	var b: PackageBox = boxes.pop_back()
	var tw := b.create_tween().set_parallel()
	tw.tween_property(b, "scale", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(b, "position:y", b.position.y - box * 0.4, 0.16)
	tw.chain().tween_callback(b.queue_free)
	if not boxes.is_empty():
		var nb: PackageBox = boxes.back()
		var t2 := nb.create_tween()
		t2.tween_property(nb, "scale", Vector2(1.18, 1.18), 0.07)
		t2.tween_property(nb, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func flash_remaining() -> void:
	for i in boxes.size():
		var b: PackageBox = boxes[i]
		var tw := b.create_tween()
		tw.tween_interval(i * 0.04)
		for r in [0.18, -0.15, 0.08, 0.0]:
			tw.tween_property(b, "rotation", r, 0.05)


func _draw() -> void:
	var w := box + box * 0.5
	var hgt := height()
	DrawUtil.rrect(self, Rect2(-w / 2, -hgt + box * 0.55, w, hgt), Color(1, 1, 1, 0.5), box * 0.3)
	var f := UiTheme.font()
	var fs := int(box * 0.32)
	var label := "LOAD"
	var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(-lw / 2, box * 0.42), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.TEXT_SOFT)
	if boxes.is_empty():
		return
	var y := _slot(boxes.size() - 1).y
	var x := w / 2 + box * 0.14
	var tri := PackedVector2Array([Vector2(x, y), Vector2(x + box * 0.24, y - box * 0.17), Vector2(x + box * 0.24, y + box * 0.17)])
	draw_colored_polygon(tri, Palette.TEXT)
	draw_string(f, Vector2(x + box * 0.32, y + fs * 0.36), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.TEXT)
