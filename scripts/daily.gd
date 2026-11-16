class_name Daily
extends RefCounted
## The daily puzzle: which one is today's, and the text people share after solving it.
## Days are whole local calendar days, counted as "days since 1970-01-01" so they're easy to step through.
## Daily #1 was FIRST_DAY; the puzzles in levels/daily.json then repeat in order. Each says how spicy it is.

const PATH := "res://levels/daily.json"
const FIRST_DAY := "2026-11-10"
## The daily opens after this job's won (anyone who's played one before keeps it).
const UNLOCK_AT := 11
## Tries a day (the first go and five restarts). Out of them, today's is over.
const MAX_TRIES := 6
## What a solved daily can earn, in the order the score card deals them: [emoji (for the text that's shared;
## on screen each has a drawn icon, draw_badge_icon: emoji don't show on the phone), what it says, points]. Points
## 0 is a gold achievement (worth bragging about, no points). The streak's is per day (up to 30); its text
## takes the count. The ids are what's saved and sent, so the words can change.
const BADGES := {
	"delivered": ["✅", "Delivered!", 100],
	"first_try": ["🎯", "First try", 50],
	"no_undos": ["🧘", "No undos", 25],
	"straight": ["📏", "Straight shot (the shortest route)", 30],
	"express": ["⚡", "Express (under 20 seconds)", 40],
	"speedy": ["💨", "Speedy (under 45 seconds)", 20],
	"steady": ["⏱️", "Steady (under 90 seconds)", 10],
	"scenic": ["🌄", "Scenic route (the long way round)", 10],
	"wire": ["😅", "Down to the wire (your last try)", 15],
	"streak": ["🔥", "%d-day streak", 1],
	"perfect": ["✨", "Perfect (flawless run)", 0],
	"best": ["🏆", "Personal best", 0],
	"above": ["📈", "Above your average", 0],
}
## Badges worth putting in the share, most impressive first (the first one earned goes in).
const SHOWOFF := ["perfect", "express", "best", "straight", "first_try"]
## Over the Share button once today's is solved (until it's been shared): the game, out of character, asking
## you to brag (Steven: break the fourth wall, stay silly).
const BEGS := ["Brag to a friend! You look smart, and Last Mile might get a new player. (We really need those.)",
	"Go on, show someone. Best case, they're impressed. Worst case, this game gets a second player.",
	"Bragging is good for you. It's even better for us. Please brag.",
	"Send it to a friend. You get to look clever, and we get to say \"players\", plural.",
	"This is the game talking. Tell one person. That would double our marketing."]
## Level numbers for dailies (so they never mix with the main levels' progress).
const NUMBER_BASE := 900
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


## The simulated drivers' numbers for day `day`'s puzzle (levels/daily_sim.json, from
## tools/engine/daily_sim.py: the same thirty made-up drivers test-drive every daily), in the shape the
## server sends for a day. {} if there are none.
static var _sim: Array = []
static var _sim_read := false

static func sim_stats(day: int) -> Dictionary:
	if not _sim_read:
		_sim_read = true
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://levels/daily_sim.json")) if FileAccess.file_exists("res://levels/daily_sim.json") else null
		if data is Dictionary and data.get("puzzles") is Array:
			_sim = data["puzzles"]
	var all := puzzles()
	if all.is_empty() or _sim.size() != all.size():
		return {}
	var d = _sim[posmod(number(day) - 1, all.size())]
	return d if d is Dictionary else {}


static func clock(secs: float) -> String:
	var s := int(round(secs))
	return "%d:%02d" % [s / 60, s % 60]


## Is the daily open to play? (Progress looked up by name: the tools load this without the autoloads.)
static func unlocked() -> bool:
	var p = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Progress")
	if p == null:
		return true
	return p.is_complete(UNLOCK_AT) or p.completed.size() >= UNLOCK_AT or not p.daily.is_empty() or p.all_open


## What a solved day earns: {ids (in order), score}. From its record (attempts, time, tiles, undos, shortest),
## the scores of the days before it (`prior`), and the streak with it counted.
static func earn(r: Dictionary, prior: Array, streak: int) -> Dictionary:
	var ids := ["delivered"]
	var tries := int(r.get("attempts", 1))
	var undos := int(r.get("undos", 0))
	var tiles := int(r.get("tiles", 0))
	var shortest := int(r.get("shortest", 0))
	var secs := float(r.get("time", 999.0))
	if tries <= 1:
		ids.append("first_try")
	if undos == 0:
		ids.append("no_undos")
	var straight := shortest > 0 and tiles > 0 and tiles <= shortest
	if straight:
		ids.append("straight")
	if secs < 20.0:
		ids.append("express")
	elif secs < 45.0:
		ids.append("speedy")
	elif secs < 90.0:
		ids.append("steady")
	if shortest > 0 and tiles >= shortest + 6:
		ids.append("scenic")
	if tries >= MAX_TRIES:
		ids.append("wire")
	if streak > 0:
		ids.append("streak")
	var score := 0
	for id in ids:
		score += mini(streak, 30) if id == "streak" else int(BADGES[id][2])
	if tries <= 1 and undos == 0 and straight:
		ids.append("perfect")
	if not prior.is_empty():
		var best := 0
		var total := 0
		for p in prior:
			best = maxi(best, int(p))
			total += int(p)
		if score > best:
			ids.append("best")
		elif prior.size() >= 3 and score > total / prior.size():
			ids.append("above")
	return {"ids": ids, "score": score}


## A badge as the score card shows it: {id, icon, text, pts (0: a gold one)}.
static func badge(id: String, streak := 0) -> Dictionary:
	var b: Array = BADGES.get(id, ["⭐", id, 0])
	var text := str(b[1]) % streak if id == "streak" else str(b[1])
	return {"id": id, "icon": str(b[0]), "text": text, "pts": mini(streak, 30) if id == "streak" else int(b[2])}


## A badge's picture, about `s` across, centred on `c` (emoji don't draw on the phone, so these are drawn).
static func draw_badge_icon(ci: CanvasItem, id: String, c: Vector2, s: float, t := 0.0) -> void:
	var ink := Color("2b2233")
	match id:
		"delivered":
			ci.draw_circle(c, s * 0.5, Color("2f9e63"))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.22, 0.0) * s, c + Vector2(-0.06, 0.16) * s, c + Vector2(0.24, -0.18) * s]), Color.WHITE, s * 0.13, true)
		"first_try":
			# A target, an arrow in the middle of it.
			ci.draw_circle(c, s * 0.5, Color("e8473c"))
			ci.draw_circle(c, s * 0.36, Color.WHITE)
			ci.draw_circle(c, s * 0.22, Color("e8473c"))
			ci.draw_circle(c, s * 0.08, Color.WHITE)
			ci.draw_line(c, c + Vector2(0.5, -0.5) * s, ink, s * 0.08, true)
		"no_undos":
			# The undo arrow, struck through.
			ci.draw_circle(c, s * 0.5, Color("4d8dff"))
			Icons.draw(ci, "undo", c, s * 0.7, Color.WHITE)
			ci.draw_line(c + Vector2(-0.34, 0.34) * s, c + Vector2(0.34, -0.34) * s, Color("e8473c"), s * 0.12, true)
		"straight":
			# A ruler-straight arrow.
			ci.draw_circle(c, s * 0.5, Color("16a98f"))
			ci.draw_line(c + Vector2(-0.3, 0.0) * s, c + Vector2(0.16, 0.0) * s, Color.WHITE, s * 0.13, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.34, 0.0) * s, c + Vector2(0.08, -0.2) * s, c + Vector2(0.08, 0.2) * s]), Color.WHITE)
		"express", "speedy":
			# A bolt (express), or speed lines behind a dot (speedy).
			ci.draw_circle(c, s * 0.5, Color("ffc53d") if id == "express" else Color("8fd3ff"))
			if id == "express":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.1, -0.38) * s, c + Vector2(-0.2, 0.06) * s, c + Vector2(0.0, 0.06) * s,
					c + Vector2(-0.1, 0.38) * s, c + Vector2(0.22, -0.08) * s, c + Vector2(0.02, -0.08) * s]), ink)
			else:
				for k in 3:
					var y := (k - 1) * 0.17 * s
					ci.draw_line(c + Vector2(-0.32 + 0.06 * absf(k - 1.0), 0) * s + Vector2(0, y), c + Vector2(0.02, 0) * s + Vector2(0, y), ink, s * 0.07, true)
				ci.draw_circle(c + Vector2(0.2, 0) * s, s * 0.14, ink)
		"steady":
			# A clock.
			ci.draw_circle(c, s * 0.5, Color("b7a98f"))
			ci.draw_circle(c, s * 0.36, Color.WHITE)
			ci.draw_line(c, c + Vector2(0, -0.24) * s, ink, s * 0.07, true)
			ci.draw_line(c, c + Vector2(0.16, 0.06) * s, ink, s * 0.07, true)
		"scenic":
			# Hills and a sun.
			ci.draw_circle(c, s * 0.5, Color("ffd9b0"))
			ci.draw_circle(c + Vector2(0.18, -0.16) * s, s * 0.12, Color("ff9a3c"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.4, 0.26) * s, c + Vector2(-0.12, -0.14) * s, c + Vector2(0.14, 0.26) * s]), Color("5fae5a"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.08, 0.26) * s, c + Vector2(0.18, -0.02) * s, c + Vector2(0.4, 0.26) * s]), Color("4f9e4c"))
		"wire":
			# A stopwatch on its last tick.
			ci.draw_circle(c, s * 0.5, Color("ff8a5c"))
			ci.draw_rect(Rect2(c + Vector2(-0.07, -0.5) * s, Vector2(0.14, 0.14) * s), ink)
			ci.draw_circle(c + Vector2(0, 0.04) * s, s * 0.32, Color.WHITE)
			ci.draw_arc(c + Vector2(0, 0.04) * s, s * 0.2, -PI / 2.0, PI * 1.3, 20, Color("e8473c"), s * 0.1, true)
		"streak":
			AnimeFire.draw_flame(ci, c + Vector2(0, s * 0.46), s * 0.7, s * 1.0, t, 1.0, AnimeFire.palette(4))
		"perfect":
			# A gold star, twinkling.
			Icons.star(ci, c, s * 0.5, Color("ffc53d"), sin(t * 2.0) * 0.15)
			Icons.star(ci, c + Vector2(0.34, -0.34) * s, s * 0.16 * (0.6 + 0.4 * sin(t * 6.0)), Color.WHITE)
		"best":
			# A trophy.
			var gold := Color("ffc53d")
			ci.draw_arc(c + Vector2(0, -0.14) * s, s * 0.34, 0.2, PI - 0.2, 12, gold.darkened(0.15), s * 0.08, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.26, -0.4) * s, c + Vector2(0.26, -0.4) * s, c + Vector2(0.16, 0.08) * s, c + Vector2(-0.16, 0.08) * s]), gold)
			ci.draw_rect(Rect2(c + Vector2(-0.05, 0.08) * s, Vector2(0.1, 0.2) * s), gold.darkened(0.15))
			ci.draw_rect(Rect2(c + Vector2(-0.2, 0.28) * s, Vector2(0.4, 0.12) * s), gold.darkened(0.25))
		"above":
			# A line going up, with an arrowhead.
			ci.draw_circle(c, s * 0.5, Color("d9f2e3"))
			var pts := PackedVector2Array([c + Vector2(-0.3, 0.2) * s, c + Vector2(-0.08, 0.0) * s, c + Vector2(0.06, 0.1) * s, c + Vector2(0.28, -0.18) * s])
			ci.draw_polyline(pts, Color("2f9e63"), s * 0.1, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.36, -0.28) * s, c + Vector2(0.1, -0.24) * s, c + Vector2(0.32, -0.02) * s]), Color("2f9e63"))
		_:
			Icons.star(ci, c, s * 0.45, Color("ffc53d"))


## The most impressive badge a day earned, for the share (or "" if none is impressive enough).
static func showoff(r: Dictionary) -> String:
	var got: Array = r.get("badges", [])
	for id in SHOWOFF:
		if got.has(id):
			return id
	return ""


## Tries left today (the first go counts as one); 0 once they're spent, MAX_TRIES before any.
static func tries_left(r: Dictionary) -> int:
	return maxi(MAX_TRIES - int(r.get("attempts", 0)), 0)


## Every try spent and still not solved: today's is over.
static func out_of_tries(r: Dictionary) -> bool:
	return not r.get("done", false) and int(r.get("attempts", 0)) >= MAX_TRIES


## Today's begging line (BEGS), the same all day.
static func beg(day: int) -> String:
	return BEGS[posmod(day, BEGS.size())]


## A speech bubble pointing down at `at` (the top middle of the Share button), saying `text`, bobbing.
static func draw_beg(ci: CanvasItem, at: Vector2, text: String, t: float, alpha := 1.0) -> void:
	var px := 34
	var w := minf(860.0, ci.get_viewport_rect().size.x - 60.0)
	var lines := BossIntro.wrap_text(text, px, w - 60.0)
	var h := lines.size() * px * 1.25 + 40.0
	var bob := sin(t * 3.0) * 6.0
	var x := clampf(at.x - w / 2.0, 30.0, ci.get_viewport_rect().size.x - 30.0 - w)
	var box := Rect2(x, at.y - 30.0 - h + bob, w, h)
	DrawUtil.rrect(ci, Rect2(box.position + Vector2(0, 8), box.size), Color(0, 0, 0, 0.22 * alpha), 30)
	DrawUtil.rrect(ci, box, Color(1, 1, 1, alpha), 30)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(at.x - 22, box.end.y - 1), Vector2(at.x + 22, box.end.y - 1), Vector2(at.x, box.end.y + 26)]), Color(1, 1, 1, alpha))
	var f := UiTheme.font()
	for i in lines.size():
		var lw := f.get_string_size(str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		ci.draw_string(f, Vector2(box.get_center().x - lw / 2.0, box.position.y + 20.0 + px + i * px * 1.25), str(lines[i]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(Palette.TEXT, alpha))


## Rows for the share, one per try: [packages it delivered, packages in all, won]. The failed tries first
## (as far as each got), the win last. Never the colours or the order: that would give the puzzle away.
## At most `most` rows (the latest).
static func rows(r: Dictionary, most := 6) -> Array:
	var total := (r.get("order", []) as Array).size()
	var out := []
	for got in r.get("tries", []):
		total = maxi(total, int(got))
		out.append([int(got), 0, false])
	for row in out:
		row[1] = total
	if r.get("done", false):
		out.append([total, total, true])
	return out.slice(maxi(0, out.size() - most))


## Tries the record doesn't know how far went (dailies played before it kept them): the share says how many
## redos instead.
static func untracked(r: Dictionary) -> bool:
	return (r.get("tries", []) as Array).size() < int(r.get("attempts", 1)) - 1


## The emoji text people paste into a message after solving today's puzzle: a row per try, green as far as
## it got (a 💥 where it died, a 📦 on the one that made it).
static func share_text(day: int, r: Dictionary, streak: int) -> String:
	var L := puzzle_for(day)
	var lines := []
	lines.append("🚚 Last Mile Daily #%d%s" % [number(day), (" · “%s”" % L.title) if L and L.title != "" else ""])
	var all := rows(r, 99)
	if all.size() > 6:
		lines.append("…%d more tries" % (all.size() - 6))
	for row in all.slice(maxi(0, all.size() - 6)):
		lines.append("🟩".repeat(row[0]) + "⬛".repeat(row[1] - row[0]) + (" 📦" if row[2] else " 💥"))
	var redos := maxi(int(r.get("attempts", 1)) - 1, 0)
	var tail := "⏱️ %s" % clock(float(r.get("time", 0.0)))
	if r.has("score"):
		tail += "   🏁 %d points" % int(r["score"])
	if untracked(r):
		tail += "   🔁 %s" % ("no redos" if redos == 0 else ("1 redo" if redos == 1 else "%d redos" % redos))
	lines.append(tail)
	# The most impressive badge, if it's one worth showing off.
	var best := showoff(r)
	if best != "":
		var b := badge(best)
		lines.append("%s %s" % [b["icon"], str(b["text"]).get_slice(" (", 0)])
	if streak > 0:
		lines.append("%s %d-day streak" % ["🔥".repeat(mini(streak, 7)), streak])
	lines.append("")
	lines.append(INVITE)
	return "\n".join(lines)
