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
## Undo rewinds the last segment (to the last stop, with headlights on; packages come back): the free ones
## each try starts with (Progress.undo_slots()); past them (or the hints), a tank of gas makes undos and
## hints both unlimited on the level. Hint shows the next stretch of a
## winning route: the level's free ones (Progress.hint_slots()), then a tank each. Out of gas, a (pretend)
## ad pays AD_TANKS bonus tanks. Playing and retrying a level is free.
## Winning a job the first time adds its packages to the count delivered (Progress.delivered), which opens
## zones and unlocks trails and looks. Using help costs nothing but gas.
##
## Sim updates instantly as the van reaches each tile; the matching animations (packages
## flying, the load rolling along) run on a small timeline so they always play in rule
## order even when several happen close together.

signal menu_requested
signal level_requested(index: int)   # go to a level (Next): Main charges gas if it's unbeaten
## Next after a win on the main road: Main shows the map, the van drives on to `to`, and the Next card.
signal next_requested(from: int, to: int)
signal retry_requested(index: int)   # the same level again (free)
signal daily_menu_requested
## After the daily: back to the map, the card up for the job the van's at.
signal work_requested
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
## Hints a level starts with: Progress.hint_slots() (one, and one more from each of the chests at levels
## 10 and 20, up to three).
const NOWHERE := Vector2i(-99, -99)

var level: LevelData
var index := 0
## The last unfinished attempt's route ({"key", "route"}), kept across a restart for the Replay ghost path
## option (ReplayGhost).
static var last_attempt := {}
## An OG 100 level (the old levels, played for fun from the title once everything's beaten): free, and
## nothing about it is saved but "won here". Main sets it before setup().
var og := false
var replay_ghost: ReplayGhost
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
## Headlights (Progress.lights_on(), the default): the route can only be plotted as far ahead of the
## van as its lights reach. Draw further and the van follows behind: seg[1.._fs_committed] can't be taken
## back, and it drives them (delivering as it goes) while the finger's still down. Lifting the finger sends
## it the rest. Undo then goes back to the last stop (a delivery, a pickup, a swap).
var _fs := 0                     # the foresight this stroke was begun with (0: not a short-foresight stroke)
var _fs_committed := 0           # tiles of `seg` the van's committed to
var _fs_dist := 0.0              # how far along `seg` the van has got (tiles)
var _fs_released := false        # finger up: the van's driving the rest, then the stroke ends
var _fs_hold := 0.0              # (game clock) the van waits on its tile till then: packages are coming and going
var _last_handoff := 0.0         # how long the last stop's packages take to leave or reach the van (_handoff_time)
var _fs_rot0 := 0.0              # the way the van faced when the stroke began (for undo)
var _seg_cols: Array = []        # while driving: the tint of each stretch of `seg`
var _load_drag := {}             # a press on the chute: {at, view, moved}
## True when the last retry_requested took a gas tank (Main shows the "-1" on the gauge).
var retry_paid := false
var history: Array = []          # per driven segment: { "len", "state", "rot" } before it
var _ev_gen := 0                 # bumped by each undo: event animations set off before it don't play
var _auto_rest: Array = []        # drive_tiles: the steps left after a locker stop (see _auto_continue)
var undo_left := UNDOS_PER_ATTEMPT   # undos left this attempt (free ones, then the 3 a tank buys)
## Gas spent on each level this session, kept across retries: _attempt_key() -> {"undo": tanks, "hint": tanks}.
## On a level, the first tank for undos buys 3 more, the second makes them unlimited; the first for hints
## buys one hint, the second makes them unlimited.
static var gas_bought := {}
## Free hints used on each job (by _attempt_key) since it was last won: a retry gives the undos back, not the
## hints (they're capped per job).
static var hints_spent := {}          # (unused now: hints are a carried count)
## The job whose next start says what the Radio's for (after job 4's lesson card: a road torn up that was
## needed is exactly what it can warn about).
static var radio_tip := -1
## Jobs known to stump people: a while on one (GUIDE_AFTER_SECS) or a few failed tries (GUIDE_AFTER_FAILS),
## and GuideCard offers a free start: the first half of the way that works. Once a job per app run.
const GUIDE_JOBS := [6]
static var daily_tipped := {}         # days whose daily's rules tip has shown since the app opened
const GUIDE_AFTER_SECS := 30.0
const GUIDE_AFTER_FAILS := 2
static var guide_offered := {}
static var guide_hint := -1               # the job whose next start shows the guide's half (after its Retry)

## Job LESSON_LEVEL teaches saving a road you'll need later; get it wrong and LessonCard says what happened,
## with a hint on offer. `lesson_hint`: the job whose next start opens with that hint showing (free).
const LESSON_LEVEL := 4
static var lesson_hint := 0
var _lesson_shown := false
var hint_used := false
## Hints left this level (Progress.hint_slots() to start). Out: a pretend ad, then they're unlimited for the
## level. A hint stays up, pulsing, until the next move; asking again before then replays it for free.
var hints_left: int:
	get:
		return Progress.hints
	set(v):
		Progress.hints = maxi(v, 0)
var hints_unlimited := false
var undo_used := false
var undo_count := 0                  # undos this try (the daily's No undos badge)
var modal: Node                  # the shop or the ad, on top: the game ignores input meanwhile
var sim_state: Dictionary
var combo := 0
var _fired := 0
var _drive_len := 0.0
var _legs: Array = []              # the drive in stretches: [from tile, tiles, seconds driving, seconds stopped after]
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
var actions: FlowContainer             # (a flow: with the D-pad upright, four buttons go two by two)
var hint_button: JuicyButton
var radio_button: JuicyButton          # the Radio (null where there isn't one: before job 12, dailies, detours)
var undo_button: JuicyButton
var retry_button: JuicyButton
var finish: FinishScreen
var rating_card: RatingCard
var melt_clock: MeltClock
## "Skip for now": offered on a level that's been a struggle (see _skip_tick).
var exit_ribbon: ExitRibbon          # the way out, top left: Give up, and the jump jets
var _refusals := 0                   # "Not NEXT yet!"s said this try (the early jobs)
var _jets_tipped := false            # this job's "you look stuck: jump jets" nudge has been given
## For the level's stats: after each segment driven, could the level still be won? (Undo takes one back.)
var _winnable: Array = []
var _win_stats := {}
## The pause after a win before the finish card, and what ends it (a tap ends it early).
var _win_wait: Tween
var _win_go := Callable()
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
var gift_len := 0                # how long the route was when the gift was picked up (for undo)
## For the stats (never shown): how long the player sat before the van first moved, and the longest sit since.
var _idle_t := 0.0
var _moves := 0
var _first_wait := 0.0
var _longest_wait := 0.0
var _buff := {}                  # a boss's buff just won: {"lights": n} and/or {"undos": n}, for BuffCard
var _item_opened := false        # the cosmetic won was already shown (a boss's package): the finish just tags it
var _fire_last := Vector2.INF
## Set by Main when opening this level cost a gas tank: the gauge shows it.
var charged := false
var fx: Fx
var hint_ghost: GhostFinger
var hint_run: Array = []         # tiles the current hint points along (empty: no hint showing)
var _ui_root: Control
## The cancel zone: while a route's being drawn, a little crusher at the bottom of the screen. Drag into it and
## hold (CANCEL_HOLD) till the ring closes, then let go: the route's scrapped, nothing driven.
var _cz: Control
var _cz_in := false
var _cz_t := 0.0
var _cz_crush := -1.0
const CANCEL_HOLD := 0.35
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
var _gas_line: GasLine               # Hint or Undo held down when it costs a tank: the fuel line filling
var _gas_held := ""                  # the button ("hint"/"undo") whose hold just paid: its release is swallowed
var _gas_paid := ""                  # set while the help a tank was just committed to runs (no hold needed)
var _rush_rings := {}                # "undos" / "hints" -> the RushRing on its button
var _rush_hold := ""                 # the button ("undo" / "hint") being held to start the rush in hand
var _rush_hold_t := 0.0
var _rush_won := ""                  # a detour just paid out a rush of this kind (RushCard before the finish)
var _rush_keep_t := 0.0
var _play_sent := false              # this try's play record has gone (left, skipped)
var _back_to := 0                    # a dead-end hint's "back up to here": the route's length at that stop (0: none)
var _back_mark: BackUpMark           # ...and its pin and red line on the board
var _back_old: Array = []            # ...and the road that led to the dead end (the hint then shows where to leave it)
var _limits_scene: LimitsScene       # the Baron metering the helpers (the first boss job), while it plays
var _metered := {}                   # ...and the things he's stamped so far ("pump", "hint", "radio")
var _limits_calm := 0.0              # seconds nothing else has been up (his scene waits its turn)
var _pump_gap: Control               # the pump's place in the row of buttons, after Hint
var _radio_lock: JuicyButton         # the Call button's place, padlocked, before it's on the bar (RADIO_FROM)
var _call_box: DispatchBox           # a call's answer, over the Call button, while it's up
var _verdict: VanVerdict             # ...and kept over the van till it next moves
var _verdict_n := -1                 # ...the route's length when it was said
var _dispatch_intro: DispatchBox     # job 6: Dispatch says what Hint and Call are for
var _jet_hold := -1.0                # seconds the jets' row has been held (-1: it isn't)
var _pouring := {}                   # "hint" / "radio": a can's just gone in (CanFill): its badge waits for it
var _prize_line := ""                # what this win paid in helpers ("+1 call"), for the finish
var _landing: Array = []             # parcels on their way from a shop to the chute: [{pkg, color}], oldest first
var _undo_lesson: UndoLesson         # job 6's lesson, while it's running (UndoLesson)
## Undo held down: it undoes, then again, and again, sooner each time (so a long way back is quick).
const HINT_GOLD := Color("ffc93c")     # the Hint button's face: the dear help looks it
const RUSH_HOLD := 0.65              # seconds Undo / Hint is held to start the rush in hand
const UNDO_HOLD_FIRST := 0.38
const UNDO_HOLD_GAP := 0.26
const UNDO_HOLD_MIN := 0.04
var _undo_hold := -1.0               # seconds to the hold's next undo (-1: not held)
var _undo_gap := 0.0                 # ...and the wait after that one
var _undo_streak := 0                # undos this hold's done (the rewinds get quicker too)
## "Ooh, use me": Undo shakes while the van's plainly stuck, Hint when nothing's been driven for a while.
const HINT_NUDGE_AFTER := 20.0
const EARLY_JOBS := 5                # the tutorial jobs (before the first boss): Hint waves sooner
const EARLY_NUDGE_AFTER := 8.0
const EARLY_FREE_AFTER := 75.0
var _nudge_t := 2.0
var _stranded := false               # a stop still owed a package has no road left to it (see _cut_off)
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
	undo_left = Progress.undo_slots()
	hints_unlimited = false
	_compute_insets()
	_build_world()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_apply_mode()
	_update_undo()
	LevelStats.begin(_attempt_key())
	_refresh_tags()
	board.update_gates(Sim.top_color(level, sim_state), true)
	_intro()
	if charged:
		_show_charge.call_deferred()
	if _boss_level() and BossIntro.should_show(level):
		_show_boss.call_deferred()
	elif daily_day < 0 and ChallengeIntro.should_show(level):
		_show_challenge.call_deferred()
	if not side.is_empty():
		_start_side()
	elif not og:
		# Anything on the board the player hasn't been shown yet gets its card first. In a daily too: it's
		# open from the start, so it can be where a mechanic is met first (the main road won't repeat it).
		if daily_day >= 0:
			timing = true          # (the daily's clock runs from the moment it loads, thinking time too)
			_daily_rules.call_deferred()
		_spotlight_new.call_deferred()
	_lights_intro.call_deferred()
	_queue_tips()
	_line_lesson.call_deferred()
	if UndoLesson.due(self):
		_undo_lesson = UndoLesson.new()
		_undo_lesson.game = self
		add_child(_undo_lesson)
	if OS.get_cmdline_user_args().has("--lesson-hint"):
		Game.lesson_hint = level.number          # (debug: start with the lesson's hint showing)
	if Game.lesson_hint == level.number and side.is_empty() and daily_day < 0 and not og:
		Game.lesson_hint = 0
		_lesson_hint.call_deferred()
	if Game.guide_hint == level.number and side.is_empty() and daily_day < 0 and not og:
		Game.guide_hint = -1
		_guide_show.call_deferred()
	if Game.radio_tip == level.number and radio_button != null and not Progress.seen_new.has("radio_tip") and not Progress.auto:
		# After job 4's lesson (a road torn up that was needed): what the Radio's for, on the fresh start.
		Game.radio_tip = -1
		Progress.seen_new["radio_tip"] = true
		Progress.set_option("seen_new", Progress.seen_new)
		_tips.append({"text": "Not sure next time? Call Dispatch:\nthey'll say if you can still finish.\n(Free while you're learning.)",
			"target": func(): return radio_button.get_global_rect().get_center(), "tap": false})
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gas-card="):
			# Debug: the gas explainer for "hint" or "undo" straight away (for screenshots).
			Progress.seen_new.erase(_gas_key(a.trim_prefix("--gas-card=")))
			_explain_gas.call_deferred(a.trim_prefix("--gas-card="), func(): pass)
		if a == "--gas-hold-demo":
			# Debug: Hint costs a tank; a short press (runs back), then a full hold; then a line out to Undo.
			Progress.seen_new[Progress.GAS_SEEN] = true
			Progress.seen_new[Progress.GAS_HINT_SEEN] = true
			hints_left = 0
			var tw := create_tween()
			tw.tween_interval(1.0)
			tw.tween_callback(func(): _hold_down("hint"))
			tw.tween_interval(0.3)
			tw.tween_callback(_hold_up)
			tw.tween_interval(1.0)
			tw.tween_callback(func(): _hold_down("hint"))
			tw.tween_interval(1.6)
			tw.tween_callback(_hold_up)
			tw.tween_callback(func():
				var line := GasLine.new()
				line.from = gas_chip.can_pos()
				line.buttons = [hint_button, undo_button]
				_ui_root.add_child(line))
		if a == "--gas-pour":
			# Debug: a tank poured into Hint, then one into Undo (for screenshots).
			var tw := create_tween()
			tw.tween_interval(1.0)
			tw.tween_callback(_burn_tank.bind(hint_button))
			tw.tween_interval(1.4)
			tw.tween_callback(_burn_tank.bind(undo_button))
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
	# A boss job says so the whole time it's played (BossWatch): the Baron in the corner, the gold plate.
	if (_boss_level() or Boss.is_boss(side)) and not Progress.auto:
		var bw := BossWatch.new()
		bw.game = self
		_ui_root.add_child(bw)
		_ui_root.move_child(bw, 0)
	DebugAuto.maybe_run(self)


# ---------------------------------------------------------------- side roads

func _twist() -> String:
	return str(side.get("twist", ""))


## A side road with a twist, or a speedrun: no hints, no undos. (Mega routes and boss fights allow both:
## a boss map is hard enough already.)
func _strict_side() -> bool:
	return not side.is_empty() and ((_twist() != "mega" and _twist() != "boss") or _speedrun())


## The daily is played on wits alone: no hints (undos are fine).
func _no_hints() -> bool:
	return daily_day >= 0


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
	Sfx.haptic(30, 1.0, "game:_part_done")
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
	if part == 0 and BossIntro.should_show_side(side):
		# The villain laughs you in (once a session: a retry goes straight back to the job).
		var bi := BossIntro.new()
		bi.side = side
		bi.level = level
		modal = bi
		_overlay(bi)
		bi.done.connect(func(): modal = null)
	elif part == 0 and ChallengeIntro.should_show_side(side):
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
		_cancel_plan(false)
		board.show_path([])
	state = State.FAILED
	timing = false
	_update_drive_button()
	Sfx.play("fail", 1.0, -2)
	Sfx.haptic(25, 1.0, "game:_twist_fail")
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
	for k in level.lockers.size():
		if level.lockers[k].pos == t:
			var hc: String = str(sim_state.get("held", [])[k]) if k < sim_state.get("held", []).size() else ""
			return {"kind": "park", "color": Palette.pkg(hc) if hc != "" else Color("6f7a90"), "name": _color_word(hc) if hc != "" else "",
				"count": 1 if hc != "" else 0, "at": at}
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
		return {"kind": "key" if level.gift_item == "key" else "gift", "at": at}
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
	# The first key on the road: what it is, before it's driven over.
	if level.gift_item == "key" and board.gift and not Progress.seen_new.has("key_tip") and side.is_empty() and daily_day < 0:
		Progress.seen_new["key_tip"] = true
		Progress.set_option("seen_new", Progress.seen_new)
		var key_at: Vector2i = level.gift
		_tips.append({"text": "A key! Drive over it to pick it up.\nKeys open the locked detours on the map.",
			"target": func(): return board.get_global_transform_with_canvas() * board.center(key_at), "tap": false})
	if Progress.stack_side == "auto" and not Progress.landscape:
		# The first time Auto moves the queue from where it was last level, say so.
		var was := Progress.last_auto_side
		var now_side := _chute_side()
		Progress.last_auto_side = now_side
		if was != "" and was != now_side and not Progress.queue_moved_seen:
			Progress.queue_moved_seen = true
			var msg := "Big map! Your line of packages\nmoved up here to make room." if now_side == "top" else "Your line of packages\nis over here this time."
			_tips.append({"text": msg, "target": func(): return stack_view.global_position, "tap": false})
		Progress.save_now()


func _show_tip(t: Dictionary) -> void:
	_tip = TipBubble.new()
	_tip.text = t["text"]
	_tip.target = (t["target"] as Callable).call()
	_tip.tap = t.get("tap", false)
	_ui_root.add_child(_tip)


## Is this a boss fight on the main road (the end of a zone, or one of the early core ones)?
func _boss_level() -> bool:
	return side.is_empty() and daily_day < 0 and not og and Boss.is_level(level.number)


## A boss fight on the main road: the Baron laughs you in.
func _show_boss() -> void:
	var bi := BossIntro.new()
	bi.side = Boss.level_def(level)
	bi.level = level
	modal = bi
	_overlay(bi)
	bi.done.connect(func(): modal = null)


## A challenge level (a big step up): hazard tape, a stamp, the bonus on offer.
func _show_challenge() -> void:
	var ci := ChallengeIntro.new()
	ci.level = level
	modal = ci
	_overlay(ci)
	ci.done.connect(func(): modal = null)


## Something new on this level (a road hazard, a building, a rule) the player hasn't met: the level fades
## back round it (Spotlight). After the challenge card, if there is one.
## The daily's last three tries, said by Retry as each starts (index: tries left, this one included, less one).
const DAILY_WARN := [
	"LAST TRY today!\nNo more after this one.",
	"2 tries left today,\nthis one included.",
	"3 tries left today,\nthis one included.",
]


## The daily's last try: big red words over the board as it starts.
func _last_try_flash() -> void:
	if not is_inside_tree():
		return
	fx.say(board.size_px() / 2.0, "LAST TRY!", Palette.CRASH, int(board.tile * 0.55))
	Sfx.play("bonk", 0.8, -8.0)
	retry_button.wiggle()


## The first daily: how the daily works (DailyRules), once, before anything else.
func _daily_rules() -> void:
	if Progress.auto and not OS.get_cmdline_user_args().has("--daily-rules"):
		return
	if Progress.seen_new.has("daily_rules"):
		# Seen the card before: every time a daily starts (with tries left), a tip by Undo and Retry says
		# what this one allows.
		var r := Progress.daily_record(daily_day)
		if r.get("done", false):
			return
		# (This try's already counted, so tries_left is the retries after it: this one and those are what's left.)
		var here := Daily.tries_left(r) + 1
		if here <= 3:
			# Down to the last few: a warning by Retry on every try, so nobody's surprised that it can end.
			_tips.append({"text": DAILY_WARN[here - 1],
				"target": func(): return retry_button.get_global_rect().get_center() + Vector2(0, -60),
				"tap": false})
			if here == 1:
				get_tree().create_timer(0.7).timeout.connect(_last_try_flash)     # (once the board's in)
			return
		if Game.daily_tipped.has(daily_day):
			return
		Game.daily_tipped[daily_day] = true          # (once a launch: not again on every retry)
		var u := Progress.undo_slots()
		_tips.append({"text": "Daily rules: %d undo%s a try,\n%d tries left today (this one too).\nNo hints, no gas." % [u, "" if u == 1 else "s", here],
			"target": func(): return undo_button.get_global_rect().get_center().lerp(retry_button.get_global_rect().get_center(), 0.5) + Vector2(0, -60),
			"tap": false})
		return
	Progress.seen_new["daily_rules"] = true
	Progress.set_option("seen_new", Progress.seen_new)
	_show_daily_rules(false)


## The daily's rules card: on its first daily, and again whenever the Rules button (Hint's slot) is pressed,
## then with today's tries left.
func _show_daily_rules(again := true) -> void:
	if again and dpad_mode and state == State.DRAWING:
		_cancel_plan()
	var card := DailyRules.new()
	if again:
		card.tries_left = Daily.tries_left(Progress.daily_record(daily_day))
	modal = card
	_overlay(card)
	card.closed.connect(func(): modal = null)


func _spotlight_new() -> void:
	var k := Spotlight.new_kind(level, daily_day >= 0)
	if k == "" or (Progress.auto and not OS.get_cmdline_user_args().has("--spotlight")):
		return
	while _busy_modal():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	await get_tree().create_timer(0.35).timeout
	var sp := Spotlight.new()
	sp.kind = k
	sp.in_daily = daily_day >= 0
	# The demo picture in the colour of the real thing on this level.
	var cname := ""
	match k:
		"gate":
			cname = str(level.gates.values()[0])
		"pickup", "warehouse":
			for sd in level.shops:
				if (sd.count > 1) == (k == "warehouse"):
					cname = sd.color
					break
		"multi":
			# One house: the picture, the number in the words and the lit house are all that one.
			for hd in level.houses:
				if hd.order > 1 and hd.color != "any":
					cname = hd.color
					sp.count = hd.order
					sp.spots.append(board.get_global_transform_with_canvas() * board.center(hd.pos))
					break
	if cname != "":
		sp.pic_color = Palette.pkg(cname)
		sp.pic_color_name = _color_word(cname)
	var xf := board.get_global_transform_with_canvas()
	if sp.spots.is_empty():
		for t in Spotlight.tiles_of(level, k):
			sp.spots.append(xf * board.center(t))
	if k == "return" and stack_view.flag_at != Vector2.INF:
		# End of shift: the flag waiting in the queue is the other half of it.
		sp.spots.append(stack_view.get_global_transform_with_canvas() * stack_view.flag_at)
	sp.radius = board.tile * xf.get_scale().x * 0.62
	modal = sp
	sp.closed.connect(func():
		if modal == sp:
			modal = null
		# More than one new thing here (a daily can have a few): the next one's card, in turn.
		if is_inside_tree() and Spotlight.new_kind(level, daily_day >= 0) != "":
			_spotlight_new.call_deferred())
	_ui_root.add_child(sp)


## The first level played with the headlights on: what they are, once (BuffCard). After any other card.
func _lights_intro() -> void:
	# (A new player meets them through the tutorial instead: jobs 1 and 2 in the dark, the headlights found on
	# job 2's road; this card is for a save from before the headlights, which already has some.)
	if not Progress.lights_on() or Progress.sight() <= 0 or Progress.seen_new.has("headlights") or (Progress.auto and not OS.get_cmdline_user_args().has("--lights-intro")):
		return
	while true:
		while _busy_modal():
			await get_tree().process_frame
			if not is_inside_tree():
				return
		await get_tree().create_timer(0.4).timeout
		if not is_inside_tree():
			return
		if not _busy_modal():
			break
	if state != State.IDLE:
		return                      # already driving: it'll say so next level
	Progress.seen_new["headlights"] = true
	Progress.set_option("seen_new", Progress.seen_new)
	var card := BuffCard.new()
	card.lights = Progress.sight()
	card.intro = true
	modal = card
	card.done.connect(func():
		if modal == card:
			modal = null)
	_overlay(card)


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
## Where the crusher sits: bottom middle, over the controls (they're no use mid-drag), well off the board.
func _cz_center() -> Vector2:
	var vp := get_viewport_rect().size
	if Progress.landscape:
		return Vector2(vp.x - 150.0 - UiTheme.side_insets(get_viewport()).y, vp.y - 150.0 - _bottom_inset)
	return Vector2(vp.x / 2.0, vp.y - _bottom_inset - 160.0)


## Is the finger (viewport position) in the cancel zone? It's harder to leave than to enter, so it doesn't
## flicker at the edge.
func _cz_track(at: Vector2) -> void:
	if _fs > 0:
		_cz_in = false       # short foresight: nothing to scrap, the van's already driven it
		return
	var d := at.distance_to(_cz_center())
	var was := _cz_in
	_cz_in = d < (150.0 if _cz_in else 95.0)
	if _cz_in and not was:
		Sfx.play("tick", 0.7, -4.0)
		Sfx.haptic(8, 1.0, "game:_cz_track")


func _cancel_zone_tick(delta: float) -> void:
	var drawing := state == State.DRAWING and not dpad_mode and _fs == 0
	if _cz_crush >= 0.0:
		_cz_crush += delta
		if _cz_crush > 0.45:
			_cz_crush = -1.0
	_cz.visible = drawing or _cz_crush >= 0.0
	if not _cz.visible:
		_cz_in = false
		_cz_t = 0.0
		return
	var before := _cz_t
	if _cz_in and drawing:
		_cz_t = minf(_cz_t + delta, CANCEL_HOLD + 1.0)
	else:
		_cz_t = maxf(_cz_t - delta * 3.0, 0.0)
	if before < CANCEL_HOLD and _cz_t >= CANCEL_HOLD:
		Sfx.play("gate", 0.8, -4.0)
		Sfx.haptic(16, 1.0, "game:_cancel_zone_tick")
	_cz.position = Vector2.ZERO
	_cz.size = get_viewport_rect().size
	_cz.queue_redraw()


## A car crusher: two hazard-striped plates either side of a little car. Small when idle; finger in, it grows,
## a ring sweeps round and the plates close in; full, it says RELEASE TO CANCEL. Then they slam.
func _draw_cancel_zone() -> void:
	var c := _cz_center()
	var u := clampf(_cz_t / CANCEL_HOLD, 0.0, 1.0)
	var grow := clampf(_cz_t / 0.12, 0.0, 1.0) if _cz_in else u
	if _cz_crush >= 0.0:
		grow = 1.0 - clampf(_cz_crush / 0.45, 0.0, 1.0)
		u = 1.0
	var r := lerpf(44.0, 120.0, 1.0 - pow(1.0 - grow, 3.0))
	var full := u >= 1.0
	_cz.draw_circle(c + Vector2(0, 6), r, Color(0, 0, 0, 0.22))
	_cz.draw_circle(c, r, Color("2b2f38") if not full else Color("d7192a"))
	_cz.draw_circle(c, r * 0.86, Color("3a3f4d") if not full else Color("ff3d4f"))
	if u > 0.0 and _cz_crush < 0.0:
		_cz.draw_arc(c, r * 0.93, -PI / 2.0, -PI / 2.0 + TAU * u, 48, Color("ffd166"), r * 0.1, true)
	# The car being crushed.
	var s := r / 120.0
	var squeeze := (1.0 - 0.55 * u) if _cz_crush < 0.0 else 0.35
	var cw := 90.0 * s * squeeze
	var ch := 54.0 * s
	DrawUtil.rrect(_cz, Rect2(c - Vector2(cw, ch) / 2.0, Vector2(cw, ch)), Color("e9edf5"), 12.0 * s)
	DrawUtil.rrect(_cz, Rect2(c + Vector2(cw * 0.12, -ch * 0.36), Vector2(cw * 0.3, ch * 0.72)), Palette.VAN_GLASS, 6.0 * s)
	# The plates, closing in.
	for sd: float in [-1.0, 1.0]:
		var px: float = c.x + sd * (cw / 2.0 + 10.0 * s)
		var plate := Rect2(Vector2(px if sd > 0 else px - 16.0 * s, c.y - 46.0 * s), Vector2(16.0 * s, 92.0 * s))
		DrawUtil.rrect(_cz, plate, Color("ffd166"), 4.0 * s)
		for k in 4:
			var y := plate.position.y + 8.0 * s + k * 22.0 * s
			_cz.draw_line(Vector2(plate.position.x, y), Vector2(plate.end.x, y + 10.0 * s), Color("1d1f26"), 5.0 * s)
	if not _cz_in and _cz_crush < 0.0:
		return
	var f := UiTheme.font()
	var txt := "RELEASE TO CANCEL" if full else "HOLD TO CANCEL"
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	var ty := c.y - r - 30.0
	DrawUtil.rrect(_cz, Rect2(c.x - tw / 2.0 - 22.0, ty - 46.0, tw + 44.0, 64.0), Color(Palette.BUBBLE, 0.95), 32)
	_cz.draw_string(f, Vector2(c.x - tw / 2.0, ty), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color("d7192a") if full else Palette.TEXT)


func _process(delta: float) -> void:
	_test_clock += delta
	if _cz:
		_cancel_zone_tick(delta)
	_skip_tick()
	_fs_tick(delta)
	_undo_hold_tick(delta)
	_rush_tick(delta)
	_limits_tick(delta)
	_dispatch_tick()
	_call_nudge_tick(delta)
	_verdict_tick()
	_guide_tick()
	_detour_tick()
	_nudge_tick(delta)
	if not _busy_modal() and (state == State.IDLE or state == State.DRAWING):
		_idle_t += delta
	if stars_ctl and (Progress.heat() > 0 or _twist() == "mega") and state != State.WON:
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
	if convoy and (state != State.DRAWING or _fs > 0):
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
	# Replay ghost path (an option): the last try at this level, faint, under the route.
	if Progress.ghost_path and str(last_attempt.get("key", "")) == _attempt_key() and last_attempt.get("route", []).size() >= 2:
		replay_ghost = ReplayGhost.new()
		replay_ghost.setup(board, last_attempt["route"])
		board.add_child(replay_ghost)
		board.move_child(replay_ghost, board.path_line.get_index())

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
	var buttons := _bar_buttons()
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
			b.custom_minimum_size = Vector2(minf((far_w - 14.0 * (buttons.size() - 1)) / buttons.size(), 200.0), 108)
			b.font_px = 34 if buttons.size() <= 3 else 28
		actions.size = Vector2(far_w, 108)
		actions.position = Vector2(far_l, bottom - 112 - 24 - 108)
		_place_gas_in(Rect2(far_l, bottom - 112, far_w, 112), lefty)
		text_x = far_l
		text_w = far_w
		text_bottom = actions.position.y - 20.0
	else:
		var bh := 118.0 if buttons.size() <= 3 else 100.0
		for b in buttons:
			b.custom_minimum_size = Vector2(240, bh)
			b.font_px = 40 if buttons.size() <= 3 else 36
		var col_w := 240.0
		# Stacked: (Radio,) Hint on top, then Undo, then Retry.
		actions.vertical = true
		actions.size = Vector2(col_w, bh * buttons.size() + 14 * (buttons.size() - 1))
		actions.position = Vector2(right_x - col_w, bottom - actions.size.y)
		# The gauge right on top of Hint.
		_set_gas_width(col_w)
		gas_chip.position = Vector2(right_x - col_w, actions.position.y - 14.0 - GasChip.H)
		text_bottom = bottom
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
	_cz = Control.new()
	_cz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cz.draw.connect(_draw_cancel_zone)
	_cz.visible = false
	root.add_child(_cz)
	peek = PeekBubble.new()
	peek.unit = 58.0
	peek.visible = false
	root.add_child(peek)

	# Top bar: levels button, level name (the streak burning under it), wallet, options. (The gas gauge is down by Hint and Undo,
	# which it pays for: see _layout.)
	bar = HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 36
	bar.offset_right = -36
	bar.offset_top = 40 + _top_inset
	bar.offset_bottom = 40 + _top_inset + 110
	bar.add_theme_constant_override("separation", 12)
	root.add_child(bar)

	# Where the levels button was: room for the way out, a ribbon from the screen's edge (ExitRibbon).
	var menu_gap := Control.new()
	menu_gap.custom_minimum_size = Vector2(112, 102)
	menu_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(menu_gap)
	exit_ribbon = ExitRibbon.new()
	exit_ribbon.position = Vector2(0, 40 + _top_inset)
	exit_ribbon.give_up.connect(func():
		Sfx.play("click")
		_leave())
	exit_ribbon.gift_tapped.connect(_reveal_jets)
	exit_ribbon.jets_down.connect(_jets_down)
	exit_ribbon.jets_up.connect(_jets_up)
	root.add_child(exit_ribbon)

	var mid := VBoxContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", -4)
	bar.add_child(mid)
	level_label = Label.new()
	level_label.text = "Job %d" % level.number if daily_day < 0 else "Daily #%d" % Daily.number(daily_day)
	if og:
		level_label.text = "OG %d" % level.number
	if not side.is_empty():
		level_label.text = str(side.get("title", "Detour"))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 52)
	mid.add_child(level_label)
	stars_ctl = Control.new()
	stars_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars_ctl.custom_minimum_size = Vector2(0, 40)
	stars_ctl.draw.connect(_draw_stars)
	# A tap on the momentum flame says what it is.
	stars_ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	stars_ctl.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Progress.heat() > 0 and state != State.WON:
			stars_ctl.accept_event()
			Sfx.play("click")
			var tip := TipBubble.new()
			tip.text = FinishScreen.MOMENTUM_TIP
			tip.target = stars_ctl.get_global_rect().get_center()
			_ui_root.add_child(tip))
	mid.add_child(stars_ctl)
	if _twist() == "melt":
		# Before It Melts: the clock takes the middle of the top bar, big, where you can't miss it.
		level_label.visible = false
		stars_ctl.visible = false
		melt_clock = MeltClock.new()
		melt_clock.game = self
		melt_clock.custom_minimum_size = Vector2(0, 112)
		mid.add_child(melt_clock)

	coin_chip = CoinChip.new()
	coin_chip.visible = Progress.COINS
	bar.add_child(coin_chip)
	# Options, top right (as on the title and the map): as wide as the levels button, so the level's name
	# sits in the middle.
	mode_button = JuicyButton.new()
	mode_button.icon_name = "gear"
	mode_button.custom_minimum_size = Vector2(112, 102)
	mode_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mode_button.pressed.connect(func():
		if _busy_modal():
			return
		Sfx.play("click")
		if dpad_mode and state == State.DRAWING:
			_cancel_plan()
		options_requested.emit())
	bar.add_child(mode_button)

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

	Progress.settings_changed.connect(_on_settings)
	dpad = DPad.new()
	dpad.step.connect(_dpad_step)
	dpad.clear.connect(_dpad_clear)
	root.add_child(dpad)
	drive_button = JuicyButton.new()
	drive_button.label = Cosmetics.go_word(Progress.ride, 1)
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
	actions = FlowContainer.new()
	actions.add_theme_constant_override("h_separation", 14)
	actions.add_theme_constant_override("v_separation", 14)
	root.add_child(actions)
	# The helpers you carry and gas buys more of (Hint, in gold: the dear one; the Radio, where there is one),
	# then the pump, then the two that are always free (Undo, Retry): the pump stands in the middle between them.
	hint_button = _action("bulb", "Hint", _on_hint_pressed)
	if daily_day >= 0:
		# No hints on the daily, so their slot (the bar never moves) brings back how the daily works.
		hint_button.label = "Rules"
		hint_button.icon_name = "calendar"
	hint_button.recolor(HINT_GOLD, Color("2b2233"))
	if _radio_here():
		radio_button = _action("radio", "Call", _on_radio_pressed)
		radio_button.recolor(DispatchBox.CALL_BLUE, Color("14273d"))
		radio_button.button_down.connect(_hold_down.bind("radio"))
		radio_button.button_up.connect(_hold_up)
	elif _radio_coming():
		# Not yet: its place on the bar, padlocked, so nothing moves when it arrives.
		_radio_lock = _action("radio", "Call", _on_locked_pressed.bind("radio"))
		_radio_lock.locked = true
	_pump_gap = Control.new()
	_pump_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pump_gap.visible = false
	actions.add_child(_pump_gap)
	undo_button = _action("undo", "Undo", _on_undo_pressed)
	retry_button = _action("retry", "Retry", _on_retry_pressed)
	if daily_day >= 0:
		# The daily: tries left today on Retry (Daily.MAX_TRIES; this one's already counted).
		var r := Progress.daily_record(daily_day)
		if not r.get("done", false):
			retry_button.badge = str(Daily.tries_left(r))
			retry_button.dim = Daily.tries_left(r) == 0
	# Past the free ones, a tank is spent with a hold (GasLine), not a tap.
	hint_button.button_down.connect(_hold_down.bind("hint"))
	hint_button.button_up.connect(_hold_up)
	undo_button.button_down.connect(_hold_down.bind("undo"))
	undo_button.button_up.connect(_hold_up)
	for pair in [["hints", hint_button], ["undos", undo_button]]:
		var ring := RushRing.new()
		ring.kind = pair[0]
		pair[1].add_child(ring)
		_rush_rings[pair[0]] = ring
	# The gas gauge, right by the buttons it pays for (placed in _layout).
	gas_chip = GasChip.new()
	gas_chip.pump = true             # (in a job it's the slim pump: room for a fourth button)
	gas_chip.shop_requested.connect(_open_shop)
	gas_chip.locked_pressed.connect(_on_locked_pressed.bind("pump"))
	gas_chip.locked = _pump_locked()
	root.add_child(gas_chip)


## What the label under the board says before the player starts: the level's name and its hint (or how to
## steer). The D-pad leaves less room, so there it's just the hint.
func _hint_text() -> String:
	var how := ("Tap the arrows to plot a route, then %s." % Cosmetics.go_word(Progress.ride, 1)) if dpad_mode else "Drag a route from the van."
	if Progress.lights_on() and Progress.sight() == 0:
		# The tutorial's dark: no lights yet, so every tile drawn is driven.
		how = "Tap the arrows. The van goes wherever you point... for now." if dpad_mode else "Drag from the van. It drives right under your finger... for now."
	elif Progress.lights_on():
		var ahead := "%d tile%s" % [Progress.sight(), "" if Progress.sight() == 1 else "s"]
		how = ("Tap the arrows: %s ahead, the van starts driving." % ahead) if dpad_mode else ("Drag from the van: %s ahead, it starts driving." % ahead)
	var default_hint := "Deliver everything, then park at the depot." if level.return_depot else how
	var body: String = level.hint if level.hint != "" else default_hint
	if level.number == 1:
		body = how
	if Progress.landscape and level.title != "":
		return "“%s”\n" % level.title + body
	return body


## The gas gauge in `r` (by the controls), as wide as fits; against its right edge if `right`, else its left.
func _place_gas_in(r: Rect2, right: bool) -> void:
	_set_gas_width(r.size.x)
	var y := r.position.y + (r.size.y - GasChip.H) / 2.0 + 4.0
	var x := r.end.x - gas_chip.size.x if right else r.position.x
	gas_chip.position = Vector2(x, y)


## Hint, Undo and Retry, with Call before them where there is one (or its padlocked place, till it comes).
func _bar_buttons() -> Array:
	var call: JuicyButton = radio_button if radio_button else _radio_lock
	return [hint_button] + ([call] if call else []) + [undo_button, retry_button]


## The Call button isn't on the bar yet, but it's coming: a main-road job before RADIO_FROM.
func _radio_coming() -> bool:
	return not Progress.has_radio() and side.is_empty() and daily_day < 0 and not og


## The pump's place on the bar, padlocked, till the Baron installs it (LimitsScene).
func _pump_locked() -> bool:
	return not Progress.limits_on() or _still_free("pump") or daily_day >= 0     # (gas buys nothing on a daily)


## Something on the bar that isn't open yet (a padlock on it) was tapped: when it comes.
func _on_locked_pressed(what: String) -> void:
	Sfx.play("untick", 0.9, -6.0)
	Sfx.haptic(8, 0.4, "game:_on_locked_pressed")
	var tip := TipBubble.new()
	tip.above = true
	if what == "radio":
		_radio_lock.wiggle()
		tip.text = "Call Dispatch opens on job %d." % Progress.RADIO_FROM
		tip.target = _radio_lock.get_global_rect().get_center() + Vector2(0, -50)
	else:
		gas_chip.bump()
		tip.text = "No gas on the daily.\nJust you and the map." if daily_day >= 0 else "The gas pump opens on job %d." % Progress.LIMITS_FROM
		tip.target = gas_chip.get_global_rect().get_center() + Vector2(0, -50)
	_ui_root.add_child(tip)


func _set_gas_width(room: float) -> void:
	var w := GasChip.PUMP_W if gas_chip.pump else clampf(room, 210.0, GasChip.W)
	gas_chip.wide = w
	gas_chip.custom_minimum_size = Vector2(w, GasChip.H)
	gas_chip.size = Vector2(w, GasChip.H)
	gas_chip.queue_redraw()


func _action(icon: String, text: String, on_press: Callable) -> JuicyButton:
	var b := JuicyButton.new()
	b.skinned = true                 # (the worn control scheme: Looks)
	b.icon_name = icon
	b.label = text
	b.font_px = 40
	b.custom_minimum_size = Vector2(212, 118)
	b.pressed.connect(on_press)
	actions.add_child(b)
	return b


## Under the level name: a mega route's parts, or the streak (a little flame and the count, while the run's
## alive).
func _draw_stars() -> void:
	if _twist() == "mega":
		_draw_parts_map()
		return
	var c := stars_ctl.size / 2.0
	var m := Progress.heat()
	if m > 0 and state != State.WON:
		var f := UiTheme.font()
		var t := Time.get_ticks_msec() / 1000.0
		var at := c + Vector2(-26, 0)
		AnimeFire.draw_flame(stars_ctl, at + Vector2(0, 17), 28, 38 + 2.0 * mini(m, 8), t, 1.0, AnimeFire.palette(m))
		var txt := "×%d" % m
		stars_ctl.draw_string_outline(f, at + Vector2(17, 11), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color.WHITE)
		stars_ctl.draw_string(f, at + Vector2(17, 11), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, AnimeFire.palette(m)[0].darkened(0.1))


func _layout() -> void:
	# The pump's in its place all along: padlocked till the helpers are metered (the Baron installs it:
	# LimitsScene), so nothing on the bar ever moves.
	gas_chip.visible = state != State.WON          # (the finish card's up: it showed through "Replay")
	gas_chip.locked = _pump_locked()
	_pump_gap.visible = false
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
	var buttons := _bar_buttons()
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
		# (Three in a row; four go two by two: the column's too narrow for four across.)
		var across := 3 if buttons.size() <= 3 else 2
		for b in buttons:
			b.custom_minimum_size = Vector2(floorf((far_w - 14.0 * (across - 1)) / across), 104)
			b.font_px = 32 if buttons.size() <= 3 else 36
		actions.size = Vector2(far_w, 104 if buttons.size() <= 3 else 104 * 2 + 14)
		actions.position = Vector2(far_x, drive_button.position.y + 12)
		_place_gas_in(Rect2(far_x, bottom - 112, far_w, 112), lefty)
		block_top = drive_button.position.y
	else:
		# (Four across once the Radio's aboard: the slim pump leaves the room.)
		# Hint and the Radio, then the pump (once the Baron's installed it), then Undo and Retry: the pump stands
		# in the middle of the row, between what gas buys and what's always free.
		var pump := gas_chip.visible
		var nb := buttons.size()
		var bwid := 200.0
		for b in buttons:
			b.custom_minimum_size = Vector2(bwid, 118)
			b.font_px = 40
		_pump_gap.visible = pump
		_pump_gap.custom_minimum_size = Vector2(GasChip.PUMP_W, 118)
		var row := bwid * nb + 14.0 * (nb - 1) + (GasChip.PUMP_W + 14.0 if pump else 0.0)
		actions.size = Vector2(row, 118)
		actions.position = Vector2(vp.x - 36 - row, bottom - 118)
		_set_gas_width(0.0)
		gas_chip.position = Vector2(actions.position.x + (bwid + 14.0) * (2 if (radio_button or _radio_lock) else 1), bottom - 118 + (118 - GasChip.H) / 2.0 + 4.0)
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
	# ...and out from under the ribbon at the top left (two rows tall on the main road): where the words
	# would run beside it, they're kept as far in from both sides as it sticks out, so they stay centred.
	if exit_ribbon and text_top < exit_ribbon.position.y + ExitRibbon.ROW_H * 2.0 + 12.0:
		var clear := maxf(0.0, ExitRibbon.TAB_W + 24.0 - (text_l + 40.0))
		text_l += clear
		text_w -= clear * 2.0
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


## The cancel zone sits partly over the bottom buttons, and a button swallows the pointer's moves before
## _unhandled_input sees them. So while a route's being drawn, the zone follows the finger from here.
func _input(event: InputEvent) -> void:
	if state == State.WON and _win_wait and _win_wait.is_valid() and _win_go.is_valid() and event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		_win_wait.kill()
		var go := _win_go
		_win_go = Callable()
		go.call()
		return
	if state != State.DRAWING or dpad_mode or _busy_modal():
		return
	if event is InputEventMouseMotion:
		if Progress.auto and not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			return
		_cz_track(event.position)


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
			# A quick tap does what can be done first: a locker beside the van is used. A locker that can't
			# be used yet says how (holding it still explains it); anything else explains itself.
			if event.position.distance_to(sp["pos"]) < 24.0 and not _tap_locker(sp["tile"]):
				if _locker_at(sp["tile"]) >= 0 and state == State.IDLE:
					_say("Stop beside the locker, then tap it.")
				else:
					_explain(sp["tile"])
			return
		if dpad_mode:
			return
		if event.pressed:
			_press(lp)
		elif event.canceled:
			# (The touch was taken away, not lifted: the app went to the background. The plan's dropped.)
			if state == State.DRAWING:
				_cancel_plan()
		else:
			if state == State.DRAWING:
				_cz_track(event.position)
			_release()
	elif event is InputEventMouseMotion and not _sym_press.is_empty():
		if event.position.distance_to(_sym_press["pos"]) > 24.0:
			_sym_press = {}
	elif event is InputEventMouseMotion and state == State.DRAWING and not dpad_mode:
		# Self-tests inject their own drags: ignore the real cursor wandering over the window meanwhile.
		if Progress.auto and not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			return
		_cz_track(event.position)
		if _cz_in:
			return
		_drag(board.make_input_local(event).position)


## The houses still waiting for a package of `color_name` hop, with a ring in their colour.
func _point_out(color_name: String) -> void:
	Sfx.play("tick", 1.2, -4)
	Sfx.haptic(6, 1.0, "game:_point_out")
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
	_clear_back()
	state = State.DRAWING
	timing = true
	_dim_hint(true)
	seg = [route.back()]
	seg_states = [Sim.copy_state(sim_state)]
	_fs = Progress.sight() + 1 if Progress.lights_on() else 0     # (how far ahead it can plan, plus one)
	_fs_committed = 0
	_fs_dist = 0.0
	_fs_released = false
	_fs_rot0 = van.target_rotation
	if _fs > 0:
		combo = 0
		_fired = 0
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
	Sfx.haptic(8, 1.0, "game:_begin_plan")


## While planning: the chute shows the load as it'll be at the end of the route so far (so its mouth holds
## what's next from there), and with the route preview on, a chip by the board's corner shows the next three.
func _preview_load() -> void:
	if state != State.DRAWING or seg.is_empty() or seg_states.is_empty():
		if _effects_end <= _now():
			stack_view.show_stack(sim_state["stack"])
		peek.clear()
		return
	var st: Array = seg_states.back()["stack"]
	_queue_plan()
	# (The "next three" chip that used to pop up by the queue while planning is retired: with the headlights
	# the van's a tile or three behind the finger, so there's no far end of a plan to preview.)
	if true:
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
func _cancel_plan(check := true) -> void:
	var landed := _fs > 0 and _fs_committed > 0
	if landed:
		# Short foresight: what the van's committed to stays driven. Only the plan ahead of it is dropped.
		_fs_land()
	_fs = 0
	_fs_committed = 0
	_fs_dist = 0.0
	_fs_released = false
	state = State.IDLE
	_dim_hint(false)
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
	if landed:
		_at(_effects_end + 0.05, func(): stack_view.show_stack(sim_state["stack"]))
		if check:
			# Was that the win, or a dead end? (Once whoever dropped the plan is done.)
			(func():
				if state == State.IDLE:
					_after_segment()).call_deferred()


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
	var from := 0
	var pts: Array = seg
	if _fs > 0 and seg.size() >= 2 and _fs_dist > 0.0:
		# Short foresight: the van's part-way along it. The line starts at the van.
		from = clampi(int(floor(_fs_dist)), 0, seg.size() - 2)
		pts = [van.position] + seg.slice(from + 1)
	var cols := []
	for i in range(from, seg.size() - 1):
		cols.append(_tint(Sim.top_color(level, seg_states[i])))
	board.show_path(pts, cols)


func _tint(color_name: String) -> Variant:
	return Palette.pkg(color_name) if color_name != "" else null


## The route can't go onto `t`: a red X on that edge. The line stays where it is.
func _block(t: Vector2i) -> void:
	if blocked_at == t:
		return
	blocked_at = t
	board.show_block(seg.back(), t)
	Sfx.play("bonk", 0.7, -4)
	Sfx.haptic(16, 1.0, "game:_block")


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
	stack_view.owed = _owed(sim_state)
	# Everything aboard delivered but some still out there: the chute's "Awaiting pickup" pulses red, so an
	# empty van doesn't read as "done". (Not on a job that starts empty, before its first delivery.)
	stack_view.owed_alert = sim_state["stack"].is_empty() and Sim.delivered_count(sim_state) > 0
	_queue_plan()
	# Pickups the planned route will empty hold still and fade.
	for k in board.shop_nodes.size():
		board.shop_nodes[k].planned = state == State.DRAWING and int(st["picked"][k]) > int(sim_state["picked"][k])
	var ready := _locker_ready()
	for k in board.locker_nodes.size():
		(board.locker_nodes[k] as House).next_up = k == ready      # (the one the van can use: tap it)
	var top := Sim.top_color(level, st)
	for h in level.houses.size():
		var house: House = board.house_nodes[h]
		var need: int = level.houses[h].order - st["fills"][h]
		house.ghost_done = need <= 0 and sim_state["fills"][h] < level.houses[h].order
		var was: bool = house.next_up
		house.next_up = need > 0 and top != "" and level.houses[h].color == top
		if house.next_up and not was and state == State.DRAWING:
			house.hop()


## Packages still owed that aren't aboard (parked in a locker, or still waiting at a pickup), counted by
## colour in the order they're met, for the chute's "Awaiting pickup": [[colour, n], ...].
func _owed(s: Dictionary) -> Array:
	var count := {}
	var order := []
	var add := func(c: String, n: int):
		if n <= 0:
			return
		if not count.has(c):
			order.append(c)
		count[c] = int(count.get(c, 0)) + n
	var held: Array = s.get("held", [])
	for k in level.lockers.size():
		if k < held.size() and str(held[k]) != "":
			add.call(str(held[k]), 1)
	for k in level.shops.size():
		add.call(str(level.shops[k].color), int(level.shops[k].count) - int(s["picked"][k]))
	var out := []
	for c in order:
		out.append([c, count[c]])
	return out


## While planning, the chute keeps the real load and marks up what the plan will do to it: the packages it
## delivers stay in the mouth washed out with a ghost tick, the ones it picks up wait behind them as outlines
## with a "+". (Planned, not real: the real load only changes as the van actually gets there.)
func _queue_plan() -> void:
	var cur: Array = sim_state["stack"]
	if seg_states.is_empty() or not (state == State.DRAWING or _plan_showing()):
		return
	# The load as it'll be at the end of the plan, in that order (a spinner on the way reorders it), with
	# what the plan picks up marked "new" and what it delivers added at the mouth, marked "gone". They're
	# counted by colour: a package that's only been moved by a spinner is neither (it used to come up as
	# delivered and picked up again).
	var st: Array = seg_states.back()["stack"]
	var have := {}
	for c in cur:
		have[c] = int(have.get(c, 0)) + 1
	var will := {}
	for c in st:
		will[c] = int(will.get(c, 0)) + 1
	var marks := []
	marks.resize(st.size())
	marks.fill("")
	# New ones come in at the mouth, so they're the top ones of their colour.
	var extra := {}
	for c in will:
		extra[c] = int(will[c]) - int(have.get(c, 0))
	for i in range(st.size() - 1, -1, -1):
		if int(extra.get(st[i], 0)) > 0:
			marks[i] = "new"
			extra[st[i]] = int(extra[st[i]]) - 1
	var gone := []
	var spare := {}
	for c in have:
		spare[c] = int(have[c]) - int(will.get(c, 0))
	for i in range(cur.size() - 1, -1, -1):
		if int(spare.get(cur[i], 0)) > 0:
			gone.push_front(cur[i])
			spare[cur[i]] = int(spare[cur[i]]) - 1
	# Of those, the ones the plan leaves in a parking locker aren't delivered: they're marked "P".
	var parked := {}
	for c in seg_states.back().get("held", []):
		if c != "":
			parked[c] = int(parked.get(c, 0)) + 1
	for c in sim_state.get("held", []):
		if c != "":
			parked[c] = int(parked.get(c, 0)) - 1
	var gmarks := []
	gmarks.resize(gone.size())
	gmarks.fill("gone")
	for i in range(gone.size() - 1, -1, -1):
		if int(parked.get(gone[i], 0)) > 0:
			gmarks[i] = "park"
			parked[gone[i]] = int(parked[gone[i]]) - 1
	stack_view.show_plan(st + gone, marks + gmarks)


## The chute is showing a plan's preview while the van really drives it (headlights: it follows the finger,
## and finishes the plan after it's let go). What the van really does on the way (a pickup, a delivery, a
## spinner) mustn't be played into that preview as if it were the real load: the preview is worked out again
## from the new state instead. (It used to: a parcel picked up mid-plan showed twice.)
func _plan_showing() -> bool:
	return _fs > 0 and seg.size() >= 2 and not seg_states.is_empty() and (state == State.DRAWING or state == State.DRIVING)


## Something really happened to the load (a pickup, a delivery, a spinner) while the chute was showing a
## plan's preview (`was_preview`: it was when it happened; the change lands a moment later): show the
## preview again from the real state, or (the plan's over) the real load. True if it did (so the caller
## doesn't also play the change into the chute, which already has it).
func _resync_preview(was_preview := false) -> bool:
	if not (stack_view.preview or was_preview):
		return false
	if _plan_showing():
		_queue_plan()
	else:
		stack_view.show_stack(sim_state["stack"])
	van.set_top(Sim.top_color(level, sim_state))
	return true


## Can the last tile of the plan be undrawn? (Not one the van's committed to.)
func _can_retract() -> bool:
	return seg.size() >= 2 and seg.size() - 1 > _fs_committed


func _drag(lp: Vector2) -> void:
	var last: Vector2i = seg.back()
	# Short foresight: every tile drawn is (nearly) a move made, so a thumb sliding off the board draws nothing.
	if _fs > 0 and not Rect2(Vector2.ZERO, board.size_px()).grow(board.tile * 0.4).has_point(lp):
		_unblock()
		return
	# Hysteresis: stay on the current tile until the finger is clearly out of it.
	var off := (lp - board.center(last)).abs()
	if maxf(off.x, off.y) < board.tile * 0.58:
		_unblock()
		return
	var target := board.tile_at(lp)
	if _fs > 0 and target != seg.back():
		# Short foresight: a finger back on road that's already driven means "not that way" and nothing
		# more. The plan ahead of the van is undrawn; no new way round is guessed at (it would be a move).
		# (Unless it's a real next step: the way home to the depot, or a bridge crossed the other way.)
		var at := seg.find(target)
		var step: Vector2i = target - seg.back()
		var legal: bool = absi(step.x) + absi(step.y) == 1 and _can(target)
		if (route.has(target) or (at >= 0 and at <= _fs_committed)) and not legal:
			while _can_retract():
				_retract()
			return
	var guard := 0
	while target != seg.back() and guard < 24:
		guard += 1
		var cur: Vector2i = seg.back()
		# Dragging back over the segment undraws it (finished segments are locked).
		if _can_retract() and target == seg[seg.size() - 2]:
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
		if not moved and steps[0] != Vector2i.ZERO and _can_retract() and cur + steps[0] == seg[seg.size() - 2]:
			# The finger has swept back along the line faster than tile by tile: keep undrawing toward it.
			_retract()
			moved = true
		if not moved:
			for s in steps:
				if s != Vector2i.ZERO and _wreck(cur + s):
					_block(cur + s)
					break
			break


## Lifts and lowers the colour gates. While there's a plan, they stand as they will at the END of it (that's
## what the next tile is judged by), not by what's on top where the van has got to: with the headlights the
## van trails the finger, and a gate used to swing open for a package the plan had already delivered. One
## the van has still to drive through stays up until it's through.
func _show_gates() -> void:
	if level.gates.is_empty():
		return
	if seg.size() < 2 or seg_states.size() != seg.size():
		board.update_gates(Sim.top_color(level, sim_state))
		return
	var driven := _fired if (state == State.DRIVING or _fs > 0) else 0
	board.update_gates(Sim.top_color(level, seg_states.back()), false, seg.slice(driven + 1))


## Bumping into a closed gate: it rattles (once per attempt at that tile).
func _maybe_deny(t: Vector2i) -> void:
	if t == _denied or not board.gate_nodes.has(t):
		return
	_denied = t
	board.gate_nodes[t].deny()
	Sfx.play("bonk", 1.3, -8)
	Sfx.haptic(10, 1.0, "game:_maybe_deny")


func _extend(t: Vector2i) -> void:
	var st := Sim.copy_state(seg_states.back())
	Sim.arrive(level, st, t, route + seg)
	seg.append(t)
	seg_states.append(st)
	if _fs > 0:
		_fs_committed = maxi(_fs_committed, seg.size() - _fs)
	_unblock()
	_show_seg()
	_show_gates()
	_refresh_tags()
	_preview_load()
	Sfx.play("tick", 1.0 + minf(seg.size(), 24) * 0.015, -2)
	Sfx.haptic(6, 1.0, "game:_extend")


func _retract() -> void:
	seg.pop_back()
	seg_states.pop_back()
	_denied = NOWHERE
	_unblock()
	_show_seg()
	_show_gates()
	_refresh_tags()
	_preview_load()
	Sfx.play("untick", 1.0, -4)
	Sfx.haptic(4, 1.0, "game:_retract")


## The plan is sent: the van drives it. If the X was showing (the player was pushing into wreckage), it
## ends with a hard brake just short of it.
func _release() -> void:
	if state != State.DRAWING:
		return
	if _cz_in and _cz_t >= CANCEL_HOLD:
		# Let go on the crusher: the route's scrapped.
		_cz_crush = 0.0
		_cz_in = false
		_cz_t = 0.0
		_cancel_plan()
		Sfx.play("crunch", 0.9, 0.0)
		Sfx.play("slam", 1.2, -6.0)
		Sfx.haptic(25, 1.0, "game:_release")
		_say("Route scrapped. Start again from the van.")
		return
	_cz_in = false
	_cz_t = 0.0
	var into := blocked_at
	_remove_ghost()
	if seg.size() < 2:
		_cancel_plan()
		if into != NOWHERE:
			van.shake()
		return
	_unblock()
	_brake_into = into
	if _fs > 0:
		_fs_send()
		return
	_drive()


# ---------------------------------------------------------------- short foresight

## The finger's up: the van drives what's left of the plan, and the move ends when it gets there.
func _fs_send() -> void:
	_fs_committed = seg.size() - 1
	_fs_released = true
	state = State.DRIVING
	peek.clear()
	timing = true
	_update_undo()
	_refresh_tags()


## The van follows the plan as far as it's committed, keeping close behind the finger (faster the further
## back it's fallen), and does at each tile what a drive does there.
func _fs_tick(delta: float) -> void:
	if _fs == 0 or seg.size() < 2 or not (state == State.DRAWING or (state == State.DRIVING and _fs_released)):
		return
	var goal := float(_fs_committed)
	if _now() < _fs_hold:
		return            # (stopped on a tile while its packages come and go)
	if _fs_dist < goal:
		# Quick off the mark, easing in as it catches up: one smooth follow, not a stop at every tile.
		var speed := clampf((goal - _fs_dist) * 10.0, 3.0, DRIVE_SPEED * 2.5)
		_fs_dist = minf(goal, _fs_dist + speed * delta)
		var i := clampi(int(floor(_fs_dist)), 0, seg.size() - 2)
		var a := board.center(seg[i])
		var b := board.center(seg[i + 1])
		van.position = a.lerp(b, _fs_dist - i)
		van.target_rotation = (b - a).angle()
		_show_seg()
		board.show_trail(route + seg.slice(1, i + 1) + [van.position])
		board.wreck.set_route(route + seg.slice(1, _fs_committed + 1), route.size() - 1 + i + (1 if _fs_dist - i >= 0.55 else 0))
		if board.fire.momentum > 0 and (_fire_last == Vector2.INF or van.position.distance_to(_fire_last) > board.tile * 0.22):
			_fire_last = van.position
			board.fire.emit(van.position)
		while _fired < seg.size() - 1 and _fs_dist >= _fired + 1 - 0.02:
			_fired += 1
			_last_handoff = 0.0
			_fs_arrive(_fired)
			if _last_handoff > 0.0:
				# Packages on the move here: the van pulls up on this tile till they've gone or landed, then
				# catches up with the finger.
				_fs_dist = float(_fired)
				van.position = board.center(seg[_fired])
				_fs_hold = _now() + _last_handoff
				break
	if _fs_released and _fs_dist >= goal:
		_fs = 0
		_fs_committed = 0
		_fs_dist = 0.0
		_fs_released = false
		_drive_done()


## The van reaches tile k of the plan. Undo goes back to the last stop, so each stop leaves a marker
## (`history`: how things stood there), and so does where the try began.
func _fs_arrive(k: int) -> void:
	if history.is_empty():
		history.append({"len": route.size() + k - 1, "state": Sim.copy_state(sim_state), "rot": _fs_rot0, "deliv": deliveries.size()})
	if k == 1:
		_clear_hint()
	if _arrive(k):
		history.append({"len": route.size() + k, "state": Sim.copy_state(sim_state), "rot": Vector2(seg[k] - seg[k - 1]).angle(), "deliv": deliveries.size()})


## The plan's dropped part-way (the D-pad's Clear, a twist's rule broken): the van is put where it's
## committed to, with everything on the way there done, and the rest of the plan is forgotten.
func _fs_land() -> void:
	seg.resize(_fs_committed + 1)
	seg_states.resize(_fs_committed + 1)
	while _fired < seg.size() - 1:
		_fired += 1
		_fs_arrive(_fired)
	route = _full()
	van.position = board.center(route.back())
	if seg.size() >= 2:
		van.target_rotation = Vector2(seg[seg.size() - 1] - seg[seg.size() - 2]).angle()
	board.show_trail(route)
	board.wreck.set_route(route, route.size() - 1)


## Drives `tiles` (which must start at the van) as one segment. Used by debug/autotests.
func drive_tiles(tiles: Array) -> void:
	if state != State.IDLE or tiles.size() < 2 or tiles[0] != route.back():
		return
	# A solver's steps can stop to use a locker (the same tile twice): drive to there, use it, drive on;
	# segment_finished comes once, at the very end.
	var cut := 1
	while cut < tiles.size() and tiles[cut] != tiles[cut - 1]:
		cut += 1
	_auto_rest = tiles.slice(cut - 1) if cut < tiles.size() else []
	if cut < 2:
		_auto_continue()
		return
	tiles = tiles.slice(0, cut)
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
		_say("D-pad on: tap or hold the arrows to plot a route, then %s." % Cosmetics.go_word(Progress.ride, 1))
	else:
		_say("Drawing on: drag a route from the van.")


## An option changed: steering, the hand, night mode (Main re-themes), or orientation (size_changed does it).
func _on_settings() -> void:
	set_dpad_mode(Progress.drive_mode == "dpad")
	if convoy:
		convoy.visible = Progress.trail
	# All three helpers follow "Unlimited gas" (Progress.unlimited_hints): refresh every badge, not just
	# Hint's (Call and Undo used to keep what they showed before the toggle, mid-job).
	_update_hint()
	_update_radio()
	_update_undo()
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
	if _can_retract() and nxt == seg[seg.size() - 2]:
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
	Sfx.haptic(30, 1.0, "game:_dpad_drive")
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
	_clear_back()
	state = State.DRIVING
	_clear_hint()
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
	# Where something happens, the van pulls up on that tile and waits till every package has left it or
	# landed in it, so they never chase it down the road (a warehouse loads one parcel at a time).
	var stops := {}
	for i in range(1, seg.size()):
		_seg_cols.append(_tint(Sim.top_color(level, st)))
		var ev: Array = Sim.arrive(level, st, seg[i], route + seg.slice(0, i))["events"]
		var wait := _handoff_time(ev)
		if wait > 0.0 and i < seg.size() - 1:
			stops[i] = wait
	_update_undo()
	_refresh_tags()
	_legs = []
	var from := 0
	var dur := 0.0
	for i in range(1, seg.size()):
		if stops.has(i) or i == seg.size() - 1:
			var n := float(i - from)
			var drive := (n + 2.0 * minf(RAMP, n / 2.0)) / DRIVE_SPEED
			_legs.append([from, n, drive, float(stops.get(i, 0.0))])
			dur += drive + float(stops.get(i, 0.0))
			from = i
	var tw := create_tween()
	tw.tween_method(_drive_tick, 0.0, dur, dur)
	tw.tween_callback(_drive_done)


## How long the packages at a stop take to leave the van or land in it (as _show_events plays them out),
## counted from the van reaching the tile. 0 when nothing there touches the van.
func _handoff_time(events: Array) -> float:
	var cursor := 0.0
	var done := 0.0
	for ev in events:
		match ev["type"]:
			"swap":
				cursor += 0.14
			"deliver", "park":
				done = maxf(done, cursor + DROP_TIME)
				cursor += 0.08
			"pickup", "unpark":
				done = maxf(done, cursor + FLY_TIME)
				cursor += FLY_TIME + 0.02
	# (Each queued animation starts a frame or so after the one before it: a little slack per package.)
	return done + 0.03 * events.size() if done > 0.0 else 0.0


## Distance along the segment at time t: each stretch accelerates over RAMP tiles, cruises and brakes,
## then the van waits there while its packages come and go.
func _dist_at(t: float) -> float:
	for leg in _legs:
		var n: float = leg[1]
		var drive: float = leg[2]
		if t < drive:
			return float(leg[0]) + _ease_along(t, n)
		t -= drive
		if t < float(leg[3]):
			return float(leg[0]) + n
		t -= float(leg[3])
	return _drive_len


## Accelerate over RAMP tiles, cruise, brake: distance after t seconds of a stretch n tiles long.
func _ease_along(t: float, n: float) -> float:
	var ramp := minf(RAMP, n / 2.0)
	var v := DRIVE_SPEED
	var ta := 2.0 * ramp / v
	var tc := (n - 2.0 * ramp) / v
	if t < ta:
		return 0.5 * (v / ta) * t * t
	if t < ta + tc:
		return ramp + v * (t - ta)
	var r := maxf(0.0, ta * 2.0 + tc - t)
	return n - 0.5 * (v / ta) * r * r


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


## The clock the game's own timing runs on (deliveries landing, effects ending). Normally the wall clock;
## under a sped-up self-test ("-- --test-speed=N", Engine.time_scale N) a game clock that runs N times as
## fast, so the timing keeps step with the sped-up tweens and timers.
static var _test_clock := 0.0

func _now() -> float:
	if Engine.time_scale != 1.0:
		return _test_clock
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


## The van reaches tile k of the segment it's driving. True if anything happened there (a stop).
func _arrive(k: int) -> bool:
	var tile: Vector2i = seg[k]
	# How long it sat before this (thinking time), for the stats.
	if _moves == 0:
		_first_wait = _idle_t
	else:
		_longest_wait = maxf(_longest_wait, _idle_t)
	if _idle_t > 0.0:
		LevelStats.add(_attempt_key(), "seconds_thinking", _idle_t)
	_idle_t = 0.0
	_moves += 1
	var res := Sim.arrive(level, sim_state, tile, route + seg.slice(0, k))
	# The first few jobs: a house the van drives past that's owed a package, just not the one on top, says
	# so (the rule, shown where it bites), a couple of times a try.
	if level.number <= 5 and _refusals < 2 and not Progress.auto and side.is_empty() and daily_day < 0 and not og and not sim_state["stack"].is_empty():
		for h in level.adjacent_houses.get(tile, []):
			if int(sim_state["fills"][h]) < int(level.houses[h].order) and str(level.houses[h].color) != Sim.top_color(level, sim_state) \
					and not res["events"].any(func(ev): return ev["type"] == "deliver" and int(ev["house"]) == int(h)):
				_refusals += 1
				var house: House = board.house_nodes[h]
				_at(maxf(_now(), _vis_cursor), func():
					house.hop()
					stack_view.nod()
					Sfx.play("bonk", 1.4, -12.0)
					fx.say(house.base_pos + Vector2(0, -board.tile * 0.55), "Not on top yet!", Palette.pkg(str(level.houses[h].color)).darkened(0.25), int(board.tile * 0.24)))
	_show_events(res, tile)
	_last_handoff = _handoff_time(res["events"])
	if not res["nopes"].is_empty():
		for h in res["nopes"]:
			board.house_nodes[h].wobble()
		Sfx.play("bonk", randf_range(0.95, 1.05), -3)
		Sfx.haptic(12, 1.0, "game:_arrive")
		combo = 0
	_show_gates()
	if level.return_depot and board.depot:
		board.depot.calling = Sim.all_delivered(level, sim_state)

	if board.gift and not gift_taken and tile == level.gift:
		_take_gift()
		gift_len = route.size() + k
	_refresh_tags()
	if k < seg.size() - 1:
		var d_in: Vector2i = seg[k] - seg[k - 1]
		var d_out: Vector2i = seg[k + 1] - seg[k]
		if d_in != d_out:
			van.squash()
	return not res["events"].is_empty()


## What happened at a stop (Sim's events), played out on the board and in the chute, one after another.
func _show_events(res: Dictionary, tile: Vector2i) -> void:
	var gen := _ev_gen
	for ev in res["events"]:
		var t := maxf(_now(), _vis_cursor)
		match ev["type"]:
			"swap":
				_at(t, _if_current.bind(gen, _show_swap.bind(tile, stack_view.preview)))
				_vis_cursor = t + 0.14
				_effects_end = maxf(_effects_end, t + 0.3)
			"deliver":
				deliveries.append(level.houses[ev["house"]].color)
				if daily_day >= 0:
					Progress.daily_reached(daily_day, deliveries.size())
				_at(t, _if_current.bind(gen, _launch_package.bind(ev["house"], combo, stack_view.preview)))
				combo += 1
				_vis_cursor = t + 0.08
				_effects_end = maxf(_effects_end, t + DROP_TIME + FLY_TIME + 0.02)
			"pickup":
				_at(t, _if_current.bind(gen, _collect_parcel.bind(ev["shop"], stack_view.preview)))
				_vis_cursor = t + FLY_TIME + 0.02
				_effects_end = maxf(_effects_end, t + FLY_TIME + 0.04)
			"park":
				_at(t, _if_current.bind(gen, _park_package.bind(int(ev["locker"]), str(ev["color"]), stack_view.preview)))
				_vis_cursor = t + 0.08
				_effects_end = maxf(_effects_end, t + DROP_TIME + FLY_TIME + 0.02)
			"unpark":
				_at(t, _if_current.bind(gen, _unpark_package.bind(int(ev["locker"]), str(ev["color"]), stack_view.preview)))
				_vis_cursor = t + FLY_TIME + 0.02
				_effects_end = maxf(_effects_end, t + FLY_TIME + 0.04)


## Runs an event's animation unless an undo has come since it was set off (it'd play over the rewound board).
func _if_current(gen: int, cb: Callable) -> void:
	if gen == _ev_gen:
		cb.call()


## The van drives over the present: it hops into the van (it's yours if you finish).
func _take_gift() -> void:
	gift_taken = true
	var at := board.gift.position
	board.gift.taken = true
	var is_key := level.gift_item == "key"
	var lights := level.gift_item == "headlights"
	var col := Icons.GOLD if is_key or lights else Cosmetics.tint(level.gift_item)      # (the headlights' present is gold)
	fx.burst(at, col, 18, board.tile * 3.0, board.tile * 0.12)
	fx.ring(at, Palette.STAR_GOLD, board.tile * 0.7)
	fx.say(at + Vector2(0, -board.tile * 0.4), "A key!" if is_key else "Ooh, shiny!", col.darkened(0.2), int(board.tile * 0.3))
	Sfx.play("sparkle")
	Sfx.play("kaching", 1.3, -8.0)
	Sfx.haptic(20, 1.0, "game:_take_gift")
	van.nudge()


func _show_swap(tile: Vector2i, was_preview := false) -> void:
	_land_parcels()
	if not _resync_preview(was_preview):
		stack_view.swap_top()
		van.set_top(stack_view.top_color())
	if board.hub_nodes.has(tile):
		board.hub_nodes[tile].spin()
	van.squash()
	Sfx.play("swap")
	Sfx.haptic(14, 1.0, "game:_show_swap")


## A delivery: the next package drops out of the chute's mouth into the van, then flies on to the house.
func _launch_package(h: int, step: int, was_preview := false) -> void:
	var house: House = board.house_nodes[h]
	var to := house.base_pos + Vector2(0, -board.tile * 0.35)
	var mouth := board.to_local(stack_view.mouth_global())
	var ms := stack_view.mouth_size()
	var big: float = ms.y / board.scale.x
	var out := board.to_local(stack_view.mouth_global() + stack_view._side() * stack_view.ph * 1.6)
	_land_parcels()
	if not _resync_preview(was_preview):
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
		Sfx.haptic(18, 1.0, "game:_launch_package"))


## The player taps the parking locker the van's stopped beside: it keeps the top package, or gives back the
## one it's keeping (Sim.use_locker). Its own undo step. False if there's nothing to do (not stopped beside
## one, or nothing to put in or take out).
func use_locker() -> bool:
	if state != State.IDLE:
		return false
	var tile: Vector2i = route.back()
	if Sim.locker_here(level, sim_state, tile) < 0:
		return false
	_clear_hint()
	_clear_back()
	history.append({"len": route.size(), "state": Sim.copy_state(sim_state), "rot": van.target_rotation, "deliv": deliveries.size(), "locker": true})
	timing = true
	var res := Sim.use_locker(level, sim_state, tile, route.slice(0, route.size() - 1))
	# (How things stood once it was used too: headlights' Undo backs up to this stop as it was left.)
	history.back()["after"] = Sim.copy_state(sim_state)
	history.back()["after_deliv"] = deliveries.size() + res["events"].filter(func(ev): return ev["type"] == "deliver").size()
	_show_events(res, tile)
	LevelStats.add(_attempt_key(), "locker_uses")
	van.squash()
	if Sim.is_won(level, sim_state, route):
		_at(maxf(_now(), _effects_end) + 0.1, func():
			if state == State.IDLE:
				_win())
	else:
		_stranded = _cut_off()
		_update_undo()
		if not Sim.has_move(level, route, sim_state):
			# Used it, and there's no road on from here: that's stuck (once what it set off has landed).
			_at(maxf(_now(), _effects_end) + 0.15, func():
				if state == State.IDLE and not Sim.is_won(level, sim_state, route) and not Sim.has_move(level, route, sim_state) \
						and not _locker_move_left():
					_fail())
	_refresh_tags()
	_update_drive_button()
	return true


## The parking locker on tile `t`, or -1.
func _locker_at(t: Vector2i) -> int:
	for k in level.lockers.size():
		if level.lockers[k].pos == t:
			return k
	return -1


## Stopped beside a locker that hasn't been used at this stop yet: a move, even with every road gone (the
## package in it may be the one the house next door wants). Once used here, it doesn't count again (tapping
## it back is what Undo is for), so a dead end still ends.
func _locker_move_left() -> bool:
	if route.is_empty() or Sim.locker_here(level, sim_state, route.back()) < 0:
		return false
	return history.is_empty() or not (history.back().get("locker", false) and int(history.back()["len"]) == route.size())


## The van's stopped beside a parking locker it can use: the locker that is ( -1 if none).
func _locker_ready() -> int:
	if state != State.IDLE or route.is_empty():
		return -1
	return Sim.locker_here(level, sim_state, route.back())


## A tap on a locker: use it if the van's stopped beside it. True if it was used.
func _tap_locker(t: Vector2i) -> bool:
	var k := _locker_ready()
	if k < 0 or level.lockers[k].pos != t:
		return false
	return use_locker()


## A hint path that starts by using a locker (the van's tile twice): the locker's pointed out instead of a
## way to drive. True if so.
func _locker_hint(path: Array) -> bool:
	if path.size() < 2 or path[1] != path[0]:
		return false
	var k := Sim.locker_here(level, sim_state, path[0])
	if k < 0:
		return false
	var lk: House = board.locker_nodes[k]
	lk.hop()
	fx.ring(lk.base_pos + Vector2(0, -board.tile * 0.3), Palette.HINT, board.tile * 0.6)
	# A finger pressing the locker, on a loop, till it's tapped (use_locker clears the hint).
	_clear_hint()
	hint_ghost = GhostFinger.new()
	hint_ghost.radius = board.tile * 0.3
	hint_ghost.pts.append(lk.base_pos + Vector2(0, -board.tile * 0.12))
	board.add_child(hint_ghost)
	if ghost:
		ghost.visible = false
	_say("Tap the locker.")
	Sfx.play("hint")
	return true


## drive_tiles' steps after a locker stop (first: that stop, then the stop again = use it, then on).
func _auto_continue() -> void:
	var rest := _auto_rest
	_auto_rest = []
	if rest.size() >= 2 and rest[1] == rest[0]:
		use_locker()
		rest = rest.slice(1)
	if rest.size() >= 2 and state == State.IDLE:
		drive_tiles(rest)
	else:
		if state == State.IDLE and Sim.is_won(level, sim_state, route):
			await get_tree().create_timer(0.3).timeout      # (the win's on its way)
		segment_finished.emit.call_deferred()      # (a frame on: whoever called drive_tiles is waiting by then)


## A solver path cut where it first uses a locker (the same tile twice): a hint shows the drive there.
static func _to_locker(path: Array) -> Array:
	for i in range(1, path.size()):
		if path[i] == path[i - 1]:
			return path.slice(0, i)
	return path


## Into a parking locker: the top package drops out of the chute into the van and flies on to the locker,
## which shuts it in behind an open door till the van comes back past.
func _park_package(k: int, color: String, was_preview := false) -> void:
	var lk: House = board.locker_nodes[k]
	var to := lk.base_pos + Vector2(0, -board.tile * 0.3)
	var mouth := board.to_local(stack_view.mouth_global())
	_land_parcels()
	if not _resync_preview(was_preview):
		stack_view.pop_top(true)
		van.set_top(stack_view.top_color())
	var pkg := _make_flyer(color, mouth)
	Sfx.play("whoosh", randf_range(0.95, 1.1), -10)
	var tw := create_tween()
	tw.tween_method(func(t: float): _fly(t, pkg, mouth, to, board.tile * 0.6), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		pkg.queue_free()
		_sync_lockers()        # (from the state, not `color`: an undo may have come in while it flew)
		lk.pop()
		Sfx.play("thunk", 0.8, -4.0)
		Sfx.haptic(14, 1.0, "game:_park_package")
		fx.say(to + Vector2(0, -board.tile * 0.35), "Parked!", Palette.pkg(color).darkened(0.2), int(board.tile * 0.26)))


## Out of a parking locker: the package it kept hops back onto the van, on top.
func _unpark_package(k: int, color: String, was_preview := false) -> void:
	var lk: House = board.locker_nodes[k]
	var from := lk.base_pos + Vector2(0, -board.tile * 0.3)
	_sync_lockers()
	lk.pop()
	var pkg := _make_flyer(color, from)
	Sfx.play("pickup", 0.85)
	Sfx.haptic(14, 1.0, "game:_unpark_package")
	var flight := {"pkg": pkg, "color": color, "preview": was_preview}
	_landing.append(flight)
	var tw := create_tween()
	tw.tween_method(_fly_to_van.bind(pkg, from, board.tile * 0.6), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		if _landing.has(flight):
			_land_parcels(flight)
		van.nudge())


## The parking lockers show what the state says they're keeping (after an undo or a fresh start).
func _sync_lockers() -> void:
	var held: Array = sim_state.get("held", [])
	for k in board.locker_nodes.size():
		(board.locker_nodes[k] as House).held = str(held[k]) if k < held.size() else ""


## Parcel hops from the shop onto the (moving) van, then lands on top of the stack.
func _collect_parcel(k: int, was_preview := false) -> void:
	var shop: Shop = board.shop_nodes[k]
	var color: String = level.shops[k].color
	var from := shop.parcel_pos()
	shop.collect()
	var pkg := _make_flyer(color, from)
	Sfx.play("pickup")
	Sfx.haptic(14, 1.0, "game:_collect_parcel")
	var flight := {"pkg": pkg, "color": color, "preview": was_preview}
	_landing.append(flight)
	var tw := create_tween()
	tw.tween_method(_fly_to_van.bind(pkg, from, board.tile * 0.6), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		if _landing.has(flight):
			_land_parcels(flight)          # (a delivery may have landed it already)
		van.nudge())


## Parcels still flying in from shops land in the chute, in the order they were picked up, up to and
## including `upto` (all of them when it's empty). A delivery or a spinner lands them first: on a frame that
## stalls, a delivery's turn can come round before an earlier pickup has landed, and it took the wrong parcel.
func _land_parcels(upto: Dictionary = {}) -> void:
	while not _landing.is_empty():
		var f: Dictionary = _landing.pop_front()
		if is_instance_valid(f["pkg"]):
			(f["pkg"] as Node).queue_free()
		if not _resync_preview(bool(f["preview"])):
			stack_view.push(str(f["color"]))
			van.set_top(stack_view.top_color())
		if f == upto:
			break


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
	Sfx.haptic(35, 1.0, "game:_brake")
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
	# (Whatever's still in flight has landed by now; and if the chute and the load ever disagree, the load wins.)
	_land_parcels()
	if stack_view.colors != sim_state["stack"] and not _plan_showing():
		stack_view.show_stack(sim_state["stack"])
		van.set_top(Sim.top_color(level, sim_state))
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
	elif not Sim.has_move(level, route, sim_state) and not _locker_move_left():
		_count_segment(true)
		_fail()
	else:
		_count_segment(false)
		state = State.IDLE
		_stranded = _cut_off()
		van.inviting = true
		if level.return_depot and Sim.all_delivered(level, sim_state):
			_say("All delivered! Drive back to the depot.")
		_update_undo()
	_refresh_tags()
	if not level.lockers.is_empty():
		_at(maxf(_now(), _effects_end) + 0.05, _sync_lockers)     # (stopped: the lockers show the truth)
	_update_drive_button()
	if not _auto_rest.is_empty() and state == State.IDLE:
		_auto_continue.call_deferred()
		return
	_auto_rest = []
	segment_finished.emit()


# ---------------------------------------------------------------- undo

## Tanks spent on this level (this session) for `kind` ("undo" or "hint").
func _bought(kind: String) -> int:
	return int(gas_bought.get(_attempt_key(), {}).get(kind, 0))


func _buy(kind: String) -> void:
	var d: Dictionary = gas_bought.get(_attempt_key(), {})
	d[kind] = int(d.get(kind, 0)) + 1
	gas_bought[_attempt_key()] = d
	_update_undo()


## A can's been spent on Undo on this daily (this session): its undos are unlimited. (Only a daily counts
## undos at all: _undo_free_here.)
func _tanked() -> bool:
	return _bought("undo") >= 1 and daily_day < 0      # (gas never buys undos on a daily any more)


## Undos are unlimited here: the option, the power-up, or a tank spent on this level.
func _undos_unlimited() -> bool:
	return _undo_free_here() or _rush_on("undos") or Progress.unlimited_hints or _tanked()


## Undos to hand: this try's free ones, then (with a tank to spend) as many as you like.
func undos_available() -> int:
	if _undos_unlimited():
		return 99
	if daily_day >= 0:
		return undo_left            # (the daily: this try's undos, and that's all. No gas for more.)
	if Progress.total_gas() > 0 or _rush_ready("undos"):
		return 99
	return undo_left


func can_undo() -> bool:
	if undos_available() <= 0 or history.is_empty() or not (state == State.IDLE or state == State.FAILED):
		return false
	# Headlights: there has to be a stop (or the start) behind the van to go back to.
	return not Progress.lights_on() or int(history[0]["len"]) < route.size()


func _on_undo_pressed() -> void:
	if _gate_tank("undo"):
		return
	if _busy_modal():
		return
	if _strict_side():
		Sfx.play("bonk", 1.1, -6.0)
		_say("No undos on detours!")
		return
	if dpad_mode and state == State.DRAWING:
		# A route is plotted but not driven yet: Undo just clears it.
		Sfx.play("untick", 0.9, -4)
		_cancel_plan()
		return
	if daily_day >= 0 and not _undos_unlimited() and undo_left <= 0:
		# The daily: a try's undos are all there is (gas doesn't buy more). Retry starts a fresh try.
		Sfx.play("bonk", 1.1, -6.0)
		undo_button.wiggle()
		if Daily.tries_left(Progress.daily_record(daily_day)) > 0:
			retry_button.wiggle()
			_say("No undos left on this try.\nRetry for a fresh start.", Palette.ACCENT.darkened(0.12))
		else:
			_say("No undos left, and that was today's last try.", Palette.ACCENT.darkened(0.12))
		return
	if not _undos_unlimited() and undo_left <= 0 and not history.is_empty() \
			and (state == State.IDLE or state == State.FAILED) and _explain_gas("undo", _on_undo_pressed):
		return
	if undos_available() <= 0:
		Sfx.play("click")
		_gas_ad(false, func():
			if can_undo():
				undo())
	elif can_undo():
		Sfx.play("click")
		undo()
	else:
		Sfx.play("untick", 0.8, -6)


## Out of gas, and an undo or a hint wanted: a (pretend) ad plays, pays AD_TANKS bonus tanks however it
## ends, and then `then` does what was asked. Which ad: AdPicker (any of them, not one seen lately).
func _gas_ad(hint: bool, then: Callable, kind := "") -> void:
	var ad := AdPicker.make()
	modal = ad
	_overlay(ad)
	ad.finished.connect(func():
		modal = null
		Progress.ad_watched()
		Progress.refuel()
		Progress.hint_ad_watched = true
		Sfx.play("kaching", 1.0, -4)
		Sfx.haptic(20, 1.0, "game:_gas_ad")
		gas_chip.bump()
		_say("Tank filled up!", GasChip.FUEL.darkened(0.2))
		_update_undo()
		_paid_call(kind if kind != "" else ("hint" if hint else "undo"), then))


## The first time a hint or an undo would cost gas: the explainer (GasExplainer), and `then` again if they
## go ahead. True if it's showing (the caller stops there).
## Which "seen it" key the gas explainer goes by: a hint's price has a card of its own.
func _gas_key(what: String) -> String:
	return Progress.GAS_HINT_SEEN if what == "hint" else Progress.GAS_SEEN


func _explain_gas(what: String, then: Callable) -> bool:
	if Progress.seen_new.has(_gas_key(what)) or (Progress.auto and not OS.get_cmdline_user_args().has("--gas-explain")):
		return false
	var ex := GasExplainer.new()
	ex.what = what
	ex.undos_only = _no_hints()
	ex.gauge = gas_chip.can_pos()
	ex.gauge_box = gas_chip.get_global_rect()
	ex.button = (radio_button if what == "radio" else (hint_button if what == "hint" else undo_button)).get_global_rect()
	ex.with_radio = radio_button != null
	modal = ex
	ex.chosen.connect(func(go: bool):
		if modal == ex:
			modal = null
		if go:
			_paid_call(what, then))
	_ui_root.add_child(ex)
	return true


## Would pressing Hint (or Undo) now spend a tank? (Past the level's free ones, with gas to spend and the
## explainer already seen; a hint already showing, a dead end and the like are free.)
func _tank_due(kind: String) -> bool:
	if _busy_modal() or _strict_side() or Progress.total_gas() <= 0 or not Progress.seen_new.has(_gas_key(kind)):
		return false
	if _rush_due(kind):
		return false               # (a rush in hand goes before a tank does)
	if kind == "undo":
		return daily_day < 0 and not (dpad_mode and state == State.DRAWING) and not _undos_unlimited() and undo_left <= 0 and can_undo()
	if kind == "radio":
		return radio_button != null and not _radio_unlimited() and radio_left() <= 0 and _radio_can_call() and not _radio_plain()
	if _no_hints():
		return false
	# (At a dead end too: a held Hint there spends its tank like anywhere else, and buys the same.)
	return not _hints_free() and hints_left <= 0 and hint_run.is_empty() \
			and (state == State.IDLE or state == State.FAILED or (dpad_mode and state == State.DRAWING))


## Hint or Undo pressed down: when it'll cost a tank, the fuel line starts filling (GasLine). Full, and the
## help goes ahead there and then.
func _hold_down(kind: String) -> void:
	if kind == "undo":
		_undo_hold = UNDO_HOLD_FIRST
		_undo_gap = UNDO_HOLD_GAP
		_undo_streak = 0
	if _rush_due(kind):
		# A rush in hand, and out of free ones: this hold starts it (the line runs round the button).
		_rush_hold = kind
		_rush_hold_t = 0.0
		return
	if Progress.auto or not _tank_due(kind):
		return
	if is_instance_valid(_gas_line):
		_gas_line.queue_free()
	var line := GasLine.new()
	line.from = gas_chip.can_pos()
	# (The fuel runs to the button the can's for.)
	line.buttons = [hint_button] if kind == "hint" else ([radio_button] if kind == "radio" else [undo_button])
	line.filled.connect(func():
		_gas_held = kind
		_paid_call(kind, _on_radio_pressed if kind == "radio" else (_on_hint_pressed if kind == "hint" else _on_undo_pressed)))
	_gas_line = line
	_ui_root.add_child(line)


## Let go: a line not full yet runs back (nothing spent).
func _hold_up() -> void:
	_undo_hold = -1.0
	_undo_streak = 0
	_rush_hold = ""
	if is_instance_valid(_gas_line) and not _gas_line.is_full():
		_gas_line.let_go()
	(func(): _gas_held = "").call_deferred()


## Undo, held: once the hold's long enough it undoes, then again and again while it's held, the waits
## shrinking (and the rewinds speeding up), so a long way back is one hold. Only undos that cost nothing
## (free ones left, or unlimited): a tank is never spent this way (that's the fuel line's hold, which comes
## first), and the release at the end isn't one more undo.
func _undo_hold_tick(delta: float) -> void:
	if _undo_hold < 0.0 or Progress.auto or _busy_modal() or _strict_side():
		return
	if is_instance_valid(_gas_line) and not _gas_line.is_full():
		return
	if not (state == State.IDLE or state == State.FAILED) or not can_undo() or not (_undos_unlimited() or undo_left > 0):
		return
	_undo_hold -= delta
	if _undo_hold > 0.0:
		return
	_undo_hold = _undo_gap
	_undo_gap = maxf(UNDO_HOLD_MIN, _undo_gap * 0.7)
	_undo_streak += 1
	_gas_held = "undo"
	undo()


# ---------------------------------------------------------------- job 5: a nudge toward Call

## Job 5 ("Shortcut") is built round one tempting wrong turn that only dies a couple of deliveries later.
## Once, if the player's really in it (the job can't be finished from here, though nothing says so yet) and
## stops to think, a tip by the Call button suggests asking Dispatch. Nothing is forced: the answer, and its
## first-time tip (Undo or Retry), take it from there (_say_call).
const CALL_NUDGE_JOB := 5
var _cn_n := -1
var _cn_dead := false
var _cn_t := 0.0

func _call_nudge_tick(delta: float) -> void:
	if level.number != CALL_NUDGE_JOB or not side.is_empty() or daily_day >= 0 or og or radio_button == null:
		return
	if Progress.seen_new.has("call_nudge") or (Progress.auto and not OS.get_cmdline_user_args().has("--call-nudge")):
		return
	if state != State.IDLE or route.size() < 3 or _busy_modal() or (_tip != null and is_instance_valid(_tip)) or is_instance_valid(_call_box):
		_cn_t = 0.0
		return
	if route.size() != _cn_n:
		_cn_n = route.size()
		_cn_t = 0.0
		_cn_dead = Solver.can_finish(level, route, sim_state) == 0
	if not _cn_dead:
		return
	_cn_t += delta
	if _cn_t < 1.2:
		return
	Progress.seen_new["call_nudge"] = true
	Progress.set_option("seen_new", Progress.seen_new)
	radio_button.wiggle()
	var tip := TipBubble.new()
	tip.text = "Not sure this still works?\nCall Dispatch to check."
	tip.target = radio_button.get_global_rect().get_center() + Vector2(0, -50)
	tip.above = true
	tip.life = 12.0
	_tip = tip
	_ui_root.add_child(tip)


# ---------------------------------------------------------------- Dispatch on job 6

## The first boss job, on the tutorial's unlimited help: once the Baron's said his piece, Dispatch comes on
## the radio to say this one's tricky, and what the two helpers are for (DispatchBox, Hint and Call ringed in
## their colours). Once, and only while help's still unlimited.
const DISPATCH_JOB := 6

func _dispatch_tick() -> void:
	if level.number != DISPATCH_JOB or not side.is_empty() or daily_day >= 0 or og or Progress.limits_on() or radio_button == null:
		return
	if Progress.seen_new.has("dispatch_help") or is_instance_valid(_dispatch_intro):
		return
	if Progress.auto and not OS.get_cmdline_user_args().has("--dispatch"):
		return
	if _busy_modal() or state != State.IDLE or route.size() > 1 or _alive < 1.2 or (_tip != null and is_instance_valid(_tip)) or not _tips.is_empty():
		return
	Progress.seen_new["dispatch_help"] = true
	Progress.set_option("seen_new", Progress.seen_new)
	var b := DispatchBox.new()
	b.modal = true
	b.width = 940.0
	b.text = "This one's a tricky one. But don't worry: you've got unlimited [color=#5ab8ff][b]CALLS[/b][/color] to check you're still on the right track, and unlimited [color=#ffc93c][b]HINTS[/b][/color] to show you your next move."
	b.glow = [[radio_button, DispatchBox.CALL_BLUE], [hint_button, HINT_GOLD]]
	b.target = Rect2()
	b.foot = "tap to go on"
	_dispatch_intro = b
	modal = b
	b.gone.connect(func():
		if modal == b:
			modal = null
		_dispatch_intro = null)
	_ui_root.add_child(b)
	radio_button.wiggle()
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_instance_valid(hint_button):
			hint_button.wiggle())


# ---------------------------------------------------------------- a kind word on a hard detour

## Detours a new player meets early and can bounce off (Small Tank: no hints, no undos, one way through).
## Stuck there (a while on it, a dead end, or reaching for a hint), they're reminded, kindly, once a visit,
## that detours are optional and wait on the map: back to the jobs, or "No no, I've got this!".
const DETOUR_NUDGE := ["small_tank"]
const DETOUR_NUDGE_SECS := 75.0
var _detour_nudged := false

func _detour_nudge_due() -> bool:
	return DETOUR_NUDGE.has(str(side.get("id", ""))) and not _detour_nudged and not _busy_modal() \
			and not Progress.side_done.has(str(side.get("id", ""))) and (not Progress.auto or OS.get_cmdline_user_args().has("--detour-nudge"))


func _detour_tick() -> void:
	if side.is_empty() or not (state == State.IDLE or state == State.FAILED) or not _detour_nudge_due():
		return
	var secs := LevelStats.value(_attempt_key(), "seconds_active") + play_time
	if state == State.FAILED or secs >= DETOUR_NUDGE_SECS or OS.get_cmdline_user_args().has("--detour-nudge"):
		_detour_nudge()


func _detour_nudge() -> void:
	_detour_nudged = true
	var card := GuideCard.new()
	card.icon = "next"
	card.title = "This one's a detour. It's optional!"
	card.body = "Detours are extra challenges, and they'll wait for you on the map. You can always come back later."
	card.yes_text = "Back to the jobs"
	card.no_text = "No no, I've got this!"
	modal = card
	_overlay(card)
	card.answered.connect(func(yes: bool):
		if modal == card:
			modal = null
		LevelStats.add(_attempt_key(), "detour_back" if yes else "detour_stay")
		if yes:
			_leave())


# ---------------------------------------------------------------- the guide (a free start on a hard job)

func _guide_tick() -> void:
	if not GUIDE_JOBS.has(level.number) or not side.is_empty() or daily_day >= 0 or og or Progress.auto:
		return
	if guide_offered.has(_attempt_key()) or _busy_modal() or not (state == State.IDLE or state == State.FAILED) or not hint_run.is_empty():
		return
	if Progress.is_complete(level.number) and not Progress.is_stale(level.number, level.fp):
		return
	var restarts := LevelStats.value(_attempt_key(), "restarts")
	var secs := LevelStats.value(_attempt_key(), "seconds_active") + play_time
	var fails := restarts + (1.0 if state == State.FAILED else 0.0)
	if secs < GUIDE_AFTER_SECS and fails < GUIDE_AFTER_FAILS and not OS.get_cmdline_user_args().has("--guide"):
		return
	guide_offered[_attempt_key()] = true
	var card := GuideCard.new()
	modal = card
	_overlay(card)
	card.answered.connect(func(yes: bool):
		if modal == card:
			modal = null
		LevelStats.add(_attempt_key(), "guide_yes" if yes else "guide_no")
		if not yes:
			return
		if route.size() <= 1 and state == State.IDLE:
			_guide_show()
		else:
			# (From the start: the half it shows begins at the depot.)
			Game.guide_hint = level.number
			_retry())


## The guide's free start: the first half of the way that works, from the depot, shown like a hint (nothing
## spent).
func _guide_show() -> void:
	await get_tree().create_timer(0.4).timeout
	while is_inside_tree() and _busy_modal():
		await get_tree().process_frame
	if not is_inside_tree() or state != State.IDLE:
		return
	var path := _to_locker(Solver.solve_from(level, route, sim_state))
	if path.size() < 3:
		return
	_show_hint_run(path.slice(0, maxi(2, int(ceil(path.size() / 2.0)))))
	_say("Here's the first half. The rest is up to you.", Palette.GOOD.darkened(0.2))


# ---------------------------------------------------------------- the Baron meters the helpers

## The first boss job (Progress.LIMITS_FROM), or any main-road job after it, with the helpers still unlimited:
## the Baron meters them (LimitsScene), once, after his entrance and anything else that opens the job.
func _limits_tick(delta: float) -> void:
	if Progress.limits_on() or is_instance_valid(_limits_scene) or daily_day >= 0 or not side.is_empty() or og \
			or level.number < Progress.LIMITS_FROM or (Progress.auto and not OS.get_cmdline_user_args().has("--limits-scene")):
		return
	var waiting := _busy_modal() or state != State.IDLE or (_tip != null and is_instance_valid(_tip)) or not _tips.is_empty() \
			or is_instance_valid(_undo_lesson) or Spotlight.new_kind(level, daily_day >= 0) != "" \
			or (Progress.lights_on() and Progress.sight() > 0 and not Progress.seen_new.has("headlights"))
	_limits_calm = 0.0 if waiting else _limits_calm + delta
	if _limits_calm < 0.6 or _alive < 1.0:
		return
	Progress.start_limits()
	_metered = {}
	var sc := LimitsScene.new()
	sc.game = self
	_limits_scene = sc
	modal = sc
	sc.stamped.connect(func(kind: String):
		_metered[kind] = true
		_layout()
		_update_undo()
		if kind == "pump":
			gas_chip.reveal())
	# (One Baron at a time: the one who watches a boss job from the corner steps out while this one's on.)
	for c in _ui_root.get_children():
		if c is BossWatch:
			(c as BossWatch).visible = false
	sc.finished.connect(func():
		for c in _ui_root.get_children():
			if c is BossWatch:
				(c as BossWatch).visible = true
		if modal == sc:
			modal = null
		_limits_scene = null
		_metered = {}
		_layout()
		_update_undo())
	_ui_root.add_child(sc)
	_layout()
	_update_undo()


# ---------------------------------------------------------------- the Radio

## The Radio: call Dispatch, and they say whether the job can still be finished from where the van is. Not
## how, and not where it went wrong: just yes or no (Solver.can_finish). Calls are carried from job to job
## (Progress.radio): one comes with every job delivered, more from chests and bosses, and a can of gas buys
## Progress.RADIO_PER_CAN. What anyone can see (no move left, a stop cut off for good) is never charged for,
## and nor is a call Dispatch can't answer. Not on dailies (no help there) or the detours that allow no undos.
func _radio_here() -> bool:
	return Progress.has_radio() and not _no_hints() and not _strict_side() and not og


func radio_left() -> int:
	return Progress.radio


func _radio_unlimited() -> bool:
	return Progress.unlimited_hints or _helpers_free()


## There's something to ask about: the van's been somewhere this try, and it's waiting for a move.
func _radio_can_call() -> bool:
	return (state == State.IDLE or state == State.FAILED) and route.size() >= 2


## The dead end's plain to see: asking about it costs nothing.
func _radio_plain() -> bool:
	return state == State.FAILED or _stranded


func _on_radio_pressed() -> void:
	if _gate_tank("radio"):
		return
	if _busy_modal() or radio_button == null:
		return
	if not _radio_can_call():
		Sfx.play("untick", 0.8, -6)
		if route.size() < 2 and state == State.IDLE:
			radio_button.pop()
			_call_box_up("[b]You haven't moved yet![/b] Every job can be done from the start.", true, false)
		return
	var paying := not _radio_plain() and not _radio_unlimited() and radio_left() <= 0
	if paying and _explain_gas("radio", _on_radio_pressed):
		return
	if paying and Progress.total_gas() <= 0:
		_gas_ad(false, _on_radio_pressed, "radio")
		return
	if paying:
		# A can of gas buys RADIO_PER_CAN calls: they land in the count; the next tap makes the call.
		_buy_with_can("radio")
		return
	var answer := 0 if _radio_plain() else Solver.can_finish(level, route, sim_state)
	Sfx.play("click", 1.6, -4.0)
	radio_button.pop()
	if answer < 0:
		# (Too big a question to settle in time: nothing's spent on it.)
		_call_box_up("[b]Can't tell from here.[/b] Drive on a little and call again.", true, false)
		return
	LevelStats.add(_attempt_key(), "radio")
	if not _radio_plain() and not _radio_unlimited():
		Progress.add_radio(-1)
	_say_call(answer == 1)
	_update_undo()


## What Dispatch said, said so it's seen: over the Call button, the call going through and then the answer
## (DispatchBox), and, till the van next moves, a bubble over the van that says it again (VanVerdict). The
## first call ever: once the answer's put away, a tip says what that bubble means, by the van if the road's
## clear, by Undo and Retry if it's a dead end.
func _say_call(ok: bool) -> void:
	if ok:
		Sfx.haptic(10, 1.0, "game:_say_call")
		fx.ring(van.position, Palette.GOOD, board.tile * 0.7)
	else:
		Sfx.haptic(25, 1.0, "game:_say_call")
		fx.ring(van.position, Palette.ACCENT, board.tile * 0.7)
		if can_undo():
			undo_button.wiggle()
	var first := not Progress.seen_new.has("call_tip") and not Progress.auto
	var box := _call_box_up("[color=#4fe08a][b]Still on track![/b][/color] Keep going from here." if ok
		else "[color=#ff5a4e][b]No good![/b][/color] You've gotta turn back.", ok, true)
	if box == null:
		_show_verdict(ok)
		return
	# Once the answer's put away (and only if the van hasn't moved since), it stays said over the van; the
	# first time, with a tip that spells it out.
	var n := route.size()
	box.gone.connect(func():
		if not is_inside_tree() or route.size() != n or not (state == State.IDLE or state == State.FAILED):
			return
		_show_verdict(ok)
		if not first or Progress.seen_new.has("call_tip"):
			return
		Progress.seen_new["call_tip"] = true
		Progress.set_option("seen_new", Progress.seen_new)
		var tip := TipBubble.new()
		tip.life = 30.0
		if ok:
			tip.text = "Green: the road ahead is clear.\nYou can still finish from here.\nKeep going!"
			tip.target = van.get_global_transform_with_canvas().origin + Vector2(0, -board.tile * board.scale.y * 0.45)
			tip.above = true
		else:
			tip.text = "Red: a dead end.\nThere's no way to finish from here.\nUndo back a few moves, or Retry."
			tip.target = undo_button.get_global_rect().get_center().lerp(retry_button.get_global_rect().get_center(), 0.5) + Vector2(0, -60)
			tip.above = true
		_ui_root.add_child(tip))


## Dispatch's answer over the Call button. `calling`: it rings through first.
func _call_box_up(text: String, ok: bool, calling: bool) -> DispatchBox:
	if Progress.auto and not OS.get_cmdline_user_args().has("--call-box"):
		return null
	if is_instance_valid(_call_box):
		_call_box.queue_free()
	var b := DispatchBox.new()
	b.text = text
	b.good = ok
	b.calling = calling
	b.life = 3.2
	b.width = 680.0
	b.target = (radio_button if radio_button else hint_button).get_global_rect()
	_call_box = b
	_ui_root.add_child(b)
	return b


## The answer, kept over the van (VanVerdict) on a side of it with no road still to drive.
func _show_verdict(ok: bool) -> void:
	_close_verdict()
	if Progress.auto and not OS.get_cmdline_user_args().has("--call-box"):
		return
	var at: Vector2i = route.back()
	var best := Vector2i(0, -1)
	var best_score := -99
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var p: Vector2i = at + d
		var score := 3 if d == Vector2i(0, -1) else (2 if d.y == 0 else 1)
		if level.in_bounds(p) and level.is_road(p) and not route.has(p):
			score -= 10          # (road still to drive: keep it clear)
		elif not level.in_bounds(p):
			score -= 1
		if score > best_score:
			best_score = score
			best = d
	var v := VanVerdict.new()
	v.good = ok
	v.dir = best
	_verdict = v
	_verdict_n = route.size()
	_verdict_place()
	v.closed.connect(func():
		_verdict = null)
	_ui_root.add_child(v)


func _verdict_place() -> void:
	if not is_instance_valid(_verdict):
		return
	_verdict.at = van.get_global_transform_with_canvas().origin
	_verdict.tile = board.tile * board.scale.x


func _close_verdict() -> void:
	if is_instance_valid(_verdict):
		_verdict.queue_free()
	_verdict = null


## The van's bubble goes once it moves (or an undo, or a retry: the route's not what it was when it was said).
func _verdict_tick() -> void:
	if not is_instance_valid(_verdict):
		return
	if route.size() != _verdict_n or state == State.DRAWING or state == State.WON:
		_close_verdict()
		if is_instance_valid(_call_box):
			_call_box.close()
		return
	_verdict_place()


## A can of gas poured into Hint or the Radio (a full hold on the button, the gas card's go-ahead, an ad): one
## more hint, or RADIO_PER_CAN more calls. The button fills with fuel, it sinks away with a puff of steam, and
## the new count shows (CanFill); until then its badge stays as it was.
func _buy_with_can(kind: String) -> void:
	var b: JuicyButton = hint_button if kind == "hint" else radio_button
	_burn_tank(b)
	_buy(kind)
	if kind == "hint":
		Progress.add_hints(1)
	else:
		Progress.add_radio(Progress.RADIO_PER_CAN)
	LevelStats.add(_attempt_key(), "cans_" + kind)
	if Progress.auto:
		_update_undo()
		return
	_pouring[kind] = true
	var fill := CanFill.new()
	b.add_child(fill)
	fill.done.connect(func():
		_pouring.erase(kind)
		_update_undo()
		b.pop()
		Sfx.play("sparkle", 1.2, -6.0)
		Sfx.haptic(14, 1.0, "game:_buy_with_can")
		_say("+1 hint!" if kind == "hint" else "+%d calls!" % Progress.RADIO_PER_CAN, Palette.GOOD.darkened(0.2)))


## The Radio's button: the calls carried, in a square (they travel from job to job); unlimited in the
## tutorial; out of them, what a can of gas buys.
func _update_radio() -> void:
	if radio_button == null:
		return
	radio_button.dim = not _radio_can_call()
	radio_button.turbo = false
	_helper_badge(radio_button, "radio", _radio_unlimited() or _still_free("radio"), Progress.radio, "= %d" % Progress.RADIO_PER_CAN)


## A carried helper's badge (Hint, the Radio): a green "∞" while it's unlimited; the count carried, in a dark
## SQUARE (things you carry from job to job are square; what comes back by itself is round); out of them, what
## a can of gas buys ("[can] = 1"), or with no gas, the ad that fills the tank.
func _helper_badge(b: JuicyButton, kind: String, free: bool, count: int, buys: String) -> void:
	if _pouring.has(kind):
		return                      # (a can's being poured in: the new count shows when it's settled)
	b.badge_icon = ""
	b.badge_square = false
	b.badge_px = 28
	if free:
		b.badge_color = Palette.GOOD
		b.badge = "∞" if UiTheme.font().has_char(0x221E) else "ALL"
	elif count > 0:
		b.badge_square = true
		b.badge_color = Color("2b2233")
		b.badge = str(count)
	elif Progress.total_gas() > 0:
		b.badge_icon = "gas"
		b.badge_color = GasChip.FUEL
		b.badge = buys
	else:
		b.badge_icon = "ad"
		b.badge_color = AD_PINK
		b.badge = "+%d gas" % Progress.AD_TANKS
	b.queue_redraw()


# ---------------------------------------------------------------- rushes

## Rushes (Progress.rush_*: a detour's power-up, free undos or free hints against a clock) work on the main
## road's jobs and the detours that allow undos; never on a daily, a speedrun or the OG 100.
func _rush_here() -> bool:
	return daily_day < 0 and not og and not _speedrun() and not _strict_side()


## One's running here.
func _rush_on(what: String) -> bool:
	return _rush_here() and Progress.rush_left(what) > 0.0


## One's in hand here, not started.
func _rush_ready(what: String) -> bool:
	return _rush_here() and Progress.rush_ready(what)


## Would holding Undo / Hint (`button`) now start the rush in hand? Out of this job's free ones, and with
## something for it to do.
func _rush_due(button: String) -> bool:
	if _busy_modal() or button == "radio":
		return false
	if button == "undo":
		return _rush_ready("undos") and not (dpad_mode and state == State.DRAWING) and not _undos_unlimited() and undo_left <= 0 and can_undo()
	return not _no_hints() and _rush_ready("hints") and not _hints_free() and hints_left <= 0 and hint_run.is_empty() \
			and (state == State.IDLE or state == State.FAILED or (dpad_mode and state == State.DRAWING))


func _rush_badge_col(what: String) -> Color:
	return RushRing.HOT if Progress.rush_left(what) <= RushRing.LAST else RushRing.INK


## The rush in hand starts: the clock, the splash across the screen, the ring off its button.
func _begin_rush(what: String) -> void:
	var secs := Progress.rush_start(what)
	if secs <= 0.0:
		return
	Sfx.play("whoomp", 1.1, -4.0)
	Sfx.play("sparkle", 1.0, -2.0)
	Sfx.haptic(35, 1.0, "game:_begin_rush")
	var splash := RushSplash.new()
	splash.kind = what
	splash.secs = secs
	_ui_root.add_child(splash)
	_rush_rings[what].burst()
	_update_undo()


## ...from a hold on its button, which then does what it's for (an undo, a hint), free.
func _start_rush(button: String) -> void:
	_gas_held = button             # (the release that follows isn't one more press)
	_begin_rush("undos" if button == "undo" else "hints")
	_paid_call(button, _on_undo_pressed if button == "undo" else _on_hint_pressed)


## Each frame: the hold that starts one; what the rings on the buttons show; and a running rush's clock,
## which only runs while the job's being played (not on a card, not once it's won).
func _rush_tick(delta: float) -> void:
	if _rush_hold != "":
		if not _rush_due(_rush_hold):
			_rush_hold = ""
		else:
			_rush_hold_t += delta
			if _rush_hold_t >= RUSH_HOLD:
				var b := _rush_hold
				_rush_hold = ""
				_start_rush(b)
	var here := _rush_here()
	for what in _rush_rings:
		var ring: RushRing = _rush_rings[what]
		ring.armed = here and Progress.rush_ready(what) and not (what == "hints" and _no_hints())
		ring.charge = _rush_hold_t / RUSH_HOLD if _rush_hold == ("undo" if what == "undos" else "hint") else 0.0
		ring.left = Progress.rush_left(what) if here else 0.0
		ring.full = float(Progress.rush_full.get(what, 1.0))
	if not here or Progress.rush_secs.is_empty() or state == State.WON or _busy_modal() or _alive < 1.0:
		return
	var was := {}
	for what in Progress.rush_secs:
		was[what] = int(ceil(Progress.rush_left(what)))
	var over: Array = Progress.rush_tick(delta)
	var ticked := not over.is_empty()
	for what in Progress.rush_secs:
		var now := int(ceil(Progress.rush_left(what)))
		if now != int(was[what]):
			ticked = true
			if now <= int(RushRing.LAST):
				Sfx.play("tick", 1.5, -4.0)
				Sfx.haptic(8, 1.0, "game:_rush_tick")
	for what in over:
		Sfx.play("untick", 0.7, 0.0)
		_say("%s over!" % Progress.RUSH_NAME[what], RushRing.HOT.darkened(0.2))
	if ticked:
		_update_undo()
	_rush_keep_t += delta
	if _rush_keep_t >= 5.0:
		_rush_keep_t = 0.0
		Progress.rush_keep()


func _exit_tree() -> void:
	Progress.rush_keep()


## A dead end anyone can see: a stop still owed a package with no road left to it (every road tile beside
## it is torn up, or can't be got to from here over what isn't). Gates, one-ways and bridges get the
## benefit of the doubt, so this never cries wolf; it just misses the subtle ones (the solver knows those).
func _cut_off() -> bool:
	if route.size() < 2 or not level.no_revisit:
		return false
	var driven := {}
	for p in route:
		driven[p] = true
	var here: Vector2i = route.back()
	var seen := {here: true}
	var todo: Array = [here]
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		for d in LevelData.DIRS:
			var q: Vector2i = p + d
			if seen.has(q) or not level.is_road(q):
				continue
			if driven.has(q) and not level.bridges.has(q) and not (level.return_depot and q == level.start):
				continue
			seen[q] = true
			todo.append(q)
	for h in level.houses.size():
		if int(sim_state["fills"][h]) >= int(level.houses[h].order):
			continue
		var reach := false
		for r in level.house_roads[h]:
			if seen.has(r) and r != here:
				reach = true
				break
		if not reach:
			return true
	return false


## Job 2's lesson: the line of packages, and that only the one marked NEXT can be delivered. Three taps,
## each with everything dimmed but the thing it's about (FocusDim): the whole line; the NEXT window; and
## the house that colour goes to. Once (Progress.seen_new "line_lesson"; `--line-lesson` shows it anyway).
func _line_lesson() -> void:
	var forced := OS.get_cmdline_user_args().has("--line-lesson")
	if level.number != 2 or not side.is_empty() or daily_day >= 0 or og:
		return
	if not forced and (Progress.auto or Progress.seen_new.has("line_lesson")):
		return
	await get_tree().create_timer(0.9).timeout
	while is_inside_tree() and _busy_modal():
		await get_tree().process_frame
	if not is_inside_tree() or state != State.IDLE or route.size() > 1 or sim_state["stack"].is_empty():
		return
	Progress.seen_new["line_lesson"] = true
	Progress.set_option("seen_new", Progress.seen_new)
	# Hands off the van while it's being explained (the bubbles still see the taps that move them on).
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.size = get_viewport_rect().size
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(catcher)
	modal = catcher
	var xf := stack_view.get_global_transform_with_canvas()
	var m: Vector2 = stack_view._item_size() * stack_view._ns()
	var mouth: Rect2 = xf * Rect2(-m / 2.0, m).grow(stack_view.ph * 0.2)
	# The whole line: from its NEXT window back along the tube (to the screen's edge, or the board's foot).
	var vp := get_viewport_rect().size
	var whole := Rect2(12.0, mouth.position.y, mouth.end.x - 12.0, mouth.size.y)
	if stack_view.vertical:
		var foot: float = (board.get_global_transform_with_canvas() * board.size_px()).y
		whole = Rect2(mouth.position.x, mouth.position.y, mouth.size.x, maxf(foot - mouth.position.y, mouth.size.y))
	var under := not stack_view.vertical and mouth.get_center().y < vp.y * 0.5
	var top := Sim.top_color(level, sim_state)
	var steps := [[whole, "These are your packages, waiting in line."],
		[mouth, "Only the one marked NEXT can be delivered.\nThen the line moves up."]]
	for h in level.houses.size():
		if str(level.houses[h].color) == top:
			var hc: Vector2 = board.get_global_transform_with_canvas() * board.house_nodes[h].base_pos
			var half := board.tile * board.get_global_transform_with_canvas().get_scale().x * 0.55
			steps.append([Rect2(hc - Vector2(half, half), Vector2(half, half) * 2.0),
				"%s is NEXT. So the %s house comes first." % [_color_word(top).capitalize(), _color_word(top)]])
			break
	for st in steps:
		var dim := FocusDim.new()
		dim.hole = st[0]
		dim.strength = 0.55
		_ui_root.add_child(dim)
		var tip := TipBubble.new()
		tip.text = st[1]
		tip.target = (st[0] as Rect2).get_center()
		tip.below = under and st != steps.back()
		tip.life = 90.0
		_ui_root.add_child(tip)
		await tip.gone
		if not is_inside_tree():
			return
		dim.fade_out()
	catcher.queue_free()
	if modal == catcher:
		modal = null


## One of the first jobs on the main road (where help is pushed harder)?
func _early_job() -> bool:
	return level.number <= EARLY_JOBS and side.is_empty() and daily_day < 0 and not og


## The nudges: Undo pulses and shakes while the van's plainly stuck (no move left, or a stop cut off for
## good); Hint does when nothing's been driven for HINT_NUDGE_AFTER seconds.
func _nudge_tick(delta: float) -> void:
	if Progress.auto or undo_button == null or _busy_modal() or _strict_side():
		return
	_nudge_t -= delta
	if _nudge_t > 0.0:
		return
	_nudge_t = 0.4
	if (state == State.FAILED or (state == State.IDLE and _stranded)) and can_undo() and _undo_hold < 0.0:
		undo_button.wiggle()
		_nudge_t = 1.9
	elif radio_button != null and not _boss_level() and _ribbon_row() in ["jets", "gift"]:
		# With the Radio aboard and jump jets to offer, Hint doesn't wave (being stuck offers the jump: _skip_tick).
		# Idle a while with the van part-way round and a call in hand: the Radio does.
		if state == State.IDLE and _idle_t > HINT_NUDGE_AFTER and route.size() >= 2 and (radio_left() > 0 or _radio_unlimited()):
			radio_button.wiggle()
			_nudge_t = 4.0
	elif (state == State.IDLE or (state == State.FAILED and _early_job())) and _idle_t > (EARLY_NUDGE_AFTER if _early_job() else HINT_NUDGE_AFTER) \
			and not _no_hints() and hint_run.is_empty() and not hint_button.dim and not is_instance_valid(_undo_lesson):
		hint_button.wiggle()
		_nudge_t = 3.2



## `then`, with a tank already committed to `kind` (a full fuel line, the explainer's button, an ad): no
## hold asked for.
func _paid_call(kind: String, then: Callable) -> void:
	_gas_paid = kind
	then.call()
	_gas_paid = ""


## True if this press of Hint/Undo stops here: the release after a hold that already paid, or a tap where a
## hold is wanted (it nudges).
func _gate_tank(kind: String) -> bool:
	if _gas_held == kind and _gas_paid == "":
		_gas_held = ""
		return true
	if _gas_paid != kind and _rush_due(kind):
		var what := "undos" if kind == "undo" else "hints"
		Sfx.play("bonk", 1.2, -10.0)
		_say("Hold for %s of free %s!" % [Progress.clock(float(Progress.rush_held.get(what, 0.0))), what], RushRing.GOLD.darkened(0.35))
		_rush_rings[what].nudge()
		return true
	if _gas_paid == kind or Progress.auto or not _tank_due(kind):
		return false
	Sfx.play("bonk", 1.2, -10.0)
	# (What the tank buys depends on the button: one hint, or Undo and the Radio unlimited for the job.)
	_say("Hold to pour in a can of gas: +1 hint." if kind == "hint" else ("Hold to pour in a can of gas: +%d calls." % Progress.RADIO_PER_CAN if kind == "radio"
			else "Hold: 1 can of gas, unlimited undos this try."), GasChip.FUEL.darkened(0.2))
	return true


## A tank goes on an undo or a hint (`button`): it drains out of the gauge, and (unless a held fuel line
## just carried it there) a can hops over and pours into the button (GasPour).
func _burn_tank(button: Control) -> void:
	var bonus := Progress.reserve_gas > 0
	Progress.spend_gas()
	gas_chip.drain(bonus)
	if is_instance_valid(_gas_line) and _gas_line.is_full():
		return
	var pour := GasPour.new()
	pour.from = gas_chip.can_pos()
	pour.button = button
	_ui_root.add_child(pour)


func undo() -> void:
	if not can_undo():
		return
	var lights := Progress.lights_on()
	if not _undos_unlimited() and undo_left <= 0 and _rush_ready("undos"):
		_begin_rush("undos")        # (out, with a rush in hand: it goes before any tank)
	if _rush_on("undos"):
		pass                        # a rush (a detour's power-up): undos are free
	elif undo_left > 0:
		undo_left -= 1
		undo_used = not lights      # with headlights on, going back is part of driving: it isn't counted
	elif _undos_unlimited():
		undo_used = not lights
	else:
		# A can (a daily: the only place undos are counted): unlimited undos for the rest of this try.
		_burn_tank(undo_button)
		_buy("undo")
		_say("Unlimited undos this try!", Palette.GOOD.darkened(0.2))
		undo_used = not lights
	LevelStats.add(_attempt_key(), "undos")
	undo_count += 1
	_ev_gen += 1                 # (animations still to come from before this are dropped)
	for f in _landing:            # (and parcels still flying in won't land in the chute)
		if is_instance_valid(f["pkg"]):
			(f["pkg"] as Node).queue_free()
	_landing.clear()
	if not _winnable.is_empty():
		_winnable.pop_back()
	stars_ctl.queue_redraw()
	var snap: Dictionary
	if bool(history.back().get("locker", false)) and int(history.back()["len"]) == route.size():
		# Just used a locker here: that's what's taken back (the van stays put).
		snap = history.pop_back()
	elif lights:
		# Back to the last stop behind the van (a stop it's parked on is the one taken back).
		while history.size() > 1 and int(history.back()["len"]) >= route.size():
			history.pop_back()
		snap = history.back()
		if bool(snap.get("locker", false)) and snap.has("after"):
			# That stop is where a locker was used: back to it as it was left (the package still parked),
			# not as it was before the tap (a second Undo there takes the tap back).
			snap = snap.duplicate()
			snap["state"] = Sim.copy_state(snap["after"])
			snap["deliv"] = int(snap.get("after_deliv", snap.get("deliv", deliveries.size())))
	else:
		snap = history.pop_back()
	deliveries.resize(snap.get("deliv", deliveries.size()))
	if gift_taken and gift_len > int(snap["len"]):
		gift_taken = false
		gift_len = 0
		board.gift.taken = false
		board.gift.scale = Vector2.ZERO
		board.gift.create_tween().tween_property(board.gift, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var start_i: int = snap["len"] - 1
	var back: Array = route.slice(start_i)          # segment tiles, first = where it began
	var old: Dictionary = sim_state
	# A copy: with the headlights the stop's marker stays in `history` to come back to again, and play from
	# here mustn't write into it (that kept later deliveries in the houses after the next undo).
	sim_state = Sim.copy_state(snap["state"])
	route.resize(snap["len"])
	if lights:
		# An undo isn't one whole drag here, so the "was it still winnable" record (one per drag) is
		# worked out afresh.
		_winnable = [Solver.solve_from(level, route, sim_state).size() >= 2] if Progress.rate_levels else []
	state = State.REWINDING
	_stranded = false
	van.inviting = false
	_clear_hint()
	retry_button.breathe(false)
	hint_label.add_theme_color_override("font_color", Palette.TEXT)
	hint_label.text = _base_hint
	hint_label.modulate.a = 0.35 if route.size() > 1 else 1.0
	_update_undo()
	Sfx.play("rewind")
	Sfx.haptic(20, 1.0, "game:undo")

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
	var rush := clampf(1.0 + 0.6 * _undo_streak, 1.0, 4.0)       # (a held Undo: each rewind quicker than the last)
	var rt := create_tween()
	rt.tween_method(_rewind_tick.bind(back), n, 0.0, (n / REWIND_SPEED + 0.12) / rush).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.tween_callback(func():
		van.target_rotation = snap["rot"]
		van.position = dest
		stack_view.rebuild(sim_state["stack"])
		van.set_top(stack_view.top_color())
		_sync_lockers()
		van.stop_bounce()
		board.show_trail(route)
		board.wreck.set_route(route, route.size() - 1)
		board.update_gates(Sim.top_color(level, sim_state))
		if board.depot:
			board.depot.calling = false
		state = State.IDLE
		_stranded = _cut_off()
		van.inviting = true
		_update_undo()
		_refresh_tags()
		_back_check())


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


## The Undo button. On the road it's free and never runs out, like Retry: no badge at all. On a daily (a
## try's undos are counted): a count; past them what a can buys; greyed with an ad badge when out of gas too.
func _update_undo() -> void:
	if undo_button == null:
		return
	undo_button.turbo = _tanked() and not _strict_side() and not _undo_free_here()
	hint_button.turbo = false
	undo_button.badge_square = false
	if _strict_side():
		# Side roads: no undos (or hints).
		undo_button.badge = ""
		undo_button.badge_icon = ""
		undo_button.dim = true
		hint_button.dim = true
		undo_button.queue_redraw()
		return
	undo_button.badge_px = 38 if _rush_on("undos") and not _undo_free_here() else 28
	undo_button.badge_icon = ""
	if _undo_free_here():
		undo_button.badge = ""
		undo_button.dim = not can_undo()
	elif _undos_unlimited():
		undo_button.badge_color = _rush_badge_col("undos") if _rush_on("undos") else Palette.GOOD
		undo_button.badge = Progress.clock(Progress.rush_left("undos")) if _rush_on("undos") else ("∞" if UiTheme.font().has_char(0x221E) else "ALL")
		undo_button.dim = not can_undo()
	elif undo_left > 0:
		undo_button.badge_color = COUNT_BLUE
		undo_button.badge = str(undo_left)
		undo_button.dim = not can_undo()
	elif daily_day >= 0:
		# The daily: out of this try's undos. Nothing buys more.
		undo_button.badge_color = Color("8c867a")
		undo_button.badge = "0"
		undo_button.dim = true
	elif Progress.total_gas() > 0:
		# Out of this try's: a can of gas makes them unlimited for it.
		undo_button.badge_icon = "gas"
		undo_button.badge_color = GasChip.FUEL
		undo_button.badge = "= ∞" if UiTheme.font().has_char(0x221E) else "1"
		undo_button.dim = not can_undo()
	else:
		undo_button.badge_icon = "ad"
		undo_button.badge_color = AD_PINK
		undo_button.badge = "+%d gas" % Progress.AD_TANKS
		undo_button.dim = true
	undo_button.queue_redraw()
	_update_hint()
	_update_radio()


## The Hint button: the hints carried, in a square; a rush's clock; "∞" in the tutorial; out of them, what a
## can of gas buys.
func _update_hint() -> void:
	if hint_button == null or _strict_side():
		return
	hint_button.turbo = false
	if _no_hints():
		hint_button.badge = ""
		hint_button.badge_icon = ""
		hint_button.dim = false          # (it's the daily's Rules button)
		hint_button.queue_redraw()
		return
	hint_button.dim = false
	if _rush_on("hints"):
		hint_button.badge_icon = ""
		hint_button.badge_square = false
		hint_button.badge_px = 38
		hint_button.badge_color = _rush_badge_col("hints")
		hint_button.badge = Progress.clock(Progress.rush_left("hints"))
		hint_button.queue_redraw()
		return
	_helper_badge(hint_button, "hint", _hints_free() or _still_free("hint"), Progress.hints, "= 1")
	if not _hints_free() and Progress.hints <= 0 and _rush_ready("hints"):
		hint_button.badge_icon = ""
		hint_button.badge_color = RushRing.GOLD.darkened(0.22)
		hint_button.badge = "HOLD"
		hint_button.queue_redraw()


## Hints cost nothing (neither the level's free ones nor gas): the power-up's on, or the Unlimited hints
## option (or a self-test) says so.
func _hints_free() -> bool:
	return hints_unlimited or _rush_on("hints") or Progress.unlimited_hints or _helpers_free()


## Before the Baron's metered them (Progress.limits_on: his scene on the first boss job), hints and the Radio
## are unlimited: the tutorial. (Never on a daily: no help there.)
func _helpers_free() -> bool:
	return not Progress.limits_on() and daily_day < 0


## Undo costs nothing and never runs out, like Retry: everywhere but a daily (where a try's undos are
## counted) and the detours that allow none.
func _undo_free_here() -> bool:
	return daily_day < 0 and not _strict_side()


## While the Baron's scene plays (LimitsScene), a helper still shows as unlimited until he's stamped it.
func _still_free(kind: String) -> bool:
	return is_instance_valid(_limits_scene) and not _metered.has(kind)


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
	_tip.text = "That was your last hint.\nWin more as prizes, or a can of gas buys one."
	_tip.target = hint_button.get_global_rect().get_center()
	_tip.life = 9.0
	_ui_root.add_child(_tip)


# ---------------------------------------------------------------- hints

func _on_hint_pressed() -> void:
	if _gate_tank("hint"):
		return
	if _busy_modal():
		return
	if _strict_side():
		if _detour_nudge_due():
			_detour_nudge()
			return
		Sfx.play("bonk", 1.1, -6.0)
		_say("No hints on detours!")
		return
	if _no_hints():
		_show_daily_rules()
		return
	# With the D-pad, a hint takes two taps (the first just asks), so a stray thumb can't spend a hint.
	if dpad_mode and state != State.FAILED and not hint_used and hint_run.is_empty() and Time.get_ticks_msec() / 1000.0 > _hint_armed \
			and _gas_paid == "":
		_hint_armed = Time.get_ticks_msec() / 1000.0 + 2.5
		Sfx.play("tick", 1.2, -4)
		Sfx.haptic(12, 0.5, "game:_on_hint_pressed")
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
	# Already showing one (no move since): just play it again. Free.
	if not hint_run.is_empty() and state != State.FAILED:
		if dpad_mode and state == State.DRAWING:
			_cancel_plan()
		_show_hint_run(hint_run)
		_say("Try this way.")
		return
	# A dead end (stuck, or no win left from here): the hint says so and points at Retry (or Undo). It
	# never restarts anything itself, and costs no star; after a restart, a hint shows the first step.
	if state == State.FAILED:
		if _pay_hint():
			_dead_end_hint()
		return
	if state != State.IDLE and not (dpad_mode and state == State.DRAWING):
		return
	var avoid: Array = [level.gift] if board.gift and not gift_taken and level.gift_item != "" else []
	var path := Solver.solve_from(level, route, sim_state, 400000, avoid)
	if path.size() < 2:
		if _pay_hint():
			LevelStats.add(_attempt_key(), "dead_end_hints")
			_dead_end_hint()
		return
	if not _pay_hint():
		return
	LevelStats.add(_attempt_key(), "hints")
	if dpad_mode and state == State.DRAWING:
		_cancel_plan()
	stars_ctl.queue_redraw()
	if _locker_hint(path):
		return
	_show_hint_run(_hint_run_from(_to_locker(path)))
	_say("Try this way.")


## Pays for the hint that's about to be shown (the way on, or a dead end's pin): nothing while hints are
## unlimited here (the tutorial, a Hint Rush, the testers' option); else one of the hints carried. Out of
## them, a can of gas buys one (_buy_with_can), and this returns false: nothing's shown until they tap again
## with it in hand. False too while the gas explainer or an ad is up (it asks again when it's done).
func _pay_hint() -> bool:
	if _hints_free():
		if not _rush_on("hints") and not _helpers_free():
			hint_used = true
		return true
	if Progress.hints > 0:
		hint_used = true
		_spend_free_hint()
		if Progress.hints == 0:
			_out_of_hints_tip.call_deferred()
		return true
	if _explain_gas("hint", _on_hint_pressed):
		return false
	if Progress.total_gas() <= 0:
		_gas_ad(true, _on_hint_pressed)
		return false
	# A can of gas buys one: it lands in the count (the button fills, steams, and shows it); the next tap uses it.
	_buy_with_can("hint")
	return false


## One of the hints carried goes.
func _spend_free_hint() -> void:
	Progress.add_hints(-1)
	_update_hint()


## What a hint shows of the way that works (`path`, from the van): on from the van, through any stretch
## where there's only one way to go anyway, past the first place there was a real choice, and then straight
## on until the route turns. So a hint always settles a decision; it's never just "the only move there is".
## And it's never less than HINT_MIN_TILES long (unless the job ends sooner): a one-tile hint felt stingy.
const HINT_MIN_TILES := 3

## `at_least`: tiles it must run to before it may stop (after backing out of a dead end: to where the way
## that works parts from the way that didn't, so the hint shows the turn that matters).
func _hint_run_from(path: Array, at_least := HINT_MIN_TILES) -> Array:
	var run: Array = [path[0]]
	var r: Array = route.duplicate()
	var st := Sim.copy_state(sim_state)
	var chose := false
	for i in range(1, mini(path.size(), maxi(16, at_least + 4))):
		var ways := 0
		for d in LevelData.DIRS:
			if Sim.can_extend(level, r, r.back() + d, st):
				ways += 1
		var turned: bool = run.size() >= 2 and (path[i] as Vector2i) - (path[i - 1] as Vector2i) != (run[run.size() - 1] as Vector2i) - (run[run.size() - 2] as Vector2i)
		if chose and turned and run.size() > at_least:
			break
		if ways >= 2:
			chose = true
		run.append(path[i])
		Sim.arrive(level, st, path[i], r)
		r.append(path[i])
	return run


## The last stop Undo can get back to that the job can still be finished from: {"presses": how many
## undos it takes, "len": the route's length there}; {} if there's none (no undos here). With the headlights
## an undo goes back a stop at a time; without, a drive at a time.
func _safe_stop() -> Dictionary:
	if history.is_empty() or _strict_side():
		return {}
	var presses := 0
	var last_len := route.size()
	for k in range(history.size() - 1, -1, -1):
		var ln := int(history[k]["len"])
		if ln >= last_len:
			continue                # (a marker where the van already is: an undo goes past it)
		presses += 1
		last_len = ln
		if Solver.can_finish(level, route.slice(0, ln), history[k]["state"]) != 0:
			return {"presses": presses, "len": ln}
	return {}


## Undo only stops where the van stopped, so one long drag that went wrong part-way leaves nothing to undo to
## but its start, though the first part of it was fine. From the last stop that can still win (`from_len`),
## this walks the route on to the furthest tile that can still win and leaves a stop there (a marker in
## `history`, as if the van had paused): the dead-end hint's pin goes there, and one Undo takes the van
## back to it. True if it added one.
func _mark_furthest_winnable(from_len: int) -> bool:
	# (A locker used on the way isn't in the route's tiles: the states can't be worked out from them.)
	if history.any(func(m): return m.get("locker", false) and int(m["len"]) >= from_len):
		return false
	var at := -1
	for k in history.size():
		if int(history[k]["len"]) == from_len:
			at = k
	if at < 0:
		return false
	# Each tile's state along the way, from the stop's own.
	var states := {from_len: Sim.copy_state(history[at]["state"])}
	var st: Dictionary = Sim.copy_state(history[at]["state"])
	for i in range(from_len, route.size()):
		Sim.arrive(level, st, route[i], route.slice(0, i))
		states[i + 1] = Sim.copy_state(st)
	# Winnable ends in a run from the start (a shorter part of a winnable route is winnable too), so halve
	# the range: lo can win, hi can't. Only a sure yes counts (an unsure solver says nothing here).
	var lo := from_len
	var hi := route.size()
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if Solver.can_finish(level, route.slice(0, mid), states[mid], 200000) == 1:
			lo = mid
		else:
			hi = mid
	if lo <= from_len:
		return false
	var pos := history.size()
	for k in history.size():
		if int(history[k]["len"]) == lo:
			return false            # (a stop's already there)
		if int(history[k]["len"]) > lo:
			pos = k
			break
	var base: Dictionary = history[at]
	history.insert(pos, {"len": lo, "state": states[lo], "rot": Vector2(route[lo - 1] - route[lo - 2]).angle() if lo >= 2 else float(base["rot"]),
		"deliv": int(base.get("deliv", 0)) + Sim.delivered_count(states[lo]) - Sim.delivered_count(base["state"])})
	return true


## A dead-end hint's "back up to here" comes down (the van's there, has driven on, or the hint's dropped).
func _clear_back() -> void:
	_back_to = 0
	if is_instance_valid(_back_mark):
		_back_mark.queue_free()
	_back_mark = null


## An undo's landed. If that's the stop a dead-end hint pointed back to, the hint goes on from there: the
## way on, as any hint shows it (the same hint: nothing more is spent).
func _back_check() -> void:
	if _back_to <= 0 or route.size() > _back_to:
		return
	var there := route.size() == _back_to
	if not there or state != State.IDLE:
		_clear_back()
		return
	var avoid: Array = [level.gift] if board.gift and not gift_taken and level.gift_item != "" else []
	var path := Solver.solve_from(level, route, sim_state, 400000, avoid)
	if _locker_hint(path):
		_clear_back()
		return
	path = _to_locker(path)
	if path.size() >= 2:
		# As far as the road it took last time and one tile past where the two part: the turn that matters.
		var shared := 0
		while shared + 1 < path.size() and _back_to + shared < _back_old.size() and path[shared + 1] == _back_old[_back_to + shared]:
			shared += 1
		_show_hint_run(_hint_run_from(path, maxi(HINT_MIN_TILES, shared + 1)))
		_say("Back on track. Now try this way.", Palette.GOOD.darkened(0.2))
	_clear_back()


## Shows (or replays from the start) the hint along `run`: the pulsing arrow and a finger tracing it.
func _show_hint_run(run: Array) -> void:
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
	Sfx.haptic(10, 1.0, "game:_show_hint_run")


## While a route's being drawn, the hint stays but steps back (the finger's the player's now).
func _dim_hint(dim: bool) -> void:
	if hint_ghost and is_instance_valid(hint_ghost):
		hint_ghost.visible = not dim
	board.hint_line.self_modulate.a = 0.55 if dim else 1.0
	board.hint_head.self_modulate.a = 0.55 if dim else 1.0
	board.hint_stop.self_modulate.a = 0.55 if dim else 1.0


func _dead_end_hint() -> void:
	Sfx.play("bonk", 0.9, -4)
	van.shake()
	# (It's a hint like any other, and paid for like one: _pay_hint, before this.)
	# How far back: the last stop the job can still be finished from gets a pin on the board, with the road
	# to take back marked. Once the van's back there, the hint shows the way on (_back_check).
	_clear_back()
	var safe := _safe_stop() if can_undo() else {}
	if not safe.is_empty() and _mark_furthest_winnable(int(safe["len"])):
		safe = _safe_stop()          # (now one stop further on: the last tile that still wins)
	var n := int(safe.get("presses", 0))
	var line := "No way to win from here."
	if n > 0:
		_back_to = int(safe["len"])
		_back_old = route.duplicate()
		_back_mark = BackUpMark.new()
		_back_mark.tile = board.tile
		for t in route.slice(_back_to - 1):
			_back_mark.pts.append(board.center(t))
		board.add_child(_back_mark)
		line = "Back to the pin: Undo x%d" % n if n > 1 else "Back to the pin: Undo"
		_say("Dead end: no way to win from here.\nUndo back to the pin, then I'll show you the way on.", Palette.ACCENT.darkened(0.12))
	else:
		_say("Dead end: there's no way to win from here.\n" + ("Undo, or Retry to start over." if can_undo() and not _strict_side() else "Retry to start over."),
			Palette.ACCENT.darkened(0.12))
		retry_button.breathe(true)
	_point_at_way_out()
	# The sign: a DEAD END diamond over the way out, the rest dimmed a little.
	if not Progress.auto:
		for c in _ui_root.get_children():
			if c is DeadEndSign:
				c.queue_free()
		var sign := DeadEndSign.new()
		sign.target = (undo_button if can_undo() and not _strict_side() else retry_button).get_global_rect()
		sign.line = line
		_ui_root.add_child(sign)


func _point_at_way_out() -> void:
	if can_undo():
		undo_button.pop()
	else:
		retry_button.pop()


func _clear_hint() -> void:
	hint_run = []
	board.show_hint([])
	board.hint_line.self_modulate.a = 1.0
	board.hint_head.self_modulate.a = 1.0
	board.hint_stop.self_modulate.a = 1.0
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
	if is_instance_valid(_undo_lesson) and _undo_lesson.busy() and not _busy_modal():
		# Job 6's lesson: Undo's the way out of this one.
		Sfx.play("bonk", 1.1, -6.0)
		_say("Undo's the way out of this one.")
		undo_button.wiggle()
		return
	Sfx.play("click")
	_retry()


## Once a level's been beaten (or today's daily solved), playing it again neither costs gas nor earns any.
func _replay_free() -> bool:
	if not side.is_empty() or og:
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
		# Nothing to start over... unless undos were used getting back here: those come back.
		if undo_left < Progress.undo_slots() and not _undos_unlimited() and not _strict_side():
			undo_left = Progress.undo_slots()
			_update_undo()
			undo_button.pop()
			Sfx.play("rewind", 1.2, -6.0)
			_say("Fresh start: undos refilled.")
			return
		van.nudge()
		return
	if daily_day >= 0 and Daily.out_of_tries(Progress.daily_record(daily_day)):
		# The daily's tries are spent: no more today.
		Sfx.play("bonk", 1.0, -6.0)
		retry_button.pop()
		_say("That was your last try today. Press F.\nYou'll get it tomorrow: new map, new you.", Palette.ACCENT.darkened(0.12))
		return
	# Starting over is free (with the headlights, retrying is how a level is played).
	retry_paid = false
	# Starting over breaks the run of wins.
	if state != State.WON:
		Progress.momentum = 0
	if daily_day >= 0:
		if state != State.WON:
			Progress.daily_add_time(daily_day, play_time)     # (the daily's clock runs across retries)
		Progress.daily_attempt(daily_day)
	# What this try did, for the Replay ghost path option (a try that never drove keeps the one before).
	if state != State.WON and route.size() >= 2:
		last_attempt = {"key": _attempt_key(), "route": route.duplicate()}
	if state != State.WON:
		LevelStats.add(_attempt_key(), "restarts")
		LevelStats.add(_attempt_key(), "seconds_active", play_time)
	retry_requested.emit(index)


## Which level this is, for last_attempt: the level, and the side road, part or daily it belongs to.
func _attempt_key() -> String:
	return "%d|%s|%d|%d|%s" % [level.number, str(side.get("id", "")), part, daily_day, "og" if og else ""]


## Back to the level list. Walking away from an unfinished level breaks the run of wins.
func _leave() -> void:
	if _busy_modal():
		return
	if state != State.WON and (route.size() > 1 or hint_used or undo_used):
		Progress.momentum = 0
	if side.is_empty() and daily_day < 0 and not og:
		Progress.map_here = index + 1 if state == State.WON and index + 1 < total else index
	if state != State.WON:
		_send_play("left")
		LevelStats.add(_attempt_key(), "walked_away")
		LevelStats.add(_attempt_key(), "seconds_active", play_time)
		if daily_day >= 0:
			Progress.daily_add_time(daily_day, play_time)
	last_attempt = {}
	if daily_day >= 0:
		daily_menu_requested.emit()
	else:
		menu_requested.emit()


# ---------------------------------------------------------------- results

func _win() -> void:
	state = State.WON
	timing = false
	_clear_hint()
	last_attempt = {}
	_win_stats = _stats_at_win()
	coin_chip.frozen = true
	var pay := 0
	var gas_back := false
	var crushed := false
	var side_prize := ""
	# Packages delivered before this win, and zones open: a first win adds this job's packages (Progress.delivered),
	# which can unlock a trail or a look, or open a zone.
	var delivered_before := Progress.delivered()
	var zones_before := Zones.open_count()
	var lights_before := Progress.headlights()
	var undos_before := Progress.undo_slots()
	# The first time the Baron loses here, he has something particular to say about it (BossOutro).
	var boss_first := not Progress.is_complete(level.number) if _boss_level() else not Progress.side_done.has(str(side.get("id", "")))
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
		var bonus_kind := str(side.get("bonus", {}).get("kind", ""))
		if _bonus_line != "" and Progress.RUSH_SECS.has(bonus_kind):
			_rush_won = bonus_kind
		if _twist() == "mega":
			Progress.set_mega_part(str(side.get("id", "")), 0)
	elif og:
		Progress.og_win(level.number)
	elif daily_day >= 0:
		var first: bool = not Progress.daily_record(daily_day).get("done", false)
		var shortest: Array = solve_info.get("shortest", [])
		Progress.daily_done(daily_day, Progress.daily_time(daily_day, play_time), deliveries, {"tiles": route.size() - 1, "undos": undo_count,
			"shortest": maxi(shortest.size() - 1, 0)})
		DailyResults.send(daily_day)
		if first:
			pay = Progress.FIRST_PAY if Progress.COINS else 0      # (Dollaroos are off: nothing to pay)
			gas_back = true
			if Progress.daily_record(daily_day).get("ok", false) and not Progress.auto:
				# Today's daily solved (the first time today): a hint and a Radio call for the road.
				Progress.add_hints(1)
				Progress.add_radio(1)
				_prize_line = "+1 hint   +1 call"
	else:
		gas_back = not Progress.is_complete(level.number)
		pay = Progress.mark_complete(level.number, level.fp)
		if gas_back and Progress.limits_on() and not Progress.auto:
			# A job delivered for the first time: a Radio call. A boss: three more, and a hint.
			var calls := Progress.RADIO_PER_JOB + (3 if _boss_level() else 0)
			Progress.add_radio(calls)
			_prize_line = "+%d call%s" % [calls, "" if calls == 1 else "s"]
			if _boss_level():
				Progress.add_hints(1)
				_prize_line += "   +1 hint"
		# First time through a challenge level: a bonus, and the finish goes big.
		crushed = (level.challenge or _boss_level()) and gas_back
		if crushed:
			Progress.earn(ChallengeIntro.BONUS)
			if Progress.COINS:
				pay += ChallengeIntro.BONUS
	if Zones.open_count() > zones_before:
		Progress.zone_opened = Zones.open_count() - 1
	var fresh := Progress.delivered() - delivered_before      # packages that count for the first time
	# A permanent upgrade won (a boss's buff, or the last speedrun course): BuffCard shows it before the finish.
	_buff = {}
	if Progress.headlights() > lights_before and Progress.lights_earned():
		_buff["lights"] = Progress.headlights()
		if lights_before == 0:
			# The tutorial's headlights, just found on job 2: the card says what they do (once).
			_buff["first"] = true
			Progress.seen_new["headlights"] = true
			Progress.set_option("seen_new", Progress.seen_new)
	if pay > 0 and daily_day >= 0:
		Progress.earn(pay)
	gas_back = false            # (starting a level is free, so there's nothing to hand back)
	var new_item := ""
	var found_key := false
	if gift_taken and level.gift_item == "key":
		found_key = Progress.find_key(level.number)
	elif level.gift_item == "headlights":
		pass                       # (they're the van's from winning the level: Progress.headlights)
	elif gift_taken and Progress.give(level.gift_item):
		new_item = level.gift_item
	if side_prize != "" and Progress.give(side_prize):
		new_item = side_prize
	# Enough packages delivered now for a new trail (or look)?
	if new_item == "" and fresh > 0:
		for id in Cosmetics.ORDER:
			var need := Cosmetics.need_for(id)
			if Cosmetics.by_count(id) and need > 0 and need > delivered_before and need <= Progress.delivered():
				new_item = id
				break
	# A boss on the main road: one of his company's paint jobs (Boss.LOOT), the first time he's beaten there.
	var loot := ""
	if _boss_level():
		var lid := str(Boss.level_def(level).get("reward", ""))
		if lid != "" and Progress.give(lid):
			loot = lid
			if new_item == "":
				new_item = loot
				loot = ""
	var missed := board.gift != null and not gift_taken
	Progress.momentum += 1
	momentum_ctl.visible = false
	Sfx.play("win")
	Sfx.haptic(30, 1.0, "game:_win")
	# The ride's own celebration (RideWins), and the finish card waits for it. The board pushes in on it so
	# nobody misses it (an action zoom), and eases back out just before the card.
	van.celebrate()
	var zoomed := _win_zoom(RideWins.time(Progress.ride))
	if board.depot:
		board.depot.calling = false
	for i in board.house_nodes.size():
		board.house_nodes[i].bounce(i * 0.07)
		fx.burst(board.house_nodes[i].base_pos + Vector2(0, -board.tile * 0.4), Palette.STAR_GOLD, 6, board.tile * 2.2, board.tile * 0.09)
	hint_label.visible = false
	title_label.visible = false
	actions.visible = false
	gas_chip.visible = false
	dpad.visible = false
	drive_button.visible = false
	# A boss beaten: he runs for it (BossOutro), dropping a package for each prize, and the finish waits.
	var wait := maxf(0.35, RideWins.time(Progress.ride) + 0.1) + (WIN_ZOOM_EXTRA if zoomed else 0.0)
	if (Boss.is_boss(side) or _boss_level()) and (not Progress.auto or OS.get_cmdline_user_args().has("--boss-outro")):
		var outro := BossOutro.new()
		outro.line = Boss.defeat_for(Boss.level_def(level) if _boss_level() else side, boss_first)
		# Each prize in its own package: brighter headlights, an extra undo, a cosmetic (his, or a present
		# picked up on the way). Opened there, so the cards for them don't come again after.
		var prizes := []
		if _buff.has("lights"):
			prizes.append({"kind": "lights", "value": int(_buff["lights"]), "first": bool(_buff.get("first", false))})
		if _buff.has("undos"):
			prizes.append({"kind": "undos", "value": int(_buff["undos"])})
		if new_item != "":
			prizes.append({"kind": "item", "value": new_item})
		if loot != "":
			prizes.append({"kind": "item", "value": loot})
		outro.rewards = prizes
		_overlay(outro)
		if not prizes.is_empty():
			_buff = {}
			_item_opened = new_item != ""
			outro.done.connect(_rate_then_finish.bind(fresh, pay, gas_back, new_item, missed, crushed, found_key))
			return
		wait = maxf(wait, BossOutro.TIME)
	var tw := create_tween()
	tw.tween_interval(0.35 if Progress.auto and not OS.get_cmdline_user_args().has("--slowwin") else wait)
	if crushed:
		# A big reaction on the board first: every house cheers, confetti everywhere, the screen jolts.
		Sfx.play("kaching", 1.0, -2.0)
		Sfx.haptic(45, 1.0, "game:_win")
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
	tw.tween_callback(_rate_then_finish.bind(fresh, pay, gas_back, new_item, missed, crushed, found_key))
	# A tap on the board while the van celebrates skips to the finish card.
	_win_wait = tw
	_win_go = _rate_then_finish.bind(fresh, pay, gas_back, new_item, missed, crushed, found_key)


## The win's action zoom: the board scales up round the van (it ends up a little above the middle of the
## screen) for the ride's celebration, `hold` seconds, then settles back. Not in the self-tests.
const WIN_ZOOM := 1.7
const WIN_ZOOM_EXTRA := 0.4
var _zoom_rest := {}
var _zoom_tw: Tween


func _win_zoom(hold: float) -> bool:
	if (Progress.auto and not OS.get_cmdline_user_args().has("--slowwin")) or not is_instance_valid(van):
		return false
	_zoom_rest = {"pos": board.position, "scale": board.scale}
	var k: Vector2 = board.scale * WIN_ZOOM
	var vp := get_viewport_rect().size
	var focus := Vector2(vp.x / 2.0, vp.y * 0.44)
	var to := focus - van.position * k
	_zoom_tw = create_tween().set_parallel()
	_zoom_tw.tween_property(board, "scale", k, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_zoom_tw.tween_property(board, "position", to, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh", 1.25, -8.0)
	# (The whole celebration close up, then back out before the finish goes on, which waits WIN_ZOOM_EXTRA
	# longer for it: a crushed job's shake comes after.)
	_zoom_tw.chain().tween_interval(maxf(0.2, hold - 0.1))
	_zoom_tw.chain().tween_callback(_win_unzoom.bind(0.25))
	return true


func _win_unzoom(secs: float) -> void:
	if _zoom_rest.is_empty():
		return
	if _zoom_tw and _zoom_tw.is_valid():
		_zoom_tw.kill()
	var rest := _zoom_rest
	_zoom_rest = {}
	_zoom_tw = create_tween().set_parallel()
	_zoom_tw.tween_property(board, "scale", rest["scale"], secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_zoom_tw.tween_property(board, "position", rest["pos"], secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Is this job 4, not yet beaten as it is now, with its lesson still to give this try? (The self-tests ask
## for it with --lesson.)
func _lesson_due() -> bool:
	# (Job 4: the first place a road gets torn up that was needed. Job 5 is the Undo lesson.)
	if level.number != LESSON_LEVEL or not side.is_empty() or daily_day >= 0 or og or _lesson_shown:
		return false
	if Progress.auto and not OS.get_cmdline_user_args().has("--lesson"):
		return false
	return not Progress.is_complete(level.number) or Progress.is_stale(level.number, level.fp)


## What just went wrong, and why (LessonCard), a beat after the van stops. Either way on is a fresh start;
## "Show me a hint" opens it with the way that works pointed out.
func _show_lesson() -> void:
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree() or state == State.WON:
		return
	if state == State.DRAWING or state == State.DRIVING or _busy_modal():
		_lesson_shown = false        # (already off again: it'll come when this drive ends)
		return
	var card := LessonCard.new()
	card.level = level
	card.route = route.duplicate()
	for i in level.houses.size():
		if int(sim_state["fills"][i]) < int(level.houses[i].order):
			card.stranded.append(i)
	modal = card
	_overlay(card)
	card.chosen.connect(func(hint: bool):
		modal = null
		if hint:
			Game.lesson_hint = level.number
		Game.radio_tip = level.number      # (the fresh start points at the Radio: "not sure? ask")
		_retry())


## The lesson's hint, on the fresh start it asked for: the way that works, as far as its second turn (so
## the fork's in it), pointed out for free.
func _lesson_hint() -> void:
	await get_tree().create_timer(0.5).timeout
	while is_inside_tree() and _busy_modal():
		await get_tree().process_frame
	if not is_inside_tree() or state != State.IDLE:
		return
	var path := _to_locker(Solver.solve_from(level, route, sim_state))
	if path.size() < 2:
		return
	var run: Array = [path[0], path[1]]
	var turns := 0
	for i in range(2, path.size()):
		if path[i] - path[i - 1] != path[i - 1] - path[i - 2]:
			turns += 1
			if turns == 2:
				break
		run.append(path[i])
	_show_hint_run(run)
	_say("The long way round saves the road you need.")


## A segment has been driven and the level goes on (or the van is stuck). For the level's stats: was that
## the move that lost it? Only worked out while Rate levels is on (it asks the solver after every drive).
func _count_segment(stuck: bool) -> void:
	# Job 4, and that drive lost it (stuck, or no way left to win): its lesson (once a try).
	if _lesson_due() and (stuck or Solver.solve_from(level, route, sim_state).size() < 2):
		_lesson_shown = true
		_show_lesson.call_deferred()
	var key := _attempt_key()
	LevelStats.add(key, "segments")
	if stuck:
		LevelStats.add(key, "stuck")
	if not Progress.rate_levels:
		return
	var before: bool = _winnable.is_empty() or _winnable.back()
	var ok := not stuck and Solver.solve_from(level, route, sim_state).size() >= 2
	_winnable.append(ok)
	if before and not ok:
		LevelStats.add(key, "wrong_moves")
	elif not before:
		LevelStats.add(key, "doomed_segments")


## Everything counted on the way to this win (see LevelStats), with how the level and the session stood.
func _stats_at_win() -> Dictionary:
	var key := _attempt_key()
	LevelStats.add(key, "seconds_active", play_time)
	LevelStats.add(key, "segments")
	var first_time := not _replay_free()
	var s := LevelStats.take(key)
	s["seconds_winning_try"] = play_time
	s["segments_winning_try"] = history.size()
	s["route_tiles"] = route.size() - 1
	s["used_hint"] = hint_used
	s["used_undo"] = undo_used
	s["first_time"] = first_time
	s["was_updated"] = side.is_empty() and daily_day < 0 and not og and Progress.is_stale(level.number, level.fp)
	s["challenge"] = level.challenge
	s["boss"] = _boss_level()
	s["packages"] = level.total_orders()
	s["board"] = "%dx%d" % [level.width, level.height]
	s["gift_taken"] = gift_taken
	s["momentum_before"] = Progress.momentum
	s["gas"] = Progress.gas
	s["steering"] = Progress.drive_mode
	s["unlimited_hints"] = Progress.unlimited_hints
	s["ghost_path"] = Progress.ghost_path
	s["foresight"] = Progress.sight() if Progress.lights_on() else -1     # -1: off, the old way
	s["seconds_before_first_move"] = snappedf(_first_wait, 0.1)
	s["longest_pause"] = snappedf(_longest_wait, 0.1)
	s["sideways"] = Progress.landscape
	s["levels_done"] = Progress.completed.size()
	s.merge(_play_context(), true)
	LevelStats.wins += 1
	return s


## How the job, the player and the phone stood, for a play record or a rating.
func _play_context() -> Dictionary:
	return {
		"boss": _boss_level(), "challenge": level.challenge, "packages": level.total_orders(),
		"board": "%dx%d" % [level.width, level.height], "gas": Progress.gas, "steering": Progress.drive_mode,
		"unlimited_hints": Progress.unlimited_hints, "ghost_path": Progress.ghost_path,
		"foresight": Progress.sight() if Progress.lights_on() else -1,
		"sideways": Progress.landscape, "levels_done": Progress.completed.size(), "ratings_this_session": LevelStats.rated,
		"daily": daily_day >= 0, "detour": str(side.get("id", "")), "build": Version.BUILD,
		# Which phone, and its time zone (no place finer than that).
		"device_model": OS.get_model_name().left(80), "os": ("%s %s" % [OS.get_name(), OS.get_version()]).left(80),
		"time_zone": Feedback.time_zone().left(80),
		# What they chose to hear about (NotifyPrefs): "" not asked yet, "none", or which of the three.
		"notify": _notify_choice(),
	}


static func _notify_choice() -> String:
	if not Progress.notify_chosen:
		return ""
	var on := []
	if Progress.notify_streak:
		on.append("streak")
	if Progress.notify_fresh:
		on.append("fresh")
	if Progress.notify_updates:
		on.append("news")
	return ",".join(on) if not on.is_empty() else "none"


## A play record for a job that wasn't won (left, skipped, the app put away): the counts so far, this try's
## time and moves included. Once per try at most.
func _send_play(outcome: String) -> void:
	if state == State.WON or _play_sent:
		return
	if LevelStats.value(_attempt_key(), "segments") <= 0.0 and route.size() < 2 and play_time < 3.0 and outcome != "skipped":
		return                     # (opened and closed again: nothing to say)
	_play_sent = outcome != "backgrounded"
	var s := LevelStats.peek(_attempt_key())
	s["seconds_this_try"] = play_time
	s["route_tiles"] = route.size() - 1
	s["delivered"] = deliveries.size()
	s["used_hint"] = hint_used
	s["used_undo"] = undo_used
	s["dead_end"] = state == State.FAILED
	s["first_time"] = not _replay_free()
	s.merge(_play_context(), true)
	Rating.play(level, Feedback.where_of(self), outcome, s)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_send_play("backgrounded")


## With Rate levels on, the rating card comes up first (RatingCard); the finish card follows it. Speedrun
## zones and the self-tests skip it ("-- --rate" brings it up under a self-test).
func _rate_then_finish(fresh: int, pay: int, gas_back: bool, new_item: String, missed: bool, crushed := false, found_key := false) -> void:
	_win_unzoom(0.2)
	if not _buff.is_empty() and (not Progress.auto or OS.get_cmdline_user_args().has("--buff")):
		var card := BuffCard.new()
		card.lights = int(_buff.get("lights", 0))
		card.undos = int(_buff.get("undos", 0))
		card.intro = bool(_buff.get("first", false))
		card.first_delivery = card.intro
		# Found in the present on job 2's road: it's still wrapped. Tap to open.
		card.wrapped = card.first_delivery and gift_taken and level.gift_item == "headlights"
		_buff = {}
		card.done.connect(_rate_then_finish.bind(fresh, pay, gas_back, new_item, missed, crushed, found_key))
		_overlay(card)
		return
	if _rush_won != "" and (not Progress.auto or OS.get_cmdline_user_args().has("--buff")):
		# A detour's rush: its card, before anything else.
		var rc := RushCard.new()
		rc.kind = _rush_won
		rc.secs = float(Progress.rush_held.get(_rush_won, Progress.RUSH_SECS[_rush_won]))
		_rush_won = ""
		rc.done.connect(_rate_then_finish.bind(fresh, pay, gas_back, new_item, missed, crushed, found_key))
		_overlay(rc)
		return
	_rush_won = ""
	var testing := OS.get_cmdline_user_args().has("--rate")
	var can := not _speedrun() and (not Progress.auto or testing)
	# Once, from the fifth level on: would they like to rate levels? Yes turns it on, starting with this one.
	if can and not Progress.rate_levels and not Progress.rate_asked and side.is_empty() and daily_day < 0 and not og and level.number >= 5 \
			and (not Progress.auto or OS.get_cmdline_user_args().has("--rateprompt")):
		var ask := RatePrompt.new()
		ask.answered.connect(func(yes: bool):
			Progress.rate_asked = true
			Progress.set_option("rate_levels", yes)
			_rate_then_finish(fresh, pay, gas_back, new_item, missed, crushed, found_key))
		_overlay(ask)
		return
	if not (can and Progress.rate_levels):
		Rating.play(level, Feedback.where_of(self), "won", _win_stats)
		_show_finish(fresh, pay, gas_back, new_item, missed, crushed, found_key)
		return
	rating_card = RatingCard.new()
	rating_card.level = level
	rating_card.where = Feedback.where_of(self)
	rating_card.done.connect(func(answers: Dictionary):
		if int(answers.get("difficulty", 0)) + int(answers.get("fun", 0)) + int(answers.get("frustration", 0)) > 0 \
				or not answers.get("tags", []).is_empty() or str(answers.get("note", "")) != "":
			Rating.play(level, Feedback.where_of(self), "won", _win_stats, answers)
		else:
			Rating.play(level, Feedback.where_of(self), "won", _win_stats)        # (skipped: just the play)
		rating_card = null
		_show_finish(fresh, pay, gas_back, new_item, missed, crushed, found_key))
	_overlay(rating_card)


func _show_finish(fresh: int, pay: int, gas_back: bool, new_item: String, missed: bool, crushed := false, found_key := false) -> void:
	if daily_day >= 0 and (not Progress.auto or OS.get_cmdline_user_args().has("--daily-score")):
		# The daily: its score and badges (DailyScore), with Share and Stats.
		var sc := DailyScore.new()
		sc.day = daily_day
		modal = sc
		_overlay(sc)
		sc.share_pressed.connect(_share)
		sc.stats_pressed.connect(func():
			var st := _stats_card()
			_overlay(st)
			# (What they'd like to hear from us, if it's due and never got asked on the map: NotifyPrefs.)
			st.closed.connect(func(): NotifyPrefs.ask_if_needed(self, func(): pass, true)))
		sc.done_pressed.connect(func():
			modal = null
			NotifyPrefs.ask_if_needed(self, func(): work_requested.emit(), true))
		return
	finish = FinishScreen.new()
	finish.crushed = crushed
	finish.boss = crushed and _boss_level()
	finish.level = level
	finish.fresh = fresh
	if level.number == 1 and side.is_empty() and daily_day < 0 and not og and fresh > 0:
		# The very first delivery: a heads-up, no more (the headlights are found on the next job).
		finish.note = "First delivery! It gets trickier from here.\nThere's a present on the next road."
	finish.packages = level.total_orders() if fresh <= 0 else fresh
	finish.reward = pay
	finish.gas_back = gas_back
	finish.secs = play_time
	if daily_day >= 0:
		finish.secs = float(Progress.daily_record(daily_day).get("time", play_time))     # (every try today, not just this one)
	finish.momentum = Progress.heat()
	finish.new_item = new_item
	finish.item_opened = _item_opened
	finish.missed_item = missed
	finish.found_key = found_key
	finish.missed_key = missed and level.gift_item == "key"
	finish.daily = daily_day >= 0
	if daily_day >= 0 and not Progress.daily_record(daily_day).get("shared", false):
		finish.beg = Daily.beg(daily_day)
	finish.last_level = index + 1 >= total or not side.is_empty()
	finish.side_title = str(side.get("title", ""))
	finish.side_kind = "SPEEDRUN" if _speedrun() else ("MEGA ROUTE" if _twist() == "mega" else "SIDE ROAD")
	if _speedrun():
		finish.secs = speed_elapsed + play_time
	finish.bonus_line = _bonus_line
	finish.prize_line = _prize_line
	# Job 11 beaten (the Baron twice): Dispatch sends jump jets, and the win says what they are (JetsCard).
	if side.is_empty() and daily_day < 0 and not og and level.number == Progress.JETS_FROM - 1 and not Progress.has_jets() \
			and (not Progress.auto or OS.get_cmdline_user_args().has("--jets-win")):
		Progress.grant_jets()
		Progress.seen_new["jets_tip"] = true
		Progress.set_option("seen_new", Progress.seen_new)
		finish.jets_new = true
	for what in Progress.rush_secs:
		# A rush still on the clock: the win card says so (it's waiting for the next job).
		finish.rush_line = "%s: %s left. Keep going!" % [Progress.RUSH_NAME[what], Progress.clock(Progress.rush_left(what))]
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


## "How everyone did" for today's daily.
func _stats_card() -> DailyStats:
	var st := DailyStats.new()
	st.day = daily_day
	return st


func _share() -> void:
	Progress.daily_shared(daily_day)
	var card := ShareCard.new()
	card.day = daily_day
	var under = modal          # (the score card, when it's opened from there)
	modal = card
	_overlay(card)
	card.closed.connect(func(): modal = under)


## Stuck on a level a while (three goes ended in a dead end, or four minutes on it)? A button offers to put
## it aside: the van moves on, and the level waits on the map. Main levels only, from level 5, until it's
## beaten.
const SKIP_AFTER_RESTARTS := 3
const SKIP_AFTER_SECS := 150.0
const SKIP_AFTER_STARE := 40.0
## Jobs (by _attempt_key) the "Stuck? Jump ahead" prompt has come up on since the app opened: once each.
static var skip_prompted := {}

func _skip_wanted() -> bool:
	if not side.is_empty() or daily_day >= 0 or og or level.number <= 4 or state == State.WON or Progress.is_complete(level.number):
		return false
	if index + 1 >= total or Progress.skipped.has(level.number) or _busy_modal():
		return false
	if Boss.CORE.has(level.number):
		return false                # a core boss fight: there's no going round him
	var key := _attempt_key()
	var restarts := LevelStats.value(key, "restarts")
	var secs := LevelStats.value(key, "seconds_active") + play_time
	# A few restarts, a dead end after a couple, a long time on the job, or a long stare at the board.
	return (state == State.FAILED and restarts >= 2) or restarts >= SKIP_AFTER_RESTARTS or secs > SKIP_AFTER_SECS \
			or (_idle_t > SKIP_AFTER_STARE and secs > 45.0) or OS.get_cmdline_user_args().has("--skip-offer")


func _skip_tick() -> void:
	if exit_ribbon == null:
		return
	exit_ribbon.row = _ribbon_row()
	exit_ribbon.locked_until = Progress.JETS_FROM
	exit_ribbon.jets_blocked = _boss_level()
	exit_ribbon.jets_waiting = Progress.jumps_waiting()
	exit_ribbon.jets_max = Progress.JUMPS_WAITING_MAX
	exit_ribbon.jets_full = Progress.jumps_waiting() >= Progress.JUMPS_WAITING_MAX
	# (A hold on the jets' row: long enough, and they fire.)
	if _jet_hold >= 0.0:
		_jet_hold += get_process_delta_time()
		if _jet_hold >= GasLine.TIME:
			_jump()
	exit_ribbon.instant = state == State.WON
	exit_ribbon.give_label = "Give up"
	# The jets' present, still unopened (it's been on the ribbon since job JETS_FROM, for whoever taps it):
	# stuck on a job, its bow hops. From job JETS_PUSH_FROM on the game opens it for them, sooner the further
	# they've got (_jets_push), till it's sure. Never on a boss job.
	if exit_ribbon.row == "gift" and not Progress.auto and not _boss_level() and not Progress.is_complete(level.number) \
			and (state == State.IDLE or state == State.FAILED) and not _busy_modal():
		if _jets_push():
			_reveal_jets()
			return
		if not _jets_tipped and _skip_wanted():
			_jets_tipped = true
			exit_ribbon.nudge()
	# Stuck, with jets that would work here: skipping is the first thing offered (not a hint). The ribbon
	# slides out by itself with the jets on it and says so, once a job; on later tries its arrow just hops.
	if _jets_shown() and not _boss_level() and not Progress.auto and (state == State.IDLE or state == State.FAILED) \
			and not _busy_modal() and Progress.jumps_waiting() < Progress.JUMPS_WAITING_MAX and _skip_wanted():
		if not skip_prompted.has(_attempt_key()):
			skip_prompted[_attempt_key()] = true
			_jets_tipped = true
			Progress.seen_new["jets_tip"] = true
			exit_ribbon.open()
			exit_ribbon.nudge()
			Sfx.play("sparkle", 0.9, -8.0)
			var tip := TipBubble.new()
			tip.text = "Stuck? Jump ahead: it's free.\nThis job waits on the map:\nyou can always come back."
			tip.target = exit_ribbon.get_global_rect().position + Vector2(ExitRibbon.FULL_W * 0.5, ExitRibbon.ROW_H * 2.0 + 6.0)
			tip.below = true
			tip.life = 10.0
			_ui_root.add_child(tip)
		elif not _jets_tipped:
			_jets_tipped = true
			exit_ribbon.nudge()


## What the ribbon's second row is here: nothing off the main road (or once the job's won); the jets, if
## you have them and there's something to jump; else their present (the road's reached job JETS_FROM) or the
## lock that says when it comes.
func _ribbon_row() -> String:
	if not side.is_empty() or daily_day >= 0 or og or state == State.WON:
		return ""
	if Progress.has_jets():
		return "jets" if _jets_shown() else ""
	return "gift" if Zones.reached(Progress.JETS_FROM) else "locked"


## Should the game open the jets' present for them now? Not before job JETS_PUSH_FROM. From there, how
## stuck they have to look drops job by job, and from JETS_SURE_FROM it's simply opened a moment in.
const JETS_PUSH_FROM := 21
const JETS_SURE_FROM := 26

func _jets_push() -> bool:
	var n := level.number
	if n < JETS_PUSH_FROM:
		return _skip_wanted()       # (stuck is when they're wanted: the present opens itself)
	if n >= JETS_SURE_FROM:
		return _alive > 2.5
	var restarts := LevelStats.value(_attempt_key(), "restarts")
	var secs := LevelStats.value(_attempt_key(), "seconds_active") + play_time
	var failed := state == State.FAILED
	if n >= JETS_PUSH_FROM + 3:
		return failed or restarts >= 1 or secs > 20.0
	if n == JETS_PUSH_FROM + 2:
		return failed or restarts >= 1 or secs > 60.0
	if n == JETS_PUSH_FROM + 1:
		return (failed and restarts >= 1) or restarts >= 2 or secs > 120.0
	return _skip_wanted()


## The present's opened (tapped, or opened for them): the jump jets are theirs, their card says what they
## are (JetsCard), and the ribbon pulls itself out to show where they live.
func _reveal_jets() -> void:
	if Progress.has_jets() or _busy_modal():
		return
	Progress.grant_jets()
	Progress.seen_new["jets_tip"] = true
	Progress.set_option("seen_new", Progress.seen_new)
	_jets_tipped = true
	exit_ribbon.close()
	var jc := JetsCard.new()
	modal = jc
	_overlay(jc)
	jc.closed.connect(func():
		if modal == jc:
			modal = null
		exit_ribbon.row = _ribbon_row()
		exit_ribbon.open()
		exit_ribbon.nudge())


## Is the jump jets' row on the ribbon here? You have them, and this is a job on the main road that isn't
## delivered (or already jumped), with a job after it. Never on a detour, a daily, a speedrun or an OG job.
func _jets_shown() -> bool:
	return Progress.has_jets() and side.is_empty() and daily_day < 0 and not og and state != State.WON \
			and not Progress.is_complete(level.number) and not Progress.skipped.has(level.number) and index + 1 < total


## The jets' row pressed. A jump costs no gas: what it costs is a place on the map (at most
## Progress.JUMPS_WAITING_MAX jobs may be left waiting there). On a boss job it's taped off; with the map's
## places all taken it says so; else a hold on the row (as long as a fuel line takes: GasLine.TIME) and the
## job's jumped.
func _jets_down() -> void:
	if _busy_modal() or not _jets_shown():
		return
	if _boss_level():
		Sfx.play("bonk", 0.9, -4.0)
		Sfx.play("laugh", 1.2, -10.0)
		Sfx.haptic(14, 1.0, "game:_jets_down")
		_say("No jumping the Baron's jobs.\nHe has to be beaten.", Palette.ACCENT.darkened(0.12))
		return
	if Progress.jumps_waiting() >= Progress.JUMPS_WAITING_MAX:
		Sfx.play("bonk", 1.1, -6.0)
		Sfx.haptic(14, 1.0, "game:_jets_down")
		_say("%d jobs are already waiting on the map.\nDeliver one of them, then you can jump again." % Progress.jumps_waiting(), Palette.ACCENT.darkened(0.12))
		return
	_jet_hold = 0.0


func _jets_up() -> void:
	_jet_hold = -1.0


## The jets fire, and the van's off to the next job. This one waits on the map (nothing's paid for it until
## it's delivered).
func _jump() -> void:
	_jet_hold = -1.0
	if state == State.WON or not _jets_shown() or _boss_level() or Progress.jumps_waiting() >= Progress.JUMPS_WAITING_MAX:
		return
	modal = exit_ribbon              # (hands off while it goes)
	Sfx.play("whoosh", 0.8, -2.0)
	Sfx.play("whoomp", 1.2, -6.0)
	Sfx.haptic(30, 0.8, "game:_jump")
	_say("Jump jets! This job will wait on the map.", GasChip.FUEL.darkened(0.2))
	var tw := create_tween()
	tw.tween_property(van, "scale", Vector2(1.5, 1.5), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(van, "position:y", van.position.y - board.tile * 2.5, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(van, "modulate:a", 0.0, 0.5).set_delay(0.15)
	tw.tween_callback(func():
		modal = null
		_skip())


## Put this level aside and drive on.
func _skip() -> void:
	if state == State.WON:
		return
	Sfx.play("whoosh", 1.1, -4.0)
	LevelStats.add(_attempt_key(), "skipped")
	_send_play("skipped")
	Progress.skip(level.number)
	Progress.momentum = 0
	last_attempt = {}
	Progress.map_here = index + 1
	if Progress.auto:
		level_requested.emit(index + 1)
	else:
		next_requested.emit(index, index + 1)


func _fail() -> void:
	state = State.FAILED
	_update_undo()
	Sfx.play("fail", 1.0, -2)
	Sfx.haptic(25, 1.0, "game:_fail")
	van.shake()
	stack_view.flash_remaining()
	var left := Sim.remaining(level, sim_state)
	var msg := ("Stuck! %d package%s left." % [left, "" if left == 1 else "s"]) if left > 0 \
			else ("Stuck! Can't reach the exit." if level.has_exit() else "Stuck! Can't reach the depot.")
	if daily_day >= 0 and Daily.out_of_tries(Progress.daily_record(daily_day)) and not can_undo():
		DailyResults.send(daily_day)          # (the last try spent: a miss, for today's numbers)
	if daily_day >= 0 and Daily.out_of_tries(Progress.daily_record(daily_day)):
		if can_undo():
			_say(msg + "\nUndo, or that was your last try today.", Palette.ACCENT.darkened(0.12))
		else:
			_say("Out of tries. Press F to pay respects.\nYou'll get it tomorrow: new map, new you.", Palette.ACCENT.darkened(0.12))
			fx.say(board.size_px() / 2.0, "F", Palette.TEXT_SOFT, int(board.tile * 1.2))
	else:
		_say(msg + ("\nUndo, or Retry." if can_undo() and not _strict_side() else "\nRetry?"), Palette.ACCENT.darkened(0.12))
	retry_button.breathe(true)
	if can_undo():
		undo_button.pop()


func _next() -> void:
	if og:
		# The OG 100: straight on to the next old level (or back to their list after the last).
		if index + 1 < total:
			level_requested.emit(index + 1)
		else:
			menu_requested.emit()
	elif not side.is_empty():
		menu_requested.emit()
	elif daily_day >= 0:
		daily_menu_requested.emit()
	elif index + 1 < total:
		Progress.map_here = index + 1
		# Self-tests chain straight on; players see the van drive up the map first.
		if Progress.auto:
			level_requested.emit(index + 1)
		else:
			next_requested.emit(index, index + 1)
	else:
		menu_requested.emit()


func _fade(c: CanvasItem, a: float) -> void:
	create_tween().tween_property(c, "modulate:a", a, 0.2)
