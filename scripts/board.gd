class_name Board
extends Node2D
## Renders a LevelData: grass, roads, houses, and the drawn route.
## Knows nothing about rules; Game tells it what to show.

var L: LevelData
var tile := 180.0
var house_nodes: Array = []      # House, same order as L.houses
var path_line: Line2D


func setup(level: LevelData, tile_size: float) -> void:
	L = level
	tile = tile_size
	path_line = Line2D.new()
	path_line.width = tile * 0.3
	path_line.default_color = Palette.PATH
	path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	path_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	path_line.antialiased = true
	add_child(path_line)
	for h in L.houses:
		var n := House.new()
		n.color = Palette.pkg(h.color)
		n.order = h.order
		n.size = tile
		n.base_pos = center(h.pos) + Vector2(0, tile * 0.3)
		n.position = n.base_pos
		add_child(n)
		house_nodes.append(n)
	queue_redraw()


func size_px() -> Vector2:
	return Vector2(L.width, L.height) * tile


func center(p: Vector2i) -> Vector2:
	return (Vector2(p) + Vector2(0.5, 0.5)) * tile


func tile_at(local: Vector2) -> Vector2i:
	return Vector2i(floori(local.x / tile), floori(local.y / tile))


func show_path(points: Array) -> void:
	var pv := PackedVector2Array()
	for p in points:
		pv.append(p if p is Vector2 else center(p))
	path_line.points = pv


func _draw() -> void:
	var sz := size_px()
	var pad := tile * 0.14
	var outer := Rect2(-Vector2(pad, pad), sz + Vector2(pad, pad) * 2.0)
	DrawUtil.rrect(self, Rect2(outer.position + Vector2(0, tile * 0.07), outer.size), Palette.BOARD_SHADOW, tile * 0.3)
	DrawUtil.rrect(self, outer, Palette.GRASS, tile * 0.3)

	for y in L.height:
		for x in L.width:
			var p := Vector2i(x, y)
			var r := Rect2(Vector2(p) * tile, Vector2(tile, tile)).grow(-tile * 0.05)
			match L.cell(p):
				LevelData.Cell.BLOCK:
					if (x + y) % 2 == 0:
						DrawUtil.rrect(self, r, Palette.GRASS_ALT, tile * 0.18)
					var hsh := ((x * 73856093) ^ (y * 19349663)) & 7
					if hsh < 3:
						_tree(center(p) + Vector2((hsh - 1) * tile * 0.14, -tile * 0.04), tile * (0.15 + hsh * 0.02))
				LevelData.Cell.HOUSE:
					DrawUtil.rrect(self, r, Palette.YARD, tile * 0.18)

	# Roads: rounded squares + bridges to right/down neighbours, with a darker curb pass first.
	var m := tile * 0.12
	var rw := tile - m * 2.0
	for pass_i in 2:
		var col := Palette.ROAD_EDGE if pass_i == 0 else Palette.ROAD
		var off := Vector2(0, tile * 0.045) if pass_i == 0 else Vector2.ZERO
		for y in L.height:
			for x in L.width:
				var p := Vector2i(x, y)
				if not L.is_road(p):
					continue
				var o := Vector2(p) * tile + off
				DrawUtil.rrect(self, Rect2(o + Vector2(m, m), Vector2(rw, rw)), col, tile * 0.2)
				if L.is_road(p + Vector2i(1, 0)):
					draw_rect(Rect2(o + Vector2(tile * 0.5, m), Vector2(tile, rw)), col)
				if L.is_road(p + Vector2i(0, 1)):
					draw_rect(Rect2(o + Vector2(m, tile * 0.5), Vector2(rw, tile)), col)
	for y in L.height:
		for x in L.width:
			var p := Vector2i(x, y)
			if not L.is_road(p):
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				if L.is_road(p + d):
					draw_dashed_line(center(p), center(p + d), Palette.ROAD_MARK, tile * 0.035, tile * 0.11, true, true)

	# Depot ring where the van starts.
	draw_arc(center(L.start), tile * 0.36, 0, TAU, 48, Palette.DEPOT, tile * 0.045, true)


func _tree(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(0, r * 0.35), r * 1.02, Color(0, 0, 0, 0.12))
	draw_circle(c, r, Palette.TREE)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.45, Palette.TREE_HI)
