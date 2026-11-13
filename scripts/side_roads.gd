class_name SideRoads
extends RefCounted
## Little side roads off the road trip.
## - Side challenges (levels/side.json): a short level with a twist, branching off the road after level
##   `after`, open once that level's beaten. Beating it wins a ride. Free to play, no hints or undos.
##     fuel: the tank only holds the shortest route · melt: a time limit (`seconds`) · one_shot: plan it all,
##     one drive, no stopping · fog: the load's shown for `peek` seconds, then only the next is visible.
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
	50: {"gas": 5, "coins": 1500, "hat": "crown"},
}
## What each twist is called on its sign and in the game's top bar.
const TWISTS := {"fuel": "Small tank", "melt": "Beat the clock", "one_shot": "One drive", "fog": "Fog"}
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
			return LevelData.from_dict(all[i], NUMBER_BASE + i)
	return null


## Every side road's level (for the validator).
static func all_levels() -> Array:
	var out := []
	for d in defs():
		out.append(level(str(d.get("id", ""))))
	return out


## Where a cosmetic is won, for the garage: a side road or a chest.
static func where(item: String) -> String:
	for d in defs():
		if d.get("reward", "") == item:
			return "Side road: %s" % d.get("title", "")
	for n in CHESTS:
		if CHESTS[n].get("hat", "") == item:
			return "Chest at level %d" % n
	return ""
