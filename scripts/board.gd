class_name Board
extends Node2D
## Renders a LevelData: grass, roads, houses, and the drawn route.
## Knows nothing about rules; Game tells it what to show.

var L: LevelData
var tile := 180.0
var house_nodes: Array = []      # House, same order as L.houses
var shop_nodes: Array = []       # Shop, same order as L.shops
var gate_nodes := {}             # Vector2i -> Gate
var hub_nodes := {}              # Vector2i -> Hub
var depot: DepotGlow
var path_line: Line2D
var trail_line: Line2D


func setup(level: LevelData, tile_size: float) -> void:
	L = level
	tile = tile_size
	if L.return_depot:
		depot = DepotGlow.new()
		depot.tile = tile
		depot.position = center(L.start)
		add_child(depot)
	for p in L.hubs:
		var hb := Hub.new()
		hb.tile = tile
		hb.position = center(p)
		add_child(hb)
		hub_nodes[p] = hb
	trail_line = Line2D.new()
	trail_line.width = tile * 0.26
	trail_line.default_color = Palette.TRAIL
	trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
	trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.antialiased = true
	add_child(trail_line)
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
	for sh in L.shops:
		var n := Shop.new()
		n.color = Palette.pkg(sh.color)
		n.size = tile
		n.base_pos = center(sh.pos) + Vector2(0, tile * 0.3)
		n.position = n.base_pos
		add_child(n)
		shop_nodes.append(n)
	for p in L.gates:
		var g := Gate.new()
		g.color = Palette.pkg(L.gates[p])
		g.tile = tile
		g.road_w = tile * 0.76
		g.position = center(p)
		# Traffic along x if the road continues left/right, else rotate for vertical roads.
		if not (L.is_road(p + Vector2i(1, 0)) or L.is_road(p + Vector2i(-1, 0))):
			g.rotation = PI / 2.0
		add_child(g)
		gate_nodes[p] = g
	queue_redraw()


## Lift/lower every gate for the given top package colour.
func update_gates(top: String, instant := false) -> void:
	for p in gate_nodes:
		gate_nodes[p].set_open(L.gates[p] == top, instant)


func size_px() -> Vector2:
	return Vector2(L.width, L.height) * tile


func center(p: Vector2i) -> Vector2:
	return (Vector2(p) + Vector2(0.5, 0.5)) * tile


func tile_at(local: Vector2) -> Vector2i:
	return Vector2i(floori(local.x / tile), floori(local.y / tile))


func show_path(points: Array) -> void:
	path_line.points = _pts(points)


## Faint line over everything already driven (so used roads are visible).
func show_trail(points: Array) -> void:
	trail_line.points = _pts(points)


func _pts(points: Array) -> PackedVector2Array:
	var pv := PackedVector2Array()
	for p in points:
		pv.append(p if p is Vector2 else center(p))
	return pv


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
				LevelData.Cell.HOUSE, LevelData.Cell.SHOP:
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
				if L.is_road(p + d) and not _busy(p) and not _busy(p + d):
					draw_dashed_line(center(p), center(p + d), Palette.ROAD_MARK, tile * 0.035, tile * 0.11, true, true)

	for b in L.bridges:
		_bridge(b, m, rw)
	for p in L.oneway:
		_arrow(center(p), Vector2(L.oneway[p]))

	# Depot ring where the van starts (return levels draw a fuller depot node instead).
	if not L.return_depot:
		draw_arc(center(L.start), tile * 0.36, 0, TAU, 48, Palette.DEPOT, tile * 0.045, true)


## Tiles whose centre is occupied by a marking, so lane dashes skip them.
func _busy(p: Vector2i) -> bool:
	return L.oneway.has(p) or L.hubs.has(p) or L.gates.has(p)


func _tree(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(0, r * 0.35), r * 1.02, Color(0, 0, 0, 0.12))
	draw_circle(c, r, Palette.TREE)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.45, Palette.TREE_HI)


## Vertical road passes over the horizontal one: shadow, raised deck, rails.
func _bridge(p: Vector2i, m: float, rw: float) -> void:
	var c := center(p)
	var top := p.y * tile
	var rail := tile * 0.055
	var over := tile * 0.06
	var half := rw / 2.0 + rail
	# Shadows the deck casts on the road below, either side.
	draw_rect(Rect2(c.x - half - tile * 0.1, top + m, tile * 0.1, rw), Palette.BRIDGE_SHADOW)
	draw_rect(Rect2(c.x + half, top + m, tile * 0.1, rw), Palette.BRIDGE_SHADOW)
	DrawUtil.rrect(self, Rect2(c.x - half, top - over, half * 2.0, tile + over * 2.0), Palette.RAIL, rail)
	draw_rect(Rect2(c.x - rw / 2.0, top - over, rw, tile + over * 2.0), Palette.BRIDGE_DECK)
	for sx in [-1.0, 1.0]:
		for k in 4:
			var y := top - over + (tile + over * 2.0) * (0.12 + k * 0.25)
			draw_circle(Vector2(c.x + sx * (rw / 2.0 + rail * 0.5), y), rail * 0.32, Palette.ROAD_EDGE)
	draw_dashed_line(Vector2(c.x, top - over), Vector2(c.x, top + tile + over), Palette.ROAD_MARK, tile * 0.035, tile * 0.11, true, true)


## Two chevrons pointing the one way you may enter.
func _arrow(c: Vector2, d: Vector2) -> void:
	var perp := Vector2(-d.y, d.x)
	for o in [-0.13, 0.11]:
		var tip: Vector2 = c + d * tile * (o + 0.1)
		var pts := PackedVector2Array([tip - d * tile * 0.13 + perp * tile * 0.17, tip, tip - d * tile * 0.13 - perp * tile * 0.17])
		draw_polyline(pts, Palette.ARROW, tile * 0.075, true)
		for q in pts:
			draw_circle(q, tile * 0.0375, Palette.ARROW)
