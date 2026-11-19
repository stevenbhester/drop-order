class_name ChangesCard
extends CanvasLayer
## "BIG CHANGES": for a player who was already past the first boss when the helpers changed (Progress
## .changes_note, set when their save was converted: Progress._load_helpers). One card, once: each change as a
## row with a line saying what's different; tap a row and it opens to say why (one open at a time). "Got it"
## puts it away for good. New players never see it: the Baron's scene on job 6 teaches the same things.

signal closed

var _root: Control
var _card: PanelContainer
var _rows: Array = []            # [{panel, why (Label), arrow (Label)}]
var _done := false


func _ready() -> void:
	layer = 86
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.1, 0.08, 0.16, 0.78)))
	add_child(_root)
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(52)
	sb.set_content_margin_all(40)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 14)
	sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", sb)
	_card.custom_minimum_size = Vector2(minf(980.0, _root.get_viewport_rect().size.x - 44.0), 0)
	_root.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_card.add_child(col)
	col.add_child(_label("BIG CHANGES", 30, Palette.ACCENT, true))
	col.add_child(_label("How help works now", 64, Palette.TEXT, true))
	col.add_child(_label("Tap any of these to see why.", 30, Palette.TEXT_SOFT, true))
	var note: Dictionary = Progress.changes_note
	var spare := int(note.get("spare", 0))
	for it in [
		["radio", "Meet Call Dispatch",
			"Ask Dispatch if you can still finish from where you are. You carry %d calls, and earn one for every job you deliver." % Progress.radio,
			"Most of the time, being stuck really means wondering if you've already gone wrong. Now you can ask that, without being handed the answer."],
		["bulb", "Hints travel with you",
			"You carry %d hints from job to job. They no longer refill on every job." % Progress.hints,
			"A free hint on every job meant using one on every job. A hint gives away part of the puzzle, so now each one is yours to save for when you really need it."],
		["undo", "Undo is free",
			"On the road Undo never runs out now, just like Retry.",
			"Retry was always free, so counting undos only made you draw the same route again. That was a chore, not a challenge."],
		["gas", "Gas has new prices",
			"A can buys 1 hint or %d calls. One refills every hour, and an ad fills the tank.%s" % [Progress.RADIO_PER_CAN,
				(" Your %d spare tank%s topped it up, or became hints." % [spare, "" if spare == 1 else "s"]) if spare > 0 else ""],
			"A can used to make hints unlimited for a whole job, which made it a “solve this for me” button. Now gas tops you up. It doesn't play for you."],
		["gift", "New prizes",
			"A boss pays 4 calls and a hint. A chest fills your tank. Today's daily pays a hint and a call.",
			"Help should come from playing, not from waiting."],
		["jump", "Stuck? Jump first",
			"Jump jets are free now, and offer themselves when you're stuck. Up to 3 jobs can wait on the map.",
			"Coming back later with fresh eyes beats being walked through it."],
		["star", "A hint does more",
			"Never shorter than three tiles. At a dead end it pins where to undo back to, then shows the way on.",
			"If you spend one, it should really help."],
	]:
		col.add_child(_row(it[0], it[1], it[2], it[3]))
	var ok := JuicyButton.new()
	ok.label = "Got it"
	ok.font_px = 48
	ok.bg = Palette.GOOD
	ok.fg = Color.WHITE
	ok.custom_minimum_size = Vector2(0, 124)
	ok.pressed.connect(_finish)
	col.add_child(ok)
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.2)
	Sfx.play("sparkle", 1.0, -4.0)


func _label(t: String, px: int, c: Color, centred := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centred:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## One change: its picture, what it's called, what's different; and under those, hidden until it's tapped, why.
func _row(icon: String, title: String, what: String, why: String) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.SURFACE
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(72, 72)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.draw.connect(func():
		pic.draw_circle(Vector2(36, 36), 36.0, Color(Palette.ACCENT, 0.16))
		Icons.draw(pic, icon, Vector2(36, 36), 48.0, Palette.TEXT))
	h.add_child(pic)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 4)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(texts)
	texts.add_child(_label(title, 36, Palette.TEXT))
	texts.add_child(_label(what, 27, Palette.TEXT_SOFT))
	var y := _label("Why: " + why, 27, Palette.ACCENT.darkened(0.25))
	y.visible = false
	texts.add_child(y)
	var arrow := _label("why?", 24, Palette.TEXT_SOFT)
	arrow.custom_minimum_size = Vector2(70, 0)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(arrow)
	var entry := {"panel": panel, "why": y, "arrow": arrow}
	_rows.append(entry)
	panel.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			panel.accept_event()
			var open: bool = not y.visible
			for r in _rows:
				(r["why"] as Label).visible = false
				(r["arrow"] as Label).text = "why?"
			y.visible = open
			arrow.text = "" if open else "why?"
			Sfx.play("tick", 1.1 if open else 0.9, -6.0))
	return panel


func _process(_delta: float) -> void:
	var v := _root.get_viewport_rect().size
	var sz := _card.get_combined_minimum_size()
	_card.size = sz
	_card.position = Vector2((v.x - sz.x) / 2.0, maxf(20.0, (v.y - sz.y) / 2.0))


func _finish() -> void:
	if _done:
		return
	_done = true
	Sfx.play("click")
	Progress.changes_note["due"] = false
	Progress.save_now()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		closed.emit()
		queue_free())
