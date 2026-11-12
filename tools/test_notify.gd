extends SceneTree
## Checks the daily-reminder schedule (scripts/notify.gd) on throwaway saves (nothing is written).
##   godot --headless --path . --script res://tools/test_notify.gd

const TODAY := 20500
var bad := 0


## A save with these days, oldest first, ending today: [attempts, solved, clock minutes] (clock -1: none saved).
func _save(days: Array):
	var p = load("res://scripts/progress.gd").new()
	p.volatile = true
	for i in days.size():
		var day := TODAY - (days.size() - 1 - i)
		var spec: Array = days[i]
		for a in spec[0]:
			p.daily_attempt(day)
		if spec[1]:
			p.daily_done(day, 3, 30.0, [])
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


func _init() -> void:
	var h := func(hh: int, mm := 0) -> int: return hh * 60 + mm

	# Never solved a daily: nothing, and no permission prompt.
	var p = _save([[1, false, 0]])
	var pl := Notify.plan(p, TODAY, h.call(9))
	_check("no solves yet: no messages", pl["items"].is_empty(), _desc(pl["items"]))
	_check("no solves yet: no permission prompt", not pl["ask"])
	p.free()

	# Solved yesterday at 10:15; today not started; it's 08:00.
	p = _save([[1, true, h.call(10, 15)], [0, false, 0]])
	pl = Notify.plan(p, TODAY, h.call(8))
	var it: Array = pl["items"]
	_check("asks for permission after a solve", pl["ask"])
	_check("reminder today at yesterday's solve time", it.size() > 0 and it[0]["kind"] == "remind" and it[0]["day"] == TODAY
		and it[0]["minute"] == h.call(10, 15), _desc(it))
	_check("evening last call today (streak alive, 3h+ after)", it.size() > 1 and it[1]["kind"] == "evening" and it[1]["day"] == TODAY
		and it[1]["minute"] == Notify.EVENING, _desc(it))
	_check("reminders on the next two days too, no evening", it.size() == 4 and it[2]["day"] == TODAY + 1 and it[3]["day"] == TODAY + 2
		and it[2]["kind"] == "remind" and it[3]["kind"] == "remind", _desc(it))
	_check("streak mentioned in today's reminder", it.size() > 0 and it[0]["body"].contains("1-day streak"), it[0]["body"] if it.size() > 0 else "")
	_check("ids are prefixed lm.", it.all(func(x): return x["id"].begins_with("lm.")))
	p.free()

	# Same, but it's already 11:00: today's reminder is in the past, the evening one isn't.
	p = _save([[1, true, h.call(10, 15)], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(11))["items"]
	_check("past reminder skipped, evening kept", it.size() == 3 and it[0]["kind"] == "evening" and it[0]["day"] == TODAY, _desc(it))
	p.free()

	# It's 20:00 already: today's evening message is gone too.
	p = _save([[1, true, h.call(10, 15)], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(20))["items"]
	_check("late: nothing more today", it.size() == 2 and it[0]["day"] == TODAY + 1, _desc(it))
	p.free()

	# Solved yesterday at 17:45: the reminder is 17:45, the evening one moves to 20:45 (3h later).
	p = _save([[1, true, h.call(17, 45)], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(9))["items"]
	_check("evening moves to 3h after a late reminder", it.size() > 1 and it[1]["kind"] == "evening" and it[1]["minute"] == h.call(20, 45), _desc(it))
	p.free()

	# Solved yesterday at 19:00: an evening message would be after 21:30, so there isn't one.
	p = _save([[1, true, h.call(19)], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(9))["items"]
	_check("no evening when the reminder is already evening", it.all(func(x): return x["kind"] == "remind"), _desc(it))
	p.free()

	# Solved yesterday at 23:30 and 06:10: reminder kept within 08:00..21:00.
	p = _save([[1, true, h.call(23, 30)], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(7))["items"]
	_check("late-night solve: reminder at 21:00", it.size() > 0 and it[0]["minute"] == Notify.LATEST, _desc(it))
	p.free()
	p = _save([[1, true, h.call(6, 10)], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(5))["items"]
	_check("early solve: reminder at 08:00", it.size() > 0 and it[0]["minute"] == Notify.EARLIEST, _desc(it))
	p.free()

	# Today already solved (at 12:30): nothing today, tomorrow at 12:30 with the evening last call.
	p = _save([[1, true, h.call(10)], [1, true, h.call(12, 30)]])
	it = Notify.plan(p, TODAY, h.call(13))["items"]
	_check("solved today: nothing today", it.all(func(x): return x["day"] > TODAY), _desc(it))
	_check("solved today: tomorrow at today's solve time", it.size() > 0 and it[0]["day"] == TODAY + 1 and it[0]["minute"] == h.call(12, 30), _desc(it))
	_check("solved today: tomorrow's evening, with a 2-day streak", it.size() > 1 and it[1]["kind"] == "evening"
		and it[1]["title"].contains("2-day"), _desc(it))
	p.free()

	# No streak (missed yesterday): reminders but no evening message.
	p = _save([[1, true, h.call(10)], [0, false, 0], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(9))["items"]
	_check("streak gone: reminder only, no last call", it.size() == 3 and it.all(func(x): return x["kind"] == "remind"), _desc(it))
	_check("streak gone: reminder doesn't mention a streak", it.size() > 0 and not it[0]["body"].contains("streak"), it[0]["body"] if it.size() > 0 else "")
	p.free()

	# Today's redos already used up the streak: no evening last call.
	p = _save([[1, true, h.call(10)], [3, false, 0]])
	it = Notify.plan(p, TODAY, h.call(9))["items"]
	_check("too many redos today: no last call", it.all(func(x): return x["kind"] == "remind"), _desc(it))
	p.free()

	# An old save without solve times: reminder at the default.
	p = _save([[1, true, -1], [0, false, 0]])
	it = Notify.plan(p, TODAY, h.call(9))["items"]
	_check("old save without a clock: default time", it.size() > 0 and it[0]["minute"] == Notify.DEFAULT_CLOCK, _desc(it))
	p.free()

	print("notify test: %s" % ("all ok" if bad == 0 else "%d FAILED" % bad))
	quit(1 if bad > 0 else 0)
