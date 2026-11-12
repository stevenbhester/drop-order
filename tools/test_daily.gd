extends SceneTree
## Checks the daily streak rules on a throwaway save (nothing is written).
##   godot --headless --path . --script res://tools/test_daily.gd


func _init() -> void:
	var bad := 0
	var cases := [
		# [description, days as [attempts, solved] from oldest to today, expected streak today]
		["nothing played", [], 0],
		["solved today first try", [[1, true]], 1],
		["three days in a row", [[1, true], [2, true], [1, true]], 3],
		["today with one redo still counts", [[1, true], [2, true]], 2],
		["today with two redos doesn't", [[1, true], [3, true]], 0],
		["yesterday's streak survives until today is played", [[1, true], [1, true], [0, false]], 2],
		["one redo used today, not solved yet: still alive", [[1, true], [2, false]], 1],
		["two redos used today: gone", [[1, true], [3, false]], 0],
		["a missed day breaks it", [[1, true], [0, false], [1, true]], 1],
		["too many redos two days ago breaks it", [[1, true], [4, true], [1, true], [1, true]], 2],
	]
	for c in cases:
		var p = load("res://scripts/progress.gd").new()
		p.volatile = true
		var days: Array = c[1]
		var today := 20000
		for i in days.size():
			var day := today - (days.size() - 1 - i)
			for a in days[i][0]:
				p.daily_attempt(day)
			if days[i][1]:
				p.daily_done(day, 3, 30.0, [])
		var got: int = p.streak(today)
		var ok: bool = got == c[2]
		if not ok:
			bad += 1
		print("%s  %-50s streak %d (wanted %d)" % ["ok  " if ok else "FAIL", c[0], got, c[2]])
		p.free()
	print("daily test: %s" % ("all ok" if bad == 0 else "%d FAILED" % bad))
	quit(1 if bad > 0 else 0)
