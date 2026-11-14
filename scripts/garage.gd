class_name Garage
extends Control
## Dress up the van: the van turns slowly on a pad up top, and below are the rides, paints and toppers. Owned
## ones are worn with a tap (tap a worn topper or ride to take it off); ones not found yet show a "?" and where to look.

signal back_pressed

var levels: Array = []
var _van: Van
var _t := 0.0
var _grid: GridContainer
var _top := 0.0
var _tabs: HBoxContainer
var _col: VBoxContainer
var _tab := 0
var _fx: Fx


func setup(lvls: Array) -> void:
	levels = lvls


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	theme = UiTheme.theme()
	_top = UiTheme.insets(get_viewport()).x
	var v := size

	var back := JuicyButton.new()
	back.icon_name = "grid"
	back.size = Vector2(112, 102)
	back.position = Vector2(36, 40 + _top)
	back.pressed.connect(func():
		Sfx.play("click")
		back_pressed.emit())
	add_child(back)

	_van = Van.new()
	_van.size = 380.0
	_van.position = Vector2(v.x / 2.0, 470 + _top)
	add_child(_van)

	# Tabs, by what the cosmetics change. Locked ones (nothing in them found yet) are greyed out.
	_tabs = HBoxContainer.new()
	_tabs.position = Vector2(40, 750 + _top)
	_tabs.size = Vector2(v.x - 80, 100)
	_tabs.add_theme_constant_override("separation", 14)
	add_child(_tabs)
	for i in Cosmetics.TABS.size():
		var tb := JuicyButton.new()
		tb.label = str(Cosmetics.TABS[i]["name"])
		tb.font_px = 30
		tb.custom_minimum_size = Vector2(0, 92)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(_pick_tab.bind(i))
		_tabs.add_child(tb)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 870 + _top)
	scroll.size = Vector2(v.x - 80, v.y - 870 - _top - 40)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_col = VBoxContainer.new()
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_theme_constant_override("separation", 20)
	scroll.add_child(_col)
	_show_tab(0)
	for a in OS.get_cmdline_user_args():
		# Debug: --tab=N opens the garage on tab N (if it's open).
		if a.begins_with("--tab=") and tab_open(a.trim_prefix("--tab=").to_int()):
			_show_tab.call_deferred(a.trim_prefix("--tab=").to_int())
	_fx = Fx.new()
	add_child(_fx)
	Progress.changed.connect(queue_redraw)
	# Coming in: whatever it's riding shows off once.
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(_van):
			_van.celebrate())


## Is tab `i` open: always the first; the others once something in them beyond the free defaults is yours.
static func tab_open(i: int) -> bool:
	if i == 0:
		return true
	for id in Cosmetics.ORDER:
		if Cosmetics.kind_of(id) in Cosmetics.TABS[i]["kinds"] and Cosmetics.stars_for(id) != 0 and Progress.owns(id):
			return true
	return false


## The stars the first thing in tab `i` unlocks at.
static func tab_unlock_stars(i: int) -> int:
	var best := 9999
	for id in Cosmetics.ORDER:
		if Cosmetics.kind_of(id) in Cosmetics.TABS[i]["kinds"] and Cosmetics.stars_for(id) > 0:
			best = mini(best, Cosmetics.stars_for(id))
	return best


func _pick_tab(i: int) -> void:
	if not tab_open(i):
		Sfx.play("bonk", 1.2, -8.0)
		var b: JuicyButton = _tabs.get_child(i)
		b.pop()
		_fx.say(b.get_global_rect().get_center() + Vector2(0, 90), "Unlocks at %d ★" % tab_unlock_stars(i), Palette.TEXT, 34)
		return
	Sfx.play("click")
	_show_tab(i)


func _show_tab(i: int) -> void:
	_tab = i
	for k in _tabs.get_child_count():
		var b: JuicyButton = _tabs.get_child(k)
		var open := tab_open(k)
		b.icon_name = "" if open else "lock"
		b.dim = not open
		if k == i:
			b.recolor(Palette.GOOD, Color.WHITE)
		else:
			b.recolor(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	for c in _col.get_children():
		c.queue_free()
	for kind in Cosmetics.TABS[i]["kinds"]:
		var head := Label.new()
		head.text = str(Cosmetics.KIND_TITLES.get(kind, kind))
		head.add_theme_font_size_override("font_size", 44)
		head.add_theme_color_override("font_color", Palette.TEXT_SOFT)
		_col.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 22)
		grid.add_theme_constant_override("v_separation", 22)
		_col.add_child(grid)
		for id in Cosmetics.ORDER:
			if Cosmetics.kind_of(id) == kind:
				grid.add_child(_tile(id))


## Where each cosmetic can be found, from the levels' gifts.
func _where(id: String) -> String:
	if Cosmetics.by_stars(id) and Cosmetics.stars_for(id) >= 0:
		return "Unlocks at %d ★ (you have %d)" % [Cosmetics.stars_for(id), Progress.total_stars()]
	for L in levels:
		if L.gift_item == id:
			return "Level %d" % L.number
	for L in Daily.puzzles():
		if L.gift_item == id:
			return "A daily puzzle"
	return SideRoads.where(id)


func _tile(id: String) -> Button:
	var t := ItemTile.new()
	t.id = id
	t.where = _where(id)
	t.custom_minimum_size = Vector2(306, 250)
	t.pressed.connect(func():
		if not Progress.owns(id):
			Sfx.play("bonk", 1.2, -8.0)
			t.pop()
			return
		Progress.wear(id)
		Sfx.play("pop", 1.1)
		Sfx.haptic(10)
		if Cosmetics.kind_of(id) == "trail":
			t.replay()
		# Picking a ride (or the van back) shows off its win celebration; anything else just bounces.
		if Cosmetics.kind_of(id) == "ride" or (Cosmetics.kind_of(id) == "paint" and Progress.ride == ""):
			_van.celebrate.call_deferred()
		else:
			_van.squash()
		_fx.burst(_van.position, Cosmetics.tint(id), 16, 600.0, 20.0)
		for g in get_tree().get_nodes_in_group("garage_tiles"):
			g.queue_redraw())
	return t


func _process(delta: float) -> void:
	_t += delta
	_van.rotation = sin(_t * 0.6) * 0.5 - 0.3
	_van.target_rotation = _van.rotation
	queue_redraw()


func _draw() -> void:
	var c := _van.position
	var f := UiTheme.font()
	var title := "Garage"
	var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 90).x
	draw_string(f, Vector2((size.x - w) / 2.0, 120 + _top), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 90, Palette.TEXT)
	draw_set_transform(c + Vector2(0, 20), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 320, Color(1, 1, 1, 0.55))
	draw_arc(Vector2.ZERO, 320, 0, TAU, 64, Color(Palette.TEXT, 0.08), 10.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var found := 0
	for id in Cosmetics.ORDER:
		if Progress.owns(id):
			found += 1
	var line := "%s  ·  %s" % [Cosmetics.name_of(Progress.ride) if Progress.ride != "" else Cosmetics.name_of(Progress.paint),
		Cosmetics.name_of(Progress.topper) if Progress.topper != "" else "no topper"]
	var lw := f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	draw_string(f, Vector2((size.x - lw) / 2.0, 670 + _top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Palette.TEXT)
	var tally := "%d / %d found · presents, side roads and chests" % [found, Cosmetics.ORDER.size()]
	var tw := f.get_string_size(tally, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(f, Vector2((size.x - tw) / 2.0, 720 + _top), tally, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.TEXT_SOFT)


## One cosmetic: a mini van wearing it (or a "?"), its name, and where it's from.
class ItemTile:
	extends JuicyButton

	var id := ""
	var where := ""
	var _t := 0.0
	var _trail: TrailPreview

	func _ready() -> void:
		super._ready()
		add_to_group("garage_tiles")
		# Buildings show two little houses built that way.
		if Cosmetics.kind_of(id) == "building" and Progress.owns(id):
			var bp := Looks.building_preview(id, 200.0)
			bp.position = Vector2(153, 100)
			add_child(bp)
		# A trail shows a little stretch of road torn up its way.
		if Cosmetics.kind_of(id) == "trail" and Progress.owns(id):
			_trail = TrailPreview.new()
			_trail.style = id
			_trail.tile = 52.0
			_trail.position = Vector2(153, 100)
			add_child(_trail)

	func replay() -> void:
		if _trail:
			_trail.replay()

	func _process(delta: float) -> void:
		_t += delta
		if id in Cosmetics.ANIMATED or Looks.is_look(Cosmetics.kind_of(id)):
			queue_redraw()

	func _draw() -> void:
		var f := UiTheme.font()
		var owned := Progress.owns(id)
		var worn := Progress.wearing(id)
		var mid := Vector2(size.x / 2.0, 100)
		if worn:
			DrawUtil.rrect(self, Rect2(Vector2(10, 6), size - Vector2(20, 26)), Color(Palette.GOOD, 0.18), 26)
		if owned and Looks.is_look(Cosmetics.kind_of(id)):
			if Cosmetics.kind_of(id) != "building":
				Looks.draw_preview(self, id, mid, 230.0, _t)
		elif owned and Cosmetics.kind_of(id) == "trail":
			pass
		elif owned and Cosmetics.kind_of(id) == "ride":
			draw_set_transform(mid, -0.25, Vector2.ONE)
			Cosmetics.draw_ride(self, id, 190.0 * 0.74 * 0.9, 190.0 * 0.46 * 0.9, Palette.pkg("blue"), _t, Progress.paint, -1.0, Vector2.UP.rotated(0.25))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif owned:
			var paint := id if Cosmetics.kind_of(id) == "paint" else "classic"
			var vs := 190.0
			var L := vs * 0.74
			var W := vs * 0.46
			draw_set_transform(mid, -0.25, Vector2.ONE)
			DrawUtil.rrect(self, Rect2(-L / 2, -W / 2, L, W), Cosmetics.body_color(paint), W * 0.28)
			Cosmetics.draw_pattern(self, paint, Rect2(-L / 2 + W * 0.12, -W / 2 + W * 0.1, L * 0.7 - W * 0.12, W * 0.8))
			var cab := L * 0.3
			DrawUtil.rrect(self, Rect2(L / 2 - cab, -W / 2, cab, W), Cosmetics.cab_color(paint), W * 0.28)
			if Cosmetics.kind_of(id) == "topper":
				Cosmetics.draw_topper(self, id, Vector2(L / 2 - cab * 0.62, 0), W * 1.5, _t)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(mid, 62, Color(Palette.TEXT, 0.08))
			var qw := f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
			draw_string(f, mid + Vector2(-qw / 2.0, 30), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color(Palette.TEXT, 0.3))
		var name := Cosmetics.name_of(id) if owned else (where if where != "" else "Not found yet")
		var px := 32
		while px > 20 and f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > size.x - 30:
			px -= 2
		var nw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(f, Vector2((size.x - nw) / 2.0, size.y - 52), name, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Palette.TEXT if owned else Palette.TEXT_SOFT)
		if worn:
			Icons.star(self, Vector2(size.x - 40, 40), 20.0, Palette.GOOD)
