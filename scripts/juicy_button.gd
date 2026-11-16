class_name JuicyButton
extends Button
## A chunky button that squashes when pressed, with an optional icon (Icons), label and corner badge.
## `dim` greys it out but leaves it clickable (the badge stays bright): used for "out of undos, watch an ad".

var icon_name := "":
	set(v):
		icon_name = v
		queue_redraw()
var label := "":
	set(v):
		label = v
		queue_redraw()
## Background; left unset, it's the palette's SURFACE (so it follows night mode).
var bg := Color(0, 0, 0, 0)
## Background while `dim`.
var dim_bg := Color(0, 0, 0, 0)
var fg := Color(0, 0, 0, 0)
var font_px := 44
var icon_scale := 1.0
## Nudges the label (and icon) up or down from the middle (room for a second line under it).
var label_dy := 0.0
var badge := "":
	set(v):
		badge = v
		queue_redraw()
var badge_icon := ""
var badge_color := Palette.ACCENT
var badge_px := 28
## A streak: a little flame inside the button, on the right, with the number in it (0: none).
var flame := 0:
	set(v):
		flame = v
		set_process(flame > 0 or turbo)
		queue_redraw()
## Turbo: full of fuel (marbled like GasLine's), bubbling, a shine sweeping across, the label in white. For
## Hint and Undo once a tank has made them unlimited. Turning it on flashes it.
var turbo := false:
	set(v):
		if turbo != v:
			turbo = v
			_turbo_t = 0.0
			if is_inside_tree():
				restyle()
			set_process(turbo or flame > 0)
			queue_redraw()
var dim := false:
	set(v):
		if dim != v:
			dim = v
			if is_inside_tree():
				restyle()

var _tw: Tween
var _breath: Tween
var _turbo_t := 0.0


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	restyle()
	button_down.connect(_down)
	button_up.connect(_up)
	set_process(flame > 0 or turbo)


func _process(delta: float) -> void:
	_turbo_t += delta
	queue_redraw()


func restyle() -> void:
	UiTheme.button_style(self, _dim_bg() if dim else _bg(), _fg())
	queue_redraw()


## Unset colours follow the palette, or the worn control scheme (a Looks cosmetic).
func _bg() -> Color:
	if turbo:
		return Color(0.43, 0.31, 0.72)          # (its lip: the fuel's purple)
	return bg if bg.a > 0.0 else (Looks.button_bg() if Looks.button_bg().a > 0.0 else Palette.SURFACE)


func _fg() -> Color:
	return fg if fg.a > 0.0 else (Looks.button_fg() if Looks.button_fg().a > 0.0 else Palette.TEXT)


func _dim_bg() -> Color:
	return dim_bg if dim_bg.a > 0.0 else (Looks.button_dim() if Looks.button_dim().a > 0.0 else Palette.SURFACE_DIM)


func recolor(new_bg: Color, new_fg: Color) -> void:
	bg = new_bg
	fg = new_fg
	if is_inside_tree():
		restyle()


func _down() -> void:
	pivot_offset = size / 2.0
	_kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2(0.93, 0.93), 0.05)


func _up() -> void:
	pivot_offset = size / 2.0
	_kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _kill() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	rotation = 0.0


## "Ooh, use me": a pulse and a quick shake.
func wiggle() -> void:
	if is_pressed():
		return
	pivot_offset = size / 2.0
	_kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)
	for a in [-0.1, 0.1, -0.08, 0.08, -0.04, 0.0]:
		_tw.tween_property(self, "rotation", a, 0.055)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A quick "look at me" hop.
func pop() -> void:
	pivot_offset = size / 2.0
	_kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2(1.16, 1.16), 0.08)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Gentle endless pulse, to invite a tap.
func breathe(on: bool) -> void:
	if _breath and _breath.is_valid():
		_breath.kill()
	_breath = null
	if not on:
		scale = Vector2.ONE
		return
	pivot_offset = size / 2.0
	_breath = create_tween().set_loops()
	_breath.tween_property(self, "scale", Vector2(1.06, 1.06), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(self, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _draw() -> void:
	if turbo:
		_draw_turbo()
	var f := UiTheme.font()
	var mid := size / 2.0 + Vector2(0, (2.0 if is_pressed() else -3.0) + label_dy)
	var col := Color(_fg(), 0.45) if dim else _fg()
	if turbo:
		col = Color(1, 1, 1, 0.6 if dim else 1.0)
	var isz := minf(size.y * 0.5, font_px * 1.3) * icon_scale if icon_name != "" else 0.0
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x if label != "" else 0.0
	var gap := font_px * 0.26 if (isz > 0.0 and tw > 0.0) else 0.0
	var fw := font_px * 1.5 if flame > 0 else 0.0
	var x := mid.x - (isz + gap + tw + fw) / 2.0
	if isz > 0.0:
		Icons.draw(self, icon_name, Vector2(x + isz / 2.0, mid.y), isz, col)
		x += isz + gap
	if tw > 0.0:
		draw_string(f, Vector2(x, mid.y + font_px * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, col)
		x += tw
	if flame > 0:
		var t := Time.get_ticks_msec() / 1000.0
		var fc := Vector2(x + font_px * 0.35 + fw * 0.5, mid.y + font_px * 0.66)
		var pal := AnimeFire.palette(flame + 2)
		AnimeFire.draw_flame(self, fc, font_px * 1.15, font_px * (1.5 + 0.04 * mini(flame, 8)), t, 2.0, pal)
		var num := str(flame)
		var npx := int(font_px * (0.78 if num.length() < 3 else 0.6))
		var nw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, npx).x
		var np := Vector2(fc.x - nw / 2.0, fc.y - font_px * 0.16)
		draw_string_outline(f, np, num, HORIZONTAL_ALIGNMENT_LEFT, -1, npx, 10, pal[0].darkened(0.4))
		draw_string(f, np, num, HORIZONTAL_ALIGNMENT_LEFT, -1, npx, Color.WHITE)
	if badge != "":
		var bw := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_px).x
		var bi := badge_px * 1.1 if badge_icon != "" else 0.0
		var h := badge_px * 1.7
		var w := maxf(bw + bi + (badge_px * 0.3 if bi > 0.0 else 0.0) + badge_px * 1.0, h)
		var r := Rect2(size.x - w + 14.0, -h * 0.5, w, h)
		DrawUtil.rrect(self, r.grow(5.0), Color.WHITE, h)
		DrawUtil.rrect(self, r, badge_color, h)
		var bx := r.position.x + (w - (bw + bi + (badge_px * 0.3 if bi > 0.0 else 0.0))) / 2.0
		if bi > 0.0:
			Icons.draw(self, badge_icon, Vector2(bx + bi / 2.0, r.get_center().y), bi, Color.WHITE)
			bx += bi + badge_px * 0.3
		draw_string(f, Vector2(bx, r.get_center().y + badge_px * 0.35), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_px, Color.WHITE)


## The turbo face: the button's face (its rounded top, above the lip) painted in strips of marbled fuel, a
## shine sweeping across every couple of seconds, bubbles rising; a white flash as it's switched on.
func _draw_turbo() -> void:
	var t := _turbo_t
	var face_h := size.y - (2.0 if is_pressed() else 8.0)
	var rad := minf(30.0, minf(size.x, face_h) / 2.0)
	var flash := clampf(1.0 - t / 0.5, 0.0, 1.0)
	var sheen := fmod(t * 0.45, 1.0) * (size.x + face_h * 1.4) - face_h * 0.7
	var dark := 0.35 if dim else 0.0
	var step := 8.0
	var x := 0.0
	while x < size.x - 0.01:
		var x1 := minf(x + step, size.x)
		var ins0 := _corner_inset(x, rad)
		var ins1 := _corner_inset(x1, rad)
		for k in 3:
			var ya0 := lerpf(ins0, face_h - ins0, k / 3.0)
			var yb0 := lerpf(ins0, face_h - ins0, (k + 1) / 3.0)
			var ya1 := lerpf(ins1, face_h - ins1, k / 3.0)
			var yb1 := lerpf(ins1, face_h - ins1, (k + 1) / 3.0)
			var pts := PackedVector2Array([Vector2(x, ya0), Vector2(x1, ya1), Vector2(x1, yb1), Vector2(x, yb0)])
			var cols := PackedColorArray()
			for p in pts:
				var c := GasLine.juice(p * 1.6 + global_position, t * 0.6)
				# The shine: a slanted band of light.
				var d := absf(p.x + p.y * 0.5 - sheen)
				c = c.lerp(Color.WHITE, 0.35 * clampf(1.0 - d / 26.0, 0.0, 1.0) + 0.75 * flash)
				cols.append(c.lerp(Color(0.4, 0.38, 0.42), dark))
			draw_polygon(pts, cols)
		x = x1
	# Bubbles, rising and wobbling, popping at the top.
	for i in 6:
		var sd := float(i) * 1.618
		var u := fmod(t * (0.35 + 0.08 * i) + sd, 1.0)
		var bx := fmod(sd * 97.0, size.x - 40.0) + 20.0 + sin(t * 3.0 + sd * 5.0) * 5.0
		var by := lerpf(face_h - 12.0, 14.0, u)
		draw_circle(Vector2(bx, by), 3.0 + 3.0 * fmod(sd * 3.3, 1.0), Color(1, 1, 1, 0.4 * sin(u * PI) * (1.0 - dark)))
	# A gloss along the top.
	draw_line(Vector2(rad, 7.0), Vector2(size.x - rad, 7.0), Color(1, 1, 1, 0.3), 4.0, true)


## How far in from the top (and bottom) the face's rounded corners are, at `x` across.
func _corner_inset(x: float, rad: float) -> float:
	var d := minf(x, size.x - x)
	if d >= rad:
		return 0.0
	var q := rad - d
	return rad - sqrt(maxf(rad * rad - q * q, 0.0))
