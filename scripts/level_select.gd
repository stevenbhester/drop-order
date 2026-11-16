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
var _gear: JuicyButton
var ribbon: DailyRibbon


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
	map.side_pressed.connect(_detour_card)
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
	var gas := GasChip.new()
	gas.shop_requested.connect(_open_shop)
	bar.add_child(gas)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	var coins := CoinChip.new()
	coins.visible = Progress.COINS
	bar.add_child(coins)
	var gear := JuicyButton.new()
	gear.icon_name = "gear"
	gear.custom_minimum_size = Vector2(112, 102)
	gear.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gear.pressed.connect(func():
		Sfx.play("click")
		options_pressed.emit())
	bar.add_child(gear)
	_gear = gear

	# The daily's ribbon, out from the right edge under the options (DailyRibbon).
	ribbon = DailyRibbon.new()
	ribbon.pressed.connect(func(): daily_pressed.emit())
	add_child(ribbon)

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
		if not Daily.unlocked():
			Sfx.play("bonk", 1.1, -6.0)
			daily.pop()
			return
		Sfx.play("click")
		daily_pressed.emit())
	row.add_child(daily)
	if not Daily.unlocked():
		# Locked until job Daily.UNLOCK_AT: greyed, a padlock, and when.
		daily.icon_name = "lock"
		daily.label = "Daily · after job %d" % Daily.UNLOCK_AT
		daily.font_px = 34
		daily.flame = 0
		daily.dim = true
	elif not Progress.daily_record(today).get("done", false):
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
	var focus_on: int = map.here
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map-scroll="):
			focus_on = a.trim_prefix("--map-scroll=").to_int() - 1
	map.focus(focus_on)
	for a in OS.get_cmdline_user_args():
		if a == "--daily-intro":
			# Debug: the daily's just-unlocked intro, over the map.
			(func():
				Progress.seen_new.erase("daily")
				daily_intro()).call_deferred()
		if a.begins_with("--detour-reveal="):
			# Debug: a detour drawing itself in on the map (for screenshots).
			(func(): map.reveal_detour(a.trim_prefix("--detour-reveal="))).call_deferred()
		if a.begins_with("--detour-card="):
			# Debug: a detour's own card, as if its ticket were tapped.
			_detour_card.call_deferred(a.trim_prefix("--detour-card="))
		if a.begins_with("--detour-intro="):
			# Debug: the first detour's intro, for that side road (for screenshots).
			(func(): map.detour_intro(a.trim_prefix("--detour-intro="))).call_deferred()


## A milestone chest tapped open: it pops open over the map, then any hat in it gets its own unlock card.
## After a win: the van drives from stop `from_i` up to `to_i`, then the Next card pops up (Drive!, and a
## Detour if a side road branches off the stop just beaten).
func advance(from_i: int, to_i: int) -> void:
	if Checkpoint.due(levels[to_i].number):
		# Into a new zone: its checkpoint at the gate first, then the zone opens and the van drives in.
		if not await _through_checkpoint(from_i, to_i):
			return
	else:
		map.drive(from_i, to_i)
		await map.drive_done
	if not is_inside_tree():
		return
	# The job just beaten unlocked a chest: the map shows it, and it's opened there and then (they hold
	# upgrades: nobody should drive past one).
	var beaten: int = levels[from_i].number
	if SideRoads.CHESTS.has(beaten) and Progress.is_complete(beaten) and not Progress.chest_open(beaten) \
			and (not Progress.auto or OS.get_cmdline_user_args().has("--chest-reveal")):
		if map.reveal_chest(beaten):
			await map.reveal_done
			if not is_inside_tree():
				return
		await _open_chest_now(beaten)
		if not is_inside_tree():
			return
	# Just opened up the daily: its intro first (and if they try it, that's where they go).
	if await daily_intro():
		return
	if not is_inside_tree():
		return
	# A few jobs on from their first daily: what they'd like to hear from us (NotifyPrefs), once.
	if NotifyPrefs.due():
		var np := NotifyPrefs.new()
		add_child(np)
		await np.closed
		if not is_inside_tree():
			return
	var card := NextCard.new()
	card.level = levels[to_i]
	card.costs_gas = false
	var beat: int = levels[from_i].number
	for d in SideRoads.defs():
		if int(d.get("after", 0)) == beat and Progress.side_open(d) and not Progress.side_done.has(str(d.get("id", ""))):
			card.detour = d
			break
	# The first detour ever offered: the map shows what one is first (once). Any other, the first time it's
	# on offer: a quick beat as it draws itself in (RoadMap.reveal_detour).
	var did := str(card.detour.get("id", ""))
	if not card.detour.is_empty() and not Progress.seen_new.has("detour") \
			and (not Progress.auto or OS.get_cmdline_user_args().has("--detour-intro")) \
			and map.detour_intro(did):
		Progress.seen_new["detour_" + did] = true
		await map.intro_done
		if not is_inside_tree():
			return
		if map.intro_took_detour:
			return              # (they tapped the detour itself: its own card's up, not the next job's)
	elif not card.detour.is_empty() and not Progress.seen_new.has("detour_" + did) \
			and (not Progress.auto or OS.get_cmdline_user_args().has("--detour-reveal")):
		Progress.seen_new["detour_" + did] = true
		Progress.set_option("seen_new", Progress.seen_new)
		if map.reveal_detour(did):
			await map.reveal_done
			if not is_inside_tree():
				return
	card.go_pressed.connect(func(): level_chosen.emit(to_i))
	card.detour_pressed.connect(func(): side_chosen.emit(str(card.detour.get("id", ""))))
	add_child(card)


## Through a zone's checkpoint, on the map, for its job `to_i`: the van pulls up to the gate (from stop
## `from_i`; -1: it's there already), the checkpoint comes up (Checkpoint), then the zone opens with its
## show (RoadMap.open_zone) and the van drives on in to `to_i`. False if the map's gone meanwhile.
var _at_checkpoint := false

func _through_checkpoint(from_i: int, to_i: int) -> bool:
	_at_checkpoint = true
	var zk := Zones.of(levels[to_i].number)
	map.held = zk
	if from_i >= 0:
		map.drive_to_gate(from_i, zk)
		await map.drive_done
		if not is_inside_tree():
			return false
	if OS.get_cmdline_user_args().has("--skip-checkpoint"):
		# Debug: straight through (for recording the zone opening).
		Progress.checkpoints[zk] = true
		await get_tree().create_timer(0.4).timeout
	else:
		var cp := Checkpoint.new()
		cp.zone = zk
		add_child(cp)
		await cp.done
	if not is_inside_tree():
		return false
	map.open_zone(zk)
	await map.zone_open_done
	if not is_inside_tree():
		return false
	map.drive_from_gate(zk, to_i)
	await map.drive_done
	_at_checkpoint = false
	return is_inside_tree()


## A job behind a checkpoint, chosen on the map (its stop, or the gate's sign): through the checkpoint, the
## zone opens, the van drives in, and the job's card comes up.
func checkpoint(i: int) -> void:
	if _at_checkpoint:
		return
	for c in get_children():
		if c is NextCard:
			c.queue_free()
	if await _through_checkpoint(-1, i):
		offer(i)


## A detour's ticket tapped: its own card, and only it (a Next card already up gives way to it).
func _detour_card(id: String) -> void:
	for c in get_children():
		if c is NextCard:
			c.queue_free()
	var card := NextCard.new()
	card.detour = SideRoads.get_def(id)
	card.detour_only = true
	card.detour_pressed.connect(func(): side_chosen.emit(id))
	add_child(card)


func _open_chest(n: int) -> void:
	_open_chest_now(n)


## Opens chest `n` and waits for it: the chest (ChestCard), then anything it held that needs a word of its
## own (the jump jets: JetsCard; a hat or a ride: UnlockCard).
func _open_chest_now(n: int) -> void:
	var got := Progress.open_chest(n)
	if got.is_empty():
		return
	var card := ChestCard.new()
	card.got = got
	card.level_number = n
	add_child(card)
	await card.closed
	if not is_inside_tree():
		return
	map.queue_redraw()
	if got.get("jets", false):
		var jc := JetsCard.new()
		add_child(jc)
		await jc.closed
		if not is_inside_tree():
			return
	if got.get("hat", "") != "":
		var u := UnlockCard.new()
		u.item = got["hat"]
		u.source = "the job %d chest" % n
		add_child(u)
		await u.closed


func _dock_h() -> float:
	return 250.0 + _bottom


func _process(_delta: float) -> void:
	# The ribbon sticks out from the right edge, just under the options button.
	if ribbon and _gear:
		ribbon.position = Vector2(size.x - ribbon.size.x, _gear.global_position.y + _gear.size.y + 22.0)


## The card for level `i` (Get back to work, after the daily): Drive! into it, or stay on the map.
func offer(i: int) -> void:
	i = clampi(i, 0, levels.size() - 1)
	if not Zones.level_open(levels[i].number):
		return
	var card := NextCard.new()
	card.level = levels[i]
	card.costs_gas = false
	card.go_pressed.connect(func(): level_chosen.emit(i))
	add_child(card)


## Just unlocked: the daily's ribbon gets a spotlight and a card (DailyIntro), once. True if they chose to
## try it (the daily's opened; nothing else should follow).
func daily_intro() -> bool:
	if not Daily.unlocked() or Progress.seen_new.has("daily") or not Progress.daily.is_empty() \
			or (Progress.auto and not OS.get_cmdline_user_args().has("--daily-intro")):
		return false
	Progress.seen_new["daily"] = true
	Progress.set_option("seen_new", Progress.seen_new)
	var intro := DailyIntro.new()
	intro.ribbon = ribbon
	add_child(intro)
	var tried: bool = await intro.closed
	if tried:
		daily_pressed.emit()
	return tried


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
	# Jobs done, and the packages delivered all told (what opens zones and unlocks looks).
	var a := "%d / %d jobs" % [done, levels.size()]
	var b := "%s delivered" % Progress.commas(Progress.delivered())
	var aw := f.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	var bw := f.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	var x := (s.x - (aw + 50.0 + 48.0 + bw)) / 2.0
	_dock.draw_string(f, Vector2(x, 64), a, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Palette.TEXT_SOFT)
	Icons.draw(_dock, "box", Vector2(x + aw + 50.0 + 16.0, 51), 38.0, Color.WHITE)
	_dock.draw_string(f, Vector2(x + aw + 50.0 + 48.0, 64), b, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Palette.TEXT_SOFT)


func _open_shop() -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	_modal = GasShop.new()
	add_child(_modal)
