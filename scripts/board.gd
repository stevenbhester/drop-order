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
var works_nodes := {}            # road Vector2i -> Roadworks
## A mega route's way on to the next part (null on other levels).
var exit_zone: ExitZone
var gift: Gift
var fire: AnimeFire
var wreck: Wreckage
var path_line: RouteLine
## The red X where the route being drawn runs into torn-up road (or itself): the line stops there.
var crash_mark: CrashMark

var trail_line: Line2D
var hint_line: Line2D
var hint_head: Polygon2D
var _hint_tw: Tween


func setup(level: LevelData, tile_size: float) -> void:
	L = level
	tile = tile_size
	# The start is a little pit stop (and on return levels, the finish too).
	depot = DepotGlow.new()
	depot.tile = tile
	depot.returning = L.return_depot
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
	# The torn-up road replaces the old faint trail line.
	trail_line.visible = false
	wreck = Wreckage.new()
	wreck.L = L
	wreck.tile = tile
	wreck.momentum = Progress.momentum
	wreck.style = Progress.wake
	if L.return_depot:
		wreck.sturdy = L.start
	add_child(wreck)
	if L.has_exit():
		exit_zone = ExitZone.new()
		exit_zone.tile = tile
		exit_zone.dir = L.exit_dir()
		exit_zone.pad = tile * 0.14
		exit_zone.position = center(L.exit)
		add_child(exit_zone)
	fire = AnimeFire.new()
	fire.tile = tile
	fire.momentum = Progress.momentum
	add_child(fire)
	path_line = RouteLine.new()
	path_line.board = self
	path_line.width = tile * 0.3
	add_child(path_line)
	crash_mark = CrashMark.new()
	crash_mark.tile = tile
	crash_mark.visible = false
	crash_mark.z_index = 4
	add_child(crash_mark)
	hint_line = Line2D.new()
	hint_line.width = tile * 0.16
	hint_line.default_color = Palette.HINT
	hint_line.joint_mode = Line2D.LINE_JOINT_ROUND
	hint_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	hint_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	hint_line.antialiased = true
	add_child(hint_line)
	hint_head = Polygon2D.new()
	hint_head.color = Palette.HINT
	hint_head.polygon = PackedVector2Array([Vector2(0.42, 0) * tile, Vector2(0.08, -0.24) * tile, Vector2(0.08, 0.24) * tile])
	hint_head.visible = false
	add_child(hint_head)
	for h in L.houses:
		var n := House.new()
		n.locker = h.color == "any"
		n.color = Palette.pkg(h.color) if not n.locker else Color("8f98aa")
		n.order = h.order
		n.size = tile
		n.base_pos = center(h.pos) + Vector2(0, tile * 0.3)
		n.position = n.base_pos
		add_child(n)
		house_nodes.append(n)
	for sh in L.shops:
		var n := Shop.new()
		n.stock = sh.count
		n.left = sh.count
		n.color = Palette.pkg(sh.color)
		n.size = tile
		n.base_pos = center(sh.pos) + Vector2(0, tile * 0.3)
		n.position = n.base_pos
		add_child(n)
		shop_nodes.append(n)
	if L.gift_item != "" and not Progress.owns(L.gift_item):
		gift = Gift.new()
		gift.item = L.gift_item
		gift.tile = tile
		gift.position = center(L.gift)
		gift.z_index = 3
		add_child(gift)
	for p in L.works:
		var wk := Roadworks.new()
		wk.tile = tile
		wk.need = L.works[p]
		wk.position = center(p)
		add_child(wk)
		works_nodes[p] = wk
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


## Roadworks count down with each delivery and clear away once there have been enough.
func update_works(done: int) -> void:
	for p in works_nodes:
		works_nodes[p].set_done(done)


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


## The planned route. `colors` (optional) has one entry per stretch: the colour of the package on top
## while the van drives it, or null.
func show_path(points: Array, colors: Array = []) -> void:
	path_line.set_route(_pts(points), colors)


## A red X on the edge between tile `from` and tile `to`: the route can't go that way.
func show_block(from: Vector2i, to: Vector2i) -> void:
	crash_mark.position = center(from).lerp(center(to), 0.5)
	if not crash_mark.visible:
		crash_mark.visible = true
		crash_mark.scale = Vector2.ONE * 1.7
		crash_mark.create_tween().tween_property(crash_mark, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func clear_block() -> void:
	crash_mark.visible = false


## A pulsing golden arrow along `points` (tiles): the hint. Empty clears it.
func show_hint(points: Array) -> void:
	if _hint_tw and _hint_tw.is_valid():
		_hint_tw.kill()
	hint_line.points = _pts(points)
	hint_head.visible = points.size() >= 2
	if points.size() < 2:
		return
	var last := center(points[points.size() - 1])
	hint_head.position = last
	hint_head.rotation = (last - center(points[points.size() - 2])).angle()
	hint_line.modulate.a = 1.0
	hint_head.modulate.a = 1.0
	_hint_tw = create_tween().set_loops()
	_hint_tw.tween_method(_hint_alpha, 1.0, 0.4, 0.45).set_trans(Tween.TRANS_SINE)
	_hint_tw.tween_method(_hint_alpha, 0.4, 1.0, 0.45).set_trans(Tween.TRANS_SINE)


func _hint_alpha(a: float) -> void:
	hint_line.modulate.a = a
	hint_head.modulate.a = a


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
				LevelData.Cell.SHOP:
					DrawUtil.rrect(self, r, Palette.YARD, tile * 0.18)
	# Drop-offs stand on a round bullseye in the colour they want, so they can't be mistaken for pickups
	# (square lots with a dashed outline).
	for h in L.houses:
		var col: Color = Palette.pkg(h.color) if h.color != "any" else Color("8f98aa")
		var hc := center(h.pos) + Vector2(0, tile * 0.06)
		draw_circle(hc, tile * 0.47, col.darkened(0.15))
		draw_circle(hc, tile * 0.42, col.lerp(Palette.GRASS.lerp(Color.WHITE, 0.6), 0.78))
		draw_circle(hc, tile * 0.3, col.lerp(Color.WHITE, 0.45))
		draw_circle(hc, tile * 0.18, col.lerp(Palette.GRASS.lerp(Color.WHITE, 0.6), 0.78))

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
				if L.has_exit() and p == L.exit:
					# The exit road: joined on like any other stretch, on out over the map's edge (ExitZone
					# fades it away and puts the gate on it).
					var ed := Vector2(L.exit_dir())
					var sd := Vector2(-ed.y, ed.x) * rw * 0.5
					var a := center(p) + off + sd
					var b := center(p) + off + ed * ExitZone.solid_reach(tile, tile * 0.14) - sd
					draw_rect(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs()), col)
	for y in L.height:
		for x in L.width:
			var p := Vector2i(x, y)
			if not L.is_road(p):
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				if L.is_road(p + d) and not _busy(p) and not _busy(p + d):
					draw_dashed_line(center(p), center(p + d), Palette.ROAD_MARK, tile * 0.035, tile * 0.11, true, true)

	for p in L.ice:
		_ice(p, m, rw)
	for b in L.bridges:
		_bridge(b, m, rw)
	for p in L.oneway:
		_arrow(center(p), Vector2(L.oneway[p]))



## Tiles whose centre is occupied by a marking, so lane dashes skip them.
func _busy(p: Vector2i) -> bool:
	return L.oneway.has(p) or L.hubs.has(p) or L.gates.has(p) or L.ice.has(p) or L.works.has(p)


## An ice tile: pale blue sheen over the road, with streaks along it and a snowflake. No turning on it.
func _ice(p: Vector2i, m: float, rw: float) -> void:
	var o := Vector2(p) * tile
	var r := Rect2(o + Vector2(m, m), Vector2(rw, rw)).grow(tile * 0.02)
	DrawUtil.rrect(self, r, Color("bfe6ff", 0.85), tile * 0.2)
	DrawUtil.rrect(self, r.grow(-tile * 0.06), Color("e3f5ff", 0.9), tile * 0.16)
	var c := center(p)
	for k in 3:
		var a := Vector2(-0.3 + k * 0.12, -0.28 + k * 0.2) * tile
		draw_line(c + a, c + a + Vector2(0.22, 0.0).rotated(-0.5) * tile, Color(1, 1, 1, 0.95), tile * 0.03, true)
	for k in 3:
		var ang := k * PI / 3.0
		var d := Vector2(cos(ang), sin(ang)) * tile * 0.13
		draw_line(c + Vector2(tile * 0.18, tile * 0.18) - d, c + Vector2(tile * 0.18, tile * 0.18) + d, Color("7cc4f2"), tile * 0.03, true)


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
