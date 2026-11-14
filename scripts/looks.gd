class_name Looks
extends RefCounted
## The cosmetics that restyle the game rather than the van: what packages are shaped like, how the
## buildings are built, the package queue's container, the road surface and the controls' colours. Each is
## a Cosmetics kind with a free default; the rest unlock late (with stars, or from bosses). Progress.wear()
## sets them and calls apply(); everything that draws them reads these.
##   package   "pkg_box" (cardboard), "pkg_hatbox", "pkg_crate", "pkg_capsule"
##   building  "bld_classic", "bld_gingerbread", "bld_castle"
##   queue     "q_chute", "q_conveyor", "q_neon"
##   road      "road_asphalt", "road_cobbles", "road_neon"
##   controls  "ui_classic", "ui_midnight", "ui_bubblegum", "ui_mint"

const DEFAULTS := {"package": "pkg_box", "building": "bld_classic", "queue": "q_chute", "road": "road_asphalt", "controls": "ui_classic"}
const KINDS := ["package", "building", "queue", "road", "controls"]

static var pkg := "pkg_box"
static var building := "bld_classic"
static var queue := "q_chute"
static var road := "road_asphalt"
static var controls := "ui_classic"


## Takes what's being worn from Progress.
static func apply(p: Node) -> void:
	pkg = str(p.get("look_package"))
	building = str(p.get("look_building"))
	queue = str(p.get("look_queue"))
	road = str(p.get("look_road"))
	controls = str(p.get("look_controls"))


static func is_look(kind: String) -> bool:
	return kind in KINDS


# ---------------------------------------------------------------- controls

## A plain button's colours under the worn control scheme (null colour: the palette's usual).
static func button_bg() -> Color:
	match controls:
		"ui_midnight": return Color("2b2d42")
		"ui_bubblegum": return Color("ffd1e8")
		"ui_mint": return Color("c9f2e3")
	return Color(0, 0, 0, 0)


static func button_fg() -> Color:
	match controls:
		"ui_midnight": return Color("e9ecff")
		"ui_bubblegum": return Color("8a1f5c")
		"ui_mint": return Color("1f5f4a")
	return Color(0, 0, 0, 0)


static func button_dim() -> Color:
	var b := button_bg()
	return b.lerp(Color(0.5, 0.5, 0.5), 0.45) if b.a > 0.0 else b


# ---------------------------------------------------------------- road

## [curb, surface, lane marks] for the worn road.
static func road_colors() -> Array:
	match road:
		"road_cobbles": return [Color("5e574e"), Color("8d8478"), Color(1, 1, 1, 0.0)]
		"road_neon": return [Color("00e5ff"), Color("1d1b33"), Color("ff4fd8")]
	return [Palette.ROAD_EDGE, Palette.ROAD, Palette.ROAD_MARK]


## The surface's texture on one road tile (cobbles), centred on `c`, `s` across.
static func road_detail(ci: CanvasItem, c: Vector2, s: float, seed: int) -> void:
	if road != "road_cobbles":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for gy in 3:
		for gx in 3:
			var p := c + (Vector2(gx - 1, gy - 1) + Vector2(rng.randf_range(-0.12, 0.12) + (0.15 if gy % 2 == 1 else 0.0), rng.randf_range(-0.1, 0.1))) * s * 0.26
			var sh := rng.randf_range(0.0, 0.12)
			ci.draw_set_transform(p, rng.randf_range(-0.3, 0.3), Vector2(1.0, 0.75))
			ci.draw_circle(Vector2(0, s * 0.012), s * 0.1, Color("5e574e"))
			ci.draw_circle(Vector2.ZERO, s * 0.1, Color("a39a8c").darkened(sh))
			ci.draw_circle(Vector2(-s * 0.03, -s * 0.03), s * 0.035, Color(1, 1, 1, 0.18))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- previews

## A look's picture for the garage and the unlock card: centred on `c`, about `s` across.
static func draw_preview(ci: CanvasItem, id: String, c: Vector2, s: float, t: float) -> void:
	var kind := Cosmetics.kind_of(id)
	var keep: Variant = null
	match kind:
		"package":
			keep = pkg
			pkg = id
			var cols := ["red", "blue", "yellow"]
			for k in 3:
				var p := c + Vector2((k - 1) * s * 0.3, sin(t * 2.0 + k) * s * 0.03)
				DrawUtil.package(ci, p, s * 0.26, Palette.pkg(cols[k]))
			pkg = keep
		"queue":
			keep = queue
			queue = id
			queue_strip(ci, Rect2(c - Vector2(s * 0.45, s * 0.14), Vector2(s * 0.9, s * 0.28)), t)
			var cols := ["green", "yellow", "blue"]
			for k in 3:
				DrawUtil.package(ci, c + Vector2((k - 1) * s * 0.27, 0), s * 0.2, Palette.pkg(cols[k]))
			queue = keep
		"road":
			keep = road
			road = id
			var rc: Array = road_colors()
			var r := Rect2(c - Vector2(s * 0.45, s * 0.17), Vector2(s * 0.9, s * 0.34))
			DrawUtil.rrect(ci, Rect2(r.position + Vector2(0, s * 0.02), r.size), rc[0], s * 0.1)
			DrawUtil.rrect(ci, r, rc[1], s * 0.1)
			for k in 3:
				road_detail(ci, c + Vector2((k - 1) * s * 0.3, 0), s * 0.32, k * 7 + 3)
			if rc[2].a > 0.0:
				ci.draw_dashed_line(c - Vector2(s * 0.4, 0), c + Vector2(s * 0.4, 0), rc[2], s * 0.025, s * 0.07, true, true)
			road = keep
		"controls":
			keep = controls
			controls = id
			var b := button_bg()
			var f := button_fg()
			if b.a <= 0.0:
				b = Palette.SURFACE
				f = Palette.TEXT
			for k in 2:
				var r := Rect2(c + Vector2(-s * 0.42 + k * s * 0.46, -s * 0.13), Vector2(s * 0.38, s * 0.26))
				DrawUtil.rrect(ci, Rect2(r.position + Vector2(0, s * 0.03), r.size), b.darkened(0.25), s * 0.07)
				DrawUtil.rrect(ci, r, b, s * 0.07)
				Icons.draw(ci, "bulb" if k == 0 else "undo", r.get_center(), s * 0.14, f)
			controls = keep


## Buildings can't be drawn onto another canvas, so their preview is a node: two houses in theme `id`
## (centred on the origin, about `s` across). The garage tile and the unlock card add it as a child.
static func building_preview(id: String, s: float) -> Node2D:
	var n := Node2D.new()
	for k in 2:
		var h := House.new()
		h.theme = id
		h.size = s * 0.6
		h.color = Palette.pkg(["red", "blue"][k])
		h.position = Vector2((k - 0.5) * s * 0.46, s * 0.22 + k * s * 0.04)
		n.add_child(h)
	return n


## The package queue's body under the worn skin, as a plain strip in `r` (previews; StackView draws the
## real one along its own axis with skin_tube()).
static func queue_strip(ci: CanvasItem, r: Rect2, t: float) -> void:
	skin_tube(ci, r, r.size.y, maxf(2.0, r.size.y * 0.06), Vector2(1, 0), fmod(t, 1.0))


## Draws the queue's tube in rect `r` (`tube` across, `lw` line width) for the conveyor and neon skins, `back`
## the direction toward the back of the queue, `roll` how far the belt has moved (0..1 of a place).
static func skin_tube(ci: CanvasItem, r: Rect2, tube: float, lw: float, back: Vector2, roll: float) -> void:
	match queue:
		"q_conveyor":
			DrawUtil.rrect(ci, r.grow(lw * 1.6), Color("2b2f38"), tube * 0.22 + lw)
			DrawUtil.rrect(ci, r, Color("3d434f"), tube * 0.2)
			# Slats across the belt, sliding toward the mouth; yellow roller caps along both edges.
			var horiz := absf(back.x) > 0.5
			var along := r.size.x if horiz else r.size.y
			var width := r.size.y if horiz else r.size.x
			var start := Vector2(r.position.x if back.x > 0.0 else r.end.x, r.position.y) if horiz else Vector2(r.position.x, r.position.y if back.y > 0.0 else r.end.y)
			var across := Vector2(0, 1) if horiz else Vector2(1, 0)
			var step := tube * 0.45
			for k in int(along / step) + 2:
				var d := (k + 1.0 - roll) * step
				if d < lw or d > along - lw:
					continue
				var p := start + back * d
				ci.draw_line(p + across * lw, p + across * (width - lw), Color("566074"), lw * 1.3)
			for k in int(along / (tube * 0.9)) + 1:
				var p := start + back * (k * tube * 0.9 + tube * 0.35)
				if (p - start).length() > along:
					continue
				ci.draw_circle(p, lw * 1.5, Color("ffc53d"))
				ci.draw_circle(p + across * width, lw * 1.5, Color("ffc53d"))
		"q_neon":
			var t := Time.get_ticks_msec() / 1000.0
			var glow := 0.6 + 0.4 * sin(t * 2.4)
			DrawUtil.rrect(ci, r.grow(lw * 4.0), Color(1.0, 0.3, 0.85, 0.12 * glow), tube * 0.3 + lw * 4.0)
			DrawUtil.rrect(ci, r.grow(lw * 1.6), Color(0.0, 0.9, 1.0, 0.9), tube * 0.28 + lw)
			DrawUtil.rrect(ci, r, Color(0.1, 0.08, 0.2, 0.85), tube * 0.28)
			DrawUtil.rrect(ci, r.grow(-lw * 1.2), Color(1.0, 0.3, 0.85, 0.35 * glow), tube * 0.24)
			DrawUtil.rrect(ci, r.grow(-lw * 2.2), Color(0.1, 0.08, 0.2, 0.9), tube * 0.22)
