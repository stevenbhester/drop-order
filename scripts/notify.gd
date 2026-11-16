class_name Notify
extends RefCounted
## Daily-puzzle reminders, as local notifications (nothing goes through a server).
##
## The rules live here; the iOS side is a tiny native plugin (ios/plugins/LastMileNotify) that watches the
## file this writes, user://lastmile_notify.json, and hands its entries to iOS. So the game decides what
## to send and when, and the plugin only schedules it. On desktop the file is written and nothing else happens.
##
## At most one message a day, and only what the player chose (NotifyPrefs, after their first daily: Progress
## notify_streak, notify_fresh; nothing at all, and no permission prompt, until they've chosen):
## - Streak saver ("evening"): on the next day to play, if a streak is riding on it, late in the day (at
##   EVENING, or GAP after their usual time if that's later, but never after LAST_CALL).
## - Fresh daily ("remind"): on days with no streak riding, at the clock time they solved their most recent
##   daily (kept between EARLIEST and LATEST): the next three days, in case they don't open the game.
## - Solving today's puzzle clears today's messages (the file is rewritten and the plugin reschedules); a day
##   with every try spent gets none.
## - Major updates (notify_updates) aren't scheduled here: those would come from the server, and Steven
##   decides which updates are worth one.

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
	if not p.notify_chosen:
		return {"ask": false, "items": []}
	var ask: bool = p.notify_streak or p.notify_fresh or p.notify_updates
	var clock := last_clock(p, today)
	var remind := clampi(clock if clock >= 0 else DEFAULT_CLOCK, EARLIEST, LATEST)
	var tr: Dictionary = p.daily_record(today)
	var start := today + 1 if tr.get("done", false) or Daily.out_of_tries(tr) else today
	# The streak riding on the first day to play (no record for it yet, so this counts the days before it).
	var alive: int = p.streak(start)
	var items := []
	for i in DAYS_AHEAD:
		var day := start + i
		var future := day > today
		# One message a day: the streak saver while a streak rides on it (only the first day: past that,
		# missing it has ended the streak), else the fresh-daily reminder.
		if i == 0 and alive > 0:
			if p.notify_streak:
				var evening := clampi(maxi(EVENING, remind + GAP), EVENING, LAST_CALL)
				if future or evening > now_min:
					items.append(_item("evening", day, evening, alive))
		elif p.notify_fresh and (future or remind > now_min):
			items.append(_item("remind", day, remind, 0))
	return {"ask": ask, "items": items}


static func _item(kind: String, day: int, minute: int, streak: int) -> Dictionary:
	var n := Daily.number(day)
	var L := Daily.puzzle_for(day)
	var name := ("“%s”" % L.title) if L and L.title != "" else "a fresh route"
	var title := ""
	var body := ""
	if kind == "remind":
		title = "Daily #%d just landed 📦" % n
		body = "Today's route: %s. One van, one map, every package. Start a streak?" % name
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
