class_name House
extends Node2D
## A customer house. Origin is at the house's base so squash/pop scales from the ground.

var color := Color.RED
## A parcel locker: takes whatever package is on top (drawn as a bank of little doors).
var locker := false
var order := 1
var filled := 0
var size := 180.0
## Building theme (a Looks cosmetic) for just this house (previews); "" follows what's worn.
var theme := ""
var base_pos := Vector2.ZERO
var check_t := 0.0:
	set(v):
		check_t = v
		queue_redraw()
## The package that's next out of the van (at the end of the route being planned, if there is one) is for
## this house: it gives off a soft, slowly breathing glow in its colour.
var next_up := false:
	set(v):
		if next_up != v:
			next_up = v
			set_process(true)
			queue_redraw()
var _glow := 0.0
var _gt := 0.0
## The route being planned will fill this house: a ghost of the tick shows.
var ghost_done := false:
	set(v):
		if ghost_done != v:
			ghost_done = v
			queue_redraw()

var _scale_tw: Tween
var _pos_tw: Tween

## The stroke round the building, so it stands off its pad: a child House that draws just the building, in
## one flat colour (a darker shade of the house's own), eight times a hair's breadth off in every direction,
## behind the real one. `silhouette` marks that child.
const STROKE := 0.026
const OUTLINE_SHADER := "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);\nvoid fragment() {\n\tCOLOR = vec4(tint.rgb, COLOR.a * tint.a);\n}\n"
static var _outline_shader: Shader
var silhouette := false
var _outline: House


func _ready() -> void:
	if silhouette:
		set_process(false)
		return
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = OUTLINE_SHADER
	_outline = House.new()
	_outline.silhouette = true
	_outline.color = color
	_outline.locker = locker
	_outline.order = order
	_outline.size = size
	_outline.theme = theme
	_outline.show_behind_parent = true
	var mat := ShaderMaterial.new()
	mat.shader = _outline_shader
	_outline.material = mat
	add_child(_outline)


func is_full() -> bool:
	return filled >= order


func deliver() -> void:
	filled += 1
	queue_redraw()
	pop()
	if is_full():
		var tw := create_tween()
		tw.tween_property(self, "check_t", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Undo: take packages back. Checkmark shrinks away if no longer full.
func undeliver(to_filled: int) -> void:
	var was_full := is_full()
	filled = to_filled
	queue_redraw()
	pop()
	if was_full and not is_full():
		var tw := create_tween()
		tw.tween_property(self, "check_t", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func pop() -> void:
	_kill(_scale_tw)
	_scale_tw = create_tween()
	_scale_tw.tween_property(self, "scale", Vector2(1.28, 0.74), 0.06)
	_scale_tw.tween_property(self, "scale", Vector2(0.9, 1.14), 0.08)
	_scale_tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Small horizontal shake: "not my package".
func wobble() -> void:
	_kill(_pos_tw)
	position = base_pos
	_pos_tw = create_tween()
	for off in [14.0, -12.0, 8.0, -5.0, 2.0, 0.0]:
		_pos_tw.tween_property(self, "position:x", base_pos.x + off * size / 180.0, 0.035)


func bounce(delay: float) -> void:
	_kill(_pos_tw)
	position = base_pos
	_pos_tw = create_tween()
	_pos_tw.tween_interval(delay)
	_pos_tw.tween_property(self, "position:y", base_pos.y - size * 0.2, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pos_tw.tween_property(self, "position:y", base_pos.y, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## A small hop: "that one's mine!" (houses waiting for the package now on top).
func hop() -> void:
	if _pos_tw and _pos_tw.is_valid() and _pos_tw.is_running():
		return
	position = base_pos
	_pos_tw = create_tween()
	_pos_tw.tween_property(self, "position:y", base_pos.y - size * 0.09, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pos_tw.tween_property(self, "position:y", base_pos.y, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _kill(tw: Tween) -> void:
	if tw and tw.is_valid():
		tw.kill()


func _process(delta: float) -> void:
	_gt += delta
	_glow = move_toward(_glow, 1.0 if next_up and not is_full() else 0.0, delta * 4.0)
	if _glow > 0.0:
		queue_redraw()
	elif not next_up:
		set_process(false)


func _draw() -> void:
	var s := size
	var w := s * 0.62
	var h := s * 0.4
	var done := is_full()
	var wall := color.lerp(Color.WHITE, 0.72)
	var roof := color
	if done:
		wall = wall.lerp(Color("eeeeee"), 0.5)
		roof = roof.lerp(Color("b9b9b9"), 0.5)
	var ink := roof.darkened(0.28)
	var glass := Color("e9e9e9") if done else Color("fff1b8")
	if silhouette:
		# Just the building's shape, nudged eight ways (the shader paints it all one colour).
		for k in 8:
			var a := TAU * k / 8.0
			draw_set_transform(Vector2(cos(a), sin(a)) * s * STROKE, 0.0, Vector2.ONE)
			_shape(s, w, h, wall, roof, ink, glass, done)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if _outline:
		var tint := color.darkened(0.45) if not done else Color("8d8d96")
		(_outline.material as ShaderMaterial).set_shader_parameter("tint", tint)
	if _glow > 0.0:
		# The glow: soft rings of its colour round the house, breathing.
		var pulse := 0.75 + 0.25 * sin(_gt * 3.2)
		var gc := Vector2(0, -s * 0.24)
		for k in 5:
			var r := s * (0.36 + k * 0.07)
			draw_circle(gc, r, Color(color, 0.075 * _glow * pulse))
	DrawUtil.rrect(self, Rect2(-w * 0.62, -s * 0.05, w * 1.24, s * 0.11), Color(0, 0, 0, 0.13), s * 0.05)
	_shape(s, w, h, wall, roof, ink, glass, done)
	_after(s, w, h, roof, done)


## The building itself, in whichever theme is worn.
func _shape(s: float, w: float, h: float, wall: Color, roof: Color, ink: Color, glass: Color, done: bool) -> void:
	# Each colour is a different kind of place (its packages' class): same footprint, same light walls and
	# coloured roof, so it's still the colour you read.
	var look := theme if theme != "" else Looks.building
	if look == "bld_gingerbread" and not locker:
		_gingerbread(s, w, h, roof, done)
	elif look == "bld_castle" and not locker:
		_castle(s, w, h, roof, ink, done)
	else:
		_building(s, w, h, wall, roof, ink, glass, done)


## The usual buildings: each colour a different kind of place.
func _building(s: float, w: float, h: float, wall: Color, roof: Color, ink: Color, glass: Color, done: bool) -> void:
	match "locker" if locker else Palette.kind_of(color):
		"locker":
			_locker(s, w, h, done, glass)
		"biohazard":
			_lab(s, w, h, wall, roof, ink, glass)
		"caution":
			_factory(s, w, h, wall, roof, ink, glass)
		"mystery":
			_tower(s, w, h, wall, roof, ink, glass)
		"organic":
			_barn(s, w, h, wall, roof, ink, glass)
		"hot":
			_diner(s, w, h, wall, roof, ink, glass)
		_:
			_home(s, w, h, wall, roof, ink, glass)


## Gingerbread: a biscuit house with its colour in the icing on the roof, a candy door and gumdrops.
func _gingerbread(s: float, w: float, h: float, roof: Color, done: bool) -> void:
	var dough := Color("c98a4b") if not done else Color("c9b9a8")
	DrawUtil.rrect(self, Rect2(-w / 2, -h, w, h), dough, s * 0.06)
	DrawUtil.rrect(self, Rect2(-w / 2, -s * 0.04, w, s * 0.04), dough.darkened(0.2), s * 0.02)
	var eave := s * 0.08
	var top := Vector2(0, -h - s * 0.3)
	_soft_poly(PackedVector2Array([Vector2(-w / 2 - eave, -h + s * 0.03), top, Vector2(w / 2 + eave, -h + s * 0.03)]), roof, s * 0.03)
	# Icing dripping off the eaves.
	for k in 7:
		var x := -w / 2 - eave + (w + eave * 2.0) * (k + 0.5) / 7.0
		draw_circle(Vector2(x, -h + s * 0.04), s * 0.035, Color.WHITE)
		if k % 2 == 0:
			draw_circle(Vector2(x, -h + s * 0.08), s * 0.022, Color.WHITE)
	for k in 3:
		draw_circle(top.lerp(Vector2(0, -h), 0.2 + k * 0.25) + Vector2((k - 1) * s * 0.05, 0), s * 0.03, [Color("ff5d8f"), Color("7ad7ff"), Color("ffe66d")][k])
	DrawUtil.rrect(self, Rect2(-s * 0.07, -s * 0.21, s * 0.14, s * 0.21), roof.darkened(0.15), s * 0.07)
	for k in 3:
		draw_line(Vector2(-s * 0.07, -s * 0.17 + k * s * 0.06), Vector2(s * 0.07, -s * 0.2 + k * s * 0.06), Color(1, 1, 1, 0.8), s * 0.018)
	for sx in [-1.0, 1.0]:
		var wr := Rect2(Vector2(float(sx) * (w / 2 - s * 0.12) - s * 0.055, -h + s * 0.08), Vector2(s * 0.11, s * 0.11))
		DrawUtil.rrect(self, wr.grow(s * 0.015), Color.WHITE, s * 0.03)
		DrawUtil.rrect(self, wr, Color("fff1b8") if not done else Color("e9e9e9"), s * 0.025)


## Castles: a little stone keep with battlements, two turrets roofed in its colour, and a pennant.
func _castle(s: float, w: float, h: float, roof: Color, ink: Color, done: bool) -> void:
	var stone := Color("bdb9c9") if not done else Color("d6d4dc")
	var hh := h * 1.05
	for sx in [-1.0, 1.0]:
		var tx: float = sx * (w / 2 - s * 0.02)
		DrawUtil.rrect(self, Rect2(tx - s * 0.08, -hh - s * 0.1, s * 0.16, hh + s * 0.1), stone.darkened(0.08), s * 0.03)
		_soft_poly(PackedVector2Array([Vector2(tx - s * 0.11, -hh - s * 0.08), Vector2(tx, -hh - s * 0.32), Vector2(tx + s * 0.11, -hh - s * 0.08)]), roof, s * 0.02)
	DrawUtil.rrect(self, Rect2(-w / 2 + s * 0.06, -hh, w - s * 0.12, hh), stone, s * 0.03)
	for k in 4:
		var x := -w / 2 + s * 0.08 + k * (w - s * 0.16) / 4.0
		draw_rect(Rect2(x, -hh - s * 0.06, (w - s * 0.16) / 8.0, s * 0.06), stone)
	# The pennant on the right turret, flapping.
	var fx := w / 2 - s * 0.02
	var t := Time.get_ticks_msec() / 1000.0
	draw_line(Vector2(fx, -hh - s * 0.32), Vector2(fx, -hh - s * 0.46), Color("4a4458"), s * 0.015)
	draw_colored_polygon(PackedVector2Array([Vector2(fx, -hh - s * 0.46), Vector2(fx + s * 0.13, -hh - s * 0.42 + sin(t * 4.0) * s * 0.015), Vector2(fx, -hh - s * 0.38)]), roof)
	for k in 3:
		draw_line(Vector2(-w / 2 + s * 0.1, -hh * (0.3 + 0.25 * k)), Vector2(w / 2 - s * 0.1, -hh * (0.3 + 0.25 * k)), Color(stone.darkened(0.12), 0.6), s * 0.01)
	# An arched door.
	DrawUtil.rrect(self, Rect2(-s * 0.08, -s * 0.22, s * 0.16, s * 0.22), ink, s * 0.08)
	draw_rect(Rect2(-s * 0.08, -s * 0.1, s * 0.16, s * 0.1), ink)


## On top of any building: the colorblind sign, the count, the ticks.
func _after(s: float, w: float, h: float, roof: Color, done: bool) -> void:
	# Colorblind mode: the package class's mark on a round sign on the building itself (never out over the
	# road), so the place can be matched to its packages by shape.
	if DrawUtil.bold_marks and Palette.kind_of(color) != "" and not locker:
		var kind := Palette.kind_of(color)
		var pc := _sign_at(kind, s, w, h)
		var pr := s * 0.14
		draw_circle(pc + Vector2(0, s * 0.014), pr + s * 0.016, Color(0, 0, 0, 0.16))
		draw_circle(pc, pr + s * 0.016, roof.darkened(0.25))
		draw_circle(pc, pr, Color.WHITE)
		DrawUtil.mark(self, kind, pc, pr * 2.0, SIGN_INK, Color.WHITE, true)

	if order > 1 and not done:
		DrawUtil.count_badge(self, Vector2(s * 0.27, -s * 0.6), s, order - filled, color)

	# The plan will deliver here: a ghost tick.
	if ghost_done and check_t <= 0.0:
		var gc := Vector2(w * 0.45, -h - s * 0.17)
		draw_circle(gc, s * 0.15, Color(1, 1, 1, 0.85))
		draw_arc(gc, s * 0.13, 0, TAU, 28, Color(Palette.CHECK, 0.9), s * 0.03, true)
		draw_polyline(PackedVector2Array([gc + Vector2(-0.065, 0.0) * s, gc + Vector2(-0.02, 0.045) * s, gc + Vector2(0.07, -0.045) * s]),
			Color(Palette.CHECK, 0.9), s * 0.035, true)

	if check_t > 0.0:
		var c := Vector2(w * 0.45, -h - s * 0.17)
		var r := s * 0.15 * check_t
		draw_circle(c + Vector2(0, s * 0.02), r, Color(0, 0, 0, 0.15))
		draw_circle(c, r, Palette.CHECK)
		var k := r / 0.15 / s
		var chk := PackedVector2Array([
			c + Vector2(-0.065, 0.0) * s * k,
			c + Vector2(-0.02, 0.045) * s * k,
			c + Vector2(0.07, -0.045) * s * k,
		])
		draw_polyline(chk, Color.WHITE, s * 0.035 * k, true)


# ---------------------------------------------------------------- buildings (origin at the base)

const SIGN_INK := Color("2b2233")


## Where each building wears its colorblind sign: over the door, in the tower's round window, up in the
## barn's gable, over the diner's window.
func _sign_at(kind: String, s: float, w: float, h: float) -> Vector2:
	match kind:
		"mystery":
			return Vector2(0, -h * 1.2 + s * 0.16)
		"organic":
			return Vector2(0, -h - s * 0.08)
		"hot":
			return Vector2(-w * 0.2, -s * 0.2)
	return Vector2(0, -s * 0.31)

## A filled shape with rounded corners (fill plus a round outline in the same colour).
func _soft_poly(pts: PackedVector2Array, col: Color, rad: float) -> void:
	draw_colored_polygon(pts, col)
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, col, rad * 2.0, true)
	for p in pts:
		draw_circle(p, rad, col)


## A parcel locker: a grey bank of little doors (one swings open as each package goes in) and a "?" on
## top: it takes any package.
func _locker(s: float, w: float, h: float, done: bool, glass: Color) -> void:
	var body := Color("8f98aa") if not done else Color("c9ced8")
	var lw := w * 1.0
	var lh := h * 1.1
	DrawUtil.rrect(self, Rect2(-lw / 2, -lh, lw, lh), body.darkened(0.15), s * 0.05)
	DrawUtil.rrect(self, Rect2(-lw / 2 + s * 0.02, -lh + s * 0.02, lw - s * 0.04, lh - s * 0.04), body, s * 0.04)
	var cols := 3
	var rows := 2
	var cw := (lw - s * 0.1) / cols
	var ch := (lh - s * 0.16) / rows
	var k := 0
	for ry in rows:
		for cx in cols:
			var r := Rect2(Vector2(-lw / 2 + s * 0.05 + cx * cw, -lh + s * 0.1 + ry * ch), Vector2(cw - s * 0.02, ch - s * 0.02))
			var used := k < filled
			DrawUtil.rrect(self, r, Color("e9ecf2") if not used else Palette.CHECK.lightened(0.3), s * 0.02)
			draw_circle(r.position + Vector2(r.size.x * 0.8, r.size.y * 0.5), s * 0.012, Color("6b7385"))
			k += 1
	# The "?" sign on top: any colour goes.
	var c := Vector2(0, -lh - s * 0.1)
	DrawUtil.rrect(self, Rect2(c - Vector2(s * 0.12, s * 0.09), Vector2(s * 0.24, s * 0.18)), Color("ffc93c") if not done else Color("d6d2dc"), s * 0.05)
	var f := UiTheme.font()
	var px := int(s * 0.16)
	var tw := f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(f, c + Vector2(-tw / 2.0, px * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("2b2233"))


## Gifts: a home with a gable roof.
func _home(s: float, w: float, h: float, wall: Color, roof: Color, ink: Color, glass: Color) -> void:
	DrawUtil.rrect(self, Rect2(-w / 2, -h, w, h), wall, s * 0.05)
	var eave := s * 0.07
	_soft_poly(PackedVector2Array([Vector2(-w / 2 - eave, -h + s * 0.03), Vector2(0, -h - s * 0.3), Vector2(w / 2 + eave, -h + s * 0.03)]), roof, s * 0.025)
	DrawUtil.rrect(self, Rect2(-s * 0.07, -s * 0.21, s * 0.14, s * 0.21), ink, s * 0.04)
	# A bow over the door: this is where the presents go.
	for sx in [-1.0, 1.0]:
		draw_circle(Vector2(sx * s * 0.035, -s * 0.235), s * 0.03, roof.lightened(0.2))
	draw_circle(Vector2(0, -s * 0.235), s * 0.018, roof.darkened(0.1))
	DrawUtil.rrect(self, Rect2(-w / 2 + s * 0.07, -h + s * 0.08, s * 0.11, s * 0.11), glass, s * 0.025)
	DrawUtil.rrect(self, Rect2(w / 2 - s * 0.18, -h + s * 0.08, s * 0.11, s * 0.11), glass, s * 0.025)


## Biohazard: a lab, flat-roofed with an observatory dome and a wide window band.
func _lab(s: float, w: float, h: float, wall: Color, roof: Color, ink: Color, glass: Color) -> void:
	# Lab glass is cool blue (warm glass would vanish on its cream walls).
	if glass != Color("e9e9e9"):
		glass = Color("bfe0ff")
	var hh := h * 1.06
	DrawUtil.rrect(self, Rect2(-w / 2, -hh, w, hh), wall, s * 0.04)
	# The dome, then the roof slab over its foot.
	var dc := Vector2(-w * 0.08, -hh - s * 0.02)
	draw_circle(dc, s * 0.16, roof)
	# The telescope slit, open to the sky.
	draw_line(dc + Vector2(0, -s * 0.14), dc + Vector2(0, -s * 0.03), glass, s * 0.045, true)
	DrawUtil.rrect(self, Rect2(-w / 2 - s * 0.04, -hh - s * 0.05, w + s * 0.08, s * 0.08), roof, s * 0.03)
	# A vent pipe on the right.
	DrawUtil.rrect(self, Rect2(w * 0.28, -hh - s * 0.14, s * 0.06, s * 0.1), ink, s * 0.02)
	# Window band and a glass door.
	DrawUtil.rrect(self, Rect2(-w / 2 + s * 0.06, -hh + s * 0.07, w - s * 0.12, s * 0.09), glass, s * 0.025)
	DrawUtil.rrect(self, Rect2(-s * 0.08, -s * 0.18, s * 0.16, s * 0.18), ink, s * 0.03)
	draw_line(Vector2(0, -s * 0.17), Vector2(0, 0), Color(glass, 0.6), s * 0.015)


## Caution: a factory with a sawtooth roof, a smokestack and a roller door.
func _factory(s: float, w: float, h: float, wall: Color, roof: Color, ink: Color, glass: Color) -> void:
	# The stack first, behind the roof.
	DrawUtil.rrect(self, Rect2(w * 0.22, -h - s * 0.34, s * 0.1, s * 0.34), ink, s * 0.03)
	DrawUtil.rrect(self, Rect2(w * 0.22 - s * 0.01, -h - s * 0.34, s * 0.12, s * 0.035), roof, s * 0.015)
	DrawUtil.rrect(self, Rect2(-w / 2, -h, w, h), wall, s * 0.04)
	var teeth := 3
	var tw := (w + s * 0.06) / teeth
	var x0 := -w / 2 - s * 0.03
	for i in teeth:
		var a := x0 + i * tw
		_soft_poly(PackedVector2Array([Vector2(a, -h + s * 0.02), Vector2(a, -h - s * 0.15), Vector2(a + tw, -h + s * 0.02)]), roof, s * 0.018)
	# Skylights in the teeth' steep sides... kept simple: a row of small windows, and the roller door.
	for i in 3:
		DrawUtil.rrect(self, Rect2(-w / 2 + s * 0.06 + i * (w - s * 0.12) / 3.0, -h + s * 0.07, (w - s * 0.12) / 3.0 - s * 0.03, s * 0.07), glass, s * 0.02)
	var door := Rect2(-s * 0.1, -s * 0.2, s * 0.2, s * 0.2)
	DrawUtil.rrect(self, door, ink, s * 0.03)
	for k in 2:
		draw_line(Vector2(door.position.x + s * 0.02, -s * 0.15 + k * s * 0.05), Vector2(door.end.x - s * 0.02, -s * 0.15 + k * s * 0.05), Color(wall, 0.35), s * 0.012)
	# Caution stripes along the door's foot.
	var band := Rect2(door.position.x, -s * 0.06, door.size.x, s * 0.06)
	draw_rect(band, Color.WHITE if glass != Color("e9e9e9") else wall)
	var x := band.position.x
	while x < band.end.x:
		var x1 := minf(x + s * 0.04, band.end.x)
		draw_colored_polygon(PackedVector2Array([Vector2(x, band.end.y), Vector2(minf(x + s * 0.03, band.end.x), band.position.y),
			Vector2(minf(x1 + s * 0.03, band.end.x), band.position.y), Vector2(x1, band.end.y)]), roof)
		x += s * 0.08


## Mystery: a narrow tower with a tall pointed roof and a round window.
func _tower(s: float, w: float, h: float, wall: Color, roof: Color, ink: Color, glass: Color) -> void:
	var tw := w * 0.72
	var th := h * 1.2
	DrawUtil.rrect(self, Rect2(-tw / 2, -th, tw, th), wall, s * 0.04)
	var eave := s * 0.06
	_soft_poly(PackedVector2Array([Vector2(-tw / 2 - eave, -th + s * 0.03), Vector2(s * 0.02, -th - s * 0.36), Vector2(tw / 2 + eave, -th + s * 0.03)]), roof, s * 0.022)
	# A crescent moon on the spire.
	var mc := Vector2(s * 0.02, -th - s * 0.42)
	draw_circle(mc, s * 0.05, roof.lightened(0.45))
	draw_circle(mc + Vector2(s * 0.025, -s * 0.012), s * 0.042, roof)
	draw_line(Vector2(s * 0.02, -th - s * 0.37), mc + Vector2(0, s * 0.045), roof, s * 0.02)
	draw_circle(Vector2(0, -th + s * 0.15), s * 0.065, glass)
	# An arched door.
	DrawUtil.rrect(self, Rect2(-s * 0.065, -s * 0.2, s * 0.13, s * 0.2), ink, s * 0.065)


## Organic: a barn with a gambrel roof, a hay-loft window and a big X door.
func _barn(s: float, w: float, h: float, wall: Color, roof: Color, ink: Color, glass: Color) -> void:
	DrawUtil.rrect(self, Rect2(-w / 2, -h, w, h), wall, s * 0.04)
	var e := s * 0.06
	_soft_poly(PackedVector2Array([Vector2(-w / 2 - e, -h + s * 0.03), Vector2(-w / 2 + s * 0.02, -h - s * 0.14), Vector2(0, -h - s * 0.27),
		Vector2(w / 2 - s * 0.02, -h - s * 0.14), Vector2(w / 2 + e, -h + s * 0.03)]), roof, s * 0.022)
	DrawUtil.rrect(self, Rect2(-s * 0.05, -h - s * 0.14, s * 0.1, s * 0.09), glass, s * 0.02)
	var door := Rect2(-s * 0.11, -s * 0.24, s * 0.22, s * 0.24)
	DrawUtil.rrect(self, door, ink, s * 0.03)
	var line := Color(wall, 0.7)
	draw_line(door.position + Vector2(s * 0.025, s * 0.025), door.end - Vector2(s * 0.025, s * 0.01), line, s * 0.018, true)
	draw_line(Vector2(door.end.x - s * 0.025, door.position.y + s * 0.025), Vector2(door.position.x + s * 0.025, door.end.y - s * 0.01), line, s * 0.018, true)


## Hot: a diner, low and wide, with a rounded roof, a stripe and a big front window.
func _diner(s: float, w: float, h: float, wall: Color, roof: Color, ink: Color, glass: Color) -> void:
	var dw := w * 1.1
	var dh := h * 0.92
	# A little chimney behind the roof.
	DrawUtil.rrect(self, Rect2(-dw * 0.32, -dh - s * 0.2, s * 0.07, s * 0.14), ink, s * 0.02)
	# Steam off the grill.
	var st := Vector2(-dw * 0.32 + s * 0.035, -dh - s * 0.22)
	var steam := PackedVector2Array()
	for k in 7:
		steam.append(st + Vector2(sin(k * 1.1) * s * 0.025, -k * s * 0.022))
	draw_polyline(steam, Color(1, 1, 1, 0.75), s * 0.022, true)
	var arch := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		arch.append(Vector2(cos(a) * (dw / 2 + s * 0.04), -dh + s * 0.02 + sin(a) * s * 0.17))
	draw_colored_polygon(arch, roof)
	DrawUtil.rrect(self, Rect2(-dw / 2, -dh, dw, dh), wall, s * 0.05)
	DrawUtil.rrect(self, Rect2(-dw / 2, -dh + s * 0.03, dw, s * 0.05), roof, s * 0.02)
	DrawUtil.rrect(self, Rect2(-dw / 2 + s * 0.06, -dh + s * 0.12, dw * 0.46, s * 0.1), glass, s * 0.03)
	DrawUtil.rrect(self, Rect2(dw * 0.14, -s * 0.2, s * 0.13, s * 0.2), ink, s * 0.035)
