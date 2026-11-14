extends Node
## Design aid: pickups vs drop-offs in a few looks, side by side, saved as one picture (no window needed).
##   godot --path . res://tools/preview/pickup_styles.tscn -- --out=/path/pickup_styles.png

const W := 2200
const T := 200.0
const COLORS := ["red", "blue", "yellow"]
const ROWS := [
	["Now", "Drop-offs on a light-green yard; pickups in a cream lot with a dashed outline in their colour."],
	["A. Tinted yards", "Drop-offs: a yard tinted their colour with a bold solid border. Pickups as now."],
	["B. Bare houses", "Drop-offs: no yard, just a doormat in their colour. Pickups: dark asphalt with hazard stripes."],
	["C. Targets", "Drop-offs: a round bullseye in their colour. Pickups: a square lot, as now."],
]

var _vp: SubViewport
var _ground: Node2D
var _out := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	var h := int(170 + ROWS.size() * 400 + 40)
	_vp = SubViewport.new()
	_vp.size = Vector2i(W, h)
	_vp.transparent_bg = false
	_vp.msaa_2d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_ground = Node2D.new()
	_ground.draw.connect(_draw_ground)
	_vp.add_child(_ground)
	for r in ROWS.size():
		for c in COLORS.size():
			var x0 := _group_x(c)
			var y0 := _row_y(r)
			var sh := Shop.new()
			sh.color = Palette.pkg(COLORS[c])
			sh.size = T
			sh.stock = 1 if c != 1 else 2
			sh.left = sh.stock
			if r == 2:
				sh.zone = false
			sh.base_pos = Vector2(x0 + T * 0.5, y0 + T * 0.8)
			sh.position = sh.base_pos
			_vp.add_child(sh)
			var ho := House.new()
			ho.color = Palette.pkg(COLORS[c])
			ho.size = T
			ho.base_pos = Vector2(x0 + T * 1.5 + 40.0, y0 + T * 0.8)
			ho.position = ho.base_pos
			_vp.add_child(ho)
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.save_png(_out if _out != "" else "user://pickup_styles.png")
	print("saved ", _out)
	get_tree().quit()


func _group_x(c: int) -> float:
	return 560.0 + c * 560.0


func _row_y(r: int) -> float:
	return 170.0 + r * 400.0 + 40.0


func _draw_ground() -> void:
	var g := _ground
	g.draw_rect(Rect2(0, 0, W, _vp.size.y), Palette.BG)
	var f := UiTheme.font()
	g.draw_string(f, Vector2(50, 100), "Pickups vs drop-offs: which look?", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Palette.TEXT)
	for r in ROWS.size():
		var y0 := _row_y(r)
		# The row's name and what it does.
		g.draw_string(f, Vector2(50, y0 + 70), ROWS[r][0], HORIZONTAL_ALIGNMENT_LEFT, 460, 50, Palette.TEXT)
		g.draw_multiline_string(f, Vector2(50, y0 + 130), ROWS[r][1], HORIZONTAL_ALIGNMENT_LEFT, 450, 28, -1, Palette.TEXT_SOFT)
		for c in COLORS.size():
			var x0 := _group_x(c)
			var col := Palette.pkg(COLORS[c])
			# A strip of the board: grass, the two lots, the road along the bottom.
			var strip := Rect2(x0 - 30, y0 - 20, T * 2.0 + 100.0, T + 140.0)
			DrawUtil.rrect(g, strip, Palette.GRASS, 30)
			var road := Rect2(strip.position.x + 14, y0 + T + 14, strip.size.x - 28, 90)
			DrawUtil.rrect(g, road, Palette.ROAD, 30)
			var pick := Rect2(x0, y0, T, T).grow(-T * 0.05)
			var drop := Rect2(x0 + T + 40.0, y0, T, T).grow(-T * 0.05)
			_lot(r, pick, col, false)
			_lot(r, drop, col, true)
			g.draw_string(f, Vector2(pick.get_center().x - 46, road.get_center().y + 12), "pickup", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.85))
			g.draw_string(f, Vector2(drop.get_center().x - 56, road.get_center().y + 12), "drop-off", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.85))


## The ground under a pickup or a drop-off, in row `r`'s look.
func _lot(r: int, rect: Rect2, col: Color, drop: bool) -> void:
	var g := _ground
	match r:
		0:
			if drop:
				DrawUtil.rrect(g, rect, Palette.YARD, T * 0.18)
		1:
			if drop:
				DrawUtil.rrect(g, rect, col.darkened(0.15), T * 0.2)
				DrawUtil.rrect(g, rect.grow(-T * 0.06), col.lerp(Color.WHITE, 0.72), T * 0.16)
		2:
			if drop:
				var mat := Rect2(rect.get_center().x - T * 0.2, rect.end.y - T * 0.14, T * 0.4, T * 0.12)
				DrawUtil.rrect(g, mat, col, T * 0.04)
				for k in 3:
					g.draw_line(Vector2(mat.position.x + T * 0.06, mat.position.y + T * 0.03 + k * T * 0.03), Vector2(mat.end.x - T * 0.06, mat.position.y + T * 0.03 + k * T * 0.03), Color(1, 1, 1, 0.35), T * 0.012)
			else:
				var pad := rect.grow(-T * 0.02)
				DrawUtil.rrect(g, pad, Color("2b2f38"), T * 0.08)
				DrawUtil.rrect(g, pad.grow(-T * 0.06), Color("4a4f5c"), T * 0.05)
				# Hazard stripes round the edge.
				var st := T * 0.06
				var k := 0.0
				while k < pad.size.x:
					var x := pad.position.x + k
					for yy in [pad.position.y, pad.end.y - st]:
						g.draw_colored_polygon(PackedVector2Array([Vector2(x, yy), Vector2(minf(x + st, pad.end.x), yy), Vector2(minf(x + st * 2.0, pad.end.x), yy + st), Vector2(minf(x + st, pad.end.x), yy + st)]), Color("ffc53d"))
					k += st * 2.0
		3:
			if drop:
				var c := rect.get_center() + Vector2(0, T * 0.06)
				g.draw_circle(c, T * 0.47, col.darkened(0.15))
				g.draw_circle(c, T * 0.42, col.lerp(Color.WHITE, 0.78))
				g.draw_circle(c, T * 0.3, col.lerp(Color.WHITE, 0.45))
				g.draw_circle(c, T * 0.18, col.lerp(Color.WHITE, 0.78))
