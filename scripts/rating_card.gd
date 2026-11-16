class_name RatingCard
extends CanvasLayer
## "How was that one?": the quick card after a win when Rate levels is on (see Rating), before the finish
## card. Three rows of five stars (difficulty, fun, frustration; tap a star again to clear the row), a
## handful of descriptors to tick (an emoji and a word or two each), "Add a note" (opens a small box), and Submit. With
## nothing filled in it's a plain Skip instead (which still sends the win's stats, no answers); it turns
## into Submit as soon as anything is. It sends in the background: the card never waits for the server.

signal done(answers: Dictionary)

var level: LevelData
var where := ""

const ROWS := [["difficulty", "Difficulty", "easy", "brutal"], ["fun", "Fun", "dull", "loved it"], ["frustration", "Frustration", "none", "lots"]]

var _root: Control
var _card: PanelContainer
var _col: VBoxContainer
var _answers := {"difficulty": 0, "fun": 0, "frustration": 0}
var _tags := {}
var _note: TextEdit
var _note_btn: JuicyButton
var _send: JuicyButton
var _rise := 0.0
var _closing := false


func _ready() -> void:
	layer = 84
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.1, 0.08, 0.16, 0.6)))
	add_child(_root)
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(56)
	sb.set_content_margin_all(40)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 14)
	sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", sb)
	_card.custom_minimum_size = Vector2(minf(960.0, _root.get_viewport_rect().size.x - 50.0), 0)
	_root.add_child(_card)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 14)
	_card.add_child(_col)

	_col.add_child(_label("How was that one?", 60, Palette.TEXT))
	_col.add_child(_label(("%s · %s" % [where, level.title]) if level and level.title != "" else where, 30, Palette.TEXT_SOFT))
	for r in ROWS:
		var row := Stars.new()
		row.title = r[1]
		row.low = r[2]
		row.high = r[3]
		row.custom_minimum_size = Vector2(0, 104)
		var key: String = r[0]
		row.changed.connect(func(v: int):
			_answers[key] = v
			_refresh_send())
		_col.add_child(row)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	for t in Rating.TAGS:
		var chip := Chip.new()
		chip.text = "%s %s" % [t[1], t[2]]
		var id: String = t[0]
		chip.toggled.connect(func(on: bool):
			if on:
				_tags[id] = true
			else:
				_tags.erase(id)
			_refresh_send())
		flow.add_child(chip)
	_col.add_child(flow)

	_note_btn = JuicyButton.new()
	_note_btn.label = "Add a note"
	_note_btn.icon_name = "bulb"
	_note_btn.font_px = 32
	_note_btn.custom_minimum_size = Vector2(0, 88)
	_note_btn.pressed.connect(_open_note)
	_col.add_child(_note_btn)

	_send = JuicyButton.new()
	_send.font_px = 48
	_send.custom_minimum_size = Vector2(0, 128)
	_send.pressed.connect(_submit)
	_col.add_child(_send)
	_refresh_send()

	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.15)
	Sfx.play("pop", 1.1, -6.0)
	_place()


func _label(t: String, px: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.clip_text = true
	return l


## The note box takes the button's place, with the keyboard up.
func _open_note() -> void:
	if _note != null:
		return
	_note = TextEdit.new()
	_note.placeholder_text = "Anything worth saying about this level?"
	_note.custom_minimum_size = Vector2(0, 170)
	_note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_note.add_theme_font_size_override("font_size", 34)
	_note.add_theme_color_override("font_color", Palette.TEXT)
	_note.add_theme_color_override("font_placeholder_color", Palette.TEXT_SOFT)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Palette.SURFACE
	tsb.set_corner_radius_all(24)
	tsb.set_content_margin_all(20)
	tsb.border_color = Color(Palette.TEXT, 0.15)
	tsb.set_border_width_all(3)
	_note.add_theme_stylebox_override("normal", tsb)
	var tsf := tsb.duplicate() as StyleBoxFlat
	tsf.border_color = Palette.ACCENT
	_note.add_theme_stylebox_override("focus", tsf)
	UiTheme.text_caret(_note)
	_note.text_changed.connect(_refresh_send)
	_col.add_child(_note)
	_col.move_child(_note, _note_btn.get_index())
	_note_btn.visible = false
	Sfx.play("click")
	_note.grab_focus.call_deferred()


## Centred, and up above the on-screen keyboard while it's open.
func _place() -> void:
	var v := _root.get_viewport_rect().size
	var kb := 0.0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		var screen_h := float(DisplayServer.window_get_size().y)
		if screen_h > 0.0:
			kb = DisplayServer.virtual_keyboard_get_height() * v.y / screen_h
	_rise = lerpf(_rise, kb, 0.3)
	var sz := _card.get_combined_minimum_size()
	var y := (v.y - sz.y) / 2.0
	if _rise > 1.0:
		y = minf(y, v.y - _rise - sz.y - 20.0)
	_card.position = Vector2((v.x - sz.x) / 2.0, maxf(y, 20.0) if _rise <= 1.0 else y)
	_card.size = sz


func _process(_delta: float) -> void:
	_place()


## Anything filled in yet (a star, a tick, a word)?
func _filled() -> bool:
	for k in _answers:
		if int(_answers[k]) > 0:
			return true
	return not _tags.is_empty() or (_note != null and _note.text.strip_edges() != "")


## Skip while the card's empty, Submit (bright) once anything's in it.
func _refresh_send() -> void:
	var on := _filled()
	_send.label = "Submit" if on else "Skip"
	_send.icon_name = "next" if on else ""
	_send.bg = Palette.ACCENT if on else Palette.SURFACE
	_send.fg = Color.WHITE if on else Palette.TEXT_SOFT
	if _send.is_inside_tree():
		_send.restyle()


func answers() -> Dictionary:
	var a := _answers.duplicate()
	a["tags"] = _tags.keys()
	a["note"] = _note.text if _note else ""
	return a


func _submit() -> void:
	if _closing:
		return
	_closing = true
	if _note:
		_note.release_focus()
	DisplayServer.virtual_keyboard_hide()
	Sfx.play("click", 1.1)
	Sfx.haptic(14, 0.7)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var out := answers()
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		done.emit(out)
		queue_free())


## A row of five stars with its name. Tap one to set the row; tap the same one again to clear it.
class Stars:
	extends Control
	signal changed(v: int)
	var title := ""
	var low := ""
	var high := ""
	var value := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _star_x(i: int) -> float:
		var w := minf(104.0, (size.x - 300.0) / 5.0)
		return size.x - w * (5 - i) + w / 2.0

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			var w := minf(104.0, (size.x - 300.0) / 5.0)
			var i := int(floor((e.position.x - (size.x - w * 5.0)) / w)) + 1
			if i < 1 or i > 5:
				return
			accept_event()
			value = 0 if value == i else i
			Sfx.play("click", 0.9 + 0.06 * value)
			Sfx.haptic(10, 0.5)
			changed.emit(value)
			queue_redraw()

	func _draw() -> void:
		var f := UiTheme.font()
		draw_string(f, Vector2(0, size.y / 2.0 - 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Palette.TEXT)
		var words: String = ("%s ... %s" % [low, high]) if value == 0 else str(["", low, "", "", "", high][value])
		draw_string(f, Vector2(0, size.y / 2.0 + 32), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.TEXT_SOFT)
		for i in 5:
			var c := Vector2(_star_x(i), size.y / 2.0)
			var pts := PackedVector2Array()
			for k in 10:
				var r := 40.0 if k % 2 == 0 else 17.0
				pts.append(c + Vector2(0, -r).rotated(k * PI / 5.0))
			if i < value:
				draw_colored_polygon(pts, Palette.STAR_GOLD)
			else:
				draw_colored_polygon(pts, Color(Palette.TEXT, 0.1))
			pts.append(pts[0])
			draw_polyline(pts, Color(Palette.TEXT, 0.28) if i >= value else Palette.STAR_GOLD.darkened(0.2), 3.0, true)


## A descriptor you can tick.
class Chip:
	extends Control
	signal toggled(on: bool)
	var text := ""
	var on := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(UiTheme.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x + 52.0, 84)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			accept_event()
			on = not on
			Sfx.play("click", 1.1 if on else 0.9)
			Sfx.haptic(10, 0.5)
			toggled.emit(on)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		DrawUtil.rrect(self, r, Palette.ACCENT if on else Palette.SURFACE, size.y / 2.0)
		draw_string(UiTheme.font(), Vector2(26, size.y / 2.0 + 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE if on else Palette.TEXT)
