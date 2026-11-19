class_name BossIntro
extends CanvasLayer
## Before a boss fight, his anime opening (he insists): a gold bolt of greed strikes top to bottom and tears
## open a window with his face in it, huge, cash sucked in toward him from the dark; a *SHING* off his
## monocle; his name slams down with what he calls himself. A tap skips it. Then: the lights go down over a skyline of
## glass towers, HOARDLY INC. blinks on in gold,
## and Baron Von Bottomline rises into view on his private lift, laughing at you (HAW HAW HAW) with a line
## of corporate trash talk. Then BOSS FIGHT! stamps down, with the detour's name and what he's guarding.
## "Bring it on!" (or a tap once it's settled) starts the level. Plays every time you come in: he never
## gets tired of laughing.

signal done

const INK := Color("1b1530")
const RISE := 0.55          # seconds for the lift to bring him up
const STAMP_AT := 1.25
const OPEN := 1.7           # seconds of the anime opening, before all that

var side := {}
var level: LevelData

var _root: Control
var _t := 0.0
var _op := 0.0                   # the opening's clock (the rest waits for it)
var _shinged := false
var _named := false
## Boss fights laugh you in once a session (not again on every retry): main-road ones by level number,
## boss detours by their id.
static var _seen := {}
static var _seen_side := {}


static func should_show(L: LevelData) -> bool:
	return Boss.is_level(L.number) and not _seen.has(L.number) and not Progress.auto


static func should_show_side(d: Dictionary) -> bool:
	return Boss.is_boss(d) and not _seen_side.has(str(d.get("id", ""))) and not Progress.auto


var _go: JuicyButton
var _closing := false
var _line := ""
var _laughed := false
var _stamped := false


func _ready() -> void:
	add_to_group(Music.HUSH_GROUP)      # (the background music waits while this is up)
	layer = 70
	_line = Boss.taunt_for(side)
	if side.has("level"):
		_seen[int(side["level"])] = true
	elif side.has("id"):
		_seen_side[str(side["id"])] = true
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(_draw_it)
	_root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and _op < OPEN:
			_op = OPEN                   # (a tap skips his opening)
			Sfx.play("whoomp", 0.6, -4.0)
		elif e is InputEventMouseButton and e.pressed and _t > STAMP_AT + 0.3:
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
	Sfx.play("whoosh", 0.7, -2.0)
	Sfx.play("punch", 1.3, -4.0)


func _process(delta: float) -> void:
	if _op < OPEN:
		var was := _op
		_op += delta
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--boss-open="):
				_op = float(a.trim_prefix("--boss-open="))      # (debug: hold the opening at that moment)
		if was < 0.14 and _op >= 0.14:
			Sfx.play("crash", 1.4, -4.0)
			Sfx.play("kaching", 0.7, -4.0)
			Sfx.haptic(40, 1.0, "boss_intro:_process")
		if was < 0.62 and _op >= 0.62 and not _shinged:
			_shinged = true
			Sfx.play("sparkle", 1.6, -2.0)
			Sfx.play("swap", 2.0, -8.0)
		if was < 0.85 and _op >= 0.85 and not _named:
			_named = true
			Sfx.play("slam", 1.2, -2.0)
			Sfx.haptic(25, 0.8, "boss_intro:_process")
		if _op >= OPEN:
			Sfx.play("whoomp", 0.6, -4.0)
		_root.queue_redraw()
		return
	var before := _t
	_t += delta
	if before < RISE and _t >= RISE and not _laughed:
		_laughed = true
		Sfx.play("laugh", 1.0, 0.0)
		Sfx.haptic(30, 0.8, "boss_intro:_process")
	if before < STAMP_AT and _t >= STAMP_AT:
		_stamped = true
		Sfx.play("slam", 0.8, -2.0)
		Sfx.haptic(35, 1.0, "boss_intro:_process")
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
	var rare: Color = {"lights": Color("ffc53d"), "undos": Color("4d9dff"), "radio": Color("4d9dff"), "hint": Color("ffc53d"), "paint": Color("b07aff"), "item": Color("ff6fae")}.get(kind, Color("bfc3cc"))
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
		"radio", "hint":
			Icons.draw(_root, "radio" if kind == "radio" else "bulb", Vector2(-8, -6), 58.0, Color.WHITE)
			var f2 := UiTheme.font()
			var n2 := "+%d" % int(it["n"])
			_root.draw_string_outline(f2, Vector2(4, 40), n2, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color("231a38"))
			_root.draw_string(f2, Vector2(4, 40), n2, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, rare)
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
	if _op < OPEN:
		_draw_opening()
		return
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
		DrawUtil.rrect(_root, local.grow(3), Palette.BUBBLE_RIM, 39.0)
		DrawUtil.rrect(_root, local, Palette.BUBBLE, 36.0)
		_root.draw_colored_polygon(PackedVector2Array([Vector2(-30, local.end.y - 2), Vector2(30, local.end.y - 2), Vector2(0, local.end.y + 50)]), Palette.BUBBLE)
		var f := UiTheme.font()
		for i in lines.size():
			var lw := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			_root.draw_string(f, Vector2(-lw / 2.0, local.position.y + 28.0 + px + i * px * 1.25), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Palette.TEXT)
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


## His anime opening, nothing like a win's (no sunburst, no slash across): a gold bolt of greed strikes from the
## top of the screen to the bottom, then tears open into a jagged window down the middle with him in it, huge,
## on a money-green glow where dollar signs rain down. Outside it, in the dark, cash and coins are sucked in
## toward him. A *SHING* off his monocle; his name, and what he calls himself.
const OP_INK := Color("06120c")
const OP_GREEN := Color("0f3b24")
const OP_GOLD := Color("ffc53d")
const OP_RED := Color("ff3b4f")

func _draw_opening() -> void:
	var v := _root.size
	var t := _op
	var cx := v.x / 2.0
	_root.draw_rect(Rect2(Vector2.ZERO, v), OP_INK)
	# The jagged edges crackle: a new zigzag every few frames.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t * 14.0) + 3
	var steps := 18
	var jag: Array = []
	for k in steps + 1:
		jag.append(rng.randf_range(-1.0, 1.0))
	# The bolt strikes, top to bottom.
	var strike := clampf(t / 0.16, 0.0, 1.0)
	var open := _out((t - 0.14) / 0.24)
	var half := v.x * 0.29 * open
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in steps + 1:
		var y := v.y * k / steps
		var j: float = jag[k] * 34.0
		left.append(Vector2(cx - half + j - (14.0 if k % 2 == 0 else -14.0), y))
		right.append(Vector2(cx + half + j + (14.0 if k % 2 == 0 else -14.0), y))
	if open > 0.0:
		# Inside: a money-green glow, and dollar signs raining down behind him.
		var win := PackedVector2Array(left)
		for k in range(right.size() - 1, -1, -1):
			win.append(right[k])
		_root.draw_colored_polygon(win, OP_GREEN)
		_root.draw_circle(Vector2(cx, v.y * 0.36), v.x * 0.42, Color(OP_GOLD, 0.12))
		var f := UiTheme.font()
		var r2 := RandomNumberGenerator.new()
		r2.seed = 5
		for k in 22:
			var x := cx + r2.randf_range(-v.x * 0.34, v.x * 0.34)
			var y := fmod(r2.randf_range(0.0, v.y) + t * r2.randf_range(500.0, 1100.0), v.y + 100.0) - 50.0
			var px := int(r2.randf_range(34.0, 70.0))
			f.draw_string(_root.get_canvas_item(), Vector2(x, y), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(OP_GOLD, r2.randf_range(0.12, 0.3)))
		# Him: in from above with the bolt, then a slow push in.
		var drop := _out((t - 0.14) / 0.3)
		var zoom := 1.0 + 0.05 * clampf((t - 0.4) / 1.3, 0.0, 1.0)
		var big := 1700.0 * zoom
		var head_c := Vector2(cx, lerpf(-400.0, v.y * 0.33, drop))
		Boss.draw(_root, head_c + Vector2(0, big * 0.82), big, t, "smug")
		# Dark under his name, so it reads.
		for k in 8:
			var y0 := v.y * 0.6 + k * v.y * 0.05
			_root.draw_rect(Rect2(0, y0, v.x, v.y * 0.05 + 1.0), Color(OP_INK, 0.1 * k))
		# The dark outside the window.
		var lc := PackedVector2Array([Vector2(-10, -10)])
		lc.append_array(left)
		lc.append(Vector2(-10, v.y + 10))
		_root.draw_colored_polygon(lc, OP_INK)
		var rc := PackedVector2Array([Vector2(v.x + 10, -10)])
		rc.append_array(right)
		rc.append(Vector2(v.x + 10, v.y + 10))
		_root.draw_colored_polygon(rc, OP_INK)
		# Greed: cash and coins out in the dark, pulled in toward him, faster as they go.
		var r3 := RandomNumberGenerator.new()
		r3.seed = 17
		for k in 26:
			var sd := -1.0 if k % 2 == 0 else 1.0
			var y := r3.randf_range(v.y * 0.05, v.y * 0.95)
			var u := fmod(r3.randf_range(0.0, 1.0) + t * r3.randf_range(0.7, 1.3), 1.0)
			var ease := u * u
			var from := Vector2(cx + sd * v.x * 0.62, y)
			var to := Vector2(cx + sd * (half + 10.0), lerpf(y, v.y * 0.36, 0.5))
			var p := from.lerp(to, ease)
			var a := 1.0 - u
			_root.draw_line(p, p + (from - to).normalized() * 90.0 * ease, Color(OP_GOLD, 0.25 * a), 4.0, true)
			if k % 3 == 0:
				Icons.draw(_root, "coin", p, 60.0, Color(1, 1, 1, a))
			else:
				_root.draw_set_transform(p, t * 5.0 + k, Vector2.ONE * 1.3)
				DrawUtil.rrect(_root, Rect2(-30, -15, 60, 30), Color(Color("7fcf7a"), a), 5.0)
				_root.draw_circle(Vector2.ZERO, 8.0, Color(Color("4f9c4a"), a))
				_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Falling streaks in the dark.
		for k in 16:
			var x := (r3.randf_range(0.0, v.x * 0.16)) if k % 2 == 0 else (v.x - r3.randf_range(0.0, v.x * 0.16))
			var ln := r3.randf_range(140.0, 380.0)
			var y := fmod(r3.randf_range(0.0, v.y) + t * r3.randf_range(1600.0, 2600.0), v.y + ln) - ln
			_root.draw_line(Vector2(x, y), Vector2(x, y + ln), Color(OP_GOLD, r3.randf_range(0.1, 0.3)), r3.randf_range(2.0, 5.0), true)
		# The window's edges: crackling gold, glowing.
		for edge in [left, right]:
			_root.draw_polyline(edge, Color(OP_GOLD, 0.25), 26.0, true)
			_root.draw_polyline(edge, OP_GOLD, 8.0, true)
			_root.draw_polyline(edge, Color(1, 1, 0.85), 3.0, true)
		# *SHING*: a glint off his monocle.
		var g := t - 0.62
		if g > 0.0 and g < 0.5:
			var at := head_c + Vector2(0.06 * big, -0.03 * big)
			var k := sin(PI * g / 0.5)
			Icons.star(_root, at, 120.0 * k, Color.WHITE)
			_root.draw_line(at - Vector2(220, 0) * k, at + Vector2(220, 0) * k, Color(1, 1, 1, 0.8), 6.0, true)
			_text("*SHING*", at + Vector2(60, -150), 64, Color.WHITE, 12, 0.2, 1.0, k)
	# The bolt itself, coming down (and lingering as a flash down the middle while it tears open).
	if t < 0.4:
		var bolt := PackedVector2Array()
		for k in steps + 1:
			var y := v.y * k / steps
			if y > v.y * strike:
				break
			bolt.append(Vector2(cx + float(jag[k]) * 60.0 + (40.0 if k % 2 == 0 else -40.0), y))
		if bolt.size() >= 2:
			var fade := 1.0 - clampf((t - 0.2) / 0.2, 0.0, 1.0)
			_root.draw_polyline(bolt, Color(OP_GOLD, 0.3 * fade), 60.0, true)
			_root.draw_polyline(bolt, Color(OP_GOLD, fade), 18.0, true)
			_root.draw_polyline(bolt, Color(1, 1, 0.9, fade), 7.0, true)
	# His name slams down, with what he calls himself.
	if t > 0.85:
		var u := (t - 0.85) / 0.14
		var s := lerpf(2.4, 1.0, _out(u))
		var a := clampf(u * 2.0, 0.0, 1.0)
		var ny := v.y * 0.72
		_text("BARON", Vector2(cx, ny), 130, OP_GOLD, 22, 0.0, s, a)
		_text("VON BOTTOMLINE", Vector2(cx, ny + 125.0), 84, Color("fff3c4"), 18, 0.0, s, a)
		var k2 := _out((t - 1.05) / 0.2)
		_text("CEO · VISIONARY · LITERALLY THE MAIN CHARACTER", Vector2(cx, ny + 220.0), 32, OP_RED.lightened(0.3), 8, 0.0, 1.0, k2)
	# The strike's flash: gold, not white.
	_root.draw_rect(Rect2(Vector2.ZERO, v), Color(Color("fff0b0"), maxf(0.0, 0.85 - absf(t - 0.16) / 0.12)))
