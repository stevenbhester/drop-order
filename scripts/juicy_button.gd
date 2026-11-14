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
		set_process(flame > 0)
		queue_redraw()
var dim := false:
	set(v):
		if dim != v:
			dim = v
			if is_inside_tree():
				restyle()

var _tw: Tween
var _breath: Tween


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	restyle()
	button_down.connect(_down)
	button_up.connect(_up)
	set_process(flame > 0)


func _process(_delta: float) -> void:
	queue_redraw()


func restyle() -> void:
	UiTheme.button_style(self, _dim_bg() if dim else _bg(), _fg())
	queue_redraw()


## Unset colours follow the palette, or the worn control scheme (a Looks cosmetic).
func _bg() -> Color:
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
	var f := UiTheme.font()
	var mid := size / 2.0 + Vector2(0, 2.0 if is_pressed() else -3.0)
	var col := Color(_fg(), 0.45) if dim else _fg()
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
