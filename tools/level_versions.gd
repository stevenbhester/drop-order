extends SceneTree
## Keeps levels/level_versions.json: for every main level, the fingerprint of each layout it has had, oldest
## first. A level's version (v1, v2, ...) is its place in that list (the last time that layout appears); ratings send it (Rating), so feedback on
## an old layout can be told from feedback on the current one. Run after changing levels/levels.json
## (tools/engine/assemble.py runs it):
##   godot --headless --path . --script res://tools/level_versions.gd [-- older.json ...]
## Files named after "--" are earlier sets of levels, oldest first, added to the history before the current one.

const PATH := "res://levels/level_versions.json"


func _init() -> void:
	var hist := {}
	if FileAccess.file_exists(PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary:
			hist = d
	var files: Array = []
	for a in OS.get_cmdline_user_args():
		files.append(a if a.begins_with("res://") else "res://" + a)
	files.append("res://levels/levels.json")
	var changed := 0
	for f in files:
		var data = JSON.parse_string(FileAccess.get_file_as_string(f))
		var list: Array = data["levels"] if data is Dictionary else data
		for i in list.size():
			var key := str(i + 1)
			var fp := LevelData.fingerprint(list[i])
			var seen: Array = hist.get(key, [])
			if seen.is_empty() or int(seen.back()) != fp:
				seen.append(fp)   # never reordered, so old numbers keep their meaning
				hist[key] = seen
				changed += 1
	var out := FileAccess.open(PATH, FileAccess.WRITE)
	out.store_string(JSON.stringify(hist, "", false))
	print("level versions: %d level(s) with a new layout; written %s" % [changed, PATH])
	quit()
