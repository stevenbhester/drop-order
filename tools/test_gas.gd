extends SceneTree
## Checks the gas-tank refill sums (Progress.regen) without touching any save.
##   godot --headless --path . --script res://tools/test_gas.gd


func _init() -> void:
	var P = load("res://scripts/progress.gd")
	var m: int = P.MAX_GAS
	var s: float = P.GAS_SECONDS
	var now := 1000000.0
	var cases := [
		# [tanks, refilling since, now, expected tanks, expected seconds until the next]
		[m, 0.0, now, m, 0.0],
		[m - 1, now, now + s - 1.0, m - 1, 1.0],
		[m - 1, now, now + s, m, 0.0],
		[0, now, now + s * 2.5, 2, s * 0.5],
		[0, now, now + s * 99.0, m, 0.0],
		[2, now + 500.0, now, 2, s],        # clock went backwards: the wait starts again
		[3, 0.0, now, 3, s],                # no start recorded: starts now
	]
	var bad := 0
	for c in cases:
		var r: Array = P.regen(c[0], c[1], c[2])
		var wait: float = 0.0 if r[0] >= m else r[1] + s - c[2]
		var ok: bool = r[0] == c[3] and absf(wait - c[4]) < 0.001
		if not ok:
			bad += 1
		print("%s  regen(%d, since %+.0f) -> %d tanks, next in %.0f s (wanted %d, %.0f)" % ["ok  " if ok else "FAIL", c[0], c[1] - c[2], r[0], wait, c[3], c[4]])
	print("commas: ", P.commas(0), " ", P.commas(999), " ", P.commas(1500), " ", P.commas(-1234567))
	print("gas test: %s" % ("all ok" if bad == 0 else "%d FAILED" % bad))
	quit(1 if bad > 0 else 0)
