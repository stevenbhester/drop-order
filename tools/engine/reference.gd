extends SceneTree
## What the game's own solver says about each level, in the format `build/lm solve` prints, so the two can
## be compared line for line (tools/engine/crosscheck.sh):
##   godot --headless --path . --script res://tools/engine/reference.gd -- res://levels/levels.json ...
##   id  winning-routes  capped  search-nodes  shortest-route-length

func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		var list: Array = []
		var ids: Array = []
		if data is Dictionary and data.has("levels"):
			list = data["levels"]
			for i in list.size():
				ids.append(str(i + 1))
		elif data is Dictionary and data.has("side"):
			for d in data["side"]:
				if (d as Dictionary).has("map"):
					list.append(d)
					ids.append(str(d["id"]))
		elif data is Array:
			list = data
			for i in list.size():
				ids.append(str(i + 1))
		for i in list.size():
			var L := LevelData.from_dict(list[i], 0)
			if not L.errors.is_empty() or L.has_exit():
				print("%s skip" % ids[i])
				continue
			var r := Solver.solve(L)
			print("%s %d %d %d %d" % [ids[i], r["count"], 1 if r["capped"] else 0, r["nodes"], (r["shortest"] as Array).size() - 1 if r["count"] > 0 else -1])
	quit()
