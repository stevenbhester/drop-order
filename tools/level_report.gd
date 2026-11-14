extends SceneTree
## The level scorecard: fun, cleverness, complexity and difficulty for every level, with the measures
## behind them (tools/level_metrics.gd; explained in design/level_engine.md).
##   godot --headless --path . --script res://tools/level_report.gd -- [--from=1] [--to=100]
##       [--file=res://levels/levels.json] [--json] [--fast]
## Flags: DOTS (connect-the-dots: the map allows 3 or fewer delivery orders even with colours ignored),
## decor:<mechanic> (a whole mechanic that changes nothing), N/M idle (mechanic tiles that change nothing),
## and SAME (the same flavour as the level before).
## --json prints one JSON object per level (tools/score_all.sh runs ranges side by side; tools/level_review.py
## turns that into design/level_scores.md). --fast skips the trap search and the ablation.

const Metrics := preload("res://tools/level_metrics.gd")


func _init() -> void:
	var from := 1
	var to := 9999
	var file := "res://levels/levels.json"
	var as_json := false
	var fast := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			from = a.trim_prefix("--from=").to_int()
		elif a.begins_with("--to="):
			to = a.trim_prefix("--to=").to_int()
		elif a.begins_with("--file="):
			file = a.trim_prefix("--file=")
		elif a == "--json":
			as_json = true
		elif a == "--fast":
			fast = true
	var data = JSON.parse_string(FileAccess.get_file_as_string(file))
	var raw: Array = data["levels"] if data is Dictionary else data
	if not as_json:
		print("  #  title                  fun clv cpx dif | routes plans free orders bits dec anti trick traps late | len cover greedy | flags")
	for n in range(from, mini(to, raw.size()) + 1):
		var d: Dictionary = raw[n - 1]
		var m := Metrics.measure(d, n, {"deep": not fast, "ablate": not fast})
		if as_json:
			var o := m.duplicate()
			o.erase("route")
			o.erase("shortest")
			o["n"] = n
			o["title"] = str(d.get("title", ""))
			o["flavor"] = str(d.get("flavor", ""))
			print("JSON " + JSON.stringify(o))
			continue
		if not m["ok"]:
			print("%3d  %-22s NOT SOLVED %s" % [n, str(d.get("title", "")).substr(0, 22), str(m.get("errors", []))])
			continue
		var flags := []
		if int(m["free_orders"]) >= 0 and int(m["free_orders"]) <= 3:
			flags.append("DOTS")
		if n >= 2 and str(d.get("flavor", "")) != "" and str(d.get("flavor", "")) == str((raw[n - 2] as Dictionary).get("flavor", "")) \
				and str(d.get("flavor", "")) != "intro":
			flags.append("SAME")
		for fam in m["matters"]:
			if not m["matters"][fam]:
				flags.append("decor:" + str(fam))
		if int(m["idle"]) > 0:
			flags.append("%d/%d idle" % [m["idle"], m["mech_tiles"]])
		print("%3d  %-22s %4.1f %3.1f %3.1f %3.1f | %6d %5d %4d %6d %4.1f %3d %4d %5.1f %5d %4.1f | %3d %4d%% %5.2f | %s" % [n,
			str(d.get("title", "")).substr(0, 22), m["fun"], m["cleverness"], m["complexity"], m["difficulty"],
			m["solutions"], m["plans"], m["free"], m["free_orders"], m["bits"], m["decisions"], m["anti"], m["trick"], m["traps"],
			m["late"], m["len"], int(float(m["cover"]) * 100.0), m["greedy"], (str(d.get("flavor", "")) + " " + " ".join(flags)).strip_edges()])
	quit()
