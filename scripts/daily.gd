class_name Daily
extends RefCounted
## The daily puzzle: which one is today's, and the text people share after solving it.
## Days are whole local calendar days, counted as "days since 1970-01-01" so they're easy to step through.
## Daily #1 was FIRST_DAY; the ten puzzles in levels/daily.json then repeat in order.

const PATH := "res://levels/daily.json"
const FIRST_DAY := "2026-11-10"
## A day counts toward the streak if it was solved with no more than this many redos.
const MAX_REDOS := 1
## Level numbers for dailies (so they never mix with the main levels' progress).
const NUMBER_BASE := 900
const SQUARES := {"red": "🟥", "orange": "🟧", "yellow": "🟨", "green": "🟩", "blue": "🟦", "purple": "🟪"}
const INVITE := "Think you can beat it? Text me back for a Last Mile playtest invite 📦"

static var _puzzles: Array = []


static func _day_of(date: String) -> int:
	var parts := date.split("-")
	var t := Time.get_unix_time_from_datetime_dict({"year": parts[0].to_int(), "month": parts[1].to_int(), "day": parts[2].to_int(),
		"hour": 12, "minute": 0, "second": 0})
	return int(floor(t / 86400.0))


## Today, as a day number. "-- --day=+3" pretends it's three days later (for testing).
static func today() -> int:
	var d := Time.get_datetime_dict_from_system()
	var n := _day_of("%d-%d-%d" % [d.year, d.month, d.day])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--day="):
			n += a.trim_prefix("--day=").to_int()
	return n


static func key(day: int) -> String:
	return Time.get_datetime_string_from_unix_time(day * 86400 + 43200).substr(0, 10)


## Daily #1 is FIRST_DAY.
static func number(day: int) -> int:
	return day - _day_of(FIRST_DAY) + 1


static func puzzles() -> Array:
	if _puzzles.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		var list: Array = data.get("levels", []) if data is Dictionary else []
		for i in list.size():
			var L := LevelData.from_dict(list[i], NUMBER_BASE + i + 1)
			for e in L.errors:
				push_error("Daily %d: %s" % [i + 1, e])
			_puzzles.append(L)
	return _puzzles


static func puzzle_for(day: int) -> LevelData:
	var all := puzzles()
	if all.is_empty():
		return null
	return all[posmod(number(day) - 1, all.size())]


static func clock(secs: float) -> String:
	var s := int(round(secs))
	return "%d:%02d" % [s / 60, s % 60]


## The emoji text people paste into a message after solving today's puzzle.
static func share_text(day: int, r: Dictionary, streak: int) -> String:
	var L := puzzle_for(day)
	var lines := []
	lines.append("🚚 Last Mile Daily #%d%s" % [number(day), (" · “%s”" % L.title) if L and L.title != "" else ""])
	var chain := ""
	for c in r.get("order", []):
		chain += SQUARES.get(str(c), "⬜")
	if chain != "":
		lines.append(chain + " 📦")
	var stars := int(r.get("stars", 0))
	var redos := maxi(int(r.get("attempts", 1)) - 1, 0)
	lines.append("⏱️ %s   %s   🔁 %s" % [clock(float(r.get("time", 0.0))), "⭐".repeat(stars) + "☆".repeat(3 - stars),
		"no redos" if redos == 0 else ("1 redo" if redos == 1 else "%d redos" % redos)])
	if streak > 0:
		lines.append("%s %d-day streak" % ["🔥".repeat(mini(streak, 7)), streak])
	lines.append("")
	lines.append(INVITE)
	return "\n".join(lines)
