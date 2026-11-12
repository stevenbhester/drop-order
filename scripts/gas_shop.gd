class_name GasShop
extends CanvasLayer
## The gas station: a PRETEND purchase. A full tank costs 1,500 Door Bowl Dollaroos, which are play money
## earned in the game; if you're short it goes "on the tab" (a negative balance). No real money, no store,
## no payment code: pressing Buy only changes two numbers in the save file.

signal closed(bought: bool)

var _root: Control
var _card: PanelContainer
var _timer: Label
var _buy: JuicyButton
var _balance: Label
var _fx: Fx
var _art: Control
var _done := false


func _ready() -> void:
	layer = 70
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0.2, 0.16, 0.24, 0.6)))
	add_child(_root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(900, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffaf0")
	sb.set_corner_radius_all(64)
	sb.set_content_margin_all(56)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 14)
	sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", sb)
	center.add_child(_card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	_card.add_child(col)

	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 190)
	art.draw.connect(_draw_art.bind(art))
	_art = art
	col.add_child(art)
	col.add_child(_label("Out of gas!", 88, Palette.TEXT))
	col.add_child(_label("Every retry burns one tank.\nA free one rolls in every 20 minutes.", 38, Palette.TEXT_SOFT))
	_timer = _label("", 42, GasChip.FUEL.darkened(0.1))
	col.add_child(_timer)

	var offer := PanelContainer.new()
	var ob := StyleBoxFlat.new()
	ob.bg_color = Color("ffeccb")
	ob.set_corner_radius_all(40)
	ob.set_content_margin_all(30)
	ob.anti_aliasing = true
	offer.add_theme_stylebox_override("panel", ob)
	col.add_child(offer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	offer.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := _label("Full tank", 56, Palette.TEXT)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words.add_child(name_l)
	var sub_l := _label("%d gas tanks, right now" % Progress.MAX_GAS, 34, Palette.TEXT_SOFT)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words.add_child(sub_l)
	row.add_child(words)
	var price := Control.new()
	price.custom_minimum_size = Vector2(250, 100)
	price.draw.connect(_draw_price.bind(price))
	row.add_child(price)

	_buy = JuicyButton.new()
	_buy.custom_minimum_size = Vector2(0, 150)
	_buy.font_px = 60
	_buy.bg = Palette.GOOD
	_buy.fg = Color.WHITE
	_buy.icon_name = "coin"
	_buy.label = "Buy for %s" % Progress.commas(Progress.TANK_PRICE) if Progress.dollaroos >= Progress.TANK_PRICE else "Put it on my tab"
	_buy.pressed.connect(_on_buy)
	col.add_child(_buy)

	_balance = _label("", 34, Palette.TEXT_SOFT)
	col.add_child(_balance)
	col.add_child(_label("Door Bowl Dollaroos are pretend money.\nNothing real is ever charged. Promise.", 28, Palette.TEXT_SOFT))

	var no := Button.new()
	no.text = "No thanks, I'll wait"
	no.flat = true
	no.focus_mode = Control.FOCUS_NONE
	no.add_theme_font_size_override("font_size", 38)
	no.add_theme_color_override("font_color", Palette.TEXT_SOFT)
	no.pressed.connect(func():
		Sfx.play("click")
		_close(false))
	col.add_child(no)

	_fx = Fx.new()
	_root.add_child(_fx)
	_refresh()
	Sfx.play("empty")

	# Pop in.
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.12)
	await get_tree().process_frame
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_buy.breathe(true)


func _label(text: String, px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	return l


func _process(_delta: float) -> void:
	_art.queue_redraw()
	if not _done:
		_refresh()


func _refresh() -> void:
	var sec := Progress.seconds_to_next()
	_timer.text = "Next free tank in %d:%02d" % [sec / 60, sec % 60] if sec > 0 else "Tank's full!"
	var d := Progress.dollaroos
	_balance.text = "You have %s Dollaroos." % Progress.commas(d) if d >= 0 else "Your tab: %s Dollaroos." % Progress.commas(-d)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not _done:
		get_viewport().set_input_as_handled()
		_close(false)


func _on_buy() -> void:
	if _done:
		return
	_done = true
	_buy.breathe(false)
	Progress.buy_full_tank()
	Sfx.play("kaching")
	Sfx.haptic(30)
	_buy.label = "Filled up!"
	_buy.icon_name = "gas"
	var at := _buy.global_position + _buy.size / 2.0
	_fx.burst(at, Icons.GOLD, 26, 900.0, 26.0)
	_fx.ring(at, Icons.GOLD, 260.0)
	_refresh()
	var tw := create_tween()
	tw.tween_interval(0.75)
	tw.tween_callback(_close.bind(true))


func _close(bought: bool) -> void:
	_done = true
	closed.emit(bought)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)


func _draw_art(art: Control) -> void:
	var c := art.size / 2.0
	var t := Time.get_ticks_msec() / 1000.0
	art.draw_circle(c, 96.0, Color("ffe1b0"))
	art.draw_set_transform(c, sin(t * 3.0) * 0.12, Vector2.ONE)
	Icons.draw(art, "gas", Vector2.ZERO, 130.0, GasChip.FUEL)
	art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_price(price: Control) -> void:
	var f := UiTheme.font()
	var mid := price.size.y / 2.0
	Icons.draw(price, "coin", Vector2(38, mid), 68.0, Color.WHITE)
	price.draw_string(f, Vector2(84, mid + 20), Progress.commas(Progress.TANK_PRICE), HORIZONTAL_ALIGNMENT_LEFT, -1, 58, Palette.TEXT)
