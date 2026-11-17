extends Node
## Autoload "Progress": everything saved to user://save.json.
## - which levels are completed (and, from those, the packages delivered: delivered())
## - gas: what extra help costs. Each level comes with some free hints and undos; past those, a hint or an
##   undo burns a tank. Tanks come back on their own, one every GAS_SECONDS, up to MAX_GAS; bonus tanks
##   (reserve_gas: from chests, detours and the pretend ad) sit on top, never come back, and go first.
##   Playing and retrying levels is free.
## - Door Bowl Dollaroos: pretend money. Switched off for now (COINS): nothing earns, shows or spends them.
##   The balance stays in the save, so turning COINS back on picks up where it was.
## - cosmetics found on the road (paints and toppers for the van) and which are being worn
## - the daily puzzle: one record per day (attempts, result), and the streak built from them
## Momentum (wins in a row this session) lives here too but is never saved: it's per session.
##   Nothing here is real money and nothing is ever charged; the balance can go negative ("the tab").

signal changed
## A setting changed (options menu): night mode, sound, haptics, steering, hand, orientation.
signal settings_changed

const PATH := "user://save.json"
## The save file: PATH, or with `-- --profile=<name>` a save of its own (playtests: DebugRemote).
static func save_path() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--profile="):
			return "user://save_%s.json" % a.trim_prefix("--profile=").validate_filename()
	return PATH
const MAX_GAS := 3                # cans in the tank (the gauge): each comes back by itself; an ad fills it
## A tank every half hour: gas only buys extra help now (playing is free), so it can come back slowly.
const GAS_SECONDS := 60 * 60      # a tank an hour: one tank is a whole level's unlimited help
const TANK_PRICE := 1500
## Dollaroos are switched off (Steven, 15 Nov: "we can always bring back"). With this false nothing earns
## them, no screen shows them, and the gas station doesn't sell gas.
const COINS := false
const AD_UNDOS := 3                # (old: spare undos from the ad; now the ad gives AD_TANKS)
const AD_TANKS := MAX_GAS          # one ad fills the tank (an ad is a big ask)
## Dollaroos for finishing a level the first time, and the tip for replaying one.
const FIRST_PAY := 300
const REPLAY_TIP := 10

var completed := {}
var gas := MAX_GAS
var gas_t := 0.0           # unix time the tank now refilling started
var undo_bank := 0
var dollaroos := 0
var owned := {}            # cosmetic id -> true
var paint := "classic"
var topper := ""
var ride := ""             # "" = the van; else a Cosmetics "ride" id
var daily := {}            # "2026-11-10" -> {attempts, done, ok, time, order (the packages delivered), clock,
                           #   tries (how far each failed try got), reach (the try under way)}
var best_streak := 0
## How you steer: "draw" (drag a route from the van) or "dpad" (tap arrows to plot it, then DRIVE BABY DRIVE).
var drive_mode := "draw"
## Options: night mode, horizontal (landscape) play, the D-pad on the left for left thumbs, sound volume
## and haptic strength (both 0..1), where the package chute goes upright ("left", "right", "top", "bottom";
## sideways play always has it along the top), and the route preview bubble (off unless asked for).
var night := false
var landscape := false
var left_hand := false
var volume := 1.0
var haptics := 0.7
var stack_side := "auto"
## The player picked a chute spot themselves (else it's Auto), and the "your queue moved" tip's been shown.
var stack_chosen := false
var queue_moved_seen := false
## Where Auto put the queue last level (to notice it moving).
var last_auto_side := ""
## Levels with one-way streets played so far (the second gets the "tap a symbol" tip), and whether it's shown.
var oneway_levels := {}
var symbol_tip_seen := false
## Seen the tip about the exit road (the gate to the next part or zone).
var exit_tip_seen := false
## The trail the van leaves (a Cosmetics "trail" id): the torn-up road unless another's been picked.
var wake := "wreck"
## Option ("Unlimited gas"): extra hints and undos never cost gas.
var unlimited_hints := false
## How many times the "out of hints" tip has shown (it stops after three), and whether they've ever
## watched a hint ad (then it never shows again).
var hint_tips := 0
var hint_ad_watched := false
## Bonus tanks (from chests, detours and the ad: spent before the ones that come back; at most MAX_RESERVE),
## and free hints / free undos until these times (Unix seconds). A side road hands one out once a day.
const MAX_RESERVE := 0             # (no spare tanks any more: the tank is MAX_GAS cans, and that's all)
var reserve_gas := 0               # (always 0 now: old saves' spare tanks went into the tank, or became hints)
## Helpers. Until the Baron meters them (his scene at the start of the second boss job, LIMITS_FROM: seen_new
## "limits"), hints, the Radio and undos are all unlimited: the tutorial. After it:
##  - hints: a carried count (`hints`). They never refill by themselves: won as prizes, or a can of gas each.
##  - the Radio: a carried count too (`radio`), but a common one: one call for every job delivered, more from
##    chests and bosses, or a can of gas for RADIO_PER_CAN.
##  - undos and Retry: free, always (a daily keeps count of its undos: tries are scored there).
const LIMITS_FROM := 11            # the second boss job (the first, job 6, is still on unlimited help)
const HINTS_START := 5
const RADIO_START := 5
const RADIO_PER_CAN := 3
const RADIO_PER_JOB := 1           # ...for a job delivered the first time
const RADIO_FROM := 4              # the Radio's button appears from this job (dead ends start to matter there)
var hints := 0
var radio := 0
## What became of an old save's things when the helpers changed (for the Big Changes card): {"hints": n,
## "radio": n, "spare": spare tanks it had}. Empty: nothing to say.
var changes_note := {}
## Rushes: a detour's power-up is a charge of free undos ("undos") or free hints ("hints"), held until the
## player starts it (holding the button once they're out), then running for its seconds, and only while
## they're on a job (Game ticks it).
const RUSH_SECS := {"undos": 120.0, "hints": 60.0}
const RUSH_NAME := {"undos": "Undo Rush", "hints": "Hint Rush"}
var rush_held := {}                # kind -> the seconds its charge will run for (absent: none in hand)
var rush_secs := {}                # kind -> seconds left of one that's running
var rush_full := {}                # kind -> the seconds that one started with (for the ring round the button)
var side_bonus_day := {}           # side road id -> the day it last handed out its power-up
## Speedrun: best time per course (seconds).
var speed_best := {}

var peek := false
## Colorblind mode ("aka Paul mode"): bold class marks on packages, and the same mark on a sign on every
## building and gate, so nothing depends on telling colours apart.
var colorblind := false
## The package trail: the next few packages on drones behind the van (off unless switched on).
var trail := false
## Option "Replay ghost path": after a restart, the last attempt's route shows faintly on the board (off
## unless switched on).
var ghost_path := false
## The day the daily screen was last opened (the map's ribbon goes plain once today's has been looked at).
var daily_seen := -1
## What the player wants to hear about (NotifyPrefs, after their first daily): chosen yet, and each kind.
var notify_chosen := false
## ...asked once this many jobs are done (a few after the first daily is solved; -1: no daily solved yet).
var notify_after := -1
var notify_updates := true
var notify_streak := true
var notify_fresh := true
## Option "Hoardly ads": the Baron's company's commercials (BaronAd) turn up in the pretend-ad rotation now
## and then (on unless switched off).
var hoardly_ads := true
## Zone checkpoints passed (Checkpoint: zone number -> true), and (pretend) ads watched since the last one:
## any at all and the next checkpoint waves you through.
var checkpoints := {}
var ads_seen := 0
var gate_ads := 0                  # ads watched at checkpoints, ever (the first is Hoardly's)
var recent_ads: Array = []         # the last few ads this player saw (AdPicker ids, oldest first)
## Tester option "Full license": stands in for the premium version (no checkpoints).
var licensed := false
## Rate levels: a quick card after each win (RatingCard), sent to Steven with the level's stats (Rating).
var rate_levels := false
var play_stats := true             # each job's numbers go to Steven when it's won, left, skipped (Rating.play)
## A random id made the first time a rating is sent, so one tester's ratings can be told from another's.
var device_id := ""
## The one-time "want to rate levels?" card (RatePrompt, after level 5) has been answered.
var rate_asked := false
## Where the van waits on the map (a level index): the one after the level just won, or the one just left
## unfinished. -1: the furthest level not yet beaten. Kept for the app's run only.
var map_here := -1
## Levels put aside with "skip for now" (number -> true): the van drives on past them. Beating one clears it.
var skipped := {}
## New road hazards, buildings and rules already spotlit (Spotlight): kind -> true.
var seen_new := {}
## Testers > Open every zone (or --all-open): every zone open, however many packages are delivered.
var all_open := false
## Headlights: how many tiles ahead of the van a route can be plotted before the van starts following.
## -1 (the default): as bright as the player has earned (headlights()). 0: off, the whole route is planned
## before it moves (the old game; a tester option). 1 to 5: fixed at that, for trying things out.
## Saved as "headlights" (saves from when it was an opt-in experiment, which wrote "foresight", start on -1).
var foresight := -1
var foresight_cli := -99          # --foresight=N (-1: earned): for this run only, never saved
## A zone the last win opened (its index), for the map to celebrate; -1 when none.
var zone_opened := -1
## The looks being worn (Looks): package shape, buildings, the queue's container, the road, the buttons.
var look_package := "pkg_box"
var look_building := "bld_classic"
var look_queue := "q_chute"
var look_road := "road_asphalt"
var look_controls := "ui_classic"
## Keys: some levels have a gold key on the road where a present would be (picked up on the way to a win,
## like a present). Each one opens a locked side road for good. `keys` is how many are in hand,
## `keys_found` which levels have given theirs, `sides_unlocked` which side roads a key has opened.
var keys := 0
var keys_found := {}
## The OG 100 (the old levels, an easter egg): which have been won there (level number -> true).
var og_done := {}
## Each beaten level's fingerprint when it was last beaten (LevelData.fp): a redesign shows on the map.
var level_fp := {}
var _fp_save_queued := false
var sides_unlocked := {}
## Side roads: challenges beaten (id -> true) and milestone chests opened (level number -> true).
var side_done := {}
var chests := {}
## Mega routes: parts finished so far on the current run (id -> count; gone once the route's done).
var mega := {}
## Patch notes last seen from the title screen's version badge (the badge glows for a newer one).
var seen_version := ""
## Wins in a row this session without retrying or abandoning a level. Not saved.
var momentum := 0      # levels won in a row (see heat())


## How hot the run is, for the fire (the trail, the aura, the count under the level name): it takes three wins in a
## row to light, then goes up one for every two more (so 10, the hottest, is 21 in a row).
func heat() -> int:
	return 0 if momentum < 3 else mini(1 + (momentum - 3) / 2, 10)
## Self-tests (debug_auto.gd) play levels for real: they start from a blank slate and never save.
var volatile := false
## True in the self-tests: screens skip their entrance animations.
var auto := false


func _ready() -> void:
	var preset := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--auto"):
			volatile = true
			auto = true
			foresight = 0      # self-tests play the old way unless they ask (--foresight=N)
		elif a.begins_with("--save="):
			volatile = true
			preset = a.trim_prefix("--save=")
	if not volatile:
		_load()
	_apply_preset(preset)
	for a in OS.get_cmdline_user_args():
		# Debug: --night, --landscape, --lefty, --dpad set those options for this run (without saving them).
		if a == "--night":
			night = true
		elif a == "--landscape":
			landscape = true
		elif a == "--lefty":
			left_hand = true
		elif a == "--dpad":
			drive_mode = "dpad"
		elif a.begins_with("--stack="):
			stack_side = a.trim_prefix("--stack=")
		elif a == "--peek":
			peek = true
		elif a == "--colorblind":
			colorblind = true
		elif a.begins_with("--look="):
			# Debug: wear this look (owned for the run).
			var id := a.trim_prefix("--look=")
			if Looks.is_look(Cosmetics.kind_of(id)):
				owned[id] = true
				set("look_" + Cosmetics.kind_of(id), id)
		elif a.begins_with("--wake="):
			# Debug: leave this trail.
			wake = a.trim_prefix("--wake=")
		elif a == "--all-open":
			all_open = true
		elif a.begins_with("--foresight="):
			foresight_cli = clampi(a.trim_prefix("--foresight=").to_int(), -1, 9)
		elif a.begins_with("--map-here="):
			map_here = a.trim_prefix("--map-here=").to_int() - 1
		elif a.begins_with("--topper="):
			# Debug: wear this on top (owned for the run).
			topper = a.trim_prefix("--topper=")
			owned[topper] = true
		elif a.begins_with("--ride="):
			# Debug: ride this (owned for the run).
			ride = a.trim_prefix("--ride=")
			owned[ride] = true
	Palette.apply(night)
	DrawUtil.bold_marks = colorblind
	Looks.apply(self)
	apply_volume()
	tick()


## Debug: "-- --save=gas:0,coins:350,bank:2,done:22" starts from a made-up save (and never writes one),
## for screenshots and tests. done:N marks levels 1..N finished.
func _apply_preset(preset: String) -> void:
	for part in preset.split(",", false):
		var kv := part.split(":")
		if kv.size() != 2:
			continue
		var v := kv[1].to_int()
		match kv[0]:
			"gas":
				gas = clampi(v, 0, MAX_GAS)
				gas_t = _now() - 437.0
			"coins":
				dollaroos = v
			"bank", "bonus":
				reserve_gas = clampi(v, 0, MAX_RESERVE)
			"done":
				for n in range(1, v + 1):
					completed[n] = true
					if Boss.LOOT.has(n):
						owned[Boss.LOOT[n]] = true
				if v >= LIMITS_FROM:
					seen_new["limits"] = true
					hints = HINTS_START
					radio = RADIO_START
			"momentum":
				momentum = v
			"keys":
				keys = maxi(v, 0)
			"stale":
				# Levels 1..v were beaten on some older version of themselves (the map marks them).
				for n in range(1, v + 1):
					level_fp[n] = 1
			"streak":
				# v finished dailies on the days before today.
				for k in range(1, v + 1):
					daily[Daily.key(Daily.today() - k)] = {"attempts": 1, "done": true, "ok": true, "time": 60.0,
						"order": ["red", "blue", "yellow", "red", "blue"]}
			"today":
				# Today's daily already solved, with v attempts.
				daily[Daily.key(Daily.today())] = {"attempts": maxi(v, 1), "done": true, "ok": true, "time": 83.0,
					"tries": range(1, v).map(func(i: int) -> int: return mini(5, 1 + 2 * i)),
					"order": ["red", "blue", "blue", "yellow", "purple", "red"]}
			"seen":
				# seen:1 (today's daily screen already opened: the map's ribbon goes plain).
				if v > 0:
					daily_seen = Daily.today()
			"intros":
				# intros:1 (every one-time card already seen: road hazards, headlights, gas, the Radio, jets).
				if v > 0:
					for k in ["headlights", "gas", "gas2", "gas_hint", "radio", "jets_tip", "key_tip", "line_lesson", "oneway", "bridge", "multi", "pickup",
							"warehouse", "gate", "hub", "ice", "works", "return", "locker", "daily"]:
						seen_new[k] = true
			"oneway":
				# oneway:1 (a level with one-way streets already seen: the next one shows the symbol tip).
				if v > 0:
					oneway_levels[-1] = true
			"sides":
				# Every side road already beaten (their intros stay away).
				if v > 0:
					for d in SideRoads.defs():
						side_done[str(d.get("id", ""))] = true
			"owned":
				if v > 0:
					for id in Cosmetics.ITEMS:
						owned[id] = true
			"gateads":
				gate_ads = v           # (ads already watched at checkpoints)
			"hints":
				hints = v
			"radio":
				radio = v
			"limits":
				# limits:1 the helpers are metered (0: not yet, whatever's been done).
				if v > 0:
					seen_new["limits"] = true
				else:
					seen_new.erase("limits")
			"changes":
				# changes:1 the Big Changes card is due.
				if v > 0:
					changes_note = {"hints": hints, "radio": radio, "spare": 2, "due": true}
			"rush":
				# rush:1 (a charge of each in hand).
				if v > 0:
					for k in RUSH_SECS:
						rush_held[k] = RUSH_SECS[k]
			"wear":
				# wear:<item id> (owns it and puts it on).
				owned[kv[1]] = true
				put_on(kv[1])


func _load() -> void:
	if not FileAccess.file_exists(save_path()):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	if not d is Dictionary:
		return
	# Saves from before levels 41-90 existed: the old 41-50 are now 91-100.
	var moved := int(d.get("levels_v", 1)) < 2
	for n in d.get("completed", []):
		var k := int(n)
		completed[k + 50 if moved and k >= 41 and k <= 50 else k] = true
	gas = clampi(int(d.get("gas", MAX_GAS)), 0, MAX_GAS)
	gas_t = float(d.get("gas_t", 0.0))
	undo_bank = maxi(int(d.get("undo_bank", 0)), 0)
	dollaroos = int(d.get("dollaroos", 0))
	for id in d.get("owned", []):
		owned[str(id)] = true
	# Chests opened before they held rides (0.7 build 20): their rides arrive now.
	for n in d.get("chests", []):
		var item := str(SideRoads.CHESTS.get(int(n), {}).get("hat", ""))
		if item != "":
			owned[item] = true
	paint = str(d.get("paint", "classic"))
	topper = str(d.get("topper", ""))
	ride = str(d.get("ride", ""))
	var dd = d.get("daily", {})
	if dd is Dictionary:
		daily = dd
	best_streak = int(d.get("best_streak", 0))
	drive_mode = "dpad" if str(d.get("drive_mode", "draw")) in ["dpad", "stick"] else "draw"
	night = bool(d.get("night", false))
	landscape = bool(d.get("landscape", false))
	left_hand = bool(d.get("left_hand", false))
	volume = clampf(float(d.get("volume", 1.0)), 0.0, 1.0)
	haptics = clampf(float(d.get("haptics", 0.7)), 0.0, 1.0)
	stack_side = str(d.get("stack_side", "auto"))
	# Saves from before Auto had "left" as the default: only a choice made since counts.
	if not bool(d.get("stack_chosen", false)) or not stack_side in ["auto", "left", "right", "top", "bottom"]:
		stack_side = "auto"
	queue_moved_seen = bool(d.get("queue_moved_seen", false))
	stack_chosen = bool(d.get("stack_chosen", false))
	last_auto_side = str(d.get("last_auto_side", ""))
	for n in d.get("oneway_levels", []):
		oneway_levels[int(n)] = true
	symbol_tip_seen = bool(d.get("symbol_tip_seen", false))
	exit_tip_seen = bool(d.get("exit_tip_seen", false))
	unlimited_hints = bool(d.get("unlimited_hints", false))
	wake = str(d.get("wake", "wreck"))
	hint_tips = int(d.get("hint_tips", 0))
	hint_ad_watched = bool(d.get("hint_ad_watched", false))
	reserve_gas = 0
	# Bosses already beaten on the main road before they paid out a paint job (Boss.LOOT): theirs now.
	for n in Boss.LOOT:
		if completed.has(int(n)):
			owned[Boss.LOOT[n]] = true
	for pair in [["hints", "free_hints_until"], ["undos", "free_undos_until"]]:
		# Free hints / undos still on the old clock: a rush to start when they like, in their place.
		if float(d.get(pair[1], 0.0)) > _now():
			rush_held[pair[0]] = RUSH_SECS[pair[0]]
	for pair in [["rush_held", rush_held], ["rush_secs", rush_secs], ["rush_full", rush_full]]:
		var got = d.get(pair[0], {})
		if got is Dictionary:
			for k in got:
				if RUSH_SECS.has(str(k)) and float(got[k]) > 0.0:
					pair[1][str(k)] = float(got[k])
	var sb = d.get("speed_best", {})
	if sb is Dictionary:
		for k in sb:
			speed_best[str(k)] = float(sb[k])
	var sbd = d.get("side_bonus_day", {})
	if sbd is Dictionary:
		for k in sbd:
			side_bonus_day[str(k)] = int(sbd[k])
	peek = bool(d.get("peek", false))
	colorblind = bool(d.get("colorblind", false))
	# Saves from before 0.7 build 15 had the trail on by default: it starts off once for everyone.
	trail = bool(d.get("trail", false)) and int(d.get("prefs_v", 0)) >= 1
	ghost_path = bool(d.get("ghost_path", false))
	hoardly_ads = bool(d.get("hoardly_ads", true))
	notify_chosen = bool(d.get("notify_chosen", false))
	daily_seen = int(d.get("daily_seen", -1))
	notify_updates = bool(d.get("notify_updates", true))
	notify_streak = bool(d.get("notify_streak", true))
	notify_fresh = bool(d.get("notify_fresh", true))
	notify_after = int(d.get("notify_after", -1))
	rate_levels = bool(d.get("rate_levels", false))
	play_stats = bool(d.get("play_stats", true))
	device_id = str(d.get("device_id", ""))
	rate_asked = bool(d.get("rate_asked", false))
	all_open = all_open or bool(d.get("all_open", false))
	foresight = clampi(int(d.get("headlights", -1)), -1, 9)
	seen_new = d.get("seen_new", {}) if d.get("seen_new", {}) is Dictionary else {}
	skipped.clear()
	for n in d.get("skipped", []):
		skipped[int(n)] = true
	for k in Looks.KINDS:
		var v := str(d.get("look_" + k, Looks.DEFAULTS[k]))
		set("look_" + k, v if Cosmetics.kind_of(v) == k else Looks.DEFAULTS[k])
	var sd = d.get("side_done", {})
	if sd is Dictionary:
		side_done = sd
	for n in d.get("chests", []):
		chests[int(n)] = true
	for n in d.get("og_done", []):
		og_done[int(n)] = true
	keys = maxi(0, int(d.get("keys", 0)))
	for n in d.get("keys_found", []):
		keys_found[int(n)] = true
	for id in d.get("sides_unlocked", []):
		sides_unlocked[str(id)] = true
	var lf = d.get("level_fp", {})
	if lf is Dictionary:
		for k in lf:
			level_fp[int(k)] = int(lf[k])
	# 0.7 build 23 redesigned every level from 5 to 100. A save from before that beat the old ones: they show
	# as UPDATED on the map until they're beaten again. (Saves that already kept fingerprints
	# show it by themselves; this is for the ones that didn't.)
	if int(d.get("levels_v", 1)) < 3:
		for n in completed:
			if int(n) >= 5 and int(n) <= 100 and not level_fp.has(int(n)):
				level_fp[int(n)] = 1
	if int(d.get("levels_v", 1)) < 4:
		_renumber_v4()
	_load_helpers(d)
	for k in d.get("checkpoints", []):
		checkpoints[int(k)] = true
	ads_seen = int(d.get("ads_seen", 0))
	gate_ads = int(d.get("gate_ads", 0))
	var ra = d.get("recent_ads", [])
	if ra is Array:
		for x in ra:
			recent_ads.append(str(x))
	licensed = bool(d.get("licensed", false))
	jets = bool(d.get("jets", false))
	var mg = d.get("mega", {})
	if mg is Dictionary:
		for k in mg:
			mega[str(k)] = int(mg[k])
	seen_version = str(d.get("seen_version", ""))


func _save() -> void:
	if volatile:
		return
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"levels_v": 4, "prefs_v": 1, "completed": completed.keys(), "gas": gas, "gas_t": gas_t,
			"undo_bank": undo_bank, "dollaroos": dollaroos, "owned": owned.keys(), "paint": paint, "topper": topper, "ride": ride,
			"daily": daily, "best_streak": best_streak, "drive_mode": drive_mode,
			"night": night, "landscape": landscape, "left_hand": left_hand, "volume": volume, "haptics": haptics,
			"stack_side": stack_side, "stack_chosen": stack_chosen, "queue_moved_seen": queue_moved_seen, "last_auto_side": last_auto_side, "oneway_levels": oneway_levels.keys(), "symbol_tip_seen": symbol_tip_seen, "exit_tip_seen": exit_tip_seen, "unlimited_hints": unlimited_hints, "wake": wake, "hint_tips": hint_tips, "hint_ad_watched": hint_ad_watched,
			"hints": hints, "radio": radio, "changes_note": changes_note, "rush_held": rush_held, "rush_secs": rush_secs, "rush_full": rush_full, "side_bonus_day": side_bonus_day, "speed_best": speed_best, "peek": peek, "seen_version": seen_version,
			"colorblind": colorblind, "trail": trail, "ghost_path": ghost_path, "hoardly_ads": hoardly_ads, "notify_chosen": notify_chosen, "notify_after": notify_after, "daily_seen": daily_seen, "notify_updates": notify_updates, "notify_streak": notify_streak, "notify_fresh": notify_fresh, "rate_levels": rate_levels, "play_stats": play_stats, "device_id": device_id, "rate_asked": rate_asked, "skipped": skipped.keys(), "seen_new": seen_new, "all_open": all_open, "headlights": foresight, "look_package": look_package, "look_building": look_building, "look_queue": look_queue, "look_road": look_road, "look_controls": look_controls, "side_done": side_done, "chests": chests.keys(), "keys": keys, "og_done": og_done.keys(), "keys_found": keys_found.keys(), "sides_unlocked": sides_unlocked.keys(), "level_fp": _fp_out(),
			"mega": mega, "jets": jets, "checkpoints": checkpoints.keys(), "ads_seen": ads_seen, "gate_ads": gate_ads, "recent_ads": recent_ads, "licensed": licensed}))


func _now() -> float:
	return Time.get_unix_time_from_system()


# ---------------------------------------------------------------- levels

func is_complete(n: int) -> bool:
	return completed.has(n)


## Packages delivered, all told: every package in every job, detour, daily and OG level won, each counted
## once (a replay delivers nothing new). It's what opens zones (Zones.need) and unlocks trails and looks
## (Cosmetics.need_for).
func delivered() -> int:
	var t := 0
	for n in completed:
		t += Levels.packages(int(n))
	for id in side_done:
		t += Levels.side_packages(str(id))
	for k in daily:
		if daily[k] is Dictionary and daily[k].get("done", false):
			t += (daily[k].get("order", []) as Array).size()
	for n in og_done:
		t += Levels.og_packages(int(n))
	return t


## Records a win on the version of the level with fingerprint `fp` (LevelData.fp). Returns the Dollaroos it
## paid (already added to the balance): the full pay the first time (or the first time since a redesign),
## a tip for a replay.
func mark_complete(n: int, fp := 0) -> int:
	if skipped.has(n):
		skipped.erase(n)
	var fresh := not completed.has(n) or (fp != 0 and is_stale(n, fp))
	if fp != 0:
		level_fp[n] = fp
	completed[n] = true
	var pay: int = FIRST_PAY if fresh else REPLAY_TIP
	if not COINS:
		pay = 0
	dollaroos += pay
	_save()
	changed.emit()
	return pay


## An OG 100 level won (its packages count; no Dollaroos, no keys).
func og_win(n: int) -> void:
	if not og_done.has(n):
		og_done[n] = true
		_save()


## 0.7 build 25 re-planned the first twenty jobs: three practice jobs went in (5, 8, 10), three came out
## (the old 16, 18 and 19), and the ones between took new numbers. A save from before carries over: each
## job beaten, skipped or with a key found moves to its new number; a cut job's record goes; and a practice
## job counts as done for anyone who'd already beaten the job that now follows it. (Old job 6 is the new 7
## with a new layout, so it shows UPDATED by itself.)
const MOVED_V4 := {5: 6, 6: 7, 7: 9, 8: 11, 9: 12, 10: 13, 11: 14, 12: 19, 13: 15, 14: 16, 15: 17, 17: 18}
const CUT_V4 := [16, 18, 19]
const NEW_V4 := {5: 6, 8: 9, 10: 11}        # practice job -> the job after it

func _renumber_v4() -> void:
	for book in [completed, skipped, keys_found, level_fp, oneway_levels]:
		var moved := {}
		for n in book.keys():
			var k := int(n)
			if CUT_V4.has(k):
				continue
			moved[int(MOVED_V4.get(k, k))] = book[n]
		book.clear()
		for k in moved:
			book[k] = moved[k]
	for n in NEW_V4:
		if completed.has(int(NEW_V4[n])):
			completed[n] = true
			skipped.erase(n)


## Beaten, but on an older version of the level than the one with fingerprint `fp`. Levels beaten before
## fingerprints were kept (0.7 build 22) take the version they're first seen with as the one they were
## beaten on.
func is_stale(n: int, fp: int) -> bool:
	if not completed.has(n) or fp == 0:
		return false
	if not level_fp.has(n):
		level_fp[n] = fp
		if not _fp_save_queued:
			_fp_save_queued = true
			_save.call_deferred()
		return false
	return int(level_fp[n]) != fp


## Index (0-based) of the first level not yet completed.
## Put a level aside for now: the van moves on past it, and it waits on the map.
func skip(n: int) -> void:
	skipped[n] = true
	_save()


## Jump jets are free, but only so many jobs can be left waiting on the map at once (a jumped job comes off
## the list when it's delivered): that, not gas, is what a jump costs.
const JUMPS_WAITING_MAX := 3

func jumps_waiting() -> int:
	return skipped.size()


func first_incomplete(count: int) -> int:
	for i in count:
		if not is_complete(i + 1):
			return i
	return 0


func reset() -> void:
	hints = 0
	radio = 0
	changes_note = {}
	completed.clear()
	skipped.clear()
	seen_new.clear()
	gas = MAX_GAS
	gas_t = 0.0
	undo_bank = 0
	dollaroos = 0
	owned.clear()
	paint = "classic"
	topper = ""
	ride = ""
	wake = "wreck"           # (a trail unlocked by packages goes with them)
	daily.clear()
	best_streak = 0
	momentum = 0
	side_done.clear()
	chests.clear()
	mega.clear()
	speed_best.clear()
	checkpoints.clear()
	ads_seen = 0
	gate_ads = 0
	recent_ads.clear()
	rush_held.clear()
	rush_secs.clear()
	rush_full.clear()
	# A fresh start in full (Testers > Reset progress): keys, unlocked detours, the OG run, which layouts were
	# beaten, where the van waits. Settings, the rating id and the looks being worn stay.
	keys = 0
	keys_found.clear()
	sides_unlocked.clear()
	og_done.clear()
	level_fp.clear()
	map_here = -1
	zone_opened = -1
	for k in Looks.KINDS:
		set("look_" + k, Looks.DEFAULTS[k])
	_save()
	changed.emit()


# ---------------------------------------------------------------- gas

## Where the gas stands at time `now`: [tanks, start of the tank now refilling]. Pure, so it can be tested.
static func regen(tanks: int, since: float, now: float) -> Array:
	if tanks >= MAX_GAS:
		return [MAX_GAS, now]
	# A clock set backwards doesn't earn or lose anything: the wait starts again.
	if since <= 0.0 or since > now:
		return [tanks, now]
	var got := int(floor((now - since) / GAS_SECONDS))
	if tanks + got >= MAX_GAS:
		return [MAX_GAS, now]
	return [tanks + got, since + got * GAS_SECONDS]


## Tops up any tanks that have come back since the last look.
func tick() -> void:
	var r := regen(gas, gas_t, _now())
	if r[0] != gas:
		gas = r[0]
		gas_t = r[1]
		_save()
		changed.emit()
	else:
		gas_t = r[1]


## Seconds until the next tank arrives (0 when full).
func seconds_to_next() -> int:
	if gas >= MAX_GAS:
		return 0
	return maxi(1, int(ceil(gas_t + GAS_SECONDS - _now())))


## Cans in the tank.
func total_gas() -> int:
	tick()
	return gas


## Cans into the tank, as many as fit.
func add_bonus_gas(n: int) -> void:
	tick()
	gas = mini(gas + n, MAX_GAS)
	_save()
	changed.emit()


## The tank filled to the top (an ad; a prize). Returns how many cans went in.
func refuel() -> int:
	tick()
	var got := MAX_GAS - gas
	gas = MAX_GAS
	gas_t = _now()
	_save()
	changed.emit()
	return got


## A prize that fills the tank: if it's full already, a hint instead. Returns what it was, in words.
func refuel_or_hint() -> String:
	tick()
	if gas >= MAX_GAS:
		add_hints(1)
		return "+1 hint"
	refuel()
	return "Tank filled up"


func add_hints(n: int) -> void:
	hints = maxi(0, hints + n)
	_save()
	changed.emit()


func add_radio(n: int) -> void:
	radio = maxi(0, radio + n)
	_save()
	changed.emit()


## Have the helpers been metered yet (the Baron's scene)? Before that everything's unlimited. The self-tests
## play as if they have ("-- --helpers-free": as a new player).
func limits_on() -> bool:
	if OS.get_cmdline_user_args().has("--helpers-free"):
		return false
	return seen_new.has("limits") or auto


## The Baron meters the helpers: from here hints and the Radio are counted, starting with these.
func start_limits() -> void:
	if seen_new.has("limits"):
		return
	seen_new["limits"] = true
	hints = maxi(hints, HINTS_START)
	radio = maxi(radio, RADIO_START)
	_save()
	changed.emit()


## An old save meets the carried helpers (and one from before the Baron's scene that's already past it).
func _load_helpers(d: Dictionary) -> void:
	hints = int(d.get("hints", -1))
	radio = int(d.get("radio", -1))
	var cn = d.get("changes_note", {})
	changes_note = cn if cn is Dictionary else {}
	if hints >= 0 and radio >= 0:
		return
	hints = maxi(hints, 0)
	radio = maxi(radio, 0)
	# Spare tanks (and the old undo ad's spare undos) go into the bigger tank; what won't fit becomes hints.
	var spare := maxi(int(d.get("reserve_gas", 0)), 0) + maxi(undo_bank, 0)
	undo_bank = 0
	var fits := mini(spare, MAX_GAS - gas)
	gas += fits
	if not (completed.has(LIMITS_FROM) or completed.size() >= LIMITS_FROM):
		return                      # (still in the tutorial: the Baron's scene is ahead of them)
	# Past the first boss already: metered from here, with the starting counts, a Radio call for every job
	# done since, and a hint for each spare tank there wasn't room for. The Big Changes card says so.
	seen_new["limits"] = true
	hints = HINTS_START + (spare - fits)
	radio = RADIO_START + mini(completed.size() / 4, 15)
	# (A rush of free undos in hand is worth nothing now: Radio calls for it.)
	if rush_held.has("undos") or rush_secs.has("undos"):
		rush_held.erase("undos")
		rush_secs.erase("undos")
		rush_full.erase("undos")
		radio += 5
	changes_note = {"hints": hints, "radio": radio, "spare": spare, "due": true}


## Uses a tank: a bonus one first (so the gauge keeps refilling), then one off the gauge. False (and nothing
## spent) when there are none at all.
## How often a tank comes back, in words ("hour", "30 minutes").
func refill_every() -> String:
	var m := GAS_SECONDS / 60
	if m % 60 == 0:
		return "hour" if m == 60 else "%d hours" % (m / 60)
	return "%d minutes" % m


func spend_gas() -> bool:
	tick()
	if gas <= 0:
		return false
	if gas >= MAX_GAS:
		gas_t = _now()
	gas -= 1
	_save()
	changed.emit()
	return true


func earn(n: int) -> void:
	if not COINS:
		return
	dollaroos += n
	_save()
	changed.emit()


## A won level hands a tank back (never past a full tank).
func refund_gas() -> void:
	tick()
	if gas >= MAX_GAS:
		return
	gas += 1
	if gas >= MAX_GAS:
		gas_t = _now()
	_save()
	changed.emit()


## The pretend purchase: a full tank for TANK_PRICE Dollaroos (onto the tab if there aren't enough).
func buy_full_tank() -> void:
	dollaroos -= TANK_PRICE
	gas = MAX_GAS
	gas_t = _now()
	_save()
	changed.emit()


# ---------------------------------------------------------------- undos

func add_undos(n: int) -> void:
	undo_bank += n
	_save()
	changed.emit()


func use_bank_undo() -> bool:
	if undo_bank <= 0:
		return false
	undo_bank -= 1
	_save()
	changed.emit()
	return true


# ---------------------------------------------------------------- cosmetics

## Testers > Unlock all cosmetics: every ride, paint, topper, trail and look is yours (none is put on).
func unlock_all_cosmetics() -> int:
	var n := 0
	for id in Cosmetics.ITEMS:
		if not owned.has(id):
			owned[id] = true
			n += 1
	_save()
	changed.emit()
	return n


func owns(id: String) -> bool:
	if Cosmetics.kind_of(id) == "topper":
		return true                 # (shelved, and nobody has to find them: they're all theirs when they're back)
	if Cosmetics.by_count(id):
		return owned.has(id) or (Cosmetics.need_for(id) >= 0 and delivered() >= Cosmetics.need_for(id))
	return id == "classic" or owned.has(id)


## Adds a cosmetic found on the road. True if it's new. It isn't worn until the player chooses to
## (the unlock card offers "Wear it now"; the garage too).
func give(id: String) -> bool:
	if owns(id):
		return false
	owned[id] = true
	_save()
	changed.emit()
	return true


## Is the player wearing this right now?
func wearing(id: String) -> bool:
	var kind := Cosmetics.kind_of(id)
	if Looks.is_look(kind):
		return str(get("look_" + kind)) == id
	return paint == id or topper == id or ride == id or wake == id


## Everything the van and the town are wearing right now (for an undo: restore_look).
func look_snapshot() -> Dictionary:
	var d := {"paint": paint, "topper": topper, "ride": ride, "wake": wake}
	for k in Looks.KINDS:
		d["look_" + k] = get("look_" + k)
	return d


func restore_look(d: Dictionary) -> void:
	for k in d:
		set(k, d[k])
	Looks.apply(self)
	_save()
	changed.emit()


## Puts an owned item on (never takes it off, unlike wear()).
func put_on(id: String) -> void:
	if not wearing(id):
		wear(id)


func set_drive_mode(m: String) -> void:
	drive_mode = m
	_save()
	settings_changed.emit()


## Changes one option (by field name) and saves it. Sound applies here; the rest is up to whoever listens.
func set_option(key: String, value: Variant) -> void:
	set(key, value)
	if key == "volume":
		apply_volume()
	elif key == "colorblind":
		DrawUtil.bold_marks = colorblind
	_save()
	settings_changed.emit()


func _fp_out() -> Dictionary:
	_fp_save_queued = false
	var out := {}
	for k in level_fp:
		out[str(k)] = level_fp[k]
	return out


## Saves straight away (for flags set outside the usual changes, like a tip being shown).
func save_now() -> void:
	_save()


## Hints each level starts with: one, plus one per opened chest that holds a hint (levels 10 and 20).
const MAX_HINT_SLOTS := 3


## Are the headlights on (the van follows the finger), rather than Off (plan the whole route, then drive)?
func lights_on() -> bool:
	return (foresight_cli if foresight_cli > -99 else foresight) != 0


## How far the headlights reach right now: tiles of route that can be plotted ahead of the van (with them
## on; 0 is none at all, the tutorial's dark: the van drives right under the finger).
func sight() -> int:
	var f := foresight_cli if foresight_cli > -99 else foresight
	return headlights() if f < 0 else f


## Are the headlights on and as bright as the player has earned (not off, not fixed at a number)?
func lights_earned() -> bool:
	return (foresight_cli if foresight_cli > -99 else foresight) < 0


const MAX_LIGHTS := 5
const MAX_UNDO_SLOTS := 5
const LIGHT_NAMES := ["No lights", "Dim headlights", "Headlights", "High beams", "Rally lights", "Lighthouse"]

## Where the van finds its first headlights (in a present on the road, a forced tile between its two
## deliveries: levels.json "gift" "headlights"; opened after the win, BuffCard).
const LIGHTS_LEVEL := 2

## Headlights earned (1 to MAX_LIGHTS): the van finds dim ones on job LIGHTS_LEVEL (before that, it's driven
## in the dark); the early boss fights on the
## main road (Boss.CORE) give the next two; a boss detour guarding a set ("buff": {"lights": 1} in
## levels/side.json) and finishing every speedrun course give the last, optional ones.
func headlights() -> int:
	if not is_complete(LIGHTS_LEVEL):
		return 0            # the tutorial's first jobs are driven in the dark; the headlights are found on job 2
	var n := 1 + _buffs("lights")
	if speedruns_done():
		n += 1
	return mini(n, MAX_LIGHTS)


## Undos each try at a level starts with: one, and one more from each boss guarding one (Boss.CORE).
func undo_slots() -> int:
	return mini(1 + _buffs("undos"), MAX_UNDO_SLOTS)


func _buffs(kind: String) -> int:
	var n := 0
	for b in Boss.CORE:
		if is_complete(int(b)):
			n += int(Boss.CORE[b].get("buff", {}).get(kind, 0))
	for d in SideRoads.defs():
		if side_done.has(str(d.get("id", ""))) and d.get("buff", {}) is Dictionary:
			n += int(d.get("buff", {}).get(kind, 0))
	return n


## Has every speedrun course been finished at least once?
func speedruns_done() -> bool:
	if Speedrun.defs().is_empty():
		return false
	for c in Speedrun.defs():
		if not speed_best.has(str(c.get("id", ""))):
			return false
	return true


static func light_name(n: int) -> String:
	return LIGHT_NAMES[clampi(n, 0, MAX_LIGHTS)]


## The jump jets (skip a job for a tank of gas: Game, ExitRibbon). Their row is on the ribbon from the
## start, locked ("do not open till job JETS_FROM"); beating the boss just before it hands them over, on the
## finish (Game._win, JetsCard). Anyone past it without them gets a present with a bow, theirs to tap
## open whenever they notice it. Left unopened long enough, the game opens it for them (Game._jets_push).
const JETS_FROM := 12              # (beating job 11 hands them over: Game._win)
## The seen_new key for the gas explainer (GasExplainer). "gas2": the prices changed (a tank no longer makes
## hints unlimited: it buys one), so players who saw the old card see the new one once.
const GAS_SEEN := "gas2"
const GAS_HINT_SEEN := "gas_hint"     # ...and the card for a hint's price (a tank each), seen apart from it
## The Radio's button is on the bar: the road's reached job RADIO_FROM.
func has_radio() -> bool:
	return is_complete(RADIO_FROM - 1) or is_complete(RADIO_FROM) or all_open or auto or OS.get_cmdline_user_args().has("--radio")

var jets := false

func has_jets() -> bool:
	return jets or all_open or OS.get_cmdline_user_args().has("--jets")      # (--jets: debug, for screenshots)


func grant_jets() -> void:
	if not jets:
		jets = true
		_save()
		changed.emit()


## (Hints used to be so many a job, more with each chest: they're a carried count now, `hints`.)
func hint_slots() -> int:
	return hints


func free_hints() -> bool:
	return rush_left("hints") > 0.0


func free_undos() -> bool:
	return rush_left("undos") > 0.0


## Seconds left of a rush that's running (0: it isn't).
func rush_left(kind: String) -> float:
	return maxf(0.0, float(rush_secs.get(kind, 0.0)))


## A charge of this kind is in hand, not started (and none's running).
func rush_ready(kind: String) -> bool:
	return float(rush_held.get(kind, 0.0)) > 0.0 and rush_left(kind) <= 0.0


## The charge in hand starts. Returns the seconds it runs for (0: there wasn't one).
func rush_start(kind: String) -> float:
	if not rush_ready(kind):
		return 0.0
	var secs := float(rush_held[kind])
	rush_held.erase(kind)
	rush_secs[kind] = secs
	rush_full[kind] = secs
	_save()
	changed.emit()
	return secs


## A running rush's clock (Game calls this while a job's being played). Returns the kinds that just ran out.
func rush_tick(delta: float) -> Array:
	var over := []
	for kind in rush_secs.keys():
		rush_secs[kind] = float(rush_secs[kind]) - delta
		if float(rush_secs[kind]) <= 0.0:
			rush_secs.erase(kind)
			rush_full.erase(kind)
			over.append(kind)
	if not over.is_empty():
		_save()
		changed.emit()
	return over


## Keeps a running rush's clock (leaving a job, or now and then while it runs).
func rush_keep() -> void:
	if not rush_secs.is_empty():
		_save()


## "2:00", "0:47".
static func clock(secs: float) -> String:
	var n := maxi(0, int(ceil(secs)))
	return "%d:%02d" % [n / 60, n % 60]


## A detour's bonus, in a few words, for its card on the map ("" if it has none to give right now).
func side_bonus_says(id: String, bonus: Dictionary) -> String:
	var kind := str(bonus.get("kind", ""))
	if kind == "reserve":
		return "" if side_bonus_day.has(id) else "a full tank (or a hint, if it's full)"
	if side_bonus_day.has(id):
		return ""
	if kind == "radio":
		return "+%d calls" % int(bonus.get("amount", 1))
	if kind == "hint":
		return "+%d hint%s" % [int(bonus.get("amount", 1)), "" if int(bonus.get("amount", 1)) == 1 else "s"]
	if not RUSH_SECS.has(kind) or int(side_bonus_day.get(id, -1)) == Daily.today() or rush_ready(kind):
		return ""
	return "%s (%s of free %s)" % [RUSH_NAME[kind], clock(rush_len(bonus)), kind]


## How long a detour's rush runs: the kind's seconds, half as long again for the big ones (amount 15).
func rush_len(bonus: Dictionary) -> float:
	return float(RUSH_SECS.get(str(bonus.get("kind", "")), 0.0)) * (1.5 if int(bonus.get("amount", 10)) >= 15 else 1.0)


## A detour won: its power-up. A rush of free hints or undos (a charge to start when they like: one of each
## in hand at most) comes once a day per detour; a tank of gas only the first time it's ever won (gas is
## scarce: Small Tank can't be farmed for it). Returns a line saying what it gave ("" for none).
func side_power_up(id: String, bonus: Dictionary) -> String:
	var today := Daily.today()
	if bonus.is_empty() or int(side_bonus_day.get(id, -1)) == today:
		return ""
	# (Every detour's prize is for the first time it's won: none of them can be farmed day after day.)
	if side_bonus_day.has(id):
		return ""
	var kind := str(bonus.get("kind", ""))
	if RUSH_SECS.has(kind) and float(rush_held.get(kind, 0.0)) > 0.0:
		return ""                  # (one's in hand already: today's is still there to win once it's used)
	side_bonus_day[id] = today
	var n := int(bonus.get("amount", 1))
	var said := ""
	match kind:
		"reserve":
			said = refuel_or_hint()
		"radio":
			radio += n
			said = "+%d calls" % n
		"hint":
			hints += n
			said = "+%d hint%s" % [n, "" if n == 1 else "s"]
		"hints", "undos":
			rush_held[kind] = rush_len(bonus)
			said = "%s: %s of free %s" % [RUSH_NAME[kind], clock(rush_len(bonus)), kind]
	_save()
	changed.emit()
	return said


## A side road (SideRoads definition) opens once the level it branches off is beaten.
func side_open(d: Dictionary) -> bool:
	return is_complete(int(d.get("after", 0)))


## A side road that needs a key ("locked" in side.json) and hasn't had one used on it (one already
## beaten stays open).
func side_locked(d: Dictionary) -> bool:
	var id := str(d.get("id", ""))
	return bool(d.get("locked", false)) and not sides_unlocked.has(id) and not side_done.has(id)


## The key on level `n` was picked up on a win. False if that level's key was already found.
func find_key(n: int) -> bool:
	if keys_found.has(n):
		return false
	keys_found[n] = true
	keys += 1
	_save()
	changed.emit()
	return true


## Uses a key on side road `id`. False with none in hand.
func use_key(id: String) -> bool:
	if keys <= 0 or sides_unlocked.has(id):
		return false
	keys -= 1
	sides_unlocked[id] = true
	_save()
	changed.emit()
	return true


## A speedrun course finished in `secs`. True if that's a new best.
func speed_record(id: String, secs: float) -> bool:
	if speed_best.has(id) and float(speed_best[id]) <= secs:
		return false
	speed_best[id] = secs
	_save()
	return true


## A side challenge beaten. True the first time.
func win_side(id: String) -> bool:
	var first := not side_done.has(id)
	side_done[id] = true
	_save()
	changed.emit()
	return first


## Which part of a mega route to play next (0 when starting fresh).
func mega_part(id: String) -> int:
	return int(mega.get(id, 0))


## A mega route's part done: the next one's where it picks up (the route done: back to the start).
func set_mega_part(id: String, k: int) -> void:
	if k <= 0:
		mega.erase(id)
	else:
		mega[id] = k
	_save()


func chest_open(n: int) -> bool:
	return chests.has(n)


## Opens the chest at milestone level `n`: tops up the tank (a can that won't fit pays out in Dollaroos),
## adds its Dollaroos and gives its hat. Returns what it gave: {gas, coins, hat (or "")}.
func open_chest(n: int) -> Dictionary:
	var c: Dictionary = SideRoads.CHESTS.get(n, {})
	if c.is_empty() or chests.has(n):
		return {}
	tick()
	# A chest fills the tank (a hint instead, if it's full already), and has Radio calls and maybe hints in it.
	var hints_before := hints
	var filled := 0
	if int(c.get("gas", 0)) > 0:
		if gas >= MAX_GAS:
			hints += 1
		else:
			filled = MAX_GAS - gas
			gas = MAX_GAS
			gas_t = _now()
	hints += int(c.get("hints", 0))
	var calls := int(c.get("radio", 0))
	radio += calls
	var coins := int(c.get("coins", 0)) if COINS else 0
	dollaroos += coins
	var hat := str(c.get("hat", ""))
	var new_hat := ""
	if hat != "" and not owned.has(hat):
		owned[hat] = true
		new_hat = hat
	chests[n] = true
	_save()
	changed.emit()
	return {"gas": filled, "coins": coins, "hat": new_hat, "cashed": 0, "hints": hints - hints_before, "radio": calls}


## The patch notes for version `v` have been opened (the title badge stops glowing).
func see_version(v: String) -> void:
	if seen_version != v:
		seen_version = v
		_save()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)


func wear(id: String) -> void:
	var kind: String = Cosmetics.ITEMS.get(id, {}).get("kind", "")
	if kind == "paint" and owns(id):
		paint = id
	elif kind == "topper":
		topper = "" if topper == id else id
	elif kind == "ride" and owns(id):
		ride = "" if ride == id else id
	elif kind == "trail" and owns(id):
		wake = id
	elif Looks.is_look(kind) and owns(id):
		set("look_" + kind, id)
		Looks.apply(self)
	_save()
	changed.emit()


# ---------------------------------------------------------------- daily

func daily_record(day: int) -> Dictionary:
	return daily.get(Daily.key(day), {})


## Another go at today's puzzle (the first start, or a redo). The try before it is filed under "tries":
## how far it got (for the share, Daily.rows). False (and nothing counted) once Daily.MAX_TRIES are spent.
func daily_attempt(day: int) -> bool:
	var k := Daily.key(day)
	var r: Dictionary = daily.get(k, {"attempts": 0, "done": false})
	if r.get("done", false):
		return true
	if Daily.out_of_tries(r):
		return false
	if int(r.get("attempts", 0)) > 0:
		var tries: Array = r.get("tries", [])
		tries.append(int(r.get("reach", 0)))
		r["tries"] = tries
	r["reach"] = 0
	r["attempts"] = int(r.get("attempts", 0)) + 1
	daily[k] = r
	_save()
	changed.emit()
	return true


## A (pretend) ad watched to the end or skipped (gas, the gas station): the next checkpoint waves you through.
## An ad's about to play (AdPicker id): remembered, the last AdPicker.RECENT of them.
func saw_ad(id: String) -> void:
	recent_ads.erase(id)
	recent_ads.append(id)
	while recent_ads.size() > AdPicker.RECENT:
		recent_ads.pop_front()
	_save()


## An ad's been watched at a checkpoint.
func gate_ad_watched() -> void:
	gate_ads += 1
	_save()


func ad_watched() -> void:
	ads_seen += 1
	_save()


## Zone `k`'s checkpoint is behind you; the count of ads watched starts again.
func checkpoint_passed(k: int) -> void:
	checkpoints[k] = true
	ads_seen = 0
	_save()


## Today's solved puzzle has been shared (the begging stops for the day).
func daily_shared(day: int) -> void:
	var r: Dictionary = daily.get(Daily.key(day), {})
	if r.is_empty() or r.get("shared", false):
		return
	r["shared"] = true
	_save()


## The daily try under way has delivered `n` packages (its furthest is kept).
func daily_reached(day: int, n: int) -> void:
	var r: Dictionary = daily.get(Daily.key(day), {})
	if r.is_empty() or r.get("done", false) or n <= int(r.get("reach", 0)):
		return
	r["reach"] = n
	_save()


## Today's puzzle is solved: it counts toward the streak, however many tries it took. `extra` is how the
## winning try went ({tiles, undos, shortest}); the badges and score come from it (Daily.earn).
## Seconds a daily try took that didn't solve it (a Retry, or walking away): kept on the day's record as
## "spent", so the solve's time is the whole day's attempt, not just the winning try.
func daily_add_time(day: int, secs: float) -> void:
	var k := Daily.key(day)
	var r: Dictionary = daily.get(k, {})
	if r.is_empty() or r.get("done", false) or secs <= 0.0:
		return
	r["spent"] = float(r.get("spent", 0.0)) + secs
	daily[k] = r
	_save()


## Today's time on a daily so far: the unsolved tries' seconds, plus `now` (the try in hand).
func daily_time(day: int, now: float) -> float:
	return float(daily.get(Daily.key(day), {}).get("spent", 0.0)) + now


func daily_done(day: int, secs: float, order: Array, extra := {}) -> void:
	var k := Daily.key(day)
	var r: Dictionary = daily.get(k, {"attempts": 1})
	if r.get("done", false):
		return
	r["done"] = true
	r["ok"] = true
	r["time"] = secs
	r["order"] = order
	r.erase("reach")
	if notify_after < 0:
		notify_after = completed.size() + NotifyPrefs.LEVELS_LATER
	r["clock"] = Notify.now_minutes()   # local time of day it was solved: tomorrow's reminder comes then
	for key in extra:
		r[key] = extra[key]
	daily[k] = r
	best_streak = maxi(best_streak, streak(day))
	var prior := []
	for other in daily:
		if other != k and daily[other] is Dictionary and daily[other].has("score"):
			prior.append(int(daily[other]["score"]))
	var e := Daily.earn(r, prior, streak(day))
	r["badges"] = e["ids"]
	r["score"] = e["score"]
	r["streak"] = streak(day)
	_save()
	Notify.refresh(self)
	changed.emit()


## Days in a row solved, ending today (or yesterday, while today can still be solved). Any number of tries
## counts; spending all Daily.MAX_TRIES without solving it ends the streak.
func streak(today: int) -> int:
	var r := daily_record(today)
	var day := today
	if not r.get("done", false):
		if Daily.out_of_tries(r):
			return 0
		day = today - 1
	var n := 0
	while daily_record(day).get("done", false):
		n += 1
		day -= 1
	return n


## 12345 -> "12,345" (and -1500 -> "-1,500").
static func commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
