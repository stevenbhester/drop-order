class_name LevelSelect
extends Control
## The level select: a road trip map (RoadMap) you scroll through, every level a stop on the road, under
## the gas gauge and wallet, with the Daily puzzle and the Garage docked at the bottom.
## "--map-scroll=N" opens it scrolled to level N (for screenshots).

signal level_chosen(index: int)
signal side_chosen(id: String)
signal daily_pressed
signal garage_pressed
signal title_pressed
signal options_pressed

var levels: Array = []
var map: RoadMap
var _modal: Node
var _dock: Control
var _fade: Control
var _top := 0.0
var _bottom := 0.0


func setup(lvls: Array) -> void:
	levels = lvls


func _ready() -> void:
	# Our parent is a plain Node, so anchors alone don't size us: track the viewport.
	theme = UiTheme.theme()
	var ins := UiTheme.insets(get_viewport())
	_top = ins.x
	_bottom = ins.y

	map = RoadMap.new()
	map.setup(levels)
	map.stop_pressed.connect(func(i: int): level_chosen.emit(i))
	map.side_pressed.connect(func(id: String): side_chosen.emit(id))
	map.chest_pressed.connect(_open_chest)
	map.reset_pressed.connect(func():
		Progress.reset()
		level_chosen.emit(0))
	add_child(map)
	if Palette.night:
		# Night mode: the whole road trip under a moonlit tint.
		map.modulate = Color(0.6, 0.62, 0.8)

	# Behind the top bar, the map fades into the cream of the bar.
	_fade = Control.new()
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.draw.connect(_draw_fade)
	add_child(_fade)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 36
	bar.offset_right = -36
	bar.offset_top = 40 + _top
	bar.offset_bottom = 150 + _top
	add_child(bar)
	var home := JuicyButton.new()
	home.icon_name = "play"
	home.custom_minimum_size = Vector2(112, 102)
	home.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	home.pressed.connect(func():
		Sfx.play("click")
		title_pressed.emit())
	bar.add_child(home)
	var gear := JuicyButton.new()
	gear.icon_name = "gear"
	gear.custom_minimum_size = Vector2(112, 102)
	gear.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gear.pressed.connect(func():
		Sfx.play("click")
		options_pressed.emit())
	bar.add_child(gear)
	var gas := GasChip.new()
	gas.shop_requested.connect(_open_shop)
	bar.add_child(gas)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	bar.add_child(CoinChip.new())

	# The dock: progress tally, then Daily and Garage.
	_dock = Control.new()
	_dock.draw.connect(_draw_dock)
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dock)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.name = "Row"
	_dock.add_child(row)
	var today := Daily.today()
	var daily := JuicyButton.new()
	daily.icon_name = "calendar"
	daily.label = "Daily #%d" % Daily.number(today)
	daily.font_px = 40
	daily.custom_minimum_size = Vector2(450, 120)
	# The streak burns inside the button; if today's is still to do, the button breathes.
	daily.flame = Progress.streak(today)
	daily.pressed.connect(func():
		Sfx.play("click")
		daily_pressed.emit())
	row.add_child(daily)
	if not Progress.daily_record(today).get("done", false):
		daily.ready.connect(daily.breathe.bind(true), CONNECT_DEFERRED)
	var garage := JuicyButton.new()
	garage.icon_name = "paint"
	garage.label = "Garage"
	garage.font_px = 40
	garage.custom_minimum_size = Vector2(450, 120)
	garage.pressed.connect(func():
		Sfx.play("click")
		garage_pressed.emit())
	row.add_child(garage)

	_fit()
	get_viewport().size_changed.connect(_fit)
	var focus_on: int = map.next
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map-scroll="):
			focus_on = a.trim_prefix("--map-scroll=").to_int() - 1
	map.focus(focus_on)


## A milestone chest tapped open: it pops open over the map, then any hat in it gets its own unlock card.
func _open_chest(n: int) -> void:
	var got := Progress.open_chest(n)
	if got.is_empty():
		return
	var card := ChestCard.new()
	card.got = got
	card.level_number = n
	add_child(card)
	card.closed.connect(func():
		map.queue_redraw()
		if got.get("hat", "") != "":
			var u := UnlockCard.new()
			u.item = got["hat"]
			add_child(u))


func _dock_h() -> float:
	return 250.0 + _bottom


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	map.position = Vector2.ZERO
	map.size = size
	map.pad_top = 170.0 + _top
	map.pad_bottom = _dock_h() - 10.0
	_fade.position = Vector2.ZERO
	_fade.size = Vector2(size.x, 220.0 + _top)
	_fade.queue_redraw()
	_dock.position = Vector2(0, size.y - _dock_h())
	_dock.size = Vector2(size.x, _dock_h())
	var row := _dock.get_node("Row") as HBoxContainer
	row.position = Vector2(0, 104)
	row.size = Vector2(size.x, 120)
	_dock.queue_redraw()


func _draw_fade() -> void:
	var s := _fade.size
	var solid := Backdrop.TOP
	var clear := Color(solid, 0.0)
	var mid := s.y * 0.62
	_fade.draw_rect(Rect2(Vector2.ZERO, Vector2(s.x, mid)), Color(solid, 0.94))
	_fade.draw_polygon(PackedVector2Array([Vector2(0, mid), Vector2(s.x, mid), s, Vector2(0, s.y)]),
		PackedColorArray([Color(solid, 0.94), Color(solid, 0.94), clear, clear]))


func _draw_dock() -> void:
	var s := _dock.size
	DrawUtil.rrect(_dock, Rect2(Vector2(0, -14), s + Vector2(0, 60)), Color(0, 0, 0, 0.1), 46)
	DrawUtil.rrect(_dock, Rect2(Vector2.ZERO, s + Vector2(0, 60)), Backdrop.TOP, 46)
	var done := 0
	for L in levels:
		if Progress.is_complete(L.number):
			done += 1
	var f := UiTheme.font()
	var a := "%d / %d delivered" % [done, levels.size()]
	var b := "%d / %d" % [Progress.total_stars(), levels.size() * 3]
	var aw := f.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	var bw := f.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	var x := (s.x - (aw + 50.0 + 44.0 + bw)) / 2.0
	_dock.draw_string(f, Vector2(x, 64), a, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Palette.TEXT_SOFT)
	Icons.star(_dock, Vector2(x + aw + 50.0 + 14.0, 51), 21.0, Palette.STAR_GOLD)
	_dock.draw_string(f, Vector2(x + aw + 50.0 + 44.0, 64), b, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Palette.TEXT_SOFT)


func _open_shop() -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	_modal = GasShop.new()
	add_child(_modal)
