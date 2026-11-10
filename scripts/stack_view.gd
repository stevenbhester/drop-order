class_name StackView
extends Node2D
## The van's load as a vertical stack: last package on top, labelled NEXT.
## Origin is the bottom-centre of the stack. Mirrors Sim's stack via pop/push/swap,
## or `rebuild` for undo.

var box := 70.0
var gap := 10.0
var boxes: Array = []        # PackageBox, index 0 = bottom
var colors: Array = []       # colour names, parallel to boxes
var _capacity := 1


func setup(cols: Array, box_size: float, capacity: int) -> void:
	box = box_size
	gap = box * 0.14
	_capacity = maxi(capacity, 1)
	for c in cols:
		_add(c, false)
	queue_redraw()


func height() -> float:
	return _capacity * (box + gap) + gap + box * 0.55


func top_color() -> String:
	return colors.back() if not colors.is_empty() else ""


func _slot(i: int) -> Vector2:
	return Vector2(0, -box * 0.5 - gap - i * (box + gap))


func _add(c: String, animate: bool) -> PackageBox:
	var b := PackageBox.new()
	b.color = Palette.pkg(c)
	b.size = box
	b.position = _slot(boxes.size())
	add_child(b)
	boxes.append(b)
	colors.append(c)
	if animate:
		b.position.y -= box * 0.9
		b.scale = Vector2(0.6, 0.6)
		var tw := b.create_tween().set_parallel()
		tw.tween_property(b, "position:y", _slot(boxes.size() - 1).y, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE, 0.16)
	return b


func pop_top() -> void:
	if boxes.is_empty():
		return
	var b: PackageBox = boxes.pop_back()
	colors.pop_back()
	var tw := b.create_tween().set_parallel()
	tw.tween_property(b, "scale", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(b, "position:y", b.position.y - box * 0.4, 0.16)
	tw.chain().tween_callback(b.queue_free)
	_bump_top()
	queue_redraw()


## A collected parcel lands on top.
func push(c: String) -> void:
	_add(c, true)
	queue_redraw()


## Sorting hub: the top two trade places with a little hop.
func swap_top() -> void:
	var n := boxes.size()
	if n < 2:
		return
	var a: PackageBox = boxes[n - 1]
	var b: PackageBox = boxes[n - 2]
	boxes[n - 1] = b
	boxes[n - 2] = a
	var ca = colors[n - 1]
	colors[n - 1] = colors[n - 2]
	colors[n - 2] = ca
	for pair in [[b, n - 1, 1.0], [a, n - 2, -1.0]]:
		var bx: PackageBox = pair[0]
		var target := _slot(pair[1])
		var side: float = pair[2]
		var start := bx.position
		var tw := bx.create_tween()
		tw.tween_method(_hop.bind(bx, start, target, side), 0.0, 1.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	queue_redraw()


func _hop(t: float, bx: Node2D, from: Vector2, to: Vector2, side: float) -> void:
	bx.position = from.lerp(to, t) + Vector2(side * box * 0.7 * sin(PI * t), 0)
	bx.rotation = side * 0.5 * sin(PI * t)


## Undo: replace the whole stack, popping boxes in from the bottom up.
func rebuild(cols: Array) -> void:
	for b in boxes:
		b.queue_free()
	boxes.clear()
	colors.clear()
	for i in cols.size():
		var b := _add(cols[i], false)
		b.scale = Vector2.ZERO
		var tw := b.create_tween()
		tw.tween_interval(i * 0.035)
		tw.tween_property(b, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _bump_top() -> void:
	if boxes.is_empty():
		return
	var nb: PackageBox = boxes.back()
	var t2 := nb.create_tween()
	t2.tween_property(nb, "scale", Vector2(1.18, 1.18), 0.07)
	t2.tween_property(nb, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
