class_name Game
extends Node2D
## One level being played: input -> segments, driving, deliveries, undo, win/fail, UI.
## Rules come from Sim, visuals from Board/Van/House/Shop/Gate/StackView.
##
## The player builds the route in segments. Drawing: press on the van, drag, lift -> the van drives that
## segment. D-pad (the other steering mode): tap or hold arrows to plot it, with a ghost van at the far
## end, then DRIVE BABY DRIVE. They continue from wherever it stopped. The route can't cross road the
## van has torn up (or itself): the line just stops there with a red X, and if they send the van anyway
## it brakes hard right before the wreckage; nothing is lost.
## While planning, the line is tinted with the package that'll be on top along each stretch, houses the
## plan will deliver to show a ghost tick, and every waiting house wears its package's place in the queue
## (the truck under the board shows the whole queue, numbered the same way, the next package on its tail lift).
## Undo rewinds the last segment (packages come back): one free per attempt, then spares from
## Progress.undo_bank, which the (pretend) ad tops up. Hint shows the next stretch of a winning route.
## Retry costs a gas tank until the level has been beaten once; after that it's free.
## Stars: 3, minus one for using a hint, minus one for an undo.
##
## Sim updates instantly as the van reaches each tile; the matching animations (packages
## flying, the load rolling along) run on a small timeline so they always play in rule
## order even when several happen close together.

signal menu_requested
signal level_requested(index: int)   # go to a level (Next): Main charges gas if it's unbeaten
signal retry_requested(index: int)   # the same level again: gas already paid here
signal daily_menu_requested
signal segment_finished
signal options_requested
## A mega route's part is done (not the last): Main saves it and pans on to the next part that way.
signal part_finished(dir: Vector2i)

enum State { IDLE, DRAWING, DRIVING, REWINDING, WON, FAILED }

const DRIVE_SPEED := 7.0         # tiles per second at cruise
const REWIND_SPEED := 16.0
const RAMP := 0.6                # tiles spent accelerating / braking
const TOP_BAR := 170.0
## Between an upright chute and the board.
const CHUTE_GAP := 14.0
## The least room kept for the level's name and hint, above the truck (upright).
const TEXT_MIN := 110.0
## The D-pad's size: three keys across, two down.
const PAD_CELL := 172.0
const UNDOS_PER_ATTEMPT := 1
const FLY_TIME := 0.25
## A delivered package dropping out of the chute into the van, before it flies to the house.
const DROP_TIME := 0.2
const COMBO_STEPS := [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19]
const CHEERS := ["Nice!", "Sweet!", "Great!", "Wow!", "Unreal!"]
const AD_PINK := Color("ff3d9a")
const COUNT_BLUE := Color("4d8dff")
## Hints each level starts with; after that, watching a pretend ad makes them unlimited for the level.
const HINTS_PER_LEVEL := 3
const NOWHERE := Vector2i(-99, -99)

var level: LevelData
var index := 0
var total := 0
var solve_info := {}
var state := State.IDLE

var board: Board
var van: Van
var stack_view: StackView
var convoy: Convoy
## The route preview chip (only with the option on).
var peek: PeekBubble
var confetti: Confetti
var ghost: GhostFinger

var route: Array = []            # Vector2i: everything driven so far; route[0] = start
var seg: Array = []              # segment being drawn/driven; seg[0] = route.back()
var seg_states: Array = []       # predicted Sim state after each tile of `seg` (while drawing)
## The tile the player is pushing the route into that it can't enter: torn-up road, or the route itself.
## A red X shows on that edge. NOWHERE: none.
var blocked_at := NOWHERE
var _brake_into := NOWHERE       # set while driving a segment sent off with the X showing: brake at its end
var _seg_cols: Array = []        # while driving: the tint of each stretch of `seg`
var _load_drag := {}             # a press on the chute: {at, view, moved}
## True when the last retry_requested took a gas tank (Main shows the "-1" on the gauge).
var retry_paid := false
var history: Array = []          # per driven segment: { "len", "state", "rot" } before it
var undo_left := UNDOS_PER_ATTEMPT   # free undos left this attempt (spares are in Progress.undo_bank)
var hint_used := false
## Hints left this level (HINTS_PER_LEVEL to start). Out: a pretend ad, then they're unlimited for the level.
var hints_left := HINTS_PER_LEVEL
var hints_unlimited := false
var undo_used := false
var modal: Node                  # the shop or the ad, on top: the game ignores input meanwhile
var sim_state: Dictionary
var combo := 0
var _fired := 0
var _drive_len := 0.0
var _vis_cursor := 0.0           # timeline: when the next stack animation may start (s)
var _effects_end := 0.0          # timeline: when the last scheduled animation finishes (s)
var _denied := Vector2i(-99, -99)
var _beat := 1.6

var _top_inset := 0.0
var _bottom_inset := 0.0
var level_label: Label
var hint_label: Label
var title_label: Label                # the level's name, over the hint, up in the space under the top bar
var debug_label: Label
var stars_ctl: Control
var gas_chip: GasChip
var coin_chip: CoinChip
var actions: BoxContainer
var hint_button: JuicyButton
var undo_button: JuicyButton
var retry_button: JuicyButton
var finish: FinishScreen
var bar: HBoxContainer
var momentum_ctl: Control
## Set for the daily puzzle: the day it's for (else -1).
var daily_day := -1
## A side challenge (SideRoads): its definition, or empty for a normal level. Its `twist` changes the rules.
var side := {}
var _fogged := false
## Where Auto put the chute for this screen ("" = not decided yet).
var _auto_side := ""
## One-time tips waiting for the screen to settle ({text, target (a Callable giving a screen point), tap}),
## and the one showing.
var _tips: Array = []
var _tip: TipBubble
var _alive := 0.0
## A press on a symbol (not the van): {tile, pos, t}. Released in place (or held) it explains the symbol.
var _sym_press := {}
var _sym_card: SymbolCard
## A side road's power-up, said on the finish ("" for none).
var _bonus_line := ""
## Mega routes: which part this is, and (arriving from the last part) the way the camera pans in from.
var part := 0
var pan_from := Vector2i.ZERO
## Speedrun: the time already on the clock from earlier zones.
var speed_elapsed := 0.0
## Seconds spent playing, from the first touch to the win (menus and the ad don't count).
var play_time := 0.0
var timing := false
## Colours delivered so far, in order (for the daily share card).
var deliveries: Array = []
var gift_taken := false
var gift_seg := -1               # the segment (history index) that picked the gift up
var _fire_last := Vector2.INF
## Set by Main when opening this level cost a gas tank: the gauge shows it.
var charged := false
var fx: Fx
var hint_ghost: GhostFinger
var hint_run: Array = []         # tiles the current hint points along (empty: no hint showing)
var _ui_root: Control
var _base_hint := ""
## D-pad steering (Progress.drive_mode "dpad"): arrows plot the route a tile at a time, a ghost van shows
## where it ends, and the DRIVE button sends the real van down it.
var dpad_mode := false
var dpad: DPad
var drive_button: JuicyButton
var ghost_van: Van
var mode_button: JuicyButton          # the options (gear) button
var _tile := 100.0                   # the board's tile size as built (it's scaled to fit after)
var _hint_armed := 0.0               # D-pad: Hint was tapped once; a second tap within this many seconds uses it
var _host: PortraitHost              # sideways play: pop-ups (finish, shop, ad, share) go in a portrait column
## Sideways play: the width kept clear on each side of the board for the controls and the hint.
const SIDE_PAD := 600.0
const SIDE_DRAW := 400.0

func setup(lvl: LevelData, idx: int, count: int, solved: Dictionary) -> void:
	level = lvl
	index = idx
	total = count
	solve_info = solved


func _ready() -> void:
	dpad_mode = Progress.drive_mode == "dpad" or OS.get_cmdline_user_args().has("--dpad")
	sim_state = Sim.new_state(level)
	route = [level.start]
	_compute_insets()
	_build_world()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_apply_mode()
	_update_undo()
	_refresh_tags()
	board.update_gates(Sim.top_color(level, sim_state), true)
	_intro()
	if charged:
		_show_charge.call_deferred()
	if daily_day < 0 and ChallengeIntro.should_show(level):
		_show_challenge.call_deferred()
	if not side.is_empty():
		_start_side()
	_queue_tips()
	if OS.get_cmdline_user_args().has("--explain"):
		# Debug: show each kind of symbol's explainer in turn (for screenshots).
		var seen := {}
		var tw := create_tween()
		tw.tween_interval(0.8)
		for y in level.height:
			for x in level.width:
				var sym := _symbol_at(Vector2i(x, y))
				if sym.is_empty() or seen.has(sym["kind"]):
					continue
				seen[sym["kind"]] = true
				tw.tween_callback(_explain.bind(Vector2i(x, y)))
				tw.tween_interval(1.6)
	DebugAuto.maybe_run(self)


# ---------------------------------------------------------------- side roads

func _twist() -> String:
	return str(side.get("twist", ""))


## A side road with a twist, or a speedrun: no hints, no undos. (Mega routes allow both.)
func _strict_side() -> bool:
	return not side.is_empty() and (_twist() != "mega" or _speedrun())


func _speedrun() -> bool:
	return bool(side.get("speedrun", false))


func _parts() -> int:
	return SideRoads.part_count(side)


## A mega route's part done (all delivered, parked on the exit): saved, a cheer, the van drives off the
## edge, and Main pans on to the next part.
func _part_done() -> void:
	state = State.WON
	timing = false
	_clear_hint()
	if not _speedrun():
		Progress.set_mega_part(str(side.get("id", "")), part + 1)
		Progress.momentum += 1
	Sfx.play("win")
	Sfx.haptic(30)
	var dir := level.exit_dir()
	fx.say(board.size_px() / 2.0, ("ZONE %d!" if _speedrun() else "PART %d DONE!") % (part + 1), Palette.GOOD.darkened(0.15), int(board.tile * 0.5))
	fx.burst(van.position, Color("38d9a9"), 16, board.tile * 3.0, board.tile * 0.1)
	_say("Part %d of %d done! On to the next..." % [part + 1, _parts()], Palette.GOOD.darkened(0.2))
	var tw := create_tween()
	tw.tween_interval(0.5 if not _speedrun() else 0.15)
	tw.tween_callback(func():
		van.target_rotation = Vector2(dir).angle()
		Sfx.play("whoosh", 1.1, -6.0))
	tw.tween_property(van, "position", van.position + Vector2(dir) * board.tile * 1.6, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.15)
	tw.tween_callback(func(): part_finished.emit(dir))


## A side challenge starts: its intro (until it's been beaten), the clock for "melt", the fog countdown.
func _start_side() -> void:
	if _twist() == "melt":
		timing = true
	if _speedrun():
		# The clock: a 3-2-1-GO before the first zone; straight on after that.
		if part == 0 and not Progress.auto:
			var cd := Countdown.new()
			modal = cd
			_ui_root.add_child(cd)
			cd.done.connect(func():
				modal = null
				timing = true)
		else:
			timing = true
		_side_status()
		return
	if part == 0 and ChallengeIntro.should_show_side(side):
		var ci := ChallengeIntro.new()
		ci.level = level
		ci.side = side
		modal = ci
		_overlay(ci)
		ci.done.connect(func(): modal = null)
	_side_status()


## The tank holds just the shortest route (in road tiles moved).
func _fuel_cap() -> int:
	return maxi(solve_info.get("shortest", []).size() - 1, 1)


func _fuel_used() -> int:
	return _full().size() - 1


func _fuel_left() -> int:
	return _fuel_cap() - _fuel_used()


func _melt_left() -> float:
	return float(side.get("seconds", 60)) - play_time


## The top bar says how the twist stands: gas left, the clock, "one drive", the fog closing in.
func _side_status() -> void:
	if side.is_empty() or level_label == null:
		return
	var t := ""
	match _twist():
		"fuel":
			t = "Tank: %d" % maxi(_fuel_left(), 0)
		"melt":
			var left := maxi(int(ceil(_melt_left())), 0)
			t = "Melts in %d:%02d" % [left / 60, left % 60]
		"one_shot":
			t = "One drive!"
		"fog":
			var peek := float(side.get("peek", 6)) - play_time_total()
			t = "Fog in %d" % int(ceil(peek)) if not _fogged and peek > 0.0 else "In the fog"
		"mega":
			t = "Part %d of %d" % [part + 1, _parts()]
			if _speedrun():
				t = Speedrun.clock(speed_elapsed + play_time)
	level_label.text = t
	var warn := (_twist() == "fuel" and _fuel_left() <= 2) or (_twist() == "melt" and _melt_left() < 10.0)
	level_label.add_theme_color_override("font_color", Palette.CRASH if warn else Palette.TEXT)


var _side_t := 0.0


func play_time_total() -> float:
	return _side_t


func _side_tick(delta: float) -> void:
	if side.is_empty() or state == State.WON:
		return
	if not _busy_modal():
		_side_t += delta
	match _twist():
		"melt":
			if _melt_left() <= 0.0 and state != State.FAILED and state != State.DRIVING:
				_twist_fail("Melted! Every delivery before the clock runs out.")
		"fog":
			if not _fogged and _side_t >= float(side.get("peek", 6)):
				_fogged = true
				stack_view.fog = true
				Sfx.play("whoosh", 0.7, -4.0)
	_side_status()


## A twist's rule broken: the level's lost (Retry is free on side roads).
func _twist_fail(msg: String) -> void:
	if state == State.DRAWING:
		_cancel_plan()
		board.show_path([])
	state = State.FAILED
	timing = false
	_update_drive_button()
	Sfx.play("fail", 1.0, -2)
	Sfx.haptic(25)
	van.shake()
	stack_view.flash_remaining()
	_say(msg + "\nRetry?", Palette.ACCENT.darkened(0.12))
	retry_button.breathe(true)


# ---------------------------------------------------------------- what's this?

## What's on a tile that can be explained: {kind, color (Color), name, count, at (the spot to point at)},
## or {} for nothing.
func _symbol_at(t: Vector2i) -> Dictionary:
	if not level.in_bounds(t):
		return {}
	var at := board.center(t)
	for h in level.houses.size():
		var hd = level.houses[h]
		if hd.pos == t:
			var left: int = hd.order - int(sim_state["fills"][h])
			var k := "house_done" if left <= 0 else ("houses" if left > 1 else "house")
			if hd.color == "any":
				return {"kind": "locker" if left > 0 else "house_done", "color": Color("8f98aa"), "name": "any", "count": left, "at": at}
			return {"kind": k, "color": Palette.pkg(hd.color), "name": _color_word(hd.color), "count": left, "at": at}
	for k in level.shops.size():
		var sd = level.shops[k]
		if sd.pos == t:
			var left: int = sd.count - int(sim_state["picked"][k])
			var kind := "pickup_done" if left <= 0 else ("warehouse" if left > 1 else "pickup")
			return {"kind": kind, "color": Palette.pkg(sd.color), "name": _color_word(sd.color), "count": left, "at": at}
	if level.works.has(t):
		return {"kind": "works", "count": maxi(int(level.works[t]) - Sim.delivered_count(sim_state), 0), "at": at}
	if level.ice.has(t):
		return {"kind": "ice", "at": at}
	if level.oneway.has(t):
		return {"kind": "oneway", "at": at}
	if level.bridges.has(t):
		return {"kind": "bridge", "at": at}
	if level.gates.has(t):
		return {"kind": "gate", "color": Palette.pkg(level.gates[t]), "name": _color_word(level.gates[t]), "at": at}
	if level.hubs.has(t):
		return {"kind": "hub", "at": at}
	if level.has_exit() and t == level.exit:
		return {"kind": "exit", "at": at}
	if level.return_depot and t == level.start and route.size() > 1:
		return {"kind": "pitstop", "at": at}
	if board.gift and not gift_taken and t == level.gift:
		return {"kind": "gift", "at": at}
	if level.no_revisit and route.size() > 1 and t != route.back() and route.has(t):
		return {"kind": "wreck", "at": at}
	return {}


## A colour's name for the explainer (with its package class, so it reads without colour too).
func _color_word(c: String) -> String:
	var cls := {"red": "gift", "yellow": "biohazard", "blue": "caution", "purple": "mystery", "green": "organic", "orange": "hot"}
	return "%s (%s)" % [c, cls.get(c, "")] if Progress.colorblind else c


func _explain(t: Vector2i) -> void:
	var sym := _symbol_at(t)
	if sym.is_empty():
		return
	if _sym_card and is_instance_valid(_sym_card):
		_sym_card.close()
	if _tip and is_instance_valid(_tip):
		_tip.dismiss()
	var card := SymbolCard.new()
	card.kind = sym["kind"]
	card.col = sym.get("color", Color.WHITE)
	card.col_name = sym.get("name", "")
	card.count = int(sym.get("count", 1))
	card.target = board.get_global_transform_with_canvas() * Vector2(sym["at"])
	_sym_card = card
	modal = card
	# Only this card's closing frees the game (an older card fading out mustn't, while this one's up).
	card.closed.connect(func():
		if modal == card:
			modal = null)
	_ui_root.add_child(card)


# ---------------------------------------------------------------- tips

## The one-time tips this level might show: the queue moving (Auto), and "tap a symbol for a reminder".
func _queue_tips() -> void:
	if Progress.auto:
		return
	# The second time a level has one-way streets: tap a symbol for a reminder.
	if not level.oneway.is_empty() and daily_day < 0:
		if not Progress.oneway_levels.has(level.number):
			Progress.oneway_levels[level.number] = true
		if Progress.oneway_levels.size() >= 2 and not Progress.symbol_tip_seen:
			Progress.symbol_tip_seen = true
			var arrow: Vector2i = level.oneway.keys()[0]
			_tips.append({"text": "Forgot what a symbol does?\nTap it for a reminder.", "target": func(): return board.get_global_transform_with_canvas() * board.center(arrow), "tap": true})
		Progress.save_now()
	# The first exit road (a mega route's or a speedrun's): where it goes, and the gate.
	if level.has_exit() and not Progress.exit_tip_seen:
		Progress.exit_tip_seen = true
		Progress.save_now()
		var on := "zone" if _speedrun() else "part"
		_tips.append({"text": "This road leads to the next %s.\nDeliver everything to open the gate,\nthen finish your route here." % on,
			"target": func(): return board.get_global_transform_with_canvas() * (board.center(level.exit) + board.exit_zone.gate_offset())})
	if Progress.stack_side == "auto" and not Progress.landscape:
		# The first time Auto moves the queue from where it was last level, say so.
		var was := Progress.last_auto_side
		var now_side := _chute_side()
		Progress.last_auto_side = now_side
		if was != "" and was != now_side and not Progress.queue_moved_seen:
			Progress.queue_moved_seen = true
			var msg := "Big map! Your package queue\nmoved up here to make room." if now_side == "top" else "Your package queue's\nover here this time."
			_tips.append({"text": msg, "target": func(): return stack_view.global_position, "tap": false})
		Progress.save_now()


func _show_tip(t: Dictionary) -> void:
	_tip = TipBubble.new()
	_tip.text = t["text"]
	_tip.target = (t["target"] as Callable).call()
	_tip.tap = t.get("tap", false)
	_ui_root.add_child(_tip)


## A challenge level (a big step up): hazard tape, a stamp, the bonus on offer.
func _show_challenge() -> void:
	var ci := ChallengeIntro.new()
	ci.level = level
	modal = ci
	_overlay(ci)
	ci.done.connect(func(): modal = null)


## "−1" floats up off the gas gauge.
func _show_charge() -> void:
	gas_chip.bump()
	var l := Label.new()
	l.text = "−1"
	l.add_theme_font_size_override("font_size", 52)
	l.add_theme_color_override("font_color", GasChip.FUEL)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 12)
	l.position = gas_chip.global_position + Vector2(gas_chip.size.x - 70, 70)
	_ui_root.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y + 70, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


## The level pops into place: board rises, houses and shops spring up one by one, the load stacks itself.
func _intro() -> void:
	if Progress.auto:
		return
	var rest := board.position
	if pan_from != Vector2i.ZERO:
		# On from the last part of a mega route: the camera pans across to this one.
		var vp := get_viewport_rect().size
		board.position = rest + Vector2(pan_from) * Vector2(vp.x, vp.y) * 0.9
		var pt := create_tween()
		pt.tween_property(board, "position", rest, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		Sfx.play("whoosh", 0.75, -4.0)
		stack_view.rebuild(stack_view.colors.duplicate())
		return
	board.position = rest + Vector2(0, 50)
	board.modulate.a = 0.0
	var bt := create_tween().set_parallel()
	bt.tween_property(board, "position", rest, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.tween_property(board, "modulate:a", 1.0, 0.18)
	var nodes: Array = board.house_nodes + board.shop_nodes
	for i in nodes.size():
		var n: Node2D = nodes[i]
		n.scale = Vector2.ZERO
		var tw := n.create_tween()
		tw.tween_interval(0.12 + i * 0.05)
		tw.tween_callback(Sfx.play.bind("pop", 0.9 + i * 0.06, -16.0))
		tw.tween_property(n, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	van.scale = Vector2.ZERO
	create_tween().tween_property(van, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stack_view.rebuild(stack_view.colors.duplicate())


## While the van waits, houses that want the package now on top give a little hop every couple of
## seconds, and the top package in the load nods along: a gentle "this one goes here".
func _process(delta: float) -> void:
	if stars_ctl and (Progress.momentum > 0 or _twist() == "mega") and state != State.WON:
		stars_ctl.queue_redraw()
	_side_tick(delta)
	_alive += delta
	# Holding a symbol explains it too (no need to let go).
	if not _sym_press.is_empty() and _alive - float(_sym_press["t"]) > 0.4:
		var tile: Vector2i = _sym_press["tile"]
		_sym_press = {}
		_explain(tile)
	if not _tips.is_empty() and (_tip == null or not is_instance_valid(_tip)) and not _busy_modal() and _alive > 1.0 and state == State.IDLE:
		_show_tip(_tips.pop_front())
	# The trail follows what's really aboard (while a route's being planned, the chute shows the future).
	if convoy and state != State.DRAWING:
		convoy.set_colors(stack_view.colors)
	if timing and state != State.WON and not _busy_modal():
		play_time += delta
	if state != State.IDLE or _busy_modal():
		_beat = 0.8
		return
	_beat -= delta
	if _beat > 0.0:
		return
	_beat = 2.6
	var top := Sim.top_color(level, sim_state)
	var any := false
	for h in level.houses.size():
		if level.houses[h].color == top and sim_state["fills"][h] < level.houses[h].order:
			board.house_nodes[h].hop()
			any = true
	if any:
		stack_view.nod()


# ---------------------------------------------------------------- building

func _compute_insets() -> void:
	var ins := UiTheme.insets(get_viewport())
	_top_inset = ins.x
	_bottom_inset = ins.y


func _build_world() -> void:
	# The van's load rides in a chute beside the board (or above or below it, as the options say). It's sized
	# first (as big as fits, with room for everything the van could ever carry); the board gets what's left.
	stack_view = StackView.new()
	add_child(stack_view)
	# Room for everything the level could ever have aboard, up to the most a level may carry (a big level's
	# warehouses top the van up along the way; if a wrong turn overloads it, the truck scrolls).
	var cap := clampi(level.stack.size() + level.total_parcels(), 1, LevelData.MAX_LOAD)
	var load: Array = level.stack
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--load-demo="):
			# Debug: draw a pretend load of this many packages (for looking at big loads; not playable).
			var n := a.trim_prefix("--load-demo=").to_int()
			cap = mini(n, LevelData.MAX_LOAD)
			load = []
			for i in n:
				load.append(["purple", "red", "blue", "yellow", "green", "orange"][(i * 5 + 2) % 6])
	# Sized first as if beside the board; Auto then picks its spot (and reshapes it) when the tile's fitted.
	var auto := Progress.stack_side == "auto" and not Progress.landscape
	if auto:
		_auto_side = "left"
	var shape := _chute_shape()
	stack_view.setup(load, shape[0], cap, shape[1], shape[2])
	stack_view.finish_flag = level.return_depot
	if auto:
		_auto_side = ""
		_chute_side()
	var tile := _fit_tile()
	_tile = tile

	board = Board.new()
	add_child(board)
	board.setup(level, tile)

	if level.number == 1 and not dpad_mode and not solve_info.get("shortest", []).is_empty():
		ghost = GhostFinger.new()
		ghost.radius = tile * 0.22
		for p in solve_info["shortest"]:
			ghost.pts.append(board.center(p))
		board.add_child(ghost)

	# The package trail (an option): the next few packages on drones behind the van.
	convoy = Convoy.new()
	convoy.tile = tile
	convoy.visible = Progress.trail
	board.add_child(convoy)
	van = Van.new()
	van.size = tile
	van.position = board.center(level.start)
	van.target_rotation = _initial_heading()
	board.add_child(van)
	convoy.van = van
	van.set_top(Sim.top_color(level, sim_state))
	van.inviting = true

	fx = Fx.new()
	fx.z_index = 20
	board.add_child(fx)

	confetti = Confetti.new()
	confetti.z_index = 50
	add_child(confetti)


## Sideways: the board in the middle; the controls in the side column for the hand they're for (the D-pad
## low in that corner, DRIVE over it), Hint/Undo/Retry and the hint text in the other column, options low
## on that side. Drawing: the hint on the left, Hint/Undo/Retry stacked on the right, options bottom left.
func _layout_sideways(vp: Vector2, top: float, bsz: Vector2) -> void:
	var sides := UiTheme.side_insets(get_viewport())
	bar.offset_left = 36 + sides.x
	bar.offset_right = -36 - sides.y
	var bottom := vp.y - _bottom_inset - 28.0
	var left_x := 28.0 + sides.x
	var right_x := vp.x - 28.0 - sides.y
	var buttons := [hint_button, undo_button, retry_button]
	actions.vertical = false
	var text_x := left_x
	var text_w := board.position.x - left_x - 36.0
	var text_bottom := bottom
	if dpad_mode:
		var lefty: bool = Progress.left_hand
		var pad := Vector2(PAD_CELL * 3.0, PAD_CELL * 2.0)
		dpad.mirrored = lefty
		dpad.size = pad
		dpad.position = Vector2(left_x if lefty else right_x - pad.x, bottom - pad.y)
		drive_button.size = Vector2(pad.x, 128)
		drive_button.position = Vector2(dpad.position.x, dpad.position.y - 128 - 18)
		# The other column: hint text from the top, Hint/Undo/Retry, then options at the bottom.
		var far_l := board.position.x + bsz.x + 36.0 if lefty else left_x
		var far_w := (right_x - far_l) if lefty else (board.position.x - 36.0 - left_x)
		for b in buttons:
			b.custom_minimum_size = Vector2(minf((far_w - 20.0) / 3.0, 200.0), 108)
			b.font_px = 34
		actions.size = Vector2(far_w, 108)
		actions.position = Vector2(far_l, bottom - 112 - 24 - 108)
		mode_button.size = Vector2(118, 112)
		mode_button.position = Vector2(far_l if not lefty else right_x - 118.0, bottom - 112)
		text_x = far_l
		text_w = far_w
		text_bottom = actions.position.y - 20.0
	else:
		for b in buttons:
			b.custom_minimum_size = Vector2(240, 118)
			b.font_px = 40
		var col_w := 240.0
		# Stacked: Hint on top, then Undo, then Retry.
		actions.vertical = true
		actions.size = Vector2(col_w, 118 * 3 + 28)
		actions.position = Vector2(right_x - col_w, bottom - actions.size.y)
		mode_button.size = Vector2(118, 118)
		mode_button.position = Vector2(left_x, bottom - 118)
		text_bottom = mode_button.position.y - 20.0
	var px := 34
	var line := UiTheme.font().get_height(px) + 3.0
	var room := maxf(text_bottom - top, line)
	hint_label.add_theme_font_size_override("font_size", px)
	hint_label.position = Vector2(text_x, top)
	hint_label.size = Vector2(maxf(text_w, 200.0), room)
	hint_label.max_lines_visible = maxi(1, int((room + 3.0) / line))
	hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


## Where the chute goes: the option upright; always along the top sideways.
func _chute_side() -> String:
	if Progress.landscape:
		return "top"
	if Progress.stack_side != "auto":
		return Progress.stack_side
	if _auto_side == "":
		_auto_side = _pick_auto_side()
	return _auto_side


## Auto (the default): beside the board on the left, unless along the top gives the board clearly more
## room (wide maps, like the Death Valley ones).
func _pick_auto_side() -> String:
	var tiles := {}
	for side in ["left", "top"]:
		_auto_side = side
		var sh := _chute_shape()
		stack_view.reshape(sh[0], sh[1], sh[2])
		tiles[side] = _fit_tile()
	var pick := "left" if tiles["left"] >= tiles["top"] * 0.96 else "top"
	_auto_side = pick
	var shape := _chute_shape()
	stack_view.reshape(shape[0], shape[1], shape[2])
	return pick


func _chute_upright() -> bool:
	return _chute_side() in ["left", "right"]


## The chute's shape for the current screen: [room along it, upright, which way its spout points].
func _chute_shape() -> Array:
	var vp := get_viewport_rect().size
	match _chute_side():
		"left", "right":
			var room := vp.y - _header_bottom() - _controls_h() - _bottom_inset - 50.0
			return [room, true, 1.0 if _chute_side() == "left" else -1.0]
		"bottom":
			return [vp.x - 80.0, false, -1.0]
	return [vp.x - 80.0 if not Progress.landscape else minf(vp.x - 80.0, 1500.0), false, 1.0]


## The biggest tile size the board can have, with room left for the controls in the current steering mode.
## Room kept beyond the board on the exit's side (in tiles), so the road out and its gate are on screen.
const EXIT_ROOM := 0.75


## Which way the exit road leaves the board (zero without one): the side that needs EXIT_ROOM.
func _exit_side() -> Vector2:
	return Vector2(level.exit_dir()) if level.has_exit() else Vector2.ZERO


func _fit_tile() -> float:
	var vp := get_viewport_rect().size
	var ex := _exit_side().abs() * EXIT_ROOM
	if Progress.landscape:
		# Sideways: the board fills the middle, between the two side columns, below the truck.
		var sides := UiTheme.side_insets(get_viewport())
		var avail_w := vp.x - 2.0 * (SIDE_PAD if dpad_mode else SIDE_DRAW) - sides.x - sides.y
		var avail_hl := vp.y - _board_top() - _bottom_inset - 36.0
		return minf(minf(avail_w / (level.width + ex.x), avail_hl / (level.height + ex.y)), 230.0)
	# Upright, from the top: the bar, a little room for the level's name and hint, the board (with the chute
	# beside, above or below it), the controls. The board is as big as the width allows (its rim included),
	# or the height, whichever's less.
	var avail_w := vp.x - 40.0
	var avail_h := vp.y - _header_bottom() - TEXT_MIN - _controls_h() - _bottom_inset - 40.0
	if _chute_upright():
		avail_w -= stack_view.extent().x + CHUTE_GAP
	else:
		avail_h -= _tray_h()
	var tile := minf(avail_w / (level.width + 0.3 + ex.x), avail_h / (level.height + 0.35 + ex.y))
	return minf(tile, 230.0)


## Upright layout pieces: where the top bar ends, the truck's height (with its gap to the board), and the
## controls' height (with the margin under them).
func _header_bottom() -> float:
	return 150.0 + _top_inset


func _tray_h() -> float:
	return stack_view.extent().y + 14.0


func _controls_h() -> float:
	return (PAD_CELL * 2.0 + 18.0 + 128.0 if dpad_mode else 118.0) + 50.0


## Where the board starts: under the top bar and the truck.
func _board_top() -> float:
	return TOP_BAR + _top_inset - 14.0 + stack_view.extent().y + 14.0


func _initial_heading() -> float:
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		if level.is_road(level.start + d):
			return Vector2(d).angle()
	return 0.0


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.theme()
	ui.add_child(root)
	_ui_root = root
	peek = PeekBubble.new()
	peek.unit = 58.0
	peek.visible = false
	root.add_child(peek)

	# Top bar: levels button, gas gauge, level name with its stars, wallet.
	bar = HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 36
	bar.offset_right = -36
	bar.offset_top = 40 + _top_inset
	bar.offset_bottom = 40 + _top_inset + 110
	bar.add_theme_constant_override("separation", 12)
	root.add_child(bar)

	var menu_btn := JuicyButton.new()
	menu_btn.icon_name = "grid"
	menu_btn.custom_minimum_size = Vector2(112, 102)
	menu_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	menu_btn.pressed.connect(func():
		Sfx.play("click")
		_leave())
	bar.add_child(menu_btn)

	gas_chip = GasChip.new()
	gas_chip.shop_requested.connect(_open_shop)
	bar.add_child(gas_chip)

	var mid := VBoxContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", -4)
	bar.add_child(mid)
	level_label = Label.new()
	level_label.text = "Level %d" % level.number if daily_day < 0 else "Daily #%d" % Daily.number(daily_day)
	if not side.is_empty():
		level_label.text = str(side.get("title", "Side road"))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 52)
	mid.add_child(level_label)
	stars_ctl = Control.new()
	stars_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars_ctl.custom_minimum_size = Vector2(0, 40)
	stars_ctl.draw.connect(_draw_stars)
	mid.add_child(stars_ctl)

	coin_chip = CoinChip.new()
	bar.add_child(coin_chip)

	# Momentum, under the wallet: a little flame and the count, while it's alive.
	momentum_ctl = Control.new()
	momentum_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	momentum_ctl.size = Vector2(252, 70)
	momentum_ctl.visible = false       # the streak now burns beside the stars (see _draw_stars)
	root.add_child(momentum_ctl)

	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 26)
	debug_label.add_theme_color_override("font_color", Palette.TEXT_SOFT)
	debug_label.text = "DEBUG  solver: " + Solver.describe(level, solve_info) if not solve_info.is_empty() else ""
	debug_label.visible = OS.is_debug_build() and OS.get_cmdline_user_args().has("--debug")
	debug_label.position = Vector2(44, 160 + _top_inset)
	root.add_child(debug_label)
	momentum_ctl.position = Vector2(get_viewport_rect().size.x - 36 - 252, 150 + _top_inset)

	# Draw / D-pad switch, down with the controls (see _layout).
	mode_button = JuicyButton.new()
	mode_button.icon_name = "gear"
	mode_button.pressed.connect(func():
		if _busy_modal():
			return
		Sfx.play("click")
		if dpad_mode and state == State.DRAWING:
			_cancel_plan()
		options_requested.emit())
	root.add_child(mode_button)
	Progress.settings_changed.connect(_on_settings)
	dpad = DPad.new()
	dpad.step.connect(_dpad_step)
	dpad.clear.connect(_dpad_clear)
	root.add_child(dpad)
	drive_button = JuicyButton.new()
	drive_button.label = "DRIVE BABY DRIVE"
	drive_button.icon_name = "play"
	drive_button.font_px = 48
	drive_button.bg = Palette.GOOD
	drive_button.fg = Color.WHITE
	drive_button.pressed.connect(_dpad_drive)
	root.add_child(drive_button)

	title_label = Label.new()
	title_label.text = ("“%s”" % level.title) if level.title != "" else ""
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 58)
	title_label.add_theme_color_override("font_color", Palette.TEXT)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_label)
	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 40)
	hint_label.add_theme_color_override("font_color", Palette.TEXT)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_hint = _hint_text()
	hint_label.text = _base_hint
	root.add_child(hint_label)

	# Bottom row: Hint, Undo, Retry.
	actions = BoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	root.add_child(actions)
	hint_button = _action("bulb", "Hint", _on_hint_pressed)
	undo_button = _action("undo", "Undo", _on_undo_pressed)
	retry_button = _action("retry", "Retry", _on_retry_pressed)
	if not _replay_free():
		retry_button.badge = "1"
		retry_button.badge_icon = "gas"
		retry_button.badge_color = GasChip.FUEL


## What the label under the board says before the player starts: the level's name and its hint (or how to
## steer). The D-pad leaves less room, so there it's just the hint.
func _hint_text() -> String:
	var how := "Tap the arrows to plot a route, then DRIVE BABY DRIVE." if dpad_mode else "Drag a route from the van."
	var default_hint := "Deliver everything, then park at the depot." if level.return_depot else how
	var body: String = level.hint if level.hint != "" else default_hint
	if level.number == 1:
		body = how
	if Progress.landscape and level.title != "":
		return "“%s”\n" % level.title + body
	return body


func _action(icon: String, text: String, on_press: Callable) -> JuicyButton:
	var b := JuicyButton.new()
	b.icon_name = icon
	b.label = text
	b.font_px = 40
	b.custom_minimum_size = Vector2(212, 118)
	b.pressed.connect(on_press)
	actions.add_child(b)
	return b


## The stars still on offer this attempt, under the level name.
func _draw_stars() -> void:
	if _twist() == "mega":
		_draw_parts_map()
		return
	var lit := 3 - int(hint_used) - int(undo_used)
	var c := stars_ctl.size / 2.0
	for i in 3:
		Icons.star(stars_ctl, c + Vector2((i - 1) * 46.0, 0), 19.0, Palette.STAR_GOLD if i < lit else Color(Palette.TEXT, 0.14))
	# Momentum: a little flame and the count, while the run's alive.
	var m := Progress.momentum
	if m > 0 and state != State.WON:
		var f := UiTheme.font()
		var t := Time.get_ticks_msec() / 1000.0
		var at := c + Vector2(96, 0)
		AnimeFire.draw_flame(stars_ctl, at + Vector2(0, 17), 28, 38 + 2.0 * mini(m, 8), t, 1.0, AnimeFire.palette(m))
		var txt := "×%d" % m
		stars_ctl.draw_string_outline(f, at + Vector2(17, 11), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color.WHITE)
		stars_ctl.draw_string(f, at + Vector2(17, 11), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, AnimeFire.palette(m)[0].darkened(0.1))


func _layout() -> void:
	var vp := get_viewport_rect().size
	_auto_side = ""
	var shape := _chute_shape()
	stack_view.reshape(shape[0], shape[1], shape[2])
	# The board was built at one tile size; scale it to whatever fits the current layout.
	var k := _fit_tile() / _tile
	board.scale = Vector2(k, k)
	var bsz := board.size_px() * k
	var ce := stack_view.extent()
	var co := stack_view.origin_in()
	if Progress.landscape:
		# Sideways: the truck right under the top bar, the board under it, the controls beside.
		title_label.visible = false
		var top := _board_top()
		var exs := _exit_side() * board.tile * k * EXIT_ROOM
		if exs.y < 0.0:
			top -= exs.y
		board.position = Vector2(round((vp.x - bsz.x - exs.x) / 2.0), top)
		var front := ce.x - co.x
		var right := board.position.x + bsz.x + board.tile * k * 0.15
		stack_view.position = Vector2(clampf(right - front, 20.0 + co.x, vp.x - 20.0 - front), TOP_BAR + _top_inset - 14.0 + co.y)
		stack_view.reach = bsz.x + board.tile * k * 0.3
		_layout_sideways(vp, top, bsz)
		_place_peek()
		return
	title_label.visible = title_label.text != ""
	var bottom := vp.y - _bottom_inset - 50.0
	bar.offset_left = 36
	bar.offset_right = -36
	actions.vertical = false
	# Controls along the bottom. Drawing: options on the left, Hint/Undo/Retry on the right.
	# D-pad: the pad in the corner of the hand it's for, DRIVE right above it; Hint/Undo/Retry up on the far
	# side (well away from the pad), options under them.
	var block_top := bottom - 118.0
	var buttons := [hint_button, undo_button, retry_button]
	if dpad_mode:
		var pad := Vector2(PAD_CELL * 3.0, PAD_CELL * 2.0)
		var lefty: bool = Progress.left_hand
		var pad_x := 28.0 if lefty else vp.x - 28.0 - pad.x
		dpad.mirrored = lefty
		dpad.size = pad
		dpad.position = Vector2(pad_x, bottom - pad.y)
		drive_button.size = Vector2(pad.x, 128)
		drive_button.position = Vector2(pad_x, dpad.position.y - 128 - 18)
		var far_w := vp.x - pad.x - 28.0 * 2.0 - 64.0
		var far_x := vp.x - 28.0 - far_w if lefty else 28.0
		for b in buttons:
			b.custom_minimum_size = Vector2((far_w - 20.0) / 3.0, 104)
			b.font_px = 32
		actions.size = Vector2(far_w, 104)
		actions.position = Vector2(far_x, drive_button.position.y + 12)
		mode_button.size = Vector2(118, 112)
		mode_button.position = Vector2(far_x if not lefty else vp.x - 28.0 - 118.0, bottom - 112)
		block_top = drive_button.position.y
	else:
		for b in buttons:
			b.custom_minimum_size = Vector2(212, 118)
			b.font_px = 40
		actions.size = Vector2(212 * 3 + 28, 118)
		actions.position = Vector2(vp.x - 36 - actions.size.x, bottom - 118)
		mode_button.size = Vector2(118, 118)
		mode_button.position = Vector2(36, bottom - 118)
	# Upright, bottom-up: the board sits just above the controls (where the thumb already is) and the level's
	# name and hint get whatever's left under the top bar, centred in it. The chute stands beside the board
	# with its mouth down by the controls (left or right), or lies right on top of it or right under it.
	var tk := board.tile * k
	var side := _chute_side()
	var floor_y := block_top - 30.0
	# The board as drawn (its rim included).
	var bw := bsz.x + tk * 0.3
	# The exit road's room: beside the board (kept with it, like its rim), or above or below it.
	var exs := _exit_side() * tk * EXIT_ROOM
	bw += absf(exs.x)
	var lab := stack_view._lab()
	var text_l := 20.0
	var text_w := vp.x - 40.0
	# Upright or underneath, the chute (its label included) ends a little over the buttons, clear of their
	# badges.
	var chute_bottom := block_top - 26.0
	if side == "bottom":
		stack_view.position.y = chute_bottom - ce.y + co.y
		floor_y = chute_bottom - ce.y - 14.0
	if exs.y > 0.0:
		floor_y -= exs.y
	var board_y: float = round(floor_y - tk * 0.21 - bsz.y)
	var board_top := board_y - tk * 0.14 + minf(exs.y, 0.0)
	if _chute_upright():
		# Chute and board side by side, centred together, like a puzzle game's "next" column: NEXT and the
		# next package level with the board's top, the queue running down the board's whole height. (A load
		# longer than the board is tall: it starts higher, still ending clear of the buttons.)
		var group_x: float = round((vp.x - ce.x - CHUTE_GAP - bw) / 2.0)
		var chute_l := group_x if side == "left" else group_x + bw + CHUTE_GAP
		var board_l := group_x + ce.x + CHUTE_GAP if side == "left" else group_x
		if exs.x < 0.0:
			board_l -= exs.x
		board.position = Vector2(board_l + tk * 0.15, board_y)
		var top := minf(board_top, chute_bottom - ce.y)
		stack_view.position = Vector2(chute_l + co.x, top + co.y)
		stack_view.reach = floor_y - top - lab
		text_l = chute_l + ce.x + CHUTE_GAP - 20.0 if side == "left" else 20.0
		text_w = vp.x - 20.0 - text_l if side == "left" else chute_l - CHUTE_GAP + 20.0 - text_l
	else:
		# Lying along the board's top or bottom, its mouth at the board's right end, as long as the board.
		board.position = Vector2(round((vp.x - bsz.x - exs.x) / 2.0), board_y)
		var right := board.position.x + bsz.x + tk * 0.15
		var front := ce.x - co.x
		stack_view.position.x = clampf(right - front, 20.0 + co.x, vp.x - 20.0 - front)
		stack_view.reach = bw
		if side == "top":
			stack_view.position.y = board_top - 14.0 - ce.y + co.y
	var text_top := _header_bottom() + 12.0
	var text_bottom := board_top - 14.0
	if side == "top":
		text_bottom = stack_view.position.y - co.y - 14.0
	var room := maxf(text_bottom - text_top, 60.0)
	var px := 38
	var line := UiTheme.font().get_height(px) + 3.0
	var tpx := 58 if room > 260.0 else 46
	title_label.add_theme_font_size_override("font_size", tpx)
	var title_h := (UiTheme.font().get_height(tpx) + 6.0) if title_label.visible else 0.0
	if title_h > 0.0 and room < title_h + line and hint_label.text != "":
		# No room for the name and a line of hint: the hint matters more.
		title_label.visible = false
		title_h = 0.0
	hint_label.add_theme_font_size_override("font_size", px)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Beside an upright chute, the words keep out of its column.
	var hint_lines := maxi(1, int((room - title_h + 3.0) / line))
	var hint_h := minf(_text_height(hint_label.text, px, text_w - 100.0), hint_lines * line)
	var y := text_top + maxf(0.0, (room - title_h - hint_h) / 2.0)
	title_label.position = Vector2(text_l + 40.0, y)
	title_label.size = Vector2(text_w - 80.0, title_h)
	hint_label.position = Vector2(text_l + 50.0, y + title_h)
	hint_label.size = Vector2(text_w - 100.0, maxf(hint_h, line))
	hint_label.max_lines_visible = hint_lines
	hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place_peek()


## A mega route's parts as a little map (like a big puzzle's grid of small ones): done ones ticked, this
## one lit, the rest to come.
func _draw_parts_map() -> void:
	var grid: Array = side.get("grid", [_parts(), 1])
	var cell := 22.0
	var gap := 5.0
	var gw: float = grid[0] * cell + (grid[0] - 1) * gap
	var gh: float = grid[1] * cell + (grid[1] - 1) * gap
	var o := stars_ctl.size / 2.0 - Vector2(gw, gh) / 2.0
	var parts: Array = side.get("parts", [])
	for k in parts.size():
		var at: Array = parts[k].get("at", [k, 0])
		var r := Rect2(o + Vector2(at[0], at[1]) * (cell + gap), Vector2(cell, cell))
		if k < part:
			DrawUtil.rrect(stars_ctl, r, Palette.GOOD, 6)
			stars_ctl.draw_polyline(PackedVector2Array([r.get_center() + Vector2(-5, 0), r.get_center() + Vector2(-1, 4), r.get_center() + Vector2(6, -4)]), Color.WHITE, 3.0, true)
		elif k == part:
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
			DrawUtil.rrect(stars_ctl, r.grow(2.0 * pulse), Color(Palette.ACCENT, 0.35), 8)
			DrawUtil.rrect(stars_ctl, r, Palette.ACCENT, 6)
		else:
			DrawUtil.rrect(stars_ctl, r, Color(Palette.TEXT, 0.14), 6)


## How tall `text` wraps to at `px` in `width`.
func _text_height(text: String, px: int, width: float) -> float:
	var f := UiTheme.font()
	var lines := 0
	for para in text.split("\n"):
		lines += maxi(1, int(ceil(f.get_string_size(para, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / maxf(width - 20.0, 1.0))))
	return lines * (f.get_height(px) + 3.0)


# ---------------------------------------------------------------- input

func _busy_modal() -> bool:
	return modal != null and is_instance_valid(modal)


func _unhandled_input(event: InputEvent) -> void:
	if _busy_modal():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_retry()
			KEY_Z, KEY_U, KEY_BACKSPACE:
				undo()
			KEY_H:
				_on_hint_pressed()
			KEY_N, KEY_ENTER, KEY_SPACE:
				if state == State.WON:
					_next()
				elif state == State.FAILED:
					_retry()
				elif dpad_mode:
					_dpad_drive()
			KEY_UP:
				_dpad_step(Vector2i(0, -1))
			KEY_DOWN:
				_dpad_step(Vector2i(0, 1))
			KEY_LEFT:
				_dpad_step(Vector2i(-1, 0))
			KEY_RIGHT:
				_dpad_step(Vector2i(1, 0))
			KEY_ESCAPE:
				menu_requested.emit()
			KEY_F3, KEY_D:
				debug_label.visible = not debug_label.visible
			KEY_S:
				if OS.is_debug_build() and route.size() == 1:
					drive_tiles(solve_info.get("shortest", []))
		return
	# The chute: a tap on a package makes the houses waiting for that colour wave; a drag along it scrolls it
	# when there's more aboard than fits.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and state != State.DRAWING:
		var local: Vector2 = stack_view.make_input_local(event).position
		if event.pressed and stack_view.covers(local):
			_load_drag = {"at": stack_view.along(local), "view": stack_view.view(), "moved": false}
			return
		if not event.pressed and not _load_drag.is_empty():
			if not _load_drag.moved:
				var tapped := stack_view.tap_at(local)
				if tapped != "":
					_point_out(tapped)
			stack_view.settle()
			_load_drag = {}
			return
	if event is InputEventMouseMotion and not _load_drag.is_empty():
		# How far it's been dragged toward the mouth.
		var by: float = _load_drag.at - stack_view.along(stack_view.make_input_local(event).position)
		if absf(by) > 14.0:
			_load_drag.moved = true
		if _load_drag.moved:
			stack_view.drag(_load_drag.view, by)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var lp: Vector2 = board.make_input_local(event).position
		# A tap (or a hold) on a symbol, away from the van: what's that?
		if event.pressed and (state == State.IDLE or state == State.FAILED or state == State.WON) and _symbol_at(board.tile_at(lp)).size() > 0 \
				and (dpad_mode or state != State.IDLE or not _on_van(lp)):
			_sym_press = {"tile": board.tile_at(lp), "pos": event.position, "t": _alive}
			return
		if not event.pressed and not _sym_press.is_empty():
			var sp := _sym_press
			_sym_press = {}
			if event.position.distance_to(sp["pos"]) < 24.0:
				_explain(sp["tile"])
			return
		if dpad_mode:
			return
		if event.pressed:
			_press(lp)
		else:
			_release()
	elif event is InputEventMouseMotion and not _sym_press.is_empty():
		if event.position.distance_to(_sym_press["pos"]) > 24.0:
			_sym_press = {}
	elif event is InputEventMouseMotion and state == State.DRAWING and not dpad_mode:
		# Self-tests inject their own drags: ignore the real cursor wandering over the window meanwhile.
		if Progress.auto and not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			return
		_drag(board.make_input_local(event).position)


## The houses still waiting for a package of `color_name` hop, with a ring in their colour.
func _point_out(color_name: String) -> void:
	Sfx.play("tick", 1.2, -4)
	Sfx.haptic(6)
	for h in level.houses.size():
		if level.houses[h].color == color_name and sim_state["fills"][h] < level.houses[h].order:
			var house: House = board.house_nodes[h]
			house.hop()
			fx.ring(house.base_pos + Vector2(0, -board.tile * 0.3), Palette.pkg(color_name), board.tile * 0.6)


func _on_van(lp: Vector2) -> bool:
	var here: Vector2i = route.back()
	return board.tile_at(lp) == here or lp.distance_to(board.center(here)) < board.tile * 0.75


func _press(lp: Vector2) -> void:
	if state != State.IDLE:
		return
	var here: Vector2i = route.back()
	var on_van := _on_van(lp)
	if not on_van:
		if Rect2(Vector2.ZERO, board.size_px()).grow(board.tile).has_point(lp):
			van.nudge()
			Sfx.play("untick", 0.8, -6)
		return
	_begin_plan()


## A new segment starts at the van: nothing plotted yet.
func _begin_plan() -> void:
	state = State.DRAWING
	timing = true
	_clear_hint()
	seg = [route.back()]
	seg_states = [Sim.copy_state(sim_state)]
	_unblock()
	_denied = NOWHERE
	van.inviting = false
	van.nudge()
	if ghost:
		ghost.visible = false
	_fade(hint_label, 0.35)
	_show_seg()
	_preview_load()
	Sfx.play("tick", 0.85)
	Sfx.haptic(8)


## While planning: the chute shows the load as it'll be at the end of the route so far (so its mouth holds
## what's next from there), and with the route preview on, a chip by the board's corner shows the next three.
func _preview_load() -> void:
	if state != State.DRAWING or seg.is_empty() or seg_states.is_empty():
		stack_view.show_stack(sim_state["stack"])
		peek.clear()
		return
	var st: Array = seg_states.back()["stack"]
	stack_view.show_stack(st)
	if not Progress.peek or _twist() == "fog":
		peek.clear()
		return
	var cols := []
	for k in mini(3, st.size()):
		cols.append(Palette.pkg(st[st.size() - 1 - k]))
	peek.show_cols(cols)
	_place_peek()


## The preview chip's spot: just above the board's top-right corner (above the chute when it's on top;
## sideways, top right under the bar). Never on the board.
func _place_peek() -> void:
	var vp := get_viewport_rect().size
	var tk := board.tile * board.scale.x
	if Progress.landscape:
		var sides := UiTheme.side_insets(get_viewport())
		peek.position = Vector2(vp.x - 28.0 - sides.y, _board_top() + peek.size().y)
	elif _chute_side() == "top":
		peek.position = Vector2(board.position.x + board.size_px().x * board.scale.x, stack_view.position.y - stack_view.origin_in().y - 8.0)
	else:
		peek.position = Vector2(board.position.x + board.size_px().x * board.scale.x, board.position.y - tk * 0.14 - 8.0)


## Drops the segment being planned: back to waiting at the van.
func _cancel_plan() -> void:
	state = State.IDLE
	seg = []
	seg_states = []
	_unblock()
	_remove_ghost()
	_preview_load()
	board.show_path([])
	board.update_gates(Sim.top_color(level, sim_state))
	van.inviting = true
	if ghost and route.size() == 1 and not dpad_mode:
		ghost.visible = true
	if route.size() == 1:
		_fade(hint_label, 1.0)
	_refresh_tags()
	_update_drive_button()


func _full() -> Array:
	return route + seg.slice(1)


func _can(next: Vector2i) -> bool:
	if _twist() == "fuel" and _fuel_left() <= 0:
		return false
	return Sim.can_extend(level, _full(), next, seg_states.back())


## Would this step run into torn-up road, or into the route being planned?
func _wreck(next: Vector2i) -> bool:
	return Sim.wrecked(level, _full(), next, seg_states.back())


## The segment being planned, each stretch tinted with the package on top while driving it.
func _show_seg() -> void:
	var cols := []
	for i in range(0, seg.size() - 1):
		cols.append(_tint(Sim.top_color(level, seg_states[i])))
	board.show_path(seg, cols)


func _tint(color_name: String) -> Variant:
	return Palette.pkg(color_name) if color_name != "" else null


## The route can't go onto `t`: a red X on that edge. The line stays where it is.
func _block(t: Vector2i) -> void:
	if blocked_at == t:
		return
	blocked_at = t
	board.show_block(seg.back(), t)
	Sfx.play("bonk", 0.7, -4)
	Sfx.haptic(16)


func _unblock() -> void:
	if blocked_at != NOWHERE:
		blocked_at = NOWHERE
		board.clear_block()


## Houses waiting for the package that'll be next out of the van (as things stand at the end of the route
## being planned, or right now if none is) show a little parcel; houses the plan will fill show a ghost tick.
func _refresh_tags() -> void:
	board.update_works(Sim.delivered_count(sim_state))
	if board.exit_zone:
		board.exit_zone.open = Sim.all_delivered(level, sim_state)
	var st: Dictionary = seg_states.back() if (state == State.DRAWING and not seg_states.is_empty()) else sim_state
	# Pickups the planned route will empty hold still and fade.
	for k in board.shop_nodes.size():
		board.shop_nodes[k].planned = state == State.DRAWING and int(st["picked"][k]) > int(sim_state["picked"][k])
	var top := Sim.top_color(level, st)
	for h in level.houses.size():
		var house: House = board.house_nodes[h]
		var need: int = level.houses[h].order - st["fills"][h]
		house.ghost_done = need <= 0 and sim_state["fills"][h] < level.houses[h].order
		var was: bool = house.next_up
		house.next_up = need > 0 and top != "" and level.houses[h].color == top
		if house.next_up and not was and state == State.DRAWING:
			house.hop()


func _drag(lp: Vector2) -> void:
	var last: Vector2i = seg.back()
	# Hysteresis: stay on the current tile until the finger is clearly out of it.
	var off := (lp - board.center(last)).abs()
	if maxf(off.x, off.y) < board.tile * 0.58:
		_unblock()
		return
	var target := board.tile_at(lp)
	var guard := 0
	while target != seg.back() and guard < 24:
		guard += 1
		var cur: Vector2i = seg.back()
		# Dragging back over the segment undraws it (finished segments are locked).
		if seg.size() >= 2 and target == seg[seg.size() - 2]:
			_retract()
			continue
		var diff := target - cur
		if absi(diff.x) + absi(diff.y) == 1:
			if _can(target):
				_extend(target)
				continue
			if _wreck(target):
				_block(target)
			else:
				_unblock()
				_maybe_deny(target)
			break
		var steps: Array = [Vector2i(signi(diff.x), 0), Vector2i(0, signi(diff.y))]
		if absi(diff.y) > absi(diff.x):
			steps.reverse()
		var moved := false
		for s in steps:
			if s == Vector2i.ZERO:
				continue
			var nxt: Vector2i = cur + s
			if seg.size() >= 2 and nxt == seg[seg.size() - 2]:
				continue
			if _can(nxt):
				_extend(nxt)
				moved = true
				break
		if not moved and steps[0] != Vector2i.ZERO and seg.size() >= 2 and cur + steps[0] == seg[seg.size() - 2]:
			# The finger has swept back along the line faster than tile by tile: keep undrawing toward it.
			_retract()
			moved = true
		if not moved:
			for s in steps:
				if s != Vector2i.ZERO and _wreck(cur + s):
					_block(cur + s)
					break
			break


## Bumping into a closed gate: it rattles (once per attempt at that tile).
func _maybe_deny(t: Vector2i) -> void:
	if t == _denied or not board.gate_nodes.has(t):
		return
	_denied = t
	board.gate_nodes[t].deny()
	Sfx.play("bonk", 1.3, -8)
	Sfx.haptic(10)


func _extend(t: Vector2i) -> void:
	var st := Sim.copy_state(seg_states.back())
	Sim.arrive(level, st, t)
	seg.append(t)
	seg_states.append(st)
	_unblock()
	_show_seg()
	board.update_gates(Sim.top_color(level, st))
	_refresh_tags()
	_preview_load()
	Sfx.play("tick", 1.0 + minf(seg.size(), 24) * 0.015, -2)
	Sfx.haptic(6)


func _retract() -> void:
	seg.pop_back()
	seg_states.pop_back()
	_denied = NOWHERE
	_unblock()
	_show_seg()
	board.update_gates(Sim.top_color(level, seg_states.back()))
	_refresh_tags()
	_preview_load()
	Sfx.play("untick", 1.0, -4)
	Sfx.haptic(4)


## The plan is sent: the van drives it. If the X was showing (the player was pushing into wreckage), it
## ends with a hard brake just short of it.
func _release() -> void:
	if state != State.DRAWING:
		return
	var into := blocked_at
	_remove_ghost()
	if seg.size() < 2:
		_cancel_plan()
		if into != NOWHERE:
			van.shake()
		return
	_unblock()
	_brake_into = into
	_drive()


## Drives `tiles` (which must start at the van) as one segment. Used by debug/autotests.
func drive_tiles(tiles: Array) -> void:
	if state != State.IDLE or tiles.size() < 2 or tiles[0] != route.back():
		return
	seg = tiles.duplicate()
	_clear_hint()
	van.inviting = false
	if ghost:
		ghost.visible = false
	hint_label.modulate.a = 0.35
	board.show_path(seg)
	_drive()


# ---------------------------------------------------------------- steering mode and the D-pad

## A pop-up over the game: straight on top when upright; sideways, in a portrait column over a dim sheet.
func _overlay(node: Node) -> void:
	if not Progress.landscape:
		add_child(node)
		return
	if _host == null or not is_instance_valid(_host):
		_host = PortraitHost.new()
		_host.dim = true
		_host.auto_hide = true
		_host.layer = 60
		add_child(_host)
	_host.put(node)


## Draw or D-pad (from the options, or a test).
func set_dpad_mode(on: bool) -> void:
	if on == dpad_mode:
		return
	if state == State.DRAWING:
		_cancel_plan()
	dpad_mode = on
	_apply_mode()
	if dpad_mode:
		_say("D-pad on: tap or hold the arrows to plot a route, then DRIVE BABY DRIVE.")
	else:
		_say("Drawing on: drag a route from the van.")


## An option changed: steering, the hand, night mode (Main re-themes), or orientation (size_changed does it).
func _on_settings() -> void:
	set_dpad_mode(Progress.drive_mode == "dpad")
	if convoy:
		convoy.visible = Progress.trail
	_update_hint()
	_layout()


## Night mode flipped: labels that were given a colour get the new one.
func retheme() -> void:
	hint_label.add_theme_color_override("font_color", Palette.TEXT)
	title_label.add_theme_color_override("font_color", Palette.TEXT)
	stack_view.queue_redraw()
	board.queue_redraw()


## Shows the controls for the steering mode and lays the bottom of the screen out for them.
func _apply_mode() -> void:
	dpad.visible = dpad_mode
	drive_button.visible = dpad_mode
	if ghost and dpad_mode:
		ghost.visible = false
	_base_hint = _hint_text()
	if route.size() == 1 and state == State.IDLE:
		hint_label.text = _base_hint
	_layout()
	_update_drive_button()


## One tap (or repeat) of an arrow: a tile that way if the road allows; the way it came undraws a tile.
func _dpad_step(want: Vector2i) -> void:
	if not dpad_mode or _busy_modal():
		return
	if state == State.IDLE:
		_begin_plan()
		_spawn_ghost()
	if state != State.DRAWING:
		return
	var cur: Vector2i = seg.back()
	var nxt := cur + want
	if seg.size() >= 2 and nxt == seg[seg.size() - 2]:
		_retract()
	elif _can(nxt):
		_extend(nxt)
	elif _wreck(nxt):
		_block(nxt)
		dpad.deny(want)
	else:
		_unblock()
		_maybe_deny(nxt)
		dpad.deny(want)
		Sfx.play("untick", 0.8, -8)
	if seg.size() < 2:
		# Nothing plotted (it was undrawn, or the very first arrow pointed into wreckage): back to waiting.
		# The X stays up for a moment so the "no" is seen.
		var into := blocked_at
		_cancel_plan()
		if into != NOWHERE:
			van.shake()
			board.show_block(route.back(), into)
			var tw := create_tween()
			tw.tween_interval(0.6)
			tw.tween_callback(func():
				if blocked_at == NOWHERE:
					board.clear_block())
		return
	_move_ghost()
	_update_drive_button()


func _dpad_clear() -> void:
	if state == State.DRAWING and dpad_mode:
		Sfx.play("untick", 0.9, -4)
		_cancel_plan()


func _dpad_drive() -> void:
	if not dpad_mode or _busy_modal():
		return
	if state != State.DRAWING or seg.size() < 2:
		Sfx.play("untick", 0.8, -6)
		return
	Sfx.play("click")
	Sfx.haptic(30, 1.0)
	_release()
	_update_drive_button()


func _update_drive_button() -> void:
	if drive_button == null:
		return
	var ready := dpad_mode and state == State.DRAWING and seg.size() >= 2
	drive_button.dim = not ready
	drive_button.breathe(ready)


func _spawn_ghost() -> void:
	_remove_ghost()
	ghost_van = Van.new()
	ghost_van.size = board.tile
	ghost_van.position = van.position
	ghost_van.target_rotation = van.target_rotation
	ghost_van.modulate = Color(1, 1, 1, 0.55)
	ghost_van.z_index = 6
	board.add_child(ghost_van)
	ghost_van.set_top(Sim.top_color(level, sim_state))


func _remove_ghost() -> void:
	if ghost_van and is_instance_valid(ghost_van):
		ghost_van.queue_free()
	ghost_van = null


func _move_ghost() -> void:
	if ghost_van == null or not is_instance_valid(ghost_van) or seg.is_empty():
		return
	var to := board.center(seg.back())
	if seg.size() >= 2:
		ghost_van.target_rotation = (to - board.center(seg[seg.size() - 2])).angle()
	ghost_van.set_top(Sim.top_color(level, seg_states.back()))
	ghost_van.create_tween().tween_property(ghost_van, "position", to, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- driving

func _drive() -> void:
	state = State.DRIVING
	# The truck goes back to what's really aboard; the packages then leave it as they're delivered.
	stack_view.show_stack(sim_state["stack"])
	peek.clear()
	history.append({"len": route.size(), "state": Sim.copy_state(sim_state), "rot": van.target_rotation, "deliv": deliveries.size()})
	timing = true
	combo = 0
	_fired = 0
	_drive_len = float(seg.size() - 1)
	# The tint of each stretch: the package on top while driving it.
	_seg_cols = []
	var st := Sim.copy_state(sim_state)
	for i in range(1, seg.size()):
		_seg_cols.append(_tint(Sim.top_color(level, st)))
		Sim.arrive(level, st, seg[i])
	_update_undo()
	_refresh_tags()
	var ramp := minf(RAMP, _drive_len / 2.0)
	var dur := (_drive_len + 2.0 * ramp) / DRIVE_SPEED
	var tw := create_tween()
	tw.tween_method(_drive_tick, 0.0, dur, dur)
	tw.tween_callback(_drive_done)


## Distance along the segment at time t: accelerate over RAMP tiles, cruise, brake.
func _dist_at(t: float) -> float:
	var ramp := minf(RAMP, _drive_len / 2.0)
	var v := DRIVE_SPEED
	var ta := 2.0 * ramp / v
	var tc := (_drive_len - 2.0 * ramp) / v
	if t < ta:
		return 0.5 * (v / ta) * t * t
	if t < ta + tc:
		return ramp + v * (t - ta)
	var r := maxf(0.0, ta * 2.0 + tc - t)
	return _drive_len - 0.5 * (v / ta) * r * r


func _drive_tick(t: float) -> void:
	var d := clampf(_dist_at(t), 0.0, _drive_len)
	var i := clampi(int(floor(d)), 0, seg.size() - 2)
	var a := board.center(seg[i])
	var b := board.center(seg[i + 1])
	van.position = a.lerp(b, d - i)
	van.target_rotation = (b - a).angle()
	# Drawn route ahead of the van shrinks; the driven trail grows behind it.
	var ahead: Array = [van.position]
	for k in range(i + 1, seg.size()):
		ahead.append(seg[k])
	board.show_path(ahead, _seg_cols.slice(i))
	board.show_trail(route + seg.slice(1, i + 1) + [van.position])
	board.wreck.set_route(route + seg.slice(1), route.size() - 1 + i + (1 if d - i >= 0.55 else 0))
	# Momentum: the van leaves fire behind it.
	if board.fire.momentum > 0 and (_fire_last == Vector2.INF or van.position.distance_to(_fire_last) > board.tile * 0.22):
		_fire_last = van.position
		board.fire.emit(van.position)
	while _fired < seg.size() - 1 and d >= _fired + 1 - 0.02:
		_fired += 1
		_arrive(_fired)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Runs `cb` at absolute timeline time `at` (now if already past).
func _at(at: float, cb: Callable) -> void:
	var delay := at - _now()
	if delay <= 0.005:
		cb.call()
		return
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(cb)


func _arrive(k: int) -> void:
	var tile: Vector2i = seg[k]
	var res := Sim.arrive(level, sim_state, tile)
	for ev in res["events"]:
		var t := maxf(_now(), _vis_cursor)
		match ev["type"]:
			"swap":
				_at(t, _show_swap.bind(tile))
				_vis_cursor = t + 0.14
				_effects_end = maxf(_effects_end, t + 0.3)
			"deliver":
				deliveries.append(level.houses[ev["house"]].color)
				_at(t, _launch_package.bind(ev["house"], combo))
				combo += 1
				_vis_cursor = t + 0.08
				_effects_end = maxf(_effects_end, t + DROP_TIME + FLY_TIME + 0.02)
			"pickup":
				_at(t, _collect_parcel.bind(ev["shop"]))
				_vis_cursor = t + FLY_TIME + 0.02
				_effects_end = maxf(_effects_end, t + FLY_TIME + 0.04)
	if not res["nopes"].is_empty():
		for h in res["nopes"]:
			board.house_nodes[h].wobble()
		Sfx.play("bonk", randf_range(0.95, 1.05), -3)
		Sfx.haptic(12)
		combo = 0
	board.update_gates(Sim.top_color(level, sim_state))
	if level.return_depot and board.depot:
		board.depot.calling = Sim.all_delivered(level, sim_state)

	if board.gift and not gift_taken and tile == level.gift:
		_take_gift()
	_refresh_tags()
	if k < seg.size() - 1:
		var d_in: Vector2i = seg[k] - seg[k - 1]
		var d_out: Vector2i = seg[k + 1] - seg[k]
		if d_in != d_out:
			van.squash()


## The van drives over the present: it hops into the van (it's yours if you finish).
func _take_gift() -> void:
	gift_taken = true
	gift_seg = history.size() - 1
	var at := board.gift.position
	board.gift.taken = true
	var col := Cosmetics.tint(level.gift_item)
	fx.burst(at, col, 18, board.tile * 3.0, board.tile * 0.12)
	fx.ring(at, Palette.STAR_GOLD, board.tile * 0.7)
	fx.say(at + Vector2(0, -board.tile * 0.4), "Ooh, shiny!", col.darkened(0.2), int(board.tile * 0.3))
	Sfx.play("sparkle")
	Sfx.play("kaching", 1.3, -8.0)
	Sfx.haptic(20)
	van.nudge()


func _show_swap(tile: Vector2i) -> void:
	stack_view.swap_top()
	van.set_top(stack_view.top_color())
	if board.hub_nodes.has(tile):
		board.hub_nodes[tile].spin()
	van.squash()
	Sfx.play("swap")
	Sfx.haptic(14)


## A delivery: the next package drops out of the chute's mouth into the van, then flies on to the house.
func _launch_package(h: int, step: int) -> void:
	var house: House = board.house_nodes[h]
	var to := house.base_pos + Vector2(0, -board.tile * 0.35)
	var mouth := board.to_local(stack_view.mouth_global())
	var ms := stack_view.mouth_size()
	var big: float = ms.y / board.scale.x
	var out := board.to_local(stack_view.mouth_global() + stack_view._side() * stack_view.ph * 1.6)
	stack_view.pop_top(true)
	van.set_top(stack_view.top_color())
	var pkg := _make_flyer(level.houses[h].color, mouth)
	var small := pkg.size
	pkg.size = big
	pkg.aspect = ms.x / ms.y
	pkg.z_index = 30
	Sfx.play("whoosh", randf_range(0.95, 1.1), -10)
	var tw := create_tween()
	tw.tween_method(_drop.bind(pkg, mouth, out, small / big, ms.x / ms.y), 0.0, 1.0, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		pkg.size = small
		pkg.aspect = StackView.ASPECT
		pkg.scale = Vector2.ONE
		pkg.queue_redraw()
		van.nudge())
	tw.tween_method(func(t: float): _fly(t, pkg, pkg.get_meta("from", van.position), to, board.tile * 0.7), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		pkg.queue_free()
		house.deliver()
		# Sparkles in the package's colour, and a cheer when deliveries chain.
		var col := Palette.pkg(level.houses[h].color)
		fx.burst(to, col, 10, board.tile * 2.6, board.tile * 0.1)
		fx.ring(to, col, board.tile * 0.5)
		if step >= 1:
			fx.say(to + Vector2(0, -board.tile * 0.3), CHEERS[mini(step - 1, CHEERS.size() - 1)], col.darkened(0.12), int(board.tile * 0.32))
		var semis: int = COMBO_STEPS[mini(step, COMBO_STEPS.size() - 1)]
		Sfx.play("thunk", pow(2.0, semis / 12.0))
		Sfx.haptic(18))


## Parcel hops from the shop onto the (moving) van, then lands on top of the stack.
func _collect_parcel(k: int) -> void:
	var shop: Shop = board.shop_nodes[k]
	var color: String = level.shops[k].color
	var from := shop.parcel_pos()
	shop.collect()
	var pkg := _make_flyer(color, from)
	Sfx.play("pickup")
	Sfx.haptic(14)
	var tw := create_tween()
	tw.tween_method(_fly_to_van.bind(pkg, from, board.tile * 0.6), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		pkg.queue_free()
		stack_view.push(color)
		van.set_top(stack_view.top_color())
		van.nudge())


## Out of the chute's mouth (a little hop out the spout first) and down into the van, shrinking to board size.
## Where it ends up (the van, wherever it's got to) is where its flight to the house starts.
func _drop(t: float, pkg: PackageBox, from: Vector2, out: Vector2, shrink: float, aspect0: float) -> void:
	var to := van.position
	var u := 1.0 - t
	pkg.position = from * u * u + out * 2.0 * u * t + to * t * t
	pkg.scale = Vector2.ONE * lerpf(1.0, shrink, t)
	# Tall in an upright chute, wide on the board: it turns over on the way.
	pkg.aspect = lerpf(aspect0, StackView.ASPECT, t)
	pkg.queue_redraw()
	pkg.rotation = 0.4 * sin(PI * t)
	pkg.set_meta("from", pkg.position)


func _make_flyer(color_name: String, at: Vector2) -> PackageBox:
	var pkg := PackageBox.new()
	pkg.color = Palette.pkg(color_name)
	pkg.size = board.tile * 0.26
	pkg.aspect = StackView.ASPECT
	pkg.position = at
	pkg.z_index = 5
	board.add_child(pkg)
	return pkg


func _fly(t: float, pkg: Node2D, from: Vector2, to: Vector2, arc: float) -> void:
	pkg.position = from.lerp(to, t) + Vector2(0, -arc * 4.0 * t * (1.0 - t))
	pkg.rotation = t * PI
	pkg.scale = Vector2.ONE * lerpf(1.0, 0.75, t)


func _fly_to_van(t: float, pkg: Node2D, from: Vector2, arc: float) -> void:
	_fly(t, pkg, from, van.position, arc)


func _drive_done() -> void:
	van.stop_bounce()
	route = _full()
	seg = []
	seg_states = []
	board.show_path([])
	board.show_trail(route)
	board.wreck.set_route(route, route.size() - 1)
	var wait := maxf(0.05, _effects_end - _now() + 0.04)
	if _brake_into != NOWHERE:
		_brake(_brake_into)
		_brake_into = NOWHERE
		wait = maxf(wait, 0.7)
	var tw := create_tween()
	tw.tween_interval(wait)
	tw.tween_callback(_after_segment)


## The player sent the van on toward its own wreckage: it locks the wheels and stops just short, nose
## down, in a puff of tyre smoke. Nothing's lost: the level carries on (or is won) from here.
func _brake(into: Vector2i) -> void:
	var here := van.position
	var dir := (board.center(into) - here).normalized()
	var nose := here + dir * board.tile * 0.3
	van.target_rotation = dir.angle()
	board.show_block(route.back(), into)
	Sfx.play("screech", randf_range(0.95, 1.05), -3)
	Sfx.haptic(35)
	var tw := create_tween()
	tw.tween_property(van, "position", nose, 0.16).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		van.stop_bounce()
		for side in [-1.0, 1.0]:
			var back: Vector2 = here - dir * board.tile * 0.25 + Vector2(-dir.y, dir.x) * side * board.tile * 0.16
			fx.burst(back, Color(1, 1, 1, 0.9), 5, board.tile * 1.2, board.tile * 0.14)
		fx.burst(nose, Wreckage.DUST, 8, board.tile * 1.6, board.tile * 0.1)
		fx.say(here + Vector2(0, -board.tile * 0.5), "WHOA!", Palette.ACCENT.darkened(0.1), int(board.tile * 0.34))
		_shake_board(0.45))
	tw.tween_interval(0.12)
	tw.tween_property(van, "position", here, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(board.clear_block)


func _shake_board(amount := 1.0) -> void:
	var rest := board.position
	var tw := create_tween()
	for k in 6:
		tw.tween_property(board, "position", rest + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * board.tile * 0.07 * amount * (1.0 - k / 6.0), 0.035)
	tw.tween_property(board, "position", rest, 0.04)


func _after_segment() -> void:
	if Sim.is_won(level, sim_state, route) and _twist() == "mega" and part < _parts() - 1:
		_part_done()
	elif Sim.is_won(level, sim_state, route):
		_win()
	elif _twist() == "one_shot":
		_twist_fail("No brakes means one run: the whole route in one go.")
	elif _twist() == "fuel" and _fuel_left() <= 0:
		_twist_fail("Out of gas! Find the shortest way round.")
	elif _twist() == "melt" and _melt_left() <= 0.0:
		_twist_fail("Melted! Every delivery before the clock runs out.")
	elif not Sim.has_move(level, route, sim_state):
		_fail()
	else:
		state = State.IDLE
		van.inviting = true
		if level.return_depot and Sim.all_delivered(level, sim_state):
			_say("All delivered! Drive back to the depot.")
		_update_undo()
	_refresh_tags()
	_update_drive_button()
	segment_finished.emit()


# ---------------------------------------------------------------- undo

## Undos to hand: the free one for this attempt plus any spares earned from the ad.
func undos_available() -> int:
	if Progress.free_undos():
		return 99
	return undo_left + Progress.undo_bank


func can_undo() -> bool:
	return undos_available() > 0 and not history.is_empty() and (state == State.IDLE or state == State.FAILED)


func _on_undo_pressed() -> void:
	if _busy_modal():
		return
	if _strict_side():
		Sfx.play("bonk", 1.1, -6.0)
		_say("No undos on side roads!")
		return
	if dpad_mode and state == State.DRAWING:
		# A route is plotted but not driven yet: Undo just clears it.
		Sfx.play("untick", 0.9, -4)
		_cancel_plan()
		return
	if undos_available() <= 0:
		Sfx.play("click")
		_watch_ad()
	elif can_undo():
		Sfx.play("click")
		undo()
	else:
		Sfx.play("untick", 0.8, -6)


## Out of undos: the (pretend) ad plays, and pays AD_UNDOS spares however it ends.
func _watch_ad() -> void:
	var ad := FakeAd.new()
	modal = ad
	_overlay(ad)
	ad.finished.connect(func():
		modal = null
		Progress.add_undos(Progress.AD_UNDOS)
		Sfx.play("kaching", 1.0, -4)
		Sfx.haptic(20)
		_update_undo()
		undo_button.pop())


func undo() -> void:
	if not can_undo():
		return
	if Progress.free_undos():
		pass                        # a side road's power-up: undos are free (and cost no star)
	elif undo_left > 0:
		undo_left -= 1
		undo_used = true
	else:
		Progress.use_bank_undo()
		undo_used = true
	stars_ctl.queue_redraw()
	var snap: Dictionary = history.pop_back()
	deliveries.resize(snap.get("deliv", deliveries.size()))
	if gift_taken and gift_seg >= history.size():
		gift_taken = false
		gift_seg = -1
		board.gift.taken = false
		board.gift.scale = Vector2.ZERO
		board.gift.create_tween().tween_property(board.gift, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var start_i: int = snap["len"] - 1
	var back: Array = route.slice(start_i)          # segment tiles, first = where it began
	var old: Dictionary = sim_state
	sim_state = snap["state"]
	route.resize(snap["len"])
	state = State.REWINDING
	van.inviting = false
	_clear_hint()
	retry_button.breathe(false)
	hint_label.add_theme_color_override("font_color", Palette.TEXT)
	hint_label.text = _base_hint
	hint_label.modulate.a = 0.35 if route.size() > 1 else 1.0
	_update_undo()
	Sfx.play("rewind")
	Sfx.haptic(20)

	# Delivered packages fly back from their houses to where the van will end up;
	# collected parcels fly back to their shops.
	var dest := board.center(back[0])
	var k := 0
	for h in old["fills"].size():
		var returned: int = old["fills"][h] - sim_state["fills"][h]
		if returned <= 0:
			continue
		var house: House = board.house_nodes[h]
		house.undeliver(sim_state["fills"][h])
		for j in returned:
			_fly_back(level.houses[h].color, house.base_pos + Vector2(0, -board.tile * 0.35), dest, k * 0.05)
			k += 1
	for s in old["picked"].size():
		for j in old["picked"][s] - sim_state["picked"][s]:
			var shop: Shop = board.shop_nodes[s]
			_fly_back(level.shops[s].color, van.position, shop.parcel_pos(), k * 0.05, shop.restore)
			k += 1

	var n := float(back.size() - 1)
	var rt := create_tween()
	rt.tween_method(_rewind_tick.bind(back), n, 0.0, n / REWIND_SPEED + 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.tween_callback(func():
		van.target_rotation = snap["rot"]
		van.position = dest
		stack_view.rebuild(sim_state["stack"])
		van.set_top(stack_view.top_color())
		van.stop_bounce()
		board.show_trail(route)
		board.wreck.set_route(route, route.size() - 1)
		board.update_gates(Sim.top_color(level, sim_state))
		if board.depot:
			board.depot.calling = false
		state = State.IDLE
		van.inviting = true
		_update_undo()
		_refresh_tags())


func _fly_back(color: String, from: Vector2, to: Vector2, delay: float, done: Callable = Callable()) -> void:
	var pkg := _make_flyer(color, from)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_method(_fly.bind(pkg, from, to, board.tile * 0.5), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(pkg.queue_free)
	if done.is_valid():
		tw.tween_callback(done)


func _rewind_tick(d: float, tiles: Array) -> void:
	if tiles.size() < 2:
		return
	var i := clampi(int(floor(d)), 0, tiles.size() - 2)
	var a := board.center(tiles[i])
	var b := board.center(tiles[i + 1])
	van.position = a.lerp(b, d - i)
	van.target_rotation = (b - a).angle()   # facing forward: it's reversing
	board.show_trail(route + tiles.slice(1, i + 1) + [van.position])
	board.wreck.loud = false
	board.wreck.set_route(route + tiles.slice(1), route.size() - 1 + i + (1 if d - i >= 0.55 else 0))
	board.wreck.loud = true


## The Undo button: a count while there are undos; greyed with a bright "+3 undos" ad badge when out.
func _update_undo() -> void:
	if undo_button == null:
		return
	if _strict_side():
		# Side roads: no undos (or hints).
		undo_button.badge = ""
		undo_button.badge_icon = ""
		undo_button.dim = true
		hint_button.dim = true
		undo_button.queue_redraw()
		return
	var n := undos_available()
	if n <= 0:
		undo_button.badge_icon = "ad"
		undo_button.badge_color = AD_PINK
		undo_button.badge = "+%d undos" % Progress.AD_UNDOS
		undo_button.dim = true
	else:
		undo_button.badge_icon = ""
		undo_button.badge_color = Palette.GOOD if Progress.free_undos() else COUNT_BLUE
		undo_button.badge = "FREE" if Progress.free_undos() else str(n)
		undo_button.dim = not can_undo()
	undo_button.queue_redraw()
	_update_hint()


## The Hint button: how many are left; "FREE" with the power-up; unlimited after an ad; greyed with a bright
## ad badge when out.
func _update_hint() -> void:
	if hint_button == null or _strict_side():
		return
	hint_button.badge_icon = ""
	hint_button.dim = false
	if Progress.free_hints() or hints_unlimited or Progress.unlimited_hints:
		hint_button.badge_color = Palette.GOOD
		hint_button.badge = "FREE" if Progress.free_hints() else ("∞" if UiTheme.font().has_char(0x221E) else "ALL")
	elif hints_left > 0:
		hint_button.badge_color = COUNT_BLUE
		hint_button.badge = str(hints_left)
	else:
		hint_button.badge_icon = "ad"
		hint_button.badge_color = AD_PINK
		hint_button.badge = "more"
		hint_button.dim = true
	hint_button.queue_redraw()


## Hints cost nothing from the count: the power-up's on, an ad made them unlimited this level, or the
## Unlimited hints option is on.
func _hints_free() -> bool:
	return hints_unlimited or Progress.free_hints() or Progress.unlimited_hints


## The last hint of the level just went: a tip by the Hint button says what happens next (an ad for
## unlimited hints, or the option that skips the ads). Only the first three times, and never again once
## they've watched one of the ads.
func _out_of_hints_tip() -> void:
	if Progress.hint_ad_watched or Progress.hint_tips >= 3 or Progress.auto:
		return
	Progress.hint_tips += 1
	Progress.save_now()
	if _tip and is_instance_valid(_tip):
		_tip.dismiss()
	_tip = TipBubble.new()
	_tip.text = "That was your last hint for this level.\nTap Hint again: a quick (pretend) ad\nunlocks unlimited hints. Or turn on\nUnlimited hints in Options."
	_tip.target = hint_button.get_global_rect().get_center()
	_tip.life = 9.0
	_ui_root.add_child(_tip)


## Out of hints: a pretend ad (one of three videos, skippable straight away), then they're unlimited for
## the rest of this level.
func _play_hint_ad() -> void:
	var ad := VideoAd.new()
	modal = ad
	_overlay(ad)
	ad.finished.connect(func():
		modal = null
		hints_unlimited = true
		Progress.hint_ad_watched = true
		Progress.save_now()
		Sfx.play("kaching", 1.0, -4)
		Sfx.haptic(20)
		_update_hint()
		hint_button.pop()
		_say("Unlimited hints for this level!", Palette.GOOD.darkened(0.2)))


# ---------------------------------------------------------------- hints

func _on_hint_pressed() -> void:
	if _busy_modal():
		return
	if _strict_side():
		Sfx.play("bonk", 1.1, -6.0)
		_say("No hints on side roads!")
		return
	# With the D-pad, a hint takes two taps (the first just asks), so a stray thumb can't spend a star.
	if dpad_mode and state != State.FAILED and not hint_used and Time.get_ticks_msec() / 1000.0 > _hint_armed:
		_hint_armed = Time.get_ticks_msec() / 1000.0 + 2.5
		Sfx.play("tick", 1.2, -4)
		Sfx.haptic(12, 0.5)
		hint_button.label = "Sure?"
		hint_button.pop()
		var tw := create_tween()
		tw.tween_interval(2.5)
		tw.tween_callback(func():
			if hint_button.label == "Sure?":
				hint_button.label = "Hint")
		return
	_hint_armed = 0.0
	hint_button.label = "Hint"
	Sfx.play("click")
	# A dead end (stuck, or no win left from here): the hint says so and points at Retry (or Undo). It
	# never restarts anything itself, and costs no star; after a restart, a hint shows the first step.
	if state == State.FAILED:
		_dead_end_hint()
		return
	if state != State.IDLE and not (dpad_mode and state == State.DRAWING):
		return
	var path := Solver.solve_from(level, route, sim_state)
	if path.size() < 2:
		_dead_end_hint()
		return
	if not _hints_free() and hints_left <= 0:
		_play_hint_ad()
		return
	if dpad_mode and state == State.DRAWING:
		_cancel_plan()
	if not Progress.free_hints():
		hint_used = true
	if not _hints_free():
		hints_left -= 1
		_update_hint()
		if hints_left == 0:
			_out_of_hints_tip.call_deferred()
	stars_ctl.queue_redraw()
	# The next move: straight on from the van until the route turns.
	var run: Array = [path[0], path[1]]
	for i in range(2, path.size()):
		if path[i] - path[i - 1] != path[1] - path[0]:
			break
		run.append(path[i])
	_clear_hint()
	hint_run = run
	board.show_hint(run)
	hint_ghost = GhostFinger.new()
	hint_ghost.radius = board.tile * 0.22
	for p in run:
		hint_ghost.pts.append(board.center(p))
	board.add_child(hint_ghost)
	if ghost:
		ghost.visible = false
	Sfx.play("hint")
	Sfx.haptic(10)
	_say("Try this way.")


func _dead_end_hint() -> void:
	Sfx.play("bonk", 0.9, -4)
	van.shake()
	_say("Dead end: there's no way to win from here.\n" + ("Undo, or Retry to start over." if can_undo() else "Retry to start over."), Palette.ACCENT.darkened(0.12))
	retry_button.breathe(true)
	_point_at_way_out()


func _point_at_way_out() -> void:
	if can_undo():
		undo_button.pop()
	else:
		retry_button.pop()


func _clear_hint() -> void:
	hint_run = []
	board.show_hint([])
	if hint_ghost and is_instance_valid(hint_ghost):
		hint_ghost.queue_free()
	hint_ghost = null


func _say(text: String, color := Palette.TEXT) -> void:
	hint_label.visible = true
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)
	hint_label.modulate.a = 1.0


# ---------------------------------------------------------------- gas

func _open_shop() -> void:
	if _busy_modal():
		return
	var shop := GasShop.new()
	modal = shop
	_overlay(shop)
	shop.closed.connect(func(bought: bool):
		modal = null
		if bought:
			gas_chip.bump()
			retry_button.pop())


func _on_retry_pressed() -> void:
	Sfx.play("click")
	_retry()


## Once a level's been beaten (or today's daily solved), playing it again neither costs gas nor earns any.
func _replay_free() -> bool:
	if not side.is_empty():
		return true
	if daily_day >= 0:
		return Progress.daily_record(daily_day).get("done", false)
	return Progress.is_complete(level.number)


## Starting the level again costs a gas tank until it's been beaten once. With none left, the gas station
## opens instead.
func _retry() -> void:
	if _busy_modal():
		return
	var untouched := route.size() == 1 and not hint_used and not undo_used and (state == State.IDLE or state == State.DRAWING)
	if untouched:
		van.nudge()
		return
	retry_paid = not _replay_free()
	if retry_paid and not Progress.spend_gas():
		Sfx.play("empty")
		gas_chip.bump()
		_open_shop()
		return
	# Starting over breaks the run of wins.
	if state != State.WON:
		Progress.momentum = 0
	if daily_day >= 0:
		Progress.daily_attempt(daily_day)
	retry_requested.emit(index)


## Back to the level list. Walking away from an unfinished level breaks the run of wins.
func _leave() -> void:
	if _busy_modal():
		return
	if state != State.WON and (route.size() > 1 or hint_used or undo_used):
		Progress.momentum = 0
	if daily_day >= 0:
		daily_menu_requested.emit()
	else:
		menu_requested.emit()


# ---------------------------------------------------------------- results

func _win() -> void:
	state = State.WON
	timing = false
	_clear_hint()
	var earned := 3 - int(hint_used) - int(undo_used)
	coin_chip.frozen = true
	var pay := 0
	var gas_back := false
	var crushed := false
	var side_prize := ""
	if _speedrun():
		# A speedrun course done: the time, against the record.
		var total := speed_elapsed + play_time
		var best_before: float = Progress.speed_best.get(str(side.get("id", "")), 0.0)
		if Progress.speed_record(str(side.get("id", "")), total):
			_bonus_line = "NEW RECORD %s" % Speedrun.clock(total) + ("" if best_before <= 0.0 else " (was %s)" % Speedrun.clock(best_before))
		else:
			_bonus_line = "Best is still %s" % Speedrun.clock(best_before)
	elif not side.is_empty():
		# A side challenge: its ride, the first time.
		if Progress.win_side(str(side.get("id", ""))):
			side_prize = str(side.get("reward", ""))
		_bonus_line = Progress.side_power_up(str(side.get("id", "")), side.get("bonus", {}))
		if _twist() == "mega":
			Progress.set_mega_part(str(side.get("id", "")), 0)
	elif daily_day >= 0:
		var first: bool = not Progress.daily_record(daily_day).get("done", false)
		Progress.daily_done(daily_day, earned, play_time, deliveries)
		if first:
			pay = Progress.STAR_REWARD[earned]
			gas_back = true
	else:
		gas_back = not Progress.is_complete(level.number)
		pay = Progress.mark_complete(level.number, earned)
		# First time through a challenge level: a bonus, and the finish goes big.
		crushed = level.challenge and gas_back
		if crushed:
			Progress.earn(ChallengeIntro.BONUS)
			pay += ChallengeIntro.BONUS
	if pay > 0 and daily_day >= 0:
		Progress.earn(pay)
	if gas_back:
		Progress.refund_gas()
	var new_item := ""
	if gift_taken and Progress.give(level.gift_item):
		new_item = level.gift_item
	if side_prize != "" and Progress.give(side_prize):
		new_item = side_prize
	var missed := board.gift != null and not gift_taken
	Progress.momentum += 1
	momentum_ctl.visible = false
	Sfx.play("win")
	Sfx.haptic(30)
	if board.depot:
		board.depot.calling = false
	for i in board.house_nodes.size():
		board.house_nodes[i].bounce(i * 0.07)
		fx.burst(board.house_nodes[i].base_pos + Vector2(0, -board.tile * 0.4), Palette.STAR_GOLD, 6, board.tile * 2.2, board.tile * 0.09)
	hint_label.visible = false
	title_label.visible = false
	actions.visible = false
	dpad.visible = false
	drive_button.visible = false
	mode_button.visible = false
	var tw := create_tween()
	tw.tween_interval(0.35)
	if crushed:
		# A big reaction on the board first: every house cheers, confetti everywhere, the screen jolts.
		Sfx.play("kaching", 1.0, -2.0)
		Sfx.haptic(45, 1.0)
		var mid := board.size_px() / 2.0
		for col in ["red", "yellow", "blue", "green", "purple", "orange"]:
			fx.burst(mid, Palette.pkg(col), 14, board.tile * 6.0, board.tile * 0.14)
		fx.say(mid + Vector2(0, -board.tile * 0.6), "CRUSHED IT!", Palette.STAR_GOLD.darkened(0.25), int(board.tile * 0.6))
		var bp := board.position
		var shake := create_tween()
		for k in 6:
			shake.tween_property(board, "position", bp + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0, 0.04)
		shake.tween_property(board, "position", bp, 0.05)
		tw.tween_interval(0.5)
	tw.tween_callback(_show_finish.bind(earned, pay, gas_back, new_item, missed, crushed))


func _show_finish(earned: int, pay: int, gas_back: bool, new_item: String, missed: bool, crushed := false) -> void:
	finish = FinishScreen.new()
	finish.crushed = crushed
	finish.level = level
	finish.stars = earned
	finish.reward = pay
	finish.gas_back = gas_back
	finish.secs = play_time
	finish.momentum = Progress.momentum
	finish.new_item = new_item
	finish.missed_item = missed
	finish.daily = daily_day >= 0
	finish.last_level = index + 1 >= total or not side.is_empty()
	finish.side_title = str(side.get("title", ""))
	finish.side_kind = "SPEEDRUN" if _speedrun() else ("MEGA ROUTE" if _twist() == "mega" else "SIDE ROAD")
	if _speedrun():
		finish.secs = speed_elapsed + play_time
	finish.bonus_line = _bonus_line
	# Sideways the finish lives in its own portrait column, so rewards can't fly across to the wallet.
	finish.coin_chip = null if Progress.landscape else coin_chip
	finish.gas_chip = null if Progress.landscape else gas_chip
	finish.next_pressed.connect(_next)
	finish.replay_pressed.connect(_retry)
	finish.share_pressed.connect(_share)
	if Progress.landscape:
		_overlay(finish)
	else:
		_ui_root.add_child(finish)
	# The wallet and gauge stay on top, so the rewards can be seen landing.
	bar.move_to_front()


func _share() -> void:
	var card := ShareCard.new()
	card.day = daily_day
	modal = card
	_overlay(card)
	card.closed.connect(func(): modal = null)


func _fail() -> void:
	state = State.FAILED
	_update_undo()
	Sfx.play("fail", 1.0, -2)
	Sfx.haptic(25)
	van.shake()
	stack_view.flash_remaining()
	var left := Sim.remaining(level, sim_state)
	var msg := "Stuck! %d left." % left if left > 0 else "Stuck! Can't reach the depot."
	_say(msg + ("\nUndo, or Retry." if can_undo() else "\nRetry?"), Palette.ACCENT.darkened(0.12))
	retry_button.breathe(true)
	if can_undo():
		undo_button.pop()


func _next() -> void:
	if not side.is_empty():
		menu_requested.emit()
	elif daily_day >= 0:
		daily_menu_requested.emit()
	elif index + 1 < total:
		level_requested.emit(index + 1)
	else:
		menu_requested.emit()


func _fade(c: CanvasItem, a: float) -> void:
	create_tween().tween_property(c, "modulate:a", a, 0.2)
