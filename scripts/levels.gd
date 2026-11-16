class_name Levels
extends RefCounted
## Loads every level from levels/levels.json (see levels/README.md).

const PATH := "res://levels/levels.json"


static func load_all() -> Array:
	var text := FileAccess.get_file_as_string(PATH)
	var data = JSON.parse_string(text)
	if data == null:
		push_error("Could not parse %s" % PATH)
		return []
	var out := []
	var list: Array = data["levels"] if data is Dictionary else data
	for i in list.size():
		var L := LevelData.from_dict(list[i], i + 1)
		for e in L.errors:
			push_error("Level %d: %s" % [L.number, e])
		out.append(L)
	return out


## Packages in each job, in each OG level and on each detour: what winning one adds to the count of
## packages delivered (Progress.delivered). Worked out once, the first time they're asked for.
static var _pk: Array = []
static var _og_pk: Array = []
static var _side_pk := {}


## Packages in job `n` (0 if there's no such job).
static func packages(n: int) -> int:
	if _pk.is_empty():
		for L in load_all():
			_pk.append((L as LevelData).total_orders())
	return int(_pk[n - 1]) if n >= 1 and n <= _pk.size() else 0


## Packages in jobs 1 to `n` - 1: everything on the road before job `n`.
static func packages_before(n: int) -> int:
	var t := 0
	for k in range(1, n):
		t += packages(k)
	return t


## Packages in OG level `n` (levels/og.json).
static func og_packages(n: int) -> int:
	if _og_pk.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://levels/og.json"))
		if data is Dictionary:
			var list: Array = data.get("levels", [])
			for i in list.size():
				_og_pk.append(LevelData.from_dict(list[i], i + 1).total_orders())
	return int(_og_pk[n - 1]) if n >= 1 and n <= _og_pk.size() else 0


## Packages on detour `id` (every part of a mega route); 0 for anything that isn't one.
static func side_packages(id: String) -> int:
	if not _side_pk.has(id):
		var t := 0
		var d := SideRoads.get_def(id)
		if not d.is_empty():
			if SideRoads.is_mega(d):
				for k in SideRoads.part_count(d):
					t += SideRoads.part_level(id, k).total_orders()
			else:
				var L := SideRoads.level(id)
				t = L.total_orders() if L else 0
		_side_pk[id] = t
	return int(_side_pk[id])
