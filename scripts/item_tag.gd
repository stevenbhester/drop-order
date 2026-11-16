class_name ItemTag
extends Control
## A find, shown like a game item: a rounded tile in its colour with a small picture of it (the van wearing
## it, for paint, toppers and rides; a present otherwise), and a name tag beside it saying what kind of
## thing it is. Tap it to open its card again (UnlockCard). Pops in.

signal pressed

var item := ""
var _van: Van
var _t := 0.0


func _ready() -> void:
	size = Vector2(620, 150)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var kind := Cosmetics.kind_of(item)
	if kind in ["paint", "topper", "ride"]:
		_van = Van.new()
		_van.follow_progress = false
		_van.size = 110.0
		_van.position = Vector2(75, 75)
		_van.paint = item if kind == "paint" else Progress.paint
		_van.topper = item if kind == "topper" else ""
		_van.ride = item if kind == "ride" else Progress.ride
		_van.rotation = -0.3
		_van.target_rotation = -0.3
		add_child(_van)
	pivot_offset = size / 2.0
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("pop", 1.2, -4.0)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		accept_event()
		pressed.emit()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var tint := Cosmetics.tint(item)
	var f := UiTheme.font()
	# The tile, with a shine sweeping across now and then.
	var tile := Rect2(0, 0, 150, 150)
	DrawUtil.rrect(self, Rect2(tile.position + Vector2(0, 8), tile.size), Color(0, 0, 0, 0.3), 32)
	DrawUtil.rrect(self, tile, tint.darkened(0.25), 32)
	DrawUtil.rrect(self, tile.grow(-8), tint, 26)
	draw_arc(tile.get_center(), 70, 0, TAU, 40, Color(1, 1, 1, 0.5), 5.0, true)
	if _van == null:
		Icons.draw(self, "gift", tile.get_center(), 90.0, Color.WHITE)
	var sh := fmod(_t, 2.6)
	if sh < 0.5:
		var x := -40.0 + 260.0 * sh / 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(x, 8), Vector2(x + 30, 8), Vector2(x - 30, 142), Vector2(x - 60, 142)]), Color(1, 1, 1, 0.25))
	# The name tag.
	var tag := Rect2(170, 22, size.x - 170, 106)
	DrawUtil.rrect(self, Rect2(tag.position + Vector2(0, 6), tag.size), Color(0, 0, 0, 0.25), 24)
	DrawUtil.rrect(self, tag, Color.WHITE, 24)
	var kind: String = Cosmetics.BANNERS.get(Cosmetics.kind_of(item), "NEW!")
	draw_string(f, tag.position + Vector2(24, 40), kind, HORIZONTAL_ALIGNMENT_LEFT, tag.size.x - 40, 26, tint.darkened(0.3))
	var name := Cosmetics.name_of(item)
	var px := 44
	while px > 26 and f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > tag.size.x - 48:
		px -= 2
	draw_string(f, tag.position + Vector2(24, 88), name, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Palette.TEXT)
	draw_string(f, tag.position + Vector2(tag.size.x - 40, 40), "ⓘ", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.TEXT_SOFT)
