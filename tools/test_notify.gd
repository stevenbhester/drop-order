extends SceneTree
## Checks the daily-reminder schedule (scripts/notify.gd) on throwaway saves (nothing is written).
##   godot --headless --path . --script res://tools/test_notify.gd
## The rules: nothing until the player has chosen (NotifyPrefs); then at most one message a day: the
## streak saver (late, "evening") while a streak rides on the day, else the fresh-daily reminder ("remind")
## at their usual time.

const TODAY := 20500
var bad := 0


## A save with these days, oldest first, ending today: [attempts, solved, clock minutes] (clock -1: none
## saved). `prefs`: [chosen, streak, fresh, updates].
func _save(days: Array, prefs := [true, true, true, true]):
	var p = load("res://scripts/progress.gd").new()
	p.volatile = true
	p.notify_chosen = prefs[0]
	p.notify_streak = prefs[1]
	p.notify_fresh = prefs[2]
	p.notify_updates = prefs[3]
	for i in days.size():
		var day := TODAY - (days.size() - 1 - i)
		var spec: Array = days[i]
		for a in spec[0]:
			p.daily_attempt(day)
		if spec[1]:
			p.daily_done(day, 30.0, [])
			var r: Dictionary = p.daily[Daily.key(day)]
			if spec[2] >= 0:
				r["clock"] = spec[2]
			else:
				r.erase("clock")
	return p


func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		bad += 1
	print("%s  %-62s %s" % ["ok  " if ok else "FAIL", name, detail])


func _desc(items: Array) -> String:
	var out := []
	for it in items:
		out.append("%s d%+d %02d:%02d" % [it["kind"], it["day"] - TODAY, it["minute"] / 60, it["minute"] % 60])
	return ", ".join(out)


## At most one message on any day.
func _one_a_day(items: Array) -> bool:
	var seen := {}
	for it in items:
		if seen.has(it["day"]):
			return false
		seen[it["day"]] = true
	return true


func _init() -> void:
	var h := func(hh: int, mm := 0) -> int: return hh * 60 + mm

	# Solved yesterday, but hasn't chosen what to hear yet: nothing, and no permission prompt.
	var p = _save([[1, true, h.call(10)], [0, false, 0]], [false, true, true, true])
	var pl := Notify.plan(p, TODAY, h.call(9))
	_check("not chosen yet: no messages", pl["items"].is_empty(), _desc(pl["items"]))
	_check("not chosen yet: no permission prompt", not pl["ask"])
	p.free()

	# Chosen everything; solved yesterday at 10:15 (a 1-day streak rides on today); it's 08:00.
	p = _save([[1, true, h.call(10, 15)], [0, false, 0]])
	pl = Notify.plan(p, TODAY, h.call(8))
	var it: Array = pl["items"]
	_check("asks for permission once chosen", pl["ask"])
	_check("today: just the streak saver, in the evening", it.size() > 0 and it[0]["kind"] == "evening" and it[0]["day"] == TODAY
		and it[0]["minute"] == Notify.EVENING, _desc(it))
	_check("the saver names the streak", it.size() > 0 and it[0]["title"].contains("1-day"), it[0]["title"] if it.size() > 0 else "")
	_check("then fresh-daily reminders at the usual time", it.size() == 3 and it[1]["kind"] == "remind" and it[1]["day"] == TODAY + 1
		and it[1]["minute"] == h.call(10, 15) and it[2]["day"] == TODAY + 2, _desc(it))
	_check("never more than one a day", _one_a_day(it), _desc(it))
	_check("ids are prefixed lm.", it.all(func(x): return x["id"].begins_with("lm.")))
	p.free()

	# It's 20:00 already: today's saver has gone by.
	p = _save([[1, true, h.call(10, 15)], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(20))["items"]
	_check("late: nothing more today", it.size() == 2 and it[0]["day"] == TODAY + 1, _desc(it))
	p.free()

	# Usually plays at 17:45: the saver moves to 20:45 (3h later); at 19:00 it's capped at 21:30.
	p = _save([[1, true, h.call(17, 45)], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(9))["items"]
	_check("saver 3h after a late usual time", it.size() > 0 and it[0]["minute"] == h.call(20, 45), _desc(it))
	p.free()
	p = _save([[1, true, h.call(19)], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(9))["items"]
	_check("saver never after the last call", it.size() > 0 and it[0]["kind"] == "evening" and it[0]["minute"] == Notify.LAST_CALL, _desc(it))
	p.free()

	# Usual time kept within 08:00..21:00.
	p = _save([[1, true, h.call(23, 30)], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(7))["items"]
	_check("late-night player: reminder at 21:00", it.size() > 1 and it[1]["minute"] == Notify.LATEST, _desc(it))
	p.free()
	p = _save([[1, true, h.call(6, 10)], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(5))["items"]
	_check("early player: reminder at 08:00", it.size() > 1 and it[1]["minute"] == Notify.EARLIEST, _desc(it))
	p.free()

	# Today already solved (at 12:30): nothing today; tomorrow the saver for a 2-day streak.
	p = _save([[1, true, h.call(10)], [1, true, h.call(12, 30)]])
	it = Notify.plan(p, TODAY, h.call(13))["items"]
	_check("solved today: nothing today", it.all(func(x): return x["day"] > TODAY), _desc(it))
	_check("solved today: tomorrow's saver, 2-day streak", it.size() > 0 and it[0]["day"] == TODAY + 1 and it[0]["kind"] == "evening"
		and it[0]["title"].contains("2-day"), _desc(it))
	p.free()

	# No streak (missed yesterday): fresh-daily reminders only, no streak talk.
	p = _save([[1, true, h.call(10)], [0, false, 0], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(9))["items"]
	_check("streak gone: reminders only", it.size() == 3 and it.all(func(x): return x["kind"] == "remind"), _desc(it))
	_check("streak gone: no streak talk", it.size() > 0 and not it[0]["body"].contains("streak ") and not it[0]["title"].contains("streak"), it[0]["body"] if it.size() > 0 else "")
	p.free()

	# Today's tries all spent, unsolved: nothing today; from tomorrow, reminders.
	p = _save([[1, true, h.call(10)], [6, false, 0]])
	it = Notify.plan(p, TODAY, h.call(9))["items"]
	_check("out of tries today: nothing today", it.all(func(x): return x["day"] > TODAY and x["kind"] == "remind"), _desc(it))
	p.free()

	# Only the streak saver chosen, and no streak: nothing.
	p = _save([[1, true, h.call(10)], [0, false, 0], [0, false, 0]], [true, true, false, false])
	pl = Notify.plan(p, TODAY, h.call(9))
	_check("saver only, no streak: nothing", pl["items"].is_empty(), _desc(pl["items"]))
	p.free()

	# Only fresh dailies chosen, with a streak riding on today: nothing today, reminders after.
	p = _save([[1, true, h.call(10)], [0, false, 0]], [true, false, true, false])
	it = Notify.plan(p, TODAY, h.call(9))["items"]
	_check("fresh only, streak alive: no saver today", it.all(func(x): return x["kind"] == "remind" and x["day"] > TODAY), _desc(it))
	p.free()

	# Everything unticked: no prompt, nothing.
	p = _save([[1, true, h.call(10)], [0, false, 0]], [true, false, false, false])
	pl = Notify.plan(p, TODAY, h.call(9))
	_check("all off: no prompt, nothing", not pl["ask"] and pl["items"].is_empty(), _desc(pl["items"]))
	p.free()

	# An old save without solve times: reminders at the default.
	p = _save([[1, true, -1], [0, false, 0], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(9))["items"]
	_check("old save without a clock: default time", it.size() > 0 and it[0]["minute"] == Notify.DEFAULT_CLOCK, _desc(it))
	p.free()

	print("notify test: %s" % ("all ok" if bad == 0 else "%d FAILED" % bad))
	quit(1 if bad > 0 else 0)
