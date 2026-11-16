extends SceneTree
## Scores the simulated drivers' daily runs (build/daily_sim_raw.json, from tools/engine/daily_sim.py) by the
## game's own rules (Daily.earn: badges, points, streaks, personal bests, each driver taking the dailies in
## order), and writes each daily's totals to levels/daily_sim.json in the shape the server sends for a day
## (players, solved, scoreAvg, scores, secs, tries, badges). The game adds them to the real ones
## (Daily.sim_stats, DailyResults.with_sim).
##   godot --headless --path . --script res://tools/sim_dailies.gd

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://build/daily_sim_raw.json"))
	if not (raw is Dictionary):
		print("no build/daily_sim_raw.json: run tools/engine/daily_sim.py")
		quit(1)
		return
	var n := (raw["drivers"] as Array).size()
	var prior := []          # per driver: scores so far
	var streak := []
	for i in n:
		prior.append([])
		streak.append(0)
	var out := []
	for p in raw["puzzles"]:
		var s := {"players": n, "solved": 0, "scoreAvg": 0, "scores": {}, "secs": {}, "tries": {}, "badges": {}}
		var total := 0
		for i in n:
			var r: Dictionary = p["runs"][i]
			if not r["done"]:
				streak[i] = 0
				continue
			streak[i] += 1
			var e := Daily.earn(r, prior[i], streak[i])
			var score := int(e["score"])
			prior[i].append(score)
			s["solved"] += 1
			total += score
			_bump(s["scores"], str(score / 10 * 10))
			_bump(s["secs"], str(mini(300, int(float(r["time"]) / 5.0) * 5)))
			_bump(s["tries"], str(mini(6, int(r["attempts"]))))
			for id in e["ids"]:
				_bump(s["badges"], str(id))
		s["scoreAvg"] = roundi(float(total) / maxf(s["solved"], 1))
		s["fp"] = p["fp"]
		out.append(s)
		print("%-18s solved %2d/%d  first try %2d  avg %3d pts" % [p["title"], s["solved"], n, int(s["tries"].get("1", 0)), s["scoreAvg"]])
	var f := FileAccess.open("res://levels/daily_sim.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"drivers": n, "puzzles": out}, " ") + "\n")
	f.close()
	print("wrote levels/daily_sim.json (%d dailies, %d drivers each)" % [out.size(), n])
	quit()


func _bump(d: Dictionary, k: String) -> void:
	d[k] = int(d.get(k, 0)) + 1
