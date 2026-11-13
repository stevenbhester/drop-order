extends Node
## Autoload "Progress": everything saved to user://save.json.
## - which levels are completed, and the best stars on each
## - gas tanks (a retry costs one; one comes back every GAS_SECONDS, up to MAX_GAS)
## - spare undos earned by watching the (fake) ad
## - Door Bowl Dollaroos: pretend money, earned by finishing levels and "spent" on gas.
## - cosmetics found on the road (paints and toppers for the van) and which are being worn
## - the daily puzzle: one record per day (attempts, result), and the streak built from them
## Momentum (wins in a row this session) lives here too but is never saved: it's per session.
##   Nothing here is real money and nothing is ever charged; the balance can go negative ("the tab").

signal changed
## A setting changed (options menu): night mode, sound, haptics, steering, hand, orientation.
signal settings_changed

const PATH := "user://save.json"
const MAX_GAS := 5
const GAS_SECONDS := 20 * 60
const TANK_PRICE := 1500
const AD_UNDOS := 3
## Dollaroos for finishing a level, by stars (index 1..3), and the tip for replaying one.
const STAR_REWARD := [0, 100, 200, 300]
const REPLAY_TIP := 10

var completed := {}
var stars := {}            # level number -> best stars (1..3)
var gas := MAX_GAS
var gas_t := 0.0           # unix time the tank now refilling started
var undo_bank := 0
var dollaroos := 0
var owned := {}            # cosmetic id -> true
var paint := "classic"
var topper := ""
var ride := ""             # "" = the van; else a Cosmetics "ride" id
var daily := {}            # "2026-11-10" -> {attempts, done, ok, stars, time, order, clock}
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
## Option: hints never run out (no ads needed). They still cost a star.
var unlimited_hints := false
## How many times the "out of hints" tip has shown (it stops after three), and whether they've ever
## watched a hint ad (then it never shows again).
var hint_tips := 0
var hint_ad_watched := false
## Side-road power-ups: spare gas tanks (only used once the tank's empty; at most MAX_RESERVE), and
## free hints / free undos until these times (Unix seconds). A side road hands one out once a day.
const MAX_RESERVE := 3
var reserve_gas := 0
var free_hints_until := 0.0
var free_undos_until := 0.0
var side_bonus_day := {}           # side road id -> the day it last handed out its power-up
## Speedrun: best time per course (seconds).
var speed_best := {}

var peek := false
## Colorblind mode ("aka Paul mode"): bold class marks on packages, and the same mark on a sign on every
## building and gate, so nothing depends on telling colours apart.
var colorblind := false
## The package trail: the next few packages on drones behind the van (off unless switched on).
var trail := false
## Side roads: challenges beaten (id -> true) and milestone chests opened (level number -> true).
var side_done := {}
var chests := {}
## Mega routes: parts finished so far on the current run (id -> count; gone once the route's done).
var mega := {}
## Patch notes last seen from the title screen's version badge (the badge glows for a newer one).
var seen_version := ""
## Wins in a row this session without retrying or abandoning a level. Not saved.
var momentum := 0
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
		elif a.begins_with("--save="):
			volatile = true
			preset = a.trim_prefix("--save=")
	if not volatile:
		_load()
	_apply_preset(preset)
	for a in OS.get_cmdline_user_args():
		# Debug: --night, --landscape, --lefty set those options for this run (without saving them).
		if a == "--night":
			night = true
		elif a == "--landscape":
			landscape = true
		elif a == "--lefty":
			left_hand = true
		elif a.begins_with("--stack="):
			stack_side = a.trim_prefix("--stack=")
		elif a == "--peek":
			peek = true
		elif a == "--colorblind":
			colorblind = true
	Palette.apply(night)
	DrawUtil.bold_marks = colorblind
	apply_volume()
	tick()


## Debug: "-- --save=gas:0,coins:350,bank:2,done:22" starts from a made-up save (and never writes one),
## for screenshots and tests. done:N marks levels 1..N finished with a mix of stars.
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
			"bank":
				undo_bank = maxi(v, 0)
			"done":
				for n in range(1, v + 1):
					completed[n] = true
					stars[n] = [3, 3, 2, 3, 1][n % 5]
			"momentum":
				momentum = v
			"streak":
				# v finished dailies on the days before today.
				for k in range(1, v + 1):
					daily[Daily.key(Daily.today() - k)] = {"attempts": 1, "done": true, "ok": true, "stars": 3, "time": 60.0}
			"today":
				# Today's daily already solved, with v attempts.
				daily[Daily.key(Daily.today())] = {"attempts": maxi(v, 1), "done": true, "ok": v <= Daily.MAX_REDOS + 1, "stars": 3, "time": 83.0,
					"order": ["red", "blue", "blue", "yellow", "purple", "red"]}
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
			"wear":
				# wear:<item id> (owns it and puts it on).
				owned[kv[1]] = true
				put_on(kv[1])


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not d is Dictionary:
		return
	# Saves from before levels 41-90 existed: the old 41-50 are now 91-100.
	var moved := int(d.get("levels_v", 1)) < 2
	for n in d.get("completed", []):
		var k := int(n)
		completed[k + 50 if moved and k >= 41 and k <= 50 else k] = true
	var st = d.get("stars", {})
	if st is Dictionary:
		for k in st:
			var sk := int(k)
			stars[sk + 50 if moved and sk >= 41 and sk <= 50 else sk] = clampi(int(st[k]), 1, 3)
	gas = clampi(int(d.get("gas", MAX_GAS)), 0, MAX_GAS)
	gas_t = float(d.get("gas_t", 0.0))
	undo_bank = maxi(int(d.get("undo_bank", 0)), 0)
	dollaroos = int(d.get("dollaroos", 0))
	for id in d.get("owned", []):
		owned[str(id)] = true
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
	hint_tips = int(d.get("hint_tips", 0))
	hint_ad_watched = bool(d.get("hint_ad_watched", false))
	reserve_gas = clampi(int(d.get("reserve_gas", 0)), 0, MAX_RESERVE)
	free_hints_until = float(d.get("free_hints_until", 0.0))
	free_undos_until = float(d.get("free_undos_until", 0.0))
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
	var sd = d.get("side_done", {})
	if sd is Dictionary:
		side_done = sd
	for n in d.get("chests", []):
		chests[int(n)] = true
	var mg = d.get("mega", {})
	if mg is Dictionary:
		for k in mg:
			mega[str(k)] = int(mg[k])
	seen_version = str(d.get("seen_version", ""))


func _save() -> void:
	if volatile:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		var st := {}
		for k in stars:
			st[str(k)] = stars[k]
		f.store_string(JSON.stringify({"levels_v": 2, "prefs_v": 1, "completed": completed.keys(), "stars": st, "gas": gas, "gas_t": gas_t,
			"undo_bank": undo_bank, "dollaroos": dollaroos, "owned": owned.keys(), "paint": paint, "topper": topper, "ride": ride,
			"daily": daily, "best_streak": best_streak, "drive_mode": drive_mode,
			"night": night, "landscape": landscape, "left_hand": left_hand, "volume": volume, "haptics": haptics,
			"stack_side": stack_side, "stack_chosen": stack_chosen, "queue_moved_seen": queue_moved_seen, "last_auto_side": last_auto_side, "oneway_levels": oneway_levels.keys(), "symbol_tip_seen": symbol_tip_seen, "exit_tip_seen": exit_tip_seen, "unlimited_hints": unlimited_hints, "hint_tips": hint_tips, "hint_ad_watched": hint_ad_watched,
			"reserve_gas": reserve_gas, "free_hints_until": free_hints_until, "free_undos_until": free_undos_until, "side_bonus_day": side_bonus_day, "speed_best": speed_best, "peek": peek, "seen_version": seen_version,
			"colorblind": colorblind, "trail": trail, "side_done": side_done, "chests": chests.keys(),
			"mega": mega}))


func _now() -> float:
	return Time.get_unix_time_from_system()


# ---------------------------------------------------------------- levels

func is_complete(n: int) -> bool:
	return completed.has(n)


func stars_for(n: int) -> int:
	return stars.get(n, 1 if completed.has(n) else 0)


func total_stars() -> int:
	var t := 0
	for n in completed:
		t += stars_for(n)
	return t


## Records a win with `earned` stars. Returns the Dollaroos it paid (already added to the balance).
func mark_complete(n: int, earned := 3) -> int:
	earned = clampi(earned, 1, 3)
	var before := stars_for(n)
	completed[n] = true
	var pay: int = REPLAY_TIP
	if earned > before:
		pay = STAR_REWARD[earned] - STAR_REWARD[before]
		stars[n] = earned
	dollaroos += pay
	_save()
	changed.emit()
	return pay


## Index (0-based) of the first level not yet completed.
func first_incomplete(count: int) -> int:
	for i in count:
		if not is_complete(i + 1):
			return i
	return 0


func reset() -> void:
	completed.clear()
	stars.clear()
	gas = MAX_GAS
	gas_t = 0.0
	undo_bank = 0
	dollaroos = 0
	owned.clear()
	paint = "classic"
	topper = ""
	ride = ""
	daily.clear()
	best_streak = 0
	momentum = 0
	side_done.clear()
	chests.clear()
	mega.clear()
	speed_best.clear()
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


## Uses a tank (a spare one if the tank's empty). False (and nothing spent) when there are none at all.
func spend_gas() -> bool:
	tick()
	if gas <= 0:
		if reserve_gas > 0:
			reserve_gas -= 1
			_save()
			changed.emit()
			return true
		return false
	if gas >= MAX_GAS:
		gas_t = _now()
	gas -= 1
	_save()
	changed.emit()
	return true


func earn(n: int) -> void:
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

func owns(id: String) -> bool:
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
	return paint == id or topper == id or ride == id


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


## Saves straight away (for flags set outside the usual changes, like a tip being shown).
func save_now() -> void:
	_save()


func free_hints() -> bool:
	return _now() < free_hints_until


func free_undos() -> bool:
	return _now() < free_undos_until


## Seconds of free hints / undos left (0 when none).
func free_left(what: String) -> int:
	return maxi(0, int(ceil((free_hints_until if what == "hints" else free_undos_until) - _now())))


## A side road won: its power-up, once a day per road. Returns a line saying what it gave ("" for none).
func side_power_up(id: String, bonus: Dictionary) -> String:
	var today := Daily.today()
	if bonus.is_empty() or int(side_bonus_day.get(id, -1)) == today:
		return ""
	side_bonus_day[id] = today
	var kind := str(bonus.get("kind", ""))
	var n := int(bonus.get("amount", 1))
	var said := ""
	match kind:
		"reserve":
			var got := mini(n, MAX_RESERVE - reserve_gas)
			reserve_gas += got
			said = "+%d spare gas tank%s" % [got, "" if got == 1 else "s"] if got > 0 else "Spare tanks full!"
		"hints":
			free_hints_until = maxf(free_hints_until, _now()) + n * 60.0
			said = "Free hints for %d minutes" % n
		"undos":
			free_undos_until = maxf(free_undos_until, _now()) + n * 60.0
			said = "Free undos for %d minutes" % n
	_save()
	changed.emit()
	return said


## A side road (SideRoads definition) opens once the level it branches off is beaten.
func side_open(d: Dictionary) -> bool:
	return is_complete(int(d.get("after", 0)))


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
	var cans := int(c.get("gas", 0))
	var fits := mini(cans, MAX_GAS - gas)
	var coins := int(c.get("coins", 0)) + (cans - fits) * SideRoads.CAN_VALUE
	gas += fits
	if gas >= MAX_GAS:
		gas_t = _now()
	dollaroos += coins
	var hat := str(c.get("hat", ""))
	var new_hat := ""
	if hat != "" and not owned.has(hat):
		owned[hat] = true
		new_hat = hat
	chests[n] = true
	_save()
	changed.emit()
	return {"gas": fits, "coins": coins, "hat": new_hat, "cashed": cans - fits}


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
	_save()
	changed.emit()


# ---------------------------------------------------------------- daily

func daily_record(day: int) -> Dictionary:
	return daily.get(Daily.key(day), {})


## Another go at today's puzzle (the first start, or a redo).
func daily_attempt(day: int) -> void:
	var k := Daily.key(day)
	var r: Dictionary = daily.get(k, {"attempts": 0, "done": false})
	if r.get("done", false):
		return
	r["attempts"] = int(r.get("attempts", 0)) + 1
	daily[k] = r
	_save()
	changed.emit()


## Today's puzzle is solved. It counts toward the streak with at most Daily.MAX_REDOS redos.
func daily_done(day: int, stars_earned: int, secs: float, order: Array) -> void:
	var k := Daily.key(day)
	var r: Dictionary = daily.get(k, {"attempts": 1})
	if r.get("done", false):
		return
	r["done"] = true
	r["ok"] = int(r.get("attempts", 1)) - 1 <= Daily.MAX_REDOS
	r["stars"] = stars_earned
	r["time"] = secs
	r["order"] = order
	r["clock"] = Notify.now_minutes()   # local time of day it was solved: tomorrow's reminder comes then
	daily[k] = r
	best_streak = maxi(best_streak, streak(day))
	_save()
	Notify.refresh(self)
	changed.emit()


## Days in a row, ending today (or yesterday, while today can still count), solved within the redo limit.
func streak(today: int) -> int:
	var r := daily_record(today)
	var day := today
	if not r.get("ok", false):
		if r.get("done", false) or int(r.get("attempts", 0)) - 1 > Daily.MAX_REDOS:
			return 0
		day = today - 1
	var n := 0
	while daily_record(day).get("ok", false):
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
