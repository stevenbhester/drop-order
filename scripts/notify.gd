class_name Notify
extends RefCounted
## Daily-puzzle reminders, as local notifications (nothing goes through a server).
##
## The rules live here; the iOS side is a tiny native plugin (ios/plugins/LastMileNotify) that watches the
## file this writes, user://lastmile_notify.json, and hands its entries to iOS. So the game decides what
## to send and when, and the plugin only schedules it. On desktop the file is written and nothing else happens.
##
## - Reminder: on the next day whose puzzle isn't solved, at the clock time the player solved their most
##   recent daily (kept between EARLIEST and LATEST), and again on the two days after, in case they don't
##   open the game in between.
## - Last call: on that first day, if the streak is alive, an evening "save your streak" message, a few hours
##   after the reminder (at EVENING, or GAP after the reminder if that's later, but never after LAST_CALL).
## - Solving today's puzzle clears today's messages (the file is rewritten and the plugin reschedules).
## - The permission prompt ("ask") only comes once the player has solved a daily.

const FILE := "user://lastmile_notify.json"
## Minutes after midnight.
const EARLIEST := 8 * 60
const LATEST := 21 * 60
const EVENING := 19 * 60 + 30
const LAST_CALL := 21 * 60 + 30
## The evening message needs at least this long since the reminder.
const GAP := 3 * 60
## For solves saved before completion times were recorded.
const DEFAULT_CLOCK := 17 * 60
## Reminders for this many days, starting with the first unsolved one.
const DAYS_AHEAD := 3
## How far back to look for the latest solve.
const LOOKBACK := 60


## Local clock time (minutes after midnight) the most recent daily was solved, or -1 if none ever was.
static func last_clock(p, today: int) -> int:
	for k in LOOKBACK + 1:
		var r: Dictionary = p.daily_record(today - k)
		if r.get("done", false):
			return int(r.get("clock", DEFAULT_CLOCK))
	return -1


## What to schedule, seen from day `today` at `now_min` minutes after midnight (local).
## Returns {"ask": bool, "items": [{id, kind, day, date, minute, title, body}]}, items in time order.
static func plan(p, today: int, now_min: int) -> Dictionary:
	var clock := last_clock(p, today)
	if clock < 0:
		return {"ask": false, "items": []}
	var remind := clampi(clock, EARLIEST, LATEST)
	var start := today + 1 if p.daily_record(today).get("done", false) else today
	# The streak riding on the first unsolved day (no record for it yet, so this counts the days before it;
	# for today it also knows when today's redos have already used it up).
	var alive: int = p.streak(start)
	var items := []
	for i in DAYS_AHEAD:
		var day := start + i
		var future := day > today
		if future or remind > now_min:
			items.append(_item("remind", day, remind, alive if i == 0 else 0))
		if i == 0 and alive > 0:
			var evening := maxi(EVENING, remind + GAP)
			if evening <= LAST_CALL and (future or evening > now_min):
				items.append(_item("evening", day, evening, alive))
	return {"ask": true, "items": items}


static func _item(kind: String, day: int, minute: int, streak: int) -> Dictionary:
	var n := Daily.number(day)
	var L := Daily.puzzle_for(day)
	var name := ("“%s”" % L.title) if L and L.title != "" else "a fresh route"
	var title := ""
	var body := ""
	if kind == "remind":
		title = "Daily #%d is out for delivery 📦" % n
		if streak > 0:
			body = "Today's route: %s. Your %d-day streak is idling in the driveway. Keep it rolling!" % [name, streak]
		else:
			body = "Today's route: %s. One van, one map, every package. Can you do it in one go?" % name
	else:
		title = "Last call for your 🔥%d-day streak!" % streak
		body = "Daily #%d closes at midnight. One drive saves it." % n
	return {"id": "lm.%s.%s" % [kind, Daily.key(day)], "kind": kind, "day": day, "date": Daily.key(day),
		"minute": minute, "title": title, "body": body}


## Minutes after midnight, local, right now.
static func now_minutes() -> int:
	var t := Time.get_datetime_dict_from_system()
	return int(t.hour) * 60 + int(t.minute)


## Rewrites the schedule file from the save `p` (the Progress autoload). Self-tests never write it.
static func refresh(p) -> void:
	if p.volatile:
		return
	var pl := plan(p, Daily.today(), now_minutes())
	var out := []
	for it in pl["items"]:
		var d: PackedStringArray = it["date"].split("-")
		out.append({"id": it["id"], "year": d[0].to_int(), "month": d[1].to_int(), "day": d[2].to_int(),
			"hour": it["minute"] / 60, "minute": it["minute"] % 60, "title": it["title"], "body": it["body"]})
	var text := JSON.stringify({"version": 1, "ask": pl["ask"], "items": out}, "\t")
	# Unchanged schedules aren't rewritten, so the plugin only reschedules when something changed.
	if FileAccess.file_exists(FILE) and FileAccess.get_file_as_string(FILE) == text:
		return
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f:
		f.store_string(text)
