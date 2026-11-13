class_name OptionsMenu
extends CanvasLayer
## The options card: how you steer (draw or D-pad), which hand the D-pad is for, where the package chute
## goes (left, right, top or bottom), the route preview chip, colorblind mode (aka Paul mode), night mode, horizontal play, sound volume and
## haptic strength. Every change is saved straight away (Progress.set_option) and
## takes effect live: Main re-themes for night mode and turns the screen for horizontal play, the game
## re-lays its controls out for the D-pad and the hand.

signal closed

const ROW_H := 116.0

var _root: Control
var _card: PanelContainer
var _rows: VBoxContainer
var _t := 0.0


func _ready() -> void:
	layer = 80
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.1, 0.08, 0.16, 0.62)))
	_root.gui_input.connect(func(e: InputEvent):
		# A tap outside the card closes it.
		if e is InputEventMouseButton and e.pressed and not _card.get_global_rect().has_point(e.global_position):
			_close())
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(920, 0)
	center.add_child(_card)
	_style_card()
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	_card.add_child(_rows)
	_build()
	Progress.settings_changed.connect(_on_changed)
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2.ONE * 0.85
	_card.modulate.a = 0.0
	var tw := _card.create_tween().set_parallel()
	tw.tween_property(_card, "scale", Vector2.ONE * _fit_k(), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.15)
	Sfx.play("pop", 1.1, -6.0)


## Sideways the screen is short: shrink the card to fit.
func _fit_k() -> float:
	var h := _card.get_combined_minimum_size().y
	return minf(1.0, (_root.get_viewport_rect().size.y - 40.0) / maxf(h, 1.0))


func _style_card() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(64)
	sb.set_content_margin_all(48)
	sb.content_margin_top = 40
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 14)
	sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", sb)


func _build() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var head := HBoxContainer.new()
	var title := _label("Options", 76, Palette.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(title)
	var done := JuicyButton.new()
	done.label = "Done"
	done.font_px = 42
	done.bg = Palette.GOOD
	done.fg = Color.WHITE
	done.custom_minimum_size = Vector2(220, 104)
	done.pressed.connect(_close)
	head.add_child(done)
	_rows.add_child(head)
	_gap(8)
	_rows.add_child(_choice("Steering", "drive_mode", [["draw", "Draw", "finger"], ["dpad", "D-pad", "dpad"]]))
	_rows.add_child(_choice("D-pad hand", "left_hand", [[false, "Right", "right"], [true, "Left", "left"]]))
	_rows.add_child(_sides())
	_rows.add_child(_toggle("Route preview", "peek", "peek"))
	_rows.add_child(_toggle("Colorblind mode", "colorblind", "eye", "aka Paul mode"))
	_rows.add_child(_toggle("Night mode", "night", "moon"))
	_rows.add_child(_toggle("Play sideways", "landscape", "turn"))
	_gap(6)
	_rows.add_child(_slider("Sound", "volume", "sound", ["Off", "Loud"]))
	_rows.add_child(_slider("Haptics", "haptics", "buzz", ["None", "Max"]))


func _gap(h: float) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(g)


func _label(text: String, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _row(name: String, icon: String, sub := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.add_theme_constant_override("separation", 18)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(64, ROW_H)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func(): Icons.draw(ic, icon, Vector2(32, ROW_H / 2.0), 52.0, Palette.TEXT_SOFT))
	row.add_child(ic)
	var l := _label(name, 44, Palette.TEXT)
	l.custom_minimum_size = Vector2(280, 0)
	if sub == "":
		row.add_child(l)
		return row
	# A little line under the name.
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -6)
	names.add_child(l)
	names.add_child(_label(sub, 28, Palette.TEXT_SOFT))
	row.add_child(names)
	return row


## Two (or more) chunky choices side by side; the chosen one is filled in.
func _choice(name: String, key: String, opts: Array) -> HBoxContainer:
	var icon: String = opts[0][2] if key != "left_hand" else ("left" if Progress.left_hand else "right")
	var row := _row(name, "steer" if key == "drive_mode" else "hand")
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(box)
	for o in opts:
		var on: bool = Progress.get(key) == o[0]
		var b := JuicyButton.new()
		b.label = o[1]
		b.icon_name = o[2]
		b.font_px = 36
		b.icon_scale = 0.8
		b.custom_minimum_size = Vector2(196, 96)
		b.bg = Palette.ACCENT if on else Color(0, 0, 0, 0)
		b.fg = Color.WHITE if on else Color(0, 0, 0, 0)
		var value: Variant = o[0]
		b.pressed.connect(func():
			if Progress.get(key) == value:
				return
			Sfx.play("click")
			Sfx.haptic(12, 0.6)
			if key == "drive_mode":
				Progress.set_drive_mode(value)
			else:
				Progress.set_option(key, value))
		box.add_child(b)
	return row


## Where the package chute goes: four choices on a line of their own under the name.
func _sides() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var row := _row("Package chute", "chute")
	var note := _label("always on top sideways" if Progress.landscape else "", 30, Palette.TEXT_SOFT)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(note)
	col.add_child(row)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	col.add_child(box)
	for o in [["left", "Left"], ["right", "Right"], ["top", "Top"], ["bottom", "Bottom"]]:
		var on: bool = Progress.stack_side == o[0]
		var b := JuicyButton.new()
		b.label = o[1]
		b.icon_name = "side_" + o[0]
		b.font_px = 34
		b.icon_scale = 0.8
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		b.bg = Palette.ACCENT if on else Color(0, 0, 0, 0)
		b.fg = Color.WHITE if on else Color(0, 0, 0, 0)
		var value: String = o[0]
		b.pressed.connect(func():
			if Progress.stack_side == value:
				return
			Sfx.play("click")
			Sfx.haptic(12, 0.6)
			Progress.set_option("stack_side", value))
		box.add_child(b)
	return col


## A big switch: a pill with a knob that slides across.
func _toggle(name: String, key: String, icon: String, sub := "") -> HBoxContainer:
	var row := _row(name, icon, sub)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var sw := Switch.new()
	sw.on = bool(Progress.get(key))
	sw.custom_minimum_size = Vector2(170, 96)
	sw.toggled.connect(func(v: bool):
		Sfx.play("click", 1.1 if v else 0.9)
		Sfx.haptic(14, 0.7)
		Progress.set_option(key, v))
	row.add_child(sw)
	return row


func _slider(name: String, key: String, icon: String, ends: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	var row := _row(name, icon)
	var val := _label("", 36, Palette.TEXT_SOFT)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	col.add_child(row)
	var sl := OptionSlider.new()
	sl.value = float(Progress.get(key))
	sl.custom_minimum_size = Vector2(0, 92)
	sl.ends = ends
	var show := func(v: float):
		val.text = ends[0] if v <= 0.01 else ("%d%%" % int(round(v * 100.0)))
	show.call(sl.value)
	sl.moved.connect(func(v: float):
		show.call(v)
		Progress.set(key, v)
		if key == "volume":
			Progress.apply_volume()
		elif key == "haptics":
			# Feel it: a tap at the new strength (none at zero).
			Sfx.haptic(16))
	sl.stepped.connect(func(v: float):
		if key == "volume":
			Sfx.play("tick", 0.8 + 0.6 * v, -4.0))
	sl.released.connect(func(v: float): Progress.set_option(key, v))
	col.add_child(sl)
	return col


func _on_changed() -> void:
	# Night mode re-colours the card; any change refreshes which choices are lit.
	_style_card()
	_build()
	_refit.call_deferred()


func _refit() -> void:
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2.ONE * _fit_k()


func _close() -> void:
	if Progress.settings_changed.is_connected(_on_changed):
		Progress.settings_changed.disconnect(_on_changed)
	Sfx.play("click")
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := _card.create_tween().set_parallel()
	tw.tween_property(_card, "scale", Vector2.ONE * 0.9, 0.14)
	tw.tween_property(_card, "modulate:a", 0.0, 0.14)
	tw.chain().tween_callback(func():
		closed.emit()
		queue_free())


## A pill switch with a knob.
class Switch:
	extends Control
	signal toggled(on: bool)
	var on := false
	var _k := -1.0

	func _ready() -> void:
		_k = 1.0 if on else 0.0
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			accept_event()
			on = not on
			toggled.emit(on)

	func _process(delta: float) -> void:
		var want := 1.0 if on else 0.0
		if absf(_k - want) > 0.001:
			_k = move_toward(_k, want, delta * 7.0)
			queue_redraw()

	func _draw() -> void:
		var h := size.y * 0.78
		var r := Rect2(Vector2(0, (size.y - h) / 2.0), Vector2(size.x, h))
		var track := Color(Palette.TEXT, 0.16).lerp(Palette.GOOD, _k)
		DrawUtil.rrect(self, Rect2(r.position + Vector2(0, 5), r.size), Color(0, 0, 0, 0.12), h / 2.0)
		DrawUtil.rrect(self, r, track, h / 2.0)
		var knob := h * 0.42
		var x := lerpf(r.position.x + h / 2.0, r.end.x - h / 2.0, _k)
		draw_circle(Vector2(x, size.y / 2.0 + 4), knob, Color(0, 0, 0, 0.18))
		draw_circle(Vector2(x, size.y / 2.0), knob, Color.WHITE)


## A chunky slider: drag (or tap) anywhere along it. Emits moved while dragging, stepped every tenth, and
## released at the end.
class OptionSlider:
	extends Control
	signal moved(value: float)
	signal stepped(value: float)
	signal released(value: float)
	var value := 0.5
	var ends: Array = ["", ""]
	var _down := false
	var _last_step := -1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _set_from(x: float) -> void:
		var pad := size.y * 0.42
		value = clampf((x - pad) / maxf(size.x - pad * 2.0, 1.0), 0.0, 1.0)
		var step := int(round(value * 10.0))
		if step != _last_step:
			_last_step = step
			stepped.emit(value)
		moved.emit(value)
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_down = e.pressed
			if _down:
				_set_from(e.position.x)
			else:
				released.emit(value)
		elif e is InputEventMouseMotion and _down:
			accept_event()
			_set_from(e.position.x)

	func _draw() -> void:
		var pad := size.y * 0.42
		var y := size.y / 2.0
		var w := size.x - pad * 2.0
		DrawUtil.rrect(self, Rect2(pad - 14, y - 14, w + 28, 28), Color(Palette.TEXT, 0.14), 14)
		DrawUtil.rrect(self, Rect2(pad - 14, y - 14, w * value + 28, 28), Palette.ACCENT, 14)
		var x := pad + w * value
		var r := size.y * 0.36 * (1.12 if _down else 1.0)
		draw_circle(Vector2(x, y + 5), r, Color(0, 0, 0, 0.18))
		draw_circle(Vector2(x, y), r, Color.WHITE)
		draw_circle(Vector2(x, y), r * 0.42, Palette.ACCENT)
