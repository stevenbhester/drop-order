class_name SideRoads
extends RefCounted
## Little side roads off the road trip.
## - Side challenges (levels/side.json): a short level with a twist, branching off the road after level
##   `after`, open once that level's beaten. Beating it wins a ride. Free to play, no hints or undos.
##     fuel: the tank only holds the shortest route · melt: a time limit (`seconds`) · one_shot: plan it all,
##     one drive, no stopping · fog: the load's shown for `peek` seconds, then only the next is visible.
##   mega: a mega route, several `parts` laid out on a `grid` (each part's `at` is its cell). Each part is a
##     level of its own ending at an exit (E) on the edge toward the next; the camera pans on; progress is
##     saved part by part; finishing the last part wins. Hints and undos are allowed on mega routes.
## - Treasure chests at milestone levels (CHESTS): once that level's beaten, a spur leads to a chest to open
##   for gas, Dollaroos and sometimes a hat.

const PATH := "res://levels/side.json"
## Level numbers side levels play as (never real level numbers, so they never touch level progress).
const NUMBER_BASE := 800
const CHESTS := {
	10: {"gas": 2, "coins": 250},
	20: {"gas": 3, "coins": 400, "hat": "party_hat"},
	30: {"gas": 3, "coins": 600},
	40: {"gas": 4, "coins": 800, "hat": "hard_hat"},
	50: {"gas": 4, "coins": 1000},
	60: {"gas": 4, "coins": 1100},
	70: {"gas": 5, "coins": 1200, "hat": "cone_hat"},
	80: {"gas": 5, "coins": 1300},
	90: {"gas": 5, "coins": 1400},
	100: {"gas": 5, "coins": 2500, "hat": "crown"},
}
## What each twist is called on its sign and in the game's top bar.
const TWISTS := {"fuel": "Small tank", "melt": "Beat the clock", "one_shot": "One drive", "fog": "Fog", "mega": "Mega route"}
## A spare gas can (one that wouldn't fit in a full tank) is paid out in Dollaroos instead.
const CAN_VALUE := 100

static var _defs: Array = []


static func defs() -> Array:
	if _defs.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary:
			_defs = d.get("side", [])
	return _defs


static func get_def(id: String) -> Dictionary:
	for d in defs():
		if d.get("id", "") == id:
			return d
	return {}


static func level(id: String) -> LevelData:
	var all := defs()
	for i in all.size():
		if all[i].get("id", "") == id:
			if is_mega(all[i]):
				return part_level(id, 0)
			return LevelData.from_dict(all[i], NUMBER_BASE + i)
	return null


static func is_mega(d: Dictionary) -> bool:
	return d.get("twist", "") == "mega"


static func part_count(d: Dictionary) -> int:
	return (d.get("parts", []) as Array).size()


## Part `k` of a mega route, as a level of its own (numbered 820 + 6 × the route's place + k: under the
## dailies' 900s).
static func part_level(id: String, k: int) -> LevelData:
	var all := defs()
	for i in all.size():
		var d: Dictionary = all[i]
		if d.get("id", "") != id:
			continue
		return part_level_of(d, k, NUMBER_BASE + 20 + i * 6 + k)
	return null


## Part `k` of any parted route (a mega route here, or a speedrun course), numbered `number`.
static func part_level_of(d: Dictionary, k: int, number: int) -> LevelData:
	if true:
		var parts: Array = d.get("parts", [])
		k = clampi(k, 0, parts.size() - 1)
		var pd: Dictionary = (parts[k] as Dictionary).duplicate(true)
		pd["title"] = "%s · %d/%d" % [d.get("title", ""), k + 1, parts.size()]
		if k < parts.size() - 1:
			# The exit leads toward the next part on the route's grid.
			var here: Array = parts[k].get("at", [k, 0])
			var there: Array = parts[k + 1].get("at", [k + 1, 0])
			pd["exit_dir"] = [signi(int(there[0]) - int(here[0])), signi(int(there[1]) - int(here[1]))]
		pd["hint"] = d.get("hint", "") if k == 0 else ("Part %d of %d. Deliver everything, then take the exit." % [k + 1, parts.size()] if k < parts.size() - 1 else "Last part! Deliver everything to finish the route.")
		return LevelData.from_dict(pd, number)
	return null


## Every side road's level (for the validator).
static func all_levels() -> Array:
	var out := []
	for d in defs():
		if is_mega(d):
			for k in part_count(d):
				out.append(part_level(str(d.get("id", "")), k))
		else:
			out.append(level(str(d.get("id", ""))))
	return out


## Where a cosmetic is won, for the garage: a side road or a chest.
static func where(item: String) -> String:
	for d in defs():
		if d.get("reward", "") == item:
			return ("Mega route: %s" if is_mega(d) else "Side road: %s") % d.get("title", "")
	for n in CHESTS:
		if CHESTS[n].get("hat", "") == item:
			return "Chest at level %d" % n
	return ""
