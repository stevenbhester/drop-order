class_name ChallengeIntro
extends CanvasLayer
## Before an unbeaten challenge level (a big step up from its neighbours): two strips of hazard tape whip
## across, "CHALLENGE!" stamps down over a burst of flame, then the level's name, a line of trash talk and the
## bonus on offer for beating it. "Bring it on!" (or a tap anywhere once it's settled) starts the level.
## Shown once a session per level, and never again once it's beaten. Each detour (side road) gets its own
## (THEMES): its own colour, a little scene for its twist (a fuel gauge dropping, an ice cream melting, a
## rocket, fog rolling in, towns joining up), its own tape, the rule in a line, and the ride it wins.

signal done

const BONUS := 500
const INK := Color("2b2233")
const TAPE := Color("ffc93c")
const STAMP_AT := 0.32
const TAUNTS := {
	5: "First big one. Plan the whole run before you drive.",
	14: "Over, under, around. Don't get turned around.",
	20: "Most drivers stall out right here.",
	28: "The gates don't care about your feelings.",
	32: "Lights out. Nerves of steel.",
	36: "Sort it out... if you can.",
	47: "Snow blind. Plan every slide before you go.",
	53: "Storm's coming in. The ice won't wait.",
	58: "Park it, fetch it, don't forget it.",
	67: "Harvest moon. Everything has to come home.",
	73: "Every road's dug up. Every delivery counts.",
	83: "Ice, lockers, roadworks. All at once.",
	90: "Top of the world. One last climb.",
	95: "Everything at once. Seriously.",
	100: "The final run. Make it count, driver.",
}

## Each detour's intro: [stamp, sheet colour, top tape, bottom tape, the rule ({n} for its number)].
const THEMES := {
	"fuel": ["SMALL TANK!", Color("2b6f5e"), "ONE TANK  ·  NO REFILLS  ·  ", "NO HINTS  ·  NO UNDOS  ·  ",
		"Your tank holds the shortest route. Not one tile more."],
	"melt": ["BEFORE IT MELTS!", Color("2a5d8f"), "TICK TOCK  ·  DRIP DROP  ·  ", "NO HINTS  ·  NO UNDOS  ·  ",
		"Every delivery in {n} seconds, or it's all soup."],
	"one_shot": ["NO BRAKES!", Color("8f2a2a"), "ONE DRAG  ·  NO STOPPING  ·  ", "NO HINTS  ·  NO UNDOS  ·  ",
		"Draw the whole route in one go. Once you let go, it doesn't stop."],
	"fog": ["FOG BANK!", Color("4a4e63"), "READ IT  ·  REMEMBER IT  ·  ", "NO HINTS  ·  NO UNDOS  ·  ",
		"{n} seconds to read the load. Then the fog hides all but the next package."],
	"mega": ["MEGA ROUTE!", Color("1f6f6a"), "MEGA ROUTE  ·  SAVED AS YOU GO  ·  ", "ONE BIG MAP  ·  ",
		"{n} towns, one van. Clear a town, then take its exit to the next."],
}

## Levels whose intro has played this session.
static var _seen := {}

var level: LevelData
## A side road's definition (SideRoads), or empty for a challenge level.
var side := {}

var _root: Control
var _t := 0.0
var _go: JuicyButton
var _closing := false
var _stamped := false


static func should_show(L: LevelData) -> bool:
	# (A boss fight has its own way in: BossIntro.)
	return L.challenge and not Boss.is_level(L.number) and not Progress.is_complete(L.number) and not _seen.has(L.number) and not Progress.auto


static func should_show_side(d: Dictionary) -> bool:
	var id := str(d.get("id", ""))
	return not Progress.side_done.has(id) and not _seen.has(id) and not Progress.auto and not Boss.is_boss(d)


func _ready() -> void:
	layer = 70
	_seen[level.number if side.is_empty() else str(side.get("id", ""))] = true
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(_draw_it)
	_root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and _t > 1.2:
			_close())
	add_child(_root)
	_go = JuicyButton.new()
	_go.label = "Bring it on!"
	_go.icon_name = "play"
	_go.font_px = 46
	_go.bg = TAPE
	_go.fg = INK
	_go.custom_minimum_size = Vector2(520, 128)
	_go.size = _go.custom_minimum_size
	_go.visible = false
	_go.pressed.connect(_close)
	_root.add_child(_go)
	Sfx.play("whoosh", 0.8, -4.0)


func _center() -> Vector2:
	return _root.get_viewport_rect().size / 2.0 + Vector2(0, -60)


func _process(delta: float) -> void:
	var before := _t
	_t += delta
	if before < STAMP_AT and _t >= STAMP_AT:
		_stamped = true
		Sfx.play("slam", 0.9, -2.0)
		Sfx.haptic(35, 1.0, "challenge_intro:_process")
	if before < 0.75 and _t >= 0.75:
		Sfx.play("kaching", 0.9, -8.0)
	if not _go.visible and _t >= 0.95:
		_go.visible = true
		_go.position = _center() + Vector2(-_go.size.x / 2.0, 372)
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


static func _pop(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 + 2.2 * pow(u - 1.0, 3.0) + 1.2 * pow(u - 1.0, 2.0)


## A strip of hazard tape through `c` at angle `ang`, slid along by `slide` (0: in place).
func _tape(c: Vector2, ang: float, slide: float, words: String) -> void:
	var v := _root.size
	var h := 92.0
	var f := UiTheme.font()
	_root.draw_set_transform(c + Vector2(slide, 0).rotated(ang), ang, Vector2.ONE)
	_root.draw_rect(Rect2(-v.x * 1.2, -h / 2.0 + 8.0, v.x * 2.4, h), Color(0, 0, 0, 0.25))
	_root.draw_rect(Rect2(-v.x * 1.2, -h / 2.0, v.x * 2.4, h), TAPE)
	for edge in [-h / 2.0, h / 2.0 - 14.0]:
		var x := -v.x * 1.2
		while x < v.x * 1.2:
			_root.draw_colored_polygon(PackedVector2Array([Vector2(x, edge), Vector2(x + 26, edge), Vector2(x + 40, edge + 14), Vector2(x + 14, edge + 14)]), INK)
			x += 52.0
	var w := f.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x + 60.0
	var x0 := -v.x * 1.2 + fmod(_t * 60.0, w)
	while x0 < v.x * 1.2:
		_root.draw_string(f, Vector2(x0, 15), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, INK)
		x0 += w
	_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


func _draw_it() -> void:
	var v := _root.size
	var c := _center()
	var dim := clampf(_t / 0.15, 0.0, 1.0)
	var theme: Array = THEMES.get(str(side.get("twist", "")), []) if not side.is_empty() else []
	_root.draw_rect(Rect2(Vector2.ZERO, v), Color(0.08, 0.05, 0.12, 0.82 * dim) if theme.is_empty() else Color(theme[1].darkened(0.35), 0.92 * dim))
	# Hazard tape, one strip from each side.
	_tape(c + Vector2(0, -330), -0.16, -v.x * 1.6 * (1.0 - _out(_t / 0.24)), "CHALLENGE AHEAD  ·  " if theme.is_empty() else theme[2])
	_tape(c + Vector2(0, 560), 0.1, v.x * 1.6 * (1.0 - _out((_t - 0.08) / 0.24)), "DRIVE CAREFULLY  ·  " if theme.is_empty() else theme[3])
	if not theme.is_empty():
		_draw_detour(theme, c, v)
		return
	# The flame burst behind the stamp, and the stamp.
	if _t >= STAMP_AT - 0.06:
		var k := _out((_t - STAMP_AT + 0.06) / 0.3)
		var pal := AnimeFire.palette(4)
		for i in 7:
			var x := (i - 3) * 120.0
			var hgt := (260.0 - absf(i - 3) * 46.0) * k
			AnimeFire.draw_flame(_root, c + Vector2(x, 40), 150.0 * k, hgt, _t, 3.0 + i * 1.7, pal)
		var u := (_t - STAMP_AT + 0.06) / 0.16
		var s := lerpf(2.8, 1.0, _out(u))
		var stamp := "CHALLENGE!" if side.is_empty() else ("MEGA ROUTE!" if SideRoads.is_mega(side) else "SIDE ROAD!")
		_text(stamp, c + Vector2(0, -40), 150 if side.is_empty() else 124, Color("fff3c4"), 22, -0.06, s, clampf(u * 2.0, 0.0, 1.0))
	# The level, the trash talk, the prize.
	if _t > 0.55:
		var k := _out((_t - 0.55) / 0.25)
		# A challenge level says just which level it is (its name and line are on the level itself).
		var name := "JOB %d" % level.number
		if not side.is_empty():
			name = str(SideRoads.TWISTS.get(side.get("twist", ""), "")).to_upper() + "  ·  " + str(side.get("title", "")).to_upper()
			if SideRoads.is_mega(side):
				name = "%d PARTS  ·  %s" % [SideRoads.part_count(side), str(side.get("title", "")).to_upper()]
		_text(name, c + Vector2((1.0 - k) * 500.0, 110), 50, Color.WHITE, 10, 0.0, 1.0, k)
		var taunt: String = "" if side.is_empty() else level.hint
		# Long lines (a side road's rules) break in two.
		var lines := [taunt]
		if UiTheme.font().get_string_size(taunt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x > v.x - 120.0:
			var mid := taunt.length() / 2
			var cut := taunt.rfind(" ", mid)
			if cut < 0:
				cut = taunt.find(" ", mid)
			lines = [taunt.substr(0, cut), taunt.substr(cut + 1)]
		for li in lines.size():
			_text(lines[li], c + Vector2(-(1.0 - k) * 500.0, 172 + li * 44 - (0 if lines.size() == 1 else 8)), 36, Color(1, 1, 1, 0.82), 0, 0.0, 1.0, k)
	if _t > 0.75:
		var k := _pop((_t - 0.75) / 0.3)
		var chip := Rect2(c + Vector2(-330, 236), Vector2(660, 92)) if not side.is_empty() else Rect2(c + Vector2(-190, 176), Vector2(380, 92))
		_root.draw_set_transform(chip.get_center(), 0.0, Vector2.ONE * k)
		var r := Rect2(-chip.size / 2.0, chip.size)
		DrawUtil.rrect(_root, Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.3), 46)
		DrawUtil.rrect(_root, r, Color(1, 1, 1, 0.12), 46)
		Icons.draw(_root, "coin", Vector2(-r.size.x / 2.0 + 62, 0), 58.0, Palette.STAR_GOLD)
		var f := UiTheme.font()
		var prize := "+%d bonus" % BONUS if Progress.COINS else "Crush it for the big finish"
		if not side.is_empty():
			prize = "Win the %s" % Cosmetics.name_of(str(side.get("reward", "")))
			if Cosmetics.kind_of(str(side.get("reward", ""))) == "paint":
				prize += " paint job"
		_root.draw_string(f, Vector2(-r.size.x / 2.0 + 112, 14), prize, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color("ffe08a"))
		_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A white flash on the stamp.
	if _stamped:
		_root.draw_rect(Rect2(Vector2.ZERO, v), Color(1, 1, 1, maxf(0.0, (0.06 if Palette.night else 0.14) - (_t - STAMP_AT) * 1.2)))


## A detour's intro, after its tape: the twist's little scene, its stamp, the rule, the prize.
func _draw_detour(theme: Array, c: Vector2, v: Vector2) -> void:
	var twist := str(side.get("twist", ""))
	var k := _out((_t - 0.1) / 0.35)
	_draw_scene(twist, c + Vector2(0, -150), k)
	if _t >= STAMP_AT - 0.06:
		var u := (_t - STAMP_AT + 0.06) / 0.16
		var s := lerpf(2.6, 1.0, _out(u))
		var stamp: String = theme[0]
		var px := 118
		while px > 70 and UiTheme.font().get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > v.x - 80.0:
			px -= 4
		_text(stamp, c + Vector2(0, 40), px, Color("fff3c4"), 20, -0.05, s, clampf(u * 2.0, 0.0, 1.0))
	if _t > 0.55:
		var a := _out((_t - 0.55) / 0.25)
		var n := 0
		match twist:
			"melt": n = int(side.get("seconds", 60))
			"fog": n = int(side.get("peek", 6))
			"mega": n = SideRoads.part_count(side)
		var rule := str(theme[4]).replace("{n}", str(n))
		var f := UiTheme.font()
		_root.draw_multiline_string(f, Vector2(70, c.y + 172), rule, HORIZONTAL_ALIGNMENT_CENTER, v.x - 140.0, 42, 3, Color(1, 1, 1, a))
	if _t > 0.75:
		var kk := _pop((_t - 0.75) / 0.3)
		var chip := Rect2(c + Vector2(-330, 276), Vector2(660, 92))
		_root.draw_set_transform(chip.get_center(), 0.0, Vector2.ONE * kk)
		var r := Rect2(-chip.size / 2.0, chip.size)
		DrawUtil.rrect(_root, r, Color(1, 1, 1, 0.14), 46)
		Icons.draw(_root, "gift", Vector2(-r.size.x / 2.0 + 62, 0), 52.0, Color("ffe08a"))
		var prize := "Win the %s" % Cosmetics.name_of(str(side.get("reward", "")))
		if Cosmetics.kind_of(str(side.get("reward", ""))) == "paint":
			prize += " paint job"
		_root.draw_string(UiTheme.font(), Vector2(-r.size.x / 2.0 + 112, 14), prize, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130, 38, Color("ffe08a"))
		_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _stamped:
		_root.draw_rect(Rect2(Vector2.ZERO, v), Color(1, 1, 1, maxf(0.0, (0.1 if Palette.night else 0.4) - (_t - STAMP_AT) * 3.0)))


## Each twist's little scene, about 400 wide, centred on `c`, grown in by `k`.
func _draw_scene(twist: String, c: Vector2, k: float) -> void:
	var ci := _root
	var t := _t
	ci.draw_set_transform(c, 0.0, Vector2.ONE * k)
	match twist:
		"fuel":
			# A fuel gauge, its needle dropping from F toward E and wobbling at the bottom.
			ci.draw_arc(Vector2(0, 60), 170.0, PI * 1.1, PI * 1.9, 40, Color.WHITE, 26.0, true)
			ci.draw_arc(Vector2(0, 60), 170.0, PI * 1.1, PI * 1.25, 12, Color("ff6b6b"), 26.0, true)
			_root.draw_string(UiTheme.font(), Vector2(-178, 40), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color("ff6b6b"))
			_root.draw_string(UiTheme.font(), Vector2(150, 40), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
			var drop := clampf(t / 1.4, 0.0, 1.0)
			var ang := lerpf(PI * 1.85, PI * 1.2, 1.0 - pow(1.0 - drop, 2.0)) + sin(t * 18.0) * 0.03 * drop
			ci.draw_line(Vector2(0, 60), Vector2(0, 60) + Vector2(cos(ang), sin(ang)) * 150.0, Color("ffd43b"), 12.0, true)
			ci.draw_circle(Vector2(0, 60), 22.0, Color("ffd43b"))
		"melt":
			# An ice cream, melting: the scoop sags, drips run and a puddle grows.
			var m := clampf(t / 2.5, 0.0, 1.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-60, 0), Vector2(60, 0), Vector2(0, 150)]), Color("e2a35a"))
			ci.draw_circle(Vector2(0, -50 + 30 * m), 80.0 * (1.0 - 0.25 * m), Color("ffb3c7"))
			ci.draw_rect(Rect2(-70, -20, 140, 24), Color("ffb3c7"))
			for i in 4:
				var x := -48.0 + i * 32.0
				var dl := (20.0 + 90.0 * m) * (0.6 + 0.4 * absf(sin(t * 1.6 + i)))
				ci.draw_rect(Rect2(x - 7, 0, 14, dl), Color("ffb3c7"))
				ci.draw_circle(Vector2(x, dl), 9.0, Color("ffb3c7"))
			ci.draw_set_transform(c + Vector2(0, 175) * k, 0.0, Vector2(k * (0.4 + 1.2 * m), k * 0.3))
			ci.draw_circle(Vector2.ZERO, 120.0, Color("ffb3c7", 0.85))
		"one_shot":
			# A rocket van screaming past, flames out the back, speed lines.
			for i in 7:
				var y := -90.0 + i * 30.0
				var x := fmod(t * 1600.0 + i * 280.0, 900.0) - 450.0
				ci.draw_line(Vector2(x, y), Vector2(x + 140, y), Color(1, 1, 1, 0.35), 6.0)
			var bob := sin(t * 30.0) * 4.0
			DrawUtil.rrect(ci, Rect2(-120, -50 + bob, 240, 100), Color("fffaf2"), 30)
			DrawUtil.rrect(ci, Rect2(60, -50 + bob, 60, 100), Color("596273"), 30)
			for j in 3:
				AnimeFire.draw_flame(ci, Vector2(-130, -20 + j * 20 + bob), 60.0, 120.0 + 20.0 * sin(t * 20.0 + j), t, j * 1.7, AnimeFire.palette(5), Vector2(-1, 0))
		"fog":
			# The load in a row, the fog sliding over all but the top one.
			var cols := ["red", "blue", "yellow", "green", "purple"]
			for i in 5:
				DrawUtil.parcel(ci, Vector2(-170 + i * 85, 20), Vector2(70, 54), Palette.pkg(cols[i]))
			var cover := clampf((t - 0.6) / 1.2, 0.0, 1.0)
			for i in 9:
				var x := -260.0 + 300.0 * cover + i * 34.0 - 200.0 * (1.0 - cover)
				ci.draw_circle(Vector2(x, 20 + sin(i * 1.7 + t) * 20.0), 70.0, Color(0.9, 0.92, 0.96, 0.85 * cover))
		"mega":
			# Little towns joining up into one map, a road running through them.
			var j := clampf(t / 1.0, 0.0, 1.0)
			for i in 4:
				var home := Vector2(-110 + (i % 2) * 220, -60 + (i / 2) * 140)
				var away := home * (1.0 + 1.5 * (1.0 - j))
				DrawUtil.rrect(ci, Rect2(away - Vector2(100, 60), Vector2(200, 120)), Color("bfe3a0").lerp(Color("d6dbe0"), i * 0.3), 18)
				ci.draw_line(away + Vector2(-80, 0), away + Vector2(80, 0), Color("596273"), 14.0)
			if j >= 1.0:
				ci.draw_polyline(PackedVector2Array([Vector2(-190, -60), Vector2(190, -60), Vector2(190, 80), Vector2(-190, 80)]), Color("ffd43b"), 8.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
