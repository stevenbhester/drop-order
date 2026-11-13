class_name ChallengeIntro
extends CanvasLayer
## Before an unbeaten challenge level (a big step up from its neighbours): two strips of hazard tape whip
## across, "CHALLENGE!" stamps down over a burst of flame, then the level's name, a line of trash talk and the
## bonus on offer for beating it. "Bring it on!" (or a tap anywhere once it's settled) starts the level.
## Shown once a session per level, and never again once it's beaten. Side roads get one too ("SIDE ROAD!"),
## with the twist explained and the ride they win.

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
	45: "Everything at once. Seriously.",
	50: "The final run. Make it count, driver.",
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
	return L.challenge and not Progress.is_complete(L.number) and not _seen.has(L.number) and not Progress.auto


static func should_show_side(d: Dictionary) -> bool:
	var id := str(d.get("id", ""))
	return not Progress.side_done.has(id) and not _seen.has(id) and not Progress.auto


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
		Sfx.haptic(35, 1.0)
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
	_root.draw_rect(Rect2(Vector2.ZERO, v), Color(0.08, 0.05, 0.12, 0.82 * dim))
	# Hazard tape, one strip from each side.
	_tape(c + Vector2(0, -330), -0.16, -v.x * 1.6 * (1.0 - _out(_t / 0.24)), "CHALLENGE AHEAD  ·  " if side.is_empty() else ("MEGA ROUTE  ·  SAVED AS YOU GO  ·  " if SideRoads.is_mega(side) else "SIDE ROAD  ·  DETOUR  ·  "))
	_tape(c + Vector2(0, 560), 0.1, v.x * 1.6 * (1.0 - _out((_t - 0.08) / 0.24)), "DRIVE CAREFULLY  ·  " if side.is_empty() else ("ONE BIG MAP  ·  " if SideRoads.is_mega(side) else "NO HINTS  ·  NO UNDOS  ·  "))
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
		var name := "LEVEL %d" % level.number + ("  ·  " + level.title.to_upper() if level.title != "" else "")
		if not side.is_empty():
			name = str(SideRoads.TWISTS.get(side.get("twist", ""), "")).to_upper() + "  ·  " + str(side.get("title", "")).to_upper()
			if SideRoads.is_mega(side):
				name = "%d PARTS  ·  %s" % [SideRoads.part_count(side), str(side.get("title", "")).to_upper()]
		_text(name, c + Vector2((1.0 - k) * 500.0, 110), 50, Color.WHITE, 10, 0.0, 1.0, k)
		var taunt: String = TAUNTS.get(level.number, "A big step up. Take your time.")
		if not side.is_empty():
			taunt = level.hint
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
		var chip := Rect2(c + Vector2(-330, 236), Vector2(660, 92))
		_root.draw_set_transform(chip.get_center(), 0.0, Vector2.ONE * k)
		var r := Rect2(-chip.size / 2.0, chip.size)
		DrawUtil.rrect(_root, Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.3), 46)
		DrawUtil.rrect(_root, r, Color(1, 1, 1, 0.12), 46)
		Icons.draw(_root, "coin", Vector2(-r.size.x / 2.0 + 62, 0), 58.0, Palette.STAR_GOLD)
		var f := UiTheme.font()
		var prize := "+%d Dollaroos for beating it" % BONUS
		if not side.is_empty():
			prize = "Win the %s" % Cosmetics.name_of(str(side.get("reward", "")))
			if Cosmetics.kind_of(str(side.get("reward", ""))) == "paint":
				prize += " paint job"
		_root.draw_string(f, Vector2(-r.size.x / 2.0 + 112, 14), prize, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color("ffe08a"))
		_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A white flash on the stamp.
	if _stamped:
		_root.draw_rect(Rect2(Vector2.ZERO, v), Color(1, 1, 1, maxf(0.0, 0.5 - (_t - STAMP_AT) * 4.0)))
