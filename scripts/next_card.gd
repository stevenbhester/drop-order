class_name NextCard
extends CanvasLayer
## After a win, once the van has driven up the map to the stop just unlocked: a sheet from the bottom with the
## next level and one big Drive! button, so a player in a rhythm taps straight through. If a side road
## branches off the stop just beaten, a Detour button sits under it, saying what the twist is and what it
## wins (a locked one uses a key, or says it needs one). Tapping above the sheet (or "Stay on the map")
## just leaves the map showing.
##
## With `detour_only` (a detour's ticket tapped on the map), it's that detour's card alone: its name, the
## job it branches off, its twist and prize, and one button into it (or to unlock it with a key). No main
## level on it, so Play can only mean the detour.

signal go_pressed
signal detour_pressed
signal closed

## The level up next, whether starting it costs a gas tank, and the side road off this stop (or empty).
var level: LevelData
var costs_gas := false
var detour: Dictionary = {}
var detour_only := false

var _root: Control
var _sheet: PanelContainer
var _done := false


func _ready() -> void:
	layer = 70
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.1, 0.08, 0.16, 0.35)))
	_root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and not _sheet.get_global_rect().has_point(e.global_position):
			_finish("close"))
	add_child(_root)
	var vp := _root.get_viewport_rect().size
	var bottom := UiTheme.insets(_root.get_viewport()).y
	_sheet = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.CARD
	sb.set_corner_radius_all(56)
	sb.set_content_margin_all(44)
	sb.content_margin_bottom = 44.0 + bottom
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 30
	sb.anti_aliasing = true
	_sheet.add_theme_stylebox_override("panel", sb)
	_sheet.custom_minimum_size = Vector2(vp.x - 40.0, 0)
	_root.add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	_sheet.add_child(col)

	if detour_only:
		_detour_sheet(col)
		_slide_up.call_deferred(vp)
		return
	var boss_next := Boss.is_level(level.number)
	var kicker := "NEXT STOP  ·  BOSS FIGHT!" if boss_next else ("NEXT STOP  ·  CHALLENGE!" if level.challenge else "NEXT STOP")
	col.add_child(_label(kicker, 32, Palette.ACCENT if boss_next or level.challenge else Palette.TEXT_SOFT))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 26)
	var pin := Control.new()
	pin.custom_minimum_size = Vector2(130, 130)
	pin.draw.connect(func():
		var c := pin.size / 2.0
		pin.draw_circle(c + Vector2(0, 8), 62, Color(0, 0, 0, 0.16))
		pin.draw_circle(c, 62, Color.WHITE)
		pin.draw_circle(c, 54, Palette.ACCENT)
		var f := UiTheme.font()
		var txt := str(level.number)
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x
		pin.draw_string(f, c + Vector2(-w / 2.0, 20), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color.WHITE))
	head.add_child(pin)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _label("“%s”" % level.title, 64, Palette.TEXT)
	title.clip_text = true
	names.add_child(title)
	names.add_child(_label("Job %d" % level.number, 36, Palette.TEXT_SOFT))
	head.add_child(names)
	col.add_child(head)

	var go := JuicyButton.new()
	go.icon_name = "play"
	go.label = "Drive!"
	go.font_px = 76
	go.bg = Palette.GOOD
	go.fg = Color.WHITE
	go.custom_minimum_size = Vector2(0, 180)
	if costs_gas:
		go.badge = "1"
		go.badge_icon = "gas"
		go.badge_color = GasChip.FUEL
	go.pressed.connect(_finish.bind("go"))
	go.ready.connect(go.breathe.bind(true), CONNECT_DEFERRED)
	col.add_child(go)

	if not detour.is_empty():
		var locked := Progress.side_locked(detour)
		var dname := str(detour.get("title", "Detour"))
		var boss := Boss.is_boss(detour)
		var dt := JuicyButton.new()
		dt.icon_name = "key" if locked else "turn"
		dt.font_px = 40
		dt.bg = Color("ffd166")
		dt.fg = Color("2b2233")          # (dark ink on yellow, night mode too)
		dt.custom_minimum_size = Vector2(0, 116)
		var twist := str(SideRoads.TWISTS.get(str(detour.get("twist", "")), "A twist"))
		var reward := str(detour.get("reward", ""))
		var line := twist + (" · win the %s" % Cosmetics.name_of(reward) if reward != "" else "") + " · free to play"
		if boss:
			dt.bg = Color("ff8a8a")
			line = "%s is waiting · beat him for %s · free to play" % [Boss.NAME, Boss.prize(detour)] if Boss.prize(detour) != "" else "%s wants a rematch · free to play" % Boss.NAME
		if locked and Progress.keys > 0:
			# Locked, but there's a key in hand: the button uses it.
			dt.label = ("Unlock boss fight: %s" if boss else "Unlock detour: %s") % dname
			dt.badge = str(Progress.keys)
			dt.badge_icon = "key"
			dt.badge_color = Icons.GOLD_DARK
			line = "Uses 1 of your keys · " + line.replace(" · free to play", "")
			dt.pressed.connect(func():
				if Progress.use_key(str(detour.get("id", ""))):
					Sfx.play("thunk", 1.4, -4.0)
					Sfx.play("sparkle", 1.0, -4.0)
				_finish("detour"))
		elif locked:
			# Locked with no key: it says where keys come from, and stays put.
			dt.label = ("Boss fight locked: %s" if boss else "Detour locked: %s") % dname
			dt.dim = true
			line = "Needs a key. Keys lie on the road in some jobs: pick one up on the way to a win."
			dt.pressed.connect(func():
				Sfx.play("bonk", 1.1, -6.0)
				dt.pop())
		else:
			dt.label = ("Boss fight: %s" if boss else "Detour available: %s") % dname
			dt.pressed.connect(_finish.bind("detour"))
		col.add_child(dt)
		var sub := _label(line, 32, Palette.TEXT_SOFT)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(sub)

	var stay := Button.new()
	stay.flat = true
	stay.text = "Stay on the map"
	stay.add_theme_font_size_override("font_size", 34)
	stay.add_theme_color_override("font_color", Palette.TEXT_SOFT)
	stay.focus_mode = Control.FOCUS_NONE
	stay.pressed.connect(_finish.bind("close"))
	col.add_child(stay)

	_slide_up.call_deferred(vp)


## Up from the bottom, once the sheet knows its height.
func _slide_up(vp: Vector2) -> void:
	await get_tree().process_frame
	var h := _sheet.get_combined_minimum_size().y
	_sheet.position = Vector2(20, vp.y)
	_sheet.size = Vector2(vp.x - 40.0, h)
	_sheet.create_tween().tween_property(_sheet, "position:y", vp.y - h + 10.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("pop", 1.0, -6.0)


## The detour's own card: what it is and one way in.
func _detour_sheet(col: VBoxContainer) -> void:
	var locked := Progress.side_locked(detour)
	var dname := str(detour.get("title", "Detour"))
	var boss := Boss.is_boss(detour)
	col.add_child(_label("BOSS FIGHT" if boss else "DETOUR", 32, Palette.ACCENT if boss else Palette.TEXT_SOFT))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 26)
	var pin := Control.new()
	pin.custom_minimum_size = Vector2(130, 130)
	pin.draw.connect(func():
		var c := pin.size / 2.0
		pin.draw_circle(c + Vector2(0, 8), 62, Color(0, 0, 0, 0.16))
		pin.draw_circle(c, 62, Color.WHITE)
		pin.draw_circle(c, 54, Color("ff8a8a") if boss else Color("ffd166"))
		if boss:
			Boss.draw(pin, c + Vector2(0, 40), 84.0, 0.0, "smug")
		elif locked:
			Icons.draw(pin, "key", c, 64.0, Color("2b2233"))
		else:
			# A signpost pointing off the main road.
			var ink := Color("2b2233")
			pin.draw_line(c + Vector2(-6, -30), c + Vector2(-6, 34), ink, 7.0)
			pin.draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -30), c + Vector2(18, -30), c + Vector2(32, -16),
				c + Vector2(18, -2), c + Vector2(-20, -2)]), ink)
			pin.draw_line(c + Vector2(-20, 34), c + Vector2(8, 34), ink, 6.0))
	head.add_child(pin)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _label("“%s”" % dname, 64, Palette.TEXT)
	title.clip_text = true
	names.add_child(title)
	names.add_child(_label("Branches off job %d" % int(detour.get("after", 0)), 36, Palette.TEXT_SOFT))
	head.add_child(names)
	col.add_child(head)
	var twist := str(SideRoads.TWISTS.get(str(detour.get("twist", "")), "A twist"))
	var reward := str(detour.get("reward", ""))
	var line := twist + (" · win the %s" % Cosmetics.name_of(reward) if reward != "" else "") + " · free to play"
	if boss:
		line = "%s is waiting · beat him for %s · free to play" % [Boss.NAME, Boss.prize(detour)] if Boss.prize(detour) != "" else "%s wants a rematch · free to play" % Boss.NAME
	var go := JuicyButton.new()
	go.font_px = 64
	go.bg = Color("ff8a8a") if boss else Color("ffd166")
	go.fg = Color("2b2233")
	go.custom_minimum_size = Vector2(0, 170)
	if locked and Progress.keys > 0:
		go.icon_name = "key"
		go.label = "Unlock with a key"
		go.badge = str(Progress.keys)
		go.badge_icon = "key"
		go.badge_color = Icons.GOLD_DARK
		line = "Uses 1 of your keys · " + line.replace(" · free to play", "")
		go.pressed.connect(func():
			if Progress.use_key(str(detour.get("id", ""))):
				Sfx.play("thunk", 1.4, -4.0)
				Sfx.play("sparkle", 1.0, -4.0)
				Sfx.haptic(25)
			_finish("detour"))
	elif locked:
		go.icon_name = "lock"
		go.label = "Locked"
		go.dim = true
		line = "Needs a key. Keys lie on the road in some jobs: pick one up on the way to a win."
		go.pressed.connect(func():
			Sfx.play("bonk", 1.1, -6.0)
			go.pop())
	else:
		go.icon_name = "play"
		go.label = "Fight him!" if boss else "Take the detour"
		go.pressed.connect(_finish.bind("detour"))
		go.ready.connect(go.breathe.bind(true), CONNECT_DEFERRED)
	var sub := _label(line, 34, Palette.TEXT_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	col.add_child(go)
	var stay := Button.new()
	stay.flat = true
	stay.text = "Stay on the map"
	stay.add_theme_font_size_override("font_size", 34)
	stay.add_theme_color_override("font_color", Palette.TEXT_SOFT)
	stay.focus_mode = Control.FOCUS_NONE
	stay.pressed.connect(_finish.bind("close"))
	col.add_child(stay)


func _label(text: String, px: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	return l


func _finish(what: String) -> void:
	if _done:
		return
	_done = true
	Sfx.play("click")
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := _root.get_viewport_rect().size
	var tw := _sheet.create_tween()
	tw.tween_property(_sheet, "position:y", vp.y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		match what:
			"go":
				go_pressed.emit()
			"detour":
				detour_pressed.emit()
			_:
				closed.emit()
		queue_free())
