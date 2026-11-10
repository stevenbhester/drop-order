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
