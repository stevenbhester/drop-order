class_name Speedrun
extends RefCounted
## Speedrun mode: courses of small, quick puzzles (levels/speedrun.json) played back to back against the
## clock. A course is a run of zones laid out on a grid, like a mega route: clear a zone, drive into its
## exit, the camera pans on and the next zone loads with its own packages. The clock runs from GO to the
## last delivery; no hints, no undos; Retry starts the course over. Each course keeps its best time.
## Unlocks once level UNLOCK_LEVEL is beaten (by then every mechanic in the courses has been met).

const PATH := "res://levels/speedrun.json"
const UNLOCK_LEVEL := 18
## Zone levels are numbered from here (clear of everything else).
const NUMBER_BASE := 870

static var _defs: Array = []


static func defs() -> Array:
	if _defs.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary:
			_defs = d.get("courses", [])
	return _defs


## A course, ready for Game: it plays like a mega route ("parts"), flagged as a speedrun.
static func get_def(id: String) -> Dictionary:
	for d in defs():
		if d.get("id", "") == id:
			var c: Dictionary = d.duplicate(true)
			c["twist"] = "mega"
			c["speedrun"] = true
			return c
	return {}


static func zone_level(id: String, k: int) -> LevelData:
	var all := defs()
	for i in all.size():
		if all[i].get("id", "") == id:
			return SideRoads.part_level_of(get_def(id), k, NUMBER_BASE + i * 6 + k)
	return null


static func all_levels() -> Array:
	var out := []
	for d in defs():
		for k in (d.get("parts", []) as Array).size():
			out.append(zone_level(str(d.get("id", "")), k))
	return out


## "1:23.4"
static func clock(secs: float) -> String:
	var tenths := int(floor(secs * 10.0))
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]
