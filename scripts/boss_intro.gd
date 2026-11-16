class_name BossIntro
extends CanvasLayer
## Before a boss detour: the lights go down over a skyline of glass towers, HOARDLY INC. blinks on in gold,
## and Baron Von Bottomline rises into view on his private lift, laughing at you (HAW HAW HAW) with a line
## of corporate trash talk. Then BOSS FIGHT! stamps down, with the detour's name and what he's guarding.
## "Bring it on!" (or a tap once it's settled) starts the level. Plays every time you come in: he never
## gets tired of laughing.

signal done

const INK := Color("1b1530")
const RISE := 0.55          # seconds for the lift to bring him up
const STAMP_AT := 1.25

var side := {}
var level: LevelData

var _root: Control
var _t := 0.0
## Main-road boss fights laugh you in once a session (not again on every retry).
static var _seen := {}


static func should_show(L: LevelData) -> bool:
	return Boss.is_level(L.number) and not _seen.has(L.number) and not Progress.auto


var _go: JuicyButton
var _closing := false
var _line := ""
var _laughed := false
var _stamped := false


func _ready() -> void:
	layer = 70
	_line = Boss.taunt_for(side)
	if side.has("level"):
		_seen[int(side["level"])] = true
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(_draw_it)
	_root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and _t > STAMP_AT + 0.3:
			_close())
	add_child(_root)
	_go = JuicyButton.new()
	_go.label = "Bring it on!"
	_go.icon_name = "play"
	_go.font_px = 46
	_go.bg = Boss.GOLD
	_go.fg = INK
	_go.custom_minimum_size = Vector2(520, 128)
	_go.size = _go.custom_minimum_size
	_go.visible = false
	_go.pressed.connect(_close)
	_root.add_child(_go)
	Sfx.play("whoomp", 0.6, -4.0)


func _process(delta: float) -> void:
	var before := _t
	_t += delta
	if before < RISE and _t >= RISE and not _laughed:
		_laughed = true
		Sfx.play("laugh", 1.0, 0.0)
		Sfx.haptic(30, 0.8)
	if before < STAMP_AT and _t >= STAMP_AT:
		_stamped = true
		Sfx.play("slam", 0.8, -2.0)
		Sfx.haptic(35, 1.0)
	if not _go.visible and _t >= STAMP_AT + 0.45:
		var v := _root.size
		_go.visible = true
		_go.position = Vector2(v.x / 2.0 - _go.size.x / 2.0, v.y - _go.size.y - 90.0 - UiTheme.insets(_root.get_viewport()).y)
		_go.pivot_offset = _go.size / 2.0
		_go.scale = Vector2.ZERO
		var tw := _go.create_tween()
		tw.tween_property(_go, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_go.breathe.bind(true))
	_root.queue_redraw()


func _close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("click")
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		done.emit()
		queue_free())


static func _out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


func _text(text: String, at: Vector2, px: int, col: Color, outline: int, ang := 0.0, s := 1.0, alpha := 1.0) -> void:
	var f := UiTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_root.draw_set_transform(at, ang, Vector2.ONE * s)
	var p := Vector2(-w / 2.0, px * 0.36)
	if outline > 0:
		_root.draw_string_outline(f, p + Vector2(0, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Color(0, 0, 0, 0.35 * alpha))
		_root.draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Color(INK, alpha))
	_root.draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, alpha))
	_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## One piece of loot, like a game's item slot: a dark tile with a glowing frame in its rarity's colour
## (headlights gold, undos blue, a paint job purple, anything else pink), its icon, a twinkle in the
## corner, and its name under it (shrunk to fit `w`).
func _loot_tile(c: Vector2, it: Dictionary, k: float, w: float) -> void:
	if k <= 0.0:
		return
	var kind := str(it["kind"])
	var rare: Color = {"lights": Color("ffc53d"), "undos": Color("4d9dff"), "paint": Color("b07aff"), "item": Color("ff6fae")}.get(kind, Color("bfc3cc"))
	var s := 110.0
	_root.draw_set_transform(c, 0.0, Vector2.ONE * k)
	var r := Rect2(-s / 2.0, -s / 2.0, s, s)
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	DrawUtil.rrect(_root, r.grow(10.0), Color(rare, 0.18 + 0.12 * pulse), 26)
	DrawUtil.rrect(_root, r.grow(4.0), rare, 22)
	DrawUtil.rrect(_root, r, Color("231a38"), 18)
	DrawUtil.rrect(_root, Rect2(r.position + Vector2(6, 6), Vector2(s - 12, s * 0.42)), Color(1, 1, 1, 0.06), 14)
	match kind:
		"lights":
			_root.draw_circle(Vector2(0, -6), 34.0, Color(rare, 0.25 + 0.15 * pulse))
			Icons.draw(_root, "bulb", Vector2(0, -2), 64.0, rare)
		"undos":
			Icons.draw(_root, "undo", Vector2(-8, -6), 58.0, Color.WHITE)
			var f := UiTheme.font()
			var n := "+%d" % int(it["n"])
			_root.draw_string_outline(f, Vector2(4, 40), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color("231a38"))
			_root.draw_string(f, Vector2(4, 40), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, rare)
		"item" when Cosmetics.kind_of(str(it["item"])) == "trail":
			Icons.draw(_root, "trail", Vector2(0, -2), 64.0, rare)
		"paint", "item":
			# A little van in the paint (or the item's own colour), side on.
			var id := str(it["item"])
			var body := Cosmetics.body_color(id) if kind == "paint" else Cosmetics.tint(id)
			var cab := Cosmetics.cab_color(id) if kind == "paint" else body.darkened(0.3)
			var vr := Rect2(-40, -26, 80, 44)
			DrawUtil.rrect(_root, vr, body, 12)
			if kind == "paint":
				Cosmetics.draw_pattern(_root, id, Rect2(-40, -26, 52, 44))
			DrawUtil.rrect(_root, Rect2(12, -26, 28, 30), cab, 10)
			DrawUtil.rrect(_root, Rect2(18, -20, 16, 14), Color(0.85, 0.93, 1.0), 4)
			for x in [-22.0, 22.0]:
				_root.draw_circle(Vector2(x, 20), 10.0, Color("15131a"))
				_root.draw_circle(Vector2(x, 20), 4.0, Color("bfbfc8"))
		_:
			Icons.star(_root, Vector2(0, -2), 36.0, rare)
	# A twinkle on the frame's corner.
	var tw := fmod(_t * 0.8 + c.x * 0.01, 1.0)
	if tw < 0.35:
		Icons.star(_root, Vector2(s / 2.0 - 6, -s / 2.0 + 6), 14.0 * sin(PI * tw / 0.35), Color.WHITE)
	_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The name, under it.
	var f := UiTheme.font()
	var label := str(it["label"])
	var px := 28
	while px > 18 and f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w:
		px -= 1
	_text(label, c + Vector2(0, s / 2.0 + 34.0), px, rare.lightened(0.35), 6, 0.0, 1.0, k)


## Wraps `text` to lines no wider than `w` at `px`.
static func wrap_text(text: String, px: int, w: float) -> Array:
	var f := UiTheme.font()
	var lines := []
	var cur := ""
	for word in text.split(" "):
		var next := word if cur == "" else cur + " " + word
		if f.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w and cur != "":
			lines.append(cur)
			cur = word
		else:
			cur = next
	if cur != "":
		lines.append(cur)
	return lines


func _draw_it() -> void:
	var v := _root.size
	var ins := UiTheme.insets(_root.get_viewport())
	var dim := clampf(_t / 0.2, 0.0, 1.0)
	_root.draw_rect(Rect2(Vector2.ZERO, v), Color(0.06, 0.04, 0.12, 0.95 * dim))
	# Layout, top down: the company sign, his line, him on his lift, BOSS FIGHT and the prize, the button.
	var sign_y := ins.x + v.y * 0.1
	var tall := 440.0
	var floor_y := v.y * 0.62
	var button_top := v.y - 218.0 - ins.y
	# The skyline: glass towers, windows lit here and there, the company sign blinking on.
	var base := floor_y
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := -20.0
	while x < v.x:
		var w := rng.randf_range(90.0, 170.0)
		var h := rng.randf_range(260.0, 620.0)
		var r := Rect2(x, base - h, w - 14.0, h + v.y)
		_root.draw_rect(r, Color(0.12, 0.1, 0.22, dim))
		for wy in range(int(base - h + 24.0), int(base + 120.0), 46):
			for wx in range(int(x + 14.0), int(x + w - 30.0), 30):
				if rng.randf() < 0.3:
					_root.draw_rect(Rect2(wx, wy, 14, 22), Color(1.0, 0.85, 0.4, 0.35 * dim))
		x += w
	# His rocket, of course, going up behind the towers (it's drawn before him, so it's "behind").
	var rk := Vector2(v.x * 0.86, base - 330.0 - _t * 70.0)
	var flame := 46.0 + 14.0 * sin(_t * 40.0)
	_root.draw_colored_polygon(PackedVector2Array([rk + Vector2(-10, 44), rk + Vector2(10, 44), rk + Vector2(0, 44 + flame)]), Color(1.0, 0.75, 0.3, 0.8 * dim))
	DrawUtil.rrect(_root, Rect2(rk + Vector2(-13, -34), Vector2(26, 80)), Color(0.85, 0.87, 0.93, dim), 12.0)
	_root.draw_colored_polygon(PackedVector2Array([rk + Vector2(-13, -26), rk + Vector2(0, -62), rk + Vector2(13, -26)]), Color(0.85, 0.87, 0.93, dim))
	for sd: float in [-1.0, 1.0]:
		_root.draw_colored_polygon(PackedVector2Array([rk + Vector2(sd * 13, 22), rk + Vector2(sd * 27, 48), rk + Vector2(sd * 13, 44)]), Color(Boss.GOLD, dim))
	_root.draw_circle(rk + Vector2(0, -6), 6.0, Color(0.15, 0.2, 0.4, dim))
	var sign_on := _t > 0.25 and (fmod(_t, 2.3) > 0.12 or _t < 1.0)
	_text("HOARDLY INC.", Vector2(v.x / 2.0, sign_y), 78, Boss.GOLD if sign_on else Color(0.4, 0.33, 0.2), 14, 0.0, 1.0, dim)
	_text("We deliver. To shareholders.", Vector2(v.x / 2.0, sign_y + 70.0), 34, Color(1, 1, 1, 0.75), 6, 0.0, 1.0, dim * clampf((_t - 0.4) / 0.3, 0.0, 1.0))
	# The Baron, up on his lift.
	var up := _out(_t / RISE)
	var feet := Vector2(v.x / 2.0, floor_y + (1.0 - up) * 700.0)
	var plat := Rect2(feet.x - 210.0, feet.y, 420.0, 34.0)
	DrawUtil.rrect(_root, Rect2(plat.position + Vector2(0, 10), plat.size), Color(0, 0, 0, 0.3), 12.0)
	DrawUtil.rrect(_root, plat, Boss.GOLD, 12.0)
	_root.draw_rect(Rect2(plat.position.x + 30.0, plat.end.y, 14.0, v.y), Color(0.3, 0.26, 0.2))
	_root.draw_rect(Rect2(plat.end.x - 44.0, plat.end.y, 14.0, v.y), Color(0.3, 0.26, 0.2))
	var mood := "laugh" if _t > RISE and _t < RISE + 1.6 else "smug"
	Boss.draw(_root, feet, tall, _t, mood)
	# HAW HAW HAW, popping out of him.
	if _t > RISE:
		for k in 3:
			var a := _t - RISE - k * 0.22
			if a < 0.0 or a > 1.4:
				continue
			var s := _out(a / 0.2)
			var at := feet + Vector2((k - 1) * 330.0, -tall * (0.7 if k != 1 else 1.12) - a * 70.0)
			_text("HAW!", at, 64, Color.WHITE, 10, (k - 1) * 0.2, s, clampf(1.4 - a, 0.0, 1.0))
	# His line, in a speech bubble.
	if _t > RISE + 0.2:
		var k := _out((_t - RISE - 0.2) / 0.25)
		var px := 40
		var lines: Array = wrap_text("“" + _line + "”", px, v.x - 200.0)
		var bh := lines.size() * px * 1.25 + 56.0
		var bubble := Rect2(70.0, maxf(sign_y + 120.0, feet.y - tall * 1.2 - bh - 50.0), v.x - 140.0, bh)
		_root.draw_set_transform(bubble.get_center(), 0.0, Vector2.ONE * k)
		var local := Rect2(-bubble.size / 2.0, bubble.size)
		DrawUtil.rrect(_root, Rect2(local.position + Vector2(0, 8), local.size), Color(0, 0, 0, 0.3), 36.0)
		DrawUtil.rrect(_root, local, Color.WHITE, 36.0)
		_root.draw_colored_polygon(PackedVector2Array([Vector2(-30, local.end.y - 2), Vector2(30, local.end.y - 2), Vector2(0, local.end.y + 50)]), Color.WHITE)
		var f := UiTheme.font()
		for i in lines.size():
			var lw := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			_root.draw_string(f, Vector2(-lw / 2.0, local.position.y + 28.0 + px + i * px * 1.25), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, INK)
		_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# BOSS FIGHT!, the detour, and what he's sitting on.
	if _t >= STAMP_AT - 0.05:
		var u := (_t - STAMP_AT + 0.05) / 0.16
		var s := lerpf(2.6, 1.0, _out(u))
		var loot := Boss.loot(side)
		var fight_y := (floor_y + button_top) / 2.0 - (130.0 if not loot.is_empty() else 70.0)
		_text("BOSS FIGHT!", Vector2(v.x / 2.0, fight_y), 128, Color("ff5d5d"), 22, -0.05, s, clampf(u * 2.0, 0.0, 1.0))
		var k := _out((_t - STAMP_AT - 0.1) / 0.25)
		if loot.is_empty():
			_text(str(side.get("title", "")).to_upper(), Vector2(v.x / 2.0, button_top - 120.0), 50, Color.WHITE, 10, 0.0, 1.0, k)
			_text("You've beaten him before. He's still mad.", Vector2(v.x / 2.0, button_top - 55.0), 38, Boss.GOLD.lightened(0.3), 8, 0.0, 1.0, k)
		else:
			# The job's name and BEAT HIM FOR, then what he drops, as loot: a tile each, popping in in turn.
			_text("%s  ·  BEAT HIM FOR" % str(side.get("title", "")).to_upper(), Vector2(v.x / 2.0, button_top - 245.0), 36, Color.WHITE, 8, 0.0, 1.0, k)
			var gap := minf(220.0, (v.x - 60.0) / loot.size())
			for i in loot.size():
				var at := Vector2(v.x / 2.0 + (i - (loot.size() - 1) / 2.0) * gap, button_top - 150.0)
				_loot_tile(at, loot[i], _out((_t - STAMP_AT - 0.25 - i * 0.12) / 0.3), gap - 16.0)
