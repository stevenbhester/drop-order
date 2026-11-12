class_name RouteLine
extends Node2D
## The route being planned (or still to drive): a thick rounded ribbon through `points` (board space).
## Each stretch is tinted with the package that'll be on top while the van drives it (`colors`, one per
## stretch; null or missing: plain white), inside a white edge so it reads on any road. Across a bridge
## tile it turns into dots: that tile can still be crossed the other way.

const EDGE := Color("fffdf6")

var board: Board
var width := 30.0
var points := PackedVector2Array()
var colors: Array = []


func set_route(pts: PackedVector2Array, cols: Array = []) -> void:
	points = pts
	colors = cols
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	# Every stretch is two halves, each inside one tile (the one its end point is in).
	var halves: Array = []           # [from, to, colour or null, dotted]
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var m := a.lerp(b, 0.5)
		var col = colors[i] if i < colors.size() else null
		halves.append([a, m, col, _bridge(a)])
		halves.append([b, m, col, _bridge(b)])
	for pass_i in 2:
		for h in halves:
			var col = h[2]
			if pass_i == 1 and col == null:
				continue
			var c: Color = EDGE if pass_i == 0 else col
			var w := width if pass_i == 0 else width * 0.56
			var from: Vector2 = h[0]
			var to: Vector2 = h[1]
			if h[3]:
				# Dots, counted out from the tile's own point.
				var dir := (to - from).normalized()
				for d in [0.0, 0.25, 0.5]:
					var at: Vector2 = from + dir * board.tile * d
					if at.distance_to(from) <= from.distance_to(to) + 1.0:
						draw_circle(at, w * 0.36, c)
			else:
				draw_line(from, to, c, w, true)
				draw_circle(from, w * 0.5, c)
				draw_circle(to, w * 0.5, c)


func _bridge(p: Vector2) -> bool:
	return board != null and board.L.bridges.has(board.tile_at(p))
