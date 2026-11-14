extends Node
## Screen switcher: title, level select, daily puzzle, garage and the game. Caches solver results per level.
## Gas: opening a level you haven't beaten costs a tank (Game hands it back when you win); replays of beaten
## levels are free to open. With no gas, the gas station opens instead.

var levels: Array = []
var solved := {}
var screen: Node
var _cover: ColorRect
var _modal: Node
## Re-shows the current menu screen (night mode re-themes by rebuilding it).
var _reshow := Callable()
var _night := false
var _colorblind := false
var _landscape := false
## Sideways play: menus go in a portrait column in the middle (see PortraitHost).
var _host: PortraitHost
## The update offer: which build was last offered this launch, and when (seconds since launch).
var _offered_build := 0
var _offered_at := -1.0e9


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.BG)
	add_child(Backdrop.new())
	# A sheet of background colour over everything, faded away after each screen change.
	var over := CanvasLayer.new()
	over.layer = 30
	add_child(over)
	_cover = ColorRect.new()
	_cover.color = Color(Backdrop.TOP.lerp(Backdrop.BOTTOM, 0.5), 0.0)
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(_cover)
	levels = Levels.load_all()
	Notify.refresh(Progress)
	_night = Progress.night
	_colorblind = Progress.colorblind
	_landscape = Progress.landscape
	_apply_orientation()
	Progress.settings_changed.connect(_on_settings)
	if levels.is_empty():
		push_error("No levels loaded")
		return
	var start := Progress.first_incomplete(levels.size())
	var direct := false
	var side_id := ""
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--side="):
			# Debug: straight into a side road (levels/side.json id).
			side_id = a.trim_prefix("--side=")
		elif a.begins_with("--level="):
			start = a.trim_prefix("--level=").to_int() - 1
			direct = true
		elif a.begins_with("--auto"):
			direct = true
	var speed_id := ""
	for a in args:
		if a.begins_with("--speedrun="):
			speed_id = a.trim_prefix("--speedrun=")
	if speed_id == "list":
		show_speedrun()
	elif speed_id != "":
		play_speed(speed_id)
	elif side_id != "":
		# Debug: --side-part=N starts a mega route at part N (as if just arrived: it pans in).
		var pan := Vector2i.ZERO
		for a in args:
			if a.begins_with("--side-part="):
				var k := a.trim_prefix("--side-part=").to_int()
				Progress.mega[side_id] = k
				var parts: Array = SideRoads.get_def(side_id).get("parts", [])
				if k > 0 and k < parts.size():
					pan = Vector2i(signi(int(parts[k]["at"][0]) - int(parts[k - 1]["at"][0])), signi(int(parts[k]["at"][1]) - int(parts[k - 1]["at"][1])))
		_start_side(side_id, pan)
	elif args.has("--select"):
		show_select()
	elif args.has("--daily"):
		if direct:
			play_daily()
		else:
			show_daily()
	elif args.has("--garage"):
		show_garage()
	elif direct:
		_start(start)
	else:
		show_title()
		# Once a launch, the studio card plays over the title and dives through its door into it.
		if StudioCard.due() and not OS.get_cmdline_user_args().has("--no-intro"):
			var card := StudioCard.new()
			(screen as TitleScreen).quiet = true
			card.draining.connect(_title_audible)
			_put(card)
	for a in args:
		if a.begins_with("--chest=") and screen is LevelSelect:
			# Debug: open a milestone chest on the map straight away (for screenshots).
			(screen as LevelSelect)._open_chest.call_deferred(a.trim_prefix("--chest=").to_int())
	for a in args:
		if a.begins_with("--promo-ad"):
			# Debug: play one of the pretend Last Mile ads over whatever's showing (--promo-ad=fun|bait|trash).
			var ad := PromoAd.new()
			if a.contains("="):
				ad.kind = a.trim_prefix("--promo-ad=")
			add_child.call_deferred(ad)
	for a in args:
		if a.begins_with("--next="):
			# Debug: as if level N-1 was just won: the van drives up to N, then the Next card.
			var n := a.trim_prefix("--next=").to_int()
			show_next.call_deferred(n - 2, n - 1)
	for a in args:
		if a.begins_with("--unlock="):
			# Debug: the "you found something" card for this cosmetic.
			var u := UnlockCard.new()
			u.item = a.trim_prefix("--unlock=")
			add_child.call_deferred(u)
	if args.has("--feedback"):
		# Debug: open the feedback card straight away (for screenshots).
		open_feedback.call_deferred()
	if args.has("--notes"):
		# Debug: open the patch notes straight away (for screenshots).
		open_notes.call_deferred()
	if args.has("--options"):
		# Debug: open the options card straight away (for screenshots).
		open_options.call_deferred(screen)
	# Is there a newer build in TestFlight? (Not during self-tests.)
	if not Progress.auto:
		var updates := UpdateCheck.new()
		updates.found.connect(func(_info: Dictionary): _offer_update())
		add_child(updates)


## The options card, over whatever's showing. The game passes itself so it can pause its input meanwhile.
func open_options(from: Node = null) -> OptionsMenu:
	var m := OptionsMenu.new()
	m.feedback_pressed.connect(open_feedback.bind(from))
	add_child(m)
	if from is Game:
		(from as Game).modal = m
		m.closed.connect(func(): (from as Game).modal = null)
	return m


## Feedback / Bug report: once the options card is gone, a screenshot of what's on screen, then the report.
func open_feedback(from: Node = null) -> void:
	await get_tree().create_timer(0.22).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var card := FeedbackCard.new()
	card.shot = img
	card.where = Feedback.where_of(screen)
	if from is Game:
		(from as Game).modal = card
		card.closed.connect(func(): (from as Game).modal = null)
	add_child(card)
	print("[feedback] opened at %s" % card.where)


## The title's version badge: the update on offer if there is one, else this version's patch notes.
func _on_badge() -> void:
	if UpdateCheck.available():
		open_update()
	else:
		open_notes()


## "A new version is out!", over the title.
func open_update() -> UpdateCard:
	var c := UpdateCard.new()
	c.info = UpdateCheck.latest
	add_child(c)
	return c


## Offers the newer build when the player's on the title with nothing else open: once a launch, and again if
## they come back to the game hours later.
func _offer_update() -> void:
	if not UpdateCheck.available() or not (screen is TitleScreen) or (screen as TitleScreen).quiet:
		return
	var build := int(UpdateCheck.latest.get("build", 0))
	var now := Time.get_ticks_msec() / 1000.0
	if build == _offered_build and now - _offered_at < 4 * 3600.0:
		return
	for c in get_children():
		if c is PatchNotes or c is OptionsMenu or c is FeedbackCard or c is UpdateCard:
			return
	_offered_build = build
	_offered_at = now
	open_update()


## What's new: the patch notes (from the title's version badge).
func open_notes() -> PatchNotes:
	var n := PatchNotes.new()
	add_child(n)
	return n


## Portrait (1080 wide, any height) or sideways (1080 tall, any width), and on a phone, lock the screen to it.
func _apply_orientation() -> void:
	var land := Progress.landscape
	var root := get_tree().root
	root.content_scale_size = Vector2i(1920, 1080) if land else Vector2i(1080, 1920)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT if land else Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE if land else DisplayServer.SCREEN_PORTRAIT)
	elif DisplayServer.get_name() != "headless" and not Progress.auto:
		# On a computer, turn the window to match.
		var ws := DisplayServer.window_get_size()
		if (ws.x > ws.y) != land:
			DisplayServer.window_set_size(Vector2i(ws.y, ws.x))
	if land and _host == null:
		_host = PortraitHost.new()
		_host.auto_hide = true      # only there while it holds a menu (a level plays full width)
		add_child(_host)


## Where a menu screen goes: in the portrait column when sideways, else straight in.
func _put(node: Node) -> void:
	if Progress.landscape and not (node is Game):
		_host.put(node)
	else:
		add_child(node)


func _on_settings() -> void:
	if Progress.landscape != _landscape:
		_landscape = Progress.landscape
		_apply_orientation()
		if not (screen is Game) and _reshow.is_valid():
			_reshow.call()
	if Progress.colorblind != _colorblind:
		_colorblind = Progress.colorblind
		get_tree().root.propagate_call("queue_redraw")
	if Progress.night != _night:
		_night = Progress.night
		Palette.apply(_night)
		UiTheme.refresh()
		RenderingServer.set_default_clear_color(Palette.BG)
		get_tree().root.propagate_call("restyle")
		get_tree().root.propagate_call("queue_redraw")
		if screen is Game:
			(screen as Game).retheme()
		elif _reshow.is_valid():
			_reshow.call()


## Daily reminders are rescheduled whenever the game goes to the background (and at launch, below).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Notify.refresh(Progress)


func show_title() -> void:
	_reshow = show_title
	var t := TitleScreen.new()
	t.setup(levels)
	t.play_pressed.connect(func(): play(Progress.first_incomplete(levels.size())))
	t.levels_pressed.connect(show_select)
	t.daily_pressed.connect(show_daily)
	t.garage_pressed.connect(show_garage)
	t.options_pressed.connect(open_options)
	t.notes_pressed.connect(_on_badge)
	t.speedrun_pressed.connect(show_speedrun)
	_swap(t)
	_offer_update.call_deferred()


func _title_audible() -> void:
	if screen is TitleScreen:
		(screen as TitleScreen).quiet = false
		_offer_update()


## Opens level `i`, paying a gas tank first if it hasn't been beaten.
func play(i: int) -> void:
	i = clampi(i, 0, levels.size() - 1)
	var L: LevelData = levels[i]
	var paid := not Progress.is_complete(L.number)
	if paid and not Progress.spend_gas():
		_out_of_gas(play.bind(i))
		return
	_start(i, paid)


## Opens level `i` (a retry is already paid for in the game; `paid` just shows the charge).
func _start(i: int, paid := false) -> void:
	i = clampi(i, 0, levels.size() - 1)
	var L: LevelData = levels[i]
	if not solved.has(i):
		solved[i] = Solver.solve(L)
	_reshow = Callable()
	var g := Game.new()
	g.charged = paid
	g.setup(L, i, levels.size(), solved[i])
	g.options_requested.connect(open_options.bind(g))
	g.level_requested.connect(play)
	g.next_requested.connect(show_next)
	g.retry_requested.connect(func(j): _start(j, g.retry_paid))
	g.menu_requested.connect(show_select)
	_swap(g)


## Speedrun mode: the course list (locked until level Speedrun.UNLOCK_LEVEL is beaten).
func show_speedrun() -> void:
	_reshow = show_speedrun
	var s := SpeedrunScreen.new()
	s.course_chosen.connect(play_speed)
	s.back_pressed.connect(show_title)
	_swap(s)


func play_speed(id: String) -> void:
	_start_speed(id, 0, 0.0, Vector2i.ZERO)


## Zone `k` of a speedrun course, with `elapsed` already on the clock; `pan` is the way the camera came.
func _start_speed(id: String, k: int, elapsed: float, pan: Vector2i) -> void:
	var d := Speedrun.get_def(id)
	var L := Speedrun.zone_level(id, k)
	if L == null:
		show_speedrun()
		return
	var key := "speed_%s_%d" % [id, k]
	if not solved.has(key):
		solved[key] = Solver.solve(L)
	_reshow = Callable()
	var g := Game.new()
	g.side = d
	g.part = k
	g.pan_from = pan
	g.speed_elapsed = elapsed
	g.options_requested.connect(open_options.bind(g))
	g.setup(L, 0, 1, solved[key])
	g.retry_requested.connect(func(_i): _start_speed(id, 0, 0.0, Vector2i.ZERO))
	g.menu_requested.connect(show_speedrun)
	g.part_finished.connect(func(dir: Vector2i): _start_speed(id, k + 1, elapsed + g.play_time, dir))
	_swap(g)


## A side road off the map (SideRoads): free to play and to retry; back to the map after.
func play_side(id: String) -> void:
	_start_side(id)


## A mega route picks up at the part it was left on; `pan` is the way the last part's exit led (the camera
## pans on that way).
func _start_side(id: String, pan := Vector2i.ZERO) -> void:
	var d := SideRoads.get_def(id)
	var mega := SideRoads.is_mega(d)
	var k := Progress.mega_part(id) if mega else 0
	var L := SideRoads.part_level(id, k) if mega else SideRoads.level(id)
	if L == null:
		show_select()
		return
	var key := "side_%s_%d" % [id, k]
	if not solved.has(key):
		solved[key] = Solver.solve(L)
	_reshow = Callable()
	var g := Game.new()
	g.side = d
	g.part = k
	g.pan_from = pan
	g.options_requested.connect(open_options.bind(g))
	g.setup(L, 0, 1, solved[key])
	g.retry_requested.connect(func(_i): _start_side(id))
	g.menu_requested.connect(show_select)
	g.part_finished.connect(func(dir: Vector2i): _start_side(id, dir))
	_swap(g)


## Today's puzzle. Each start counts as an attempt (the first is free of redos); unsolved, it costs gas.
func play_daily() -> void:
	var day := Daily.today()
	var paid: bool = not Progress.daily_record(day).get("done", false)
	if paid and not Progress.spend_gas():
		_out_of_gas(play_daily)
		return
	Progress.daily_attempt(day)
	_start_daily(paid)


func _start_daily(paid := false) -> void:
	var day := Daily.today()
	var L := Daily.puzzle_for(day)
	var key := "daily%d" % L.number
	if not solved.has(key):
		solved[key] = Solver.solve(L)
	_reshow = Callable()
	var g := Game.new()
	g.daily_day = day
	g.charged = paid
	g.options_requested.connect(open_options.bind(g))
	g.setup(L, 0, 1, solved[key])
	g.retry_requested.connect(func(_i): _start_daily(g.retry_paid))
	g.daily_menu_requested.connect(show_daily)
	g.menu_requested.connect(show_daily)
	_swap(g)


func show_daily() -> void:
	_reshow = show_daily
	var d := DailyScreen.new()
	d.play_pressed.connect(play_daily)
	d.back_pressed.connect(show_title)
	_swap(d)


func show_garage() -> void:
	_reshow = show_garage
	var g := Garage.new()
	g.setup(levels)
	g.back_pressed.connect(show_title)
	_swap(g)


## No gas to start with: the gas station opens over whatever's showing, and a purchase carries on.
func _out_of_gas(then: Callable) -> void:
	Sfx.play("empty")
	if _modal != null and is_instance_valid(_modal):
		return
	var shop := GasShop.new()
	_modal = shop
	_put(shop)
	shop.closed.connect(func(bought: bool):
		_modal = null
		if bought:
			then.call())


## After a win: the map, the van driving up to the next stop, then the Next card.
func show_next(from_i: int, to_i: int) -> void:
	show_select()
	(screen as LevelSelect).advance(from_i, to_i)


func show_select() -> void:
	_reshow = show_select
	var s := LevelSelect.new()
	s.setup(levels)
	s.level_chosen.connect(play)
	s.side_chosen.connect(play_side)
	s.daily_pressed.connect(show_daily)
	s.garage_pressed.connect(show_garage)
	s.title_pressed.connect(show_title)
	s.options_pressed.connect(open_options)
	_swap(s)


func _swap(next: Node) -> void:
	if screen:
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		screen.queue_free()
		if not Progress.auto:
			_cover.color.a = 1.0
			create_tween().tween_property(_cover, "color:a", 0.0, 0.22)
	screen = next
	_put(next)
	# A breadcrumb for bug reports (the log rides along with them).
	print("[screen] %s" % Feedback.where_of(next))
