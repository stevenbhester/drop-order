class_name PromoAd
extends CanvasLayer
## Pretend ads for Last Mile itself, played when you're out of hints: three short spots drawn live in code
## (like FakeAd's Frontiers Celestia one), each the idea of one of the game's trailers, with the game's own
## van, houses and sounds:
##   fun    Cozy. "Every package has someone waiting." A finger draws one route; the van delivers them all.
##   bait   A clickbait parody. "99% FAIL THIS LEVEL!" The wrong way gets a NOPE and an IQ of 63; the
##          genius way delivers everything and the IQ meter maxes out.
##   trash  Trash talk. Breaking news (publishers dodging GTA VI), a record scratch, "NO GAME DARES???",
##          "LAST MILE DOESN'T GIVE A &@$*&!!!!" on the beat, a fancam of a burning run, then a message
##          for Rockstar.
## Skip is there from the first frame; skipping, closing or finishing all emit `finished`.

signal finished

const KINDS := ["fun", "bait", "trash"]
const INK := Color("2a2233")
const CREAM := Color(0.99, 0.97, 0.92)
const NEWS_RED := Color("d7192a")
const NAVY := Color("0b1630")
const YELLOW := Color("ffe14d")
const HOT := Color("ff2e3e")
const BEAT := 60.0 / 88.0

## The little map every spot drives on (the game's level tokens: # road, S start, letters houses).
const MAP_FUN := [". r . b .", "# # # # #", "# . y . #", "# # # # #", "S . . . ."]
const MAP_BAIT := [". b . r .", "# # # # #", "# . . . #", "# # # # #", "S . y . ."]
## The way round that delivers everything: up, along the middle, up the right, back along the top.
const WAY := [Vector2i(0, 4), Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
	Vector2i(4, 2), Vector2i(4, 1), Vector2i(3, 1), Vector2i(2, 1), Vector2i(1, 1)]
## The clickbait's wrong way: straight up the left, to the blue house with yellow on top.
const WRONG := [Vector2i(0, 4), Vector2i(0, 3), Vector2i(0, 2), Vector2i(0, 1), Vector2i(1, 1)]

static var _last := -1
## Debug: this kind next (-1: at random).
static var force := -1

var kind := ""

var _t := 0.0
var _end_at := 11.0
var _closing := false
var _top := 0.0
var _bottom := 0.0
var _fired := {}
var _cues: Array = []

var _root: Control
var _stage: Node2D
var _ground: Node2D
var _air: Node2D
var _hud: Control
var _skip: JuicyButton
var _cta: JuicyButton

var _tile := 170.0
var _road := {}
var _houses: Array = []          # {p, color, node}
var _start := Vector2i.ZERO
var _van: Van
var _load: Array = []            # what's on the van, top first
var _route: Array = []           # the route being drawn / driven
var _ink := 0.0                  # how much of it is drawn, 0..1
var _ink_from := 0.0
var _ink_to := 0.0
var _drive := -1.0               # how far along it the van is (in tiles), or -1
var _speed := 3.0
var _events := {}                # route index -> ["deliver"|"nope", house]
var _flyers: Array = []          # {from, to, col, t0, h}
var _marks: Array = []           # {at, t0, kind}
var _trail: Array = []
var _iq := 100.0
var _iq_to := 100.0
var _flash := 0.0
var _punch := 0.0
var _shake := 0.0


## Which spot plays next: any but the last one.
static func pick() -> int:
	if force >= 0 and force < KINDS.size():
		return force
	var choices := []
	for i in KINDS.size():
		if i != _last:
			choices.append(i)
	return choices.pick_random()


func _ready() -> void:
	layer = 88
	if kind == "":
		var i := pick()
		_last = i
		kind = KINDS[i]
	var ins := UiTheme.insets(get_viewport())
	_top = ins.x
	_bottom = ins.y
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(_draw_back)
	add_child(_root)
	var vp := _root.get_viewport_rect().size
	_tile = minf(170.0, (vp.x - 160.0) / 5.0)
	_stage = Node2D.new()
	_root.add_child(_stage)
	_ground = Node2D.new()
	_ground.draw.connect(_draw_ground)
	_stage.add_child(_ground)
	match kind:
		"fun":
			_setup_fun()
		"bait":
			_setup_bait()
		_:
			_setup_trash()
	_air = Node2D.new()
	_air.draw.connect(_draw_air)
	_stage.add_child(_air)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	_root.add_child(_hud)

	_skip = JuicyButton.new()
	_skip.font_px = 36
	_skip.label = "Skip  »"
	_skip.custom_minimum_size = Vector2(230, 92)
	_skip.size = Vector2(230, 92)
	_skip.pressed.connect(func():
		Sfx.play("click")
		_close())
	_root.add_child(_skip)
	_cta = JuicyButton.new()
	_cta.font_px = 60
	_cta.icon_name = "play"
	_cta.bg = Palette.ACCENT
	_cta.fg = Color.WHITE
	_cta.size = Vector2(640, 160)
	_cta.visible = false
	_cta.pressed.connect(func():
		Sfx.play("kaching", 1.1, -4.0)
		_close())
	_root.add_child(_cta)
	_layout()
	_root.resized.connect(_layout)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.15)
	print("[ad] playing %s" % kind)


func _layout() -> void:
	var vp := _root.size if _root.size != Vector2.ZERO else _root.get_viewport_rect().size
	_skip.position = Vector2(vp.x - _skip.size.x - 36.0, 40.0 + _top)
	_cta.position = Vector2((vp.x - _cta.size.x) / 2.0, vp.y * 0.62)
	_cta.pivot_offset = _cta.size / 2.0
	_stage.position = _board_origin()


## The map's top-left on screen (it sits a little below the middle, under the captions).
func _board_origin() -> Vector2:
	var vp := _root.size if _root.size != Vector2.ZERO else _root.get_viewport_rect().size
	return Vector2((vp.x - 5.0 * _tile) / 2.0, vp.y * 0.56 - 2.5 * _tile)


func _center(p: Vector2i) -> Vector2:
	return (Vector2(p) + Vector2(0.5, 0.5)) * _tile


# ---------------------------------------------------------------- the three spots

func _setup_fun() -> void:
	_end_at = 11.0
	_build(MAP_FUN, ["yellow", "blue", "red"])
	_cue(0.05, "jingle", 1.0, -4.0)
	for i in 3:
		_cue(0.6 + i * 0.7, "pop", 1.0 + i * 0.12, -8.0)
	_cue(3.4, "tick", 1.2, -6.0)
	_cue(8.8, "sparkle", 1.0, -4.0)
	_cue(_end_at, "star", 1.0, -3.0)


func _setup_bait() -> void:
	_end_at = 11.2
	_build(MAP_BAIT, ["yellow", "red", "blue"])
	_cue(0.05, "slam", 1.0, -2.0)
	_cue(0.9, "punch", 1.1, -4.0)
	_cue(2.2, "tick", 1.2, -6.0)
	_cue(5.2, "rewind", 1.0, -4.0)
	_cue(5.9, "tick", 1.3, -6.0)
	_cue(_end_at, "star", 1.0, -3.0)


func _setup_trash() -> void:
	_end_at = 15.8
	_build(MAP_FUN, ["yellow", "blue", "red"])
	_stage.visible = false
	for i in 3:
		_cue(0.3 + i * 2.2, "whoosh", 0.8, 0.0)
	_cue(6.9, "screech", 1.0, -2.0)
	_cue(6.95, "slam", 0.9, -2.0)
	_cue(7.45, "slam", 1.0, -2.0)
	# The beat, from the slam to the end card.
	var k := 0
	while 8.3 + k * BEAT < _end_at:
		var bt := 8.3 + k * BEAT
		_cue(bt, "thunk", 0.55, 0.0)
		_cue(bt + BEAT * 0.5, "tick", 1.7, -12.0)
		if k % 2 == 1:
			_cue(bt, "punch", 1.4, -10.0)
		k += 1
	for at in [8.3, 8.3 + BEAT, 8.3 + 2.0 * BEAT]:
		_cue(at, "slam", 1.0, -1.0)
	for at in [12.9, 13.4, 13.9, 14.5]:
		_cue(at, "slam", 0.9, -1.0)
	_cue(_end_at, "star", 1.0, -3.0)


func _cue(at: float, sound: String, pitch: float, db: float) -> void:
	_cues.append([at, sound, pitch, db])


## The map, its houses and the van (wearing the player's paint job), loaded top first.
func _build(rows: Array, load: Array) -> void:
	for y in rows.size():
		var toks: PackedStringArray = str(rows[y]).split(" ", false)
		for x in toks.size():
			var tk: String = toks[x]
			var p := Vector2i(x, y)
			if tk == "#" or tk == "S":
				_road[p] = true
				if tk == "S":
					_start = p
			elif tk in ["r", "b", "y", "g", "p", "o"]:
				var col: String = {"r": "red", "b": "blue", "y": "yellow", "g": "green", "p": "purple", "o": "orange"}[tk]
				var h := House.new()
				h.color = Palette.pkg(col)
				h.size = _tile * 0.92
				h.base_pos = _center(p)
				h.position = h.base_pos
				_stage.add_child(h)
				_houses.append({"p": p, "color": col, "node": h})
	_load = load.duplicate()
	_van = Van.new()
	_van.size = _tile * 0.8
	_van.position = _center(_start)
	_van.target_rotation = -PI / 2.0
	_stage.add_child(_van)
	_van.set_top(_load[0])


func _house_at(p: Vector2i) -> int:
	for i in _houses.size():
		if _houses[i]["p"] == p:
			return i
	return -1


## Plan a route: it draws on over `from`..`to` seconds; `events` says what happens at which step.
func _plan(route: Array, from: float, to: float, events: Dictionary) -> void:
	_route = route
	_ink = 0.0
	_ink_from = from
	_ink_to = to
	_events = events
	_drive = -1.0


func _go(speed: float) -> void:
	_drive = 0.0
	_speed = speed


func _once(key: String, at: float) -> bool:
	if _t < at or _fired.has(key):
		return false
	_fired[key] = true
	return true


func _story() -> void:
	match kind:
		"fun":
			if _once("plan", 3.4):
				# Yellow goes to the house in the middle, blue top right, red top left.
				_plan(WAY, 3.4, 5.4, {3: ["deliver", _house_at(Vector2i(2, 2))], 8: ["deliver", _house_at(Vector2i(3, 0))],
					10: ["deliver", _house_at(Vector2i(1, 0))]})
			if _once("go", 5.6):
				_go(3.4)
			for i in 3:
				if _once("hop%d" % i, 0.6 + i * 0.7):
					_houses[i]["node"].hop()
		"bait":
			if _once("wrong", 2.2):
				_plan(WRONG, 2.2, 3.3, {4: ["nope", _house_at(Vector2i(1, 0))]})
			if _once("go1", 3.5):
				_go(3.6)
			if _once("back", 5.2):
				_drive = -1.0
				_van.position = _center(_start)
				_van.target_rotation = -PI / 2.0
				_trail.clear()
				_route = []
			if _once("right", 5.9):
				_plan(WAY, 5.9, 7.2, {3: ["deliver", _house_at(Vector2i(2, 4))], 8: ["deliver", _house_at(Vector2i(3, 0))],
					10: ["deliver", _house_at(Vector2i(1, 0))]})
			if _once("go2", 7.4):
				_go(4.6)
			if _once("genius", 9.8):
				_iq_to = 160.0
				Sfx.play("win")
				Sfx.haptic(20)
		"trash":
			if _once("cam", 10.3):
				_stage.visible = true
				_plan(WAY, 10.3, 10.3, {3: ["deliver", _house_at(Vector2i(2, 2))], 8: ["deliver", _house_at(Vector2i(3, 0))],
					10: ["deliver", _house_at(Vector2i(1, 0))]})
				_ink = 1.0
				_go(5.6)
			if _once("off", 12.8):
				_stage.visible = false
			for k in 7:
				if _once("beat%d" % k, 10.3 + k * BEAT):
					_punch = 1.0
					_flash = 0.35


func _process(delta: float) -> void:
	if _closing:
		return
	var dt := minf(delta, 0.1)
	var before := _t
	_t += dt
	for cue in _cues:
		var at: float = cue[0]
		if at > before and at <= _t:
			Sfx.play(cue[1], cue[2], cue[3])
	_story()
	if _ink_to > _ink_from and _t >= _ink_from:
		_ink = clampf((_t - _ink_from) / (_ink_to - _ink_from), 0.0, 1.0)
	if _drive >= 0.0 and not _route.is_empty():
		var was := _drive
		_drive = minf(_drive + dt * _speed, _route.size() - 1.0)
		for k in range(int(floor(was)) + 1, int(floor(_drive)) + 1):
			_reach(k)
		var i := mini(int(floor(_drive)), _route.size() - 2)
		var u := _drive - i
		var a := _center(_route[i])
		var b := _center(_route[i + 1])
		_van.position = a.lerp(b, u)
		_van.target_rotation = (b - a).angle()
		if _trail.is_empty() or _trail.back().distance_to(_van.position) > _tile * 0.3:
			_trail.append(_van.position)
		if _drive >= _route.size() - 1.0:
			_drive = -1.0
	_iq = move_toward(_iq, _iq_to, dt * 90.0)
	_flash = maxf(0.0, _flash - dt * 2.5)
	_punch = maxf(0.0, _punch - dt * 2.4)
	_shake = maxf(0.0, _shake - dt * 3.0)
	_flyers = _flyers.filter(func(f): return _t - float(f["t0"]) < 0.42)
	_marks = _marks.filter(func(m): return _t - float(m["t0"]) < 1.6)
	if kind == "trash" and _stage.visible:
		# Fancam: punch in on the van with every beat.
		var z := 1.0 + 0.32 * _punch
		var focus := _van.position.lerp(Vector2(2.5, 2.5) * _tile, 1.0 - _punch)
		var screen := _board_origin() + Vector2(2.5, 2.5) * _tile
		_stage.scale = Vector2(z, z)
		_stage.position = screen - focus * z
	if _t >= _end_at:
		_skip.icon_name = "x"
		_skip.label = "Close"
		if not _cta.visible:
			_cta.visible = true
			_cta.label = {"fun": "Back to it", "bait": "Prove it", "trash": "Keep driving"}[kind]
			_cta.scale = Vector2.ZERO
			var tw := create_tween()
			tw.tween_interval(0.5)
			tw.tween_property(_cta, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(_cta.breathe.bind(true))
	_root.queue_redraw()
	_ground.queue_redraw()
	_air.queue_redraw()
	_hud.queue_redraw()


## The van reaches step k of the route: a delivery, or a NOPE.
func _reach(k: int) -> void:
	if not _events.has(k):
		return
	var ev: Array = _events[k]
	var h: int = ev[1]
	if h < 0:
		return
	var house: House = _houses[h]["node"]
	if ev[0] == "deliver" and not _load.is_empty():
		_flyers.append({"from": _van.position, "to": house.base_pos + Vector2(0, -_tile * 0.3), "col": Palette.pkg(_load[0]), "t0": _t, "h": h})
		_load.pop_front()
		_van.set_top(_load[0] if not _load.is_empty() else "")
		_van.nudge()
		Sfx.play("whoosh", 1.1, -10.0)
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_instance_valid(house):
				house.deliver()
				_marks.append({"at": house.base_pos + Vector2(0, -_tile * 0.6), "t0": _t, "kind": "heart"})
				Sfx.play("thunk", 1.0 + 0.1 * (3 - _load.size()))
				Sfx.haptic(14))
	else:
		house.wobble()
		_van.shake()
		_marks.append({"at": house.base_pos, "t0": _t, "kind": "x"})
		_shake = 1.0
		_iq_to = 63.0
		_drive = -1.0
		Sfx.play("bonk", 0.9, -2.0)
		Sfx.play("fail", 1.0, -6.0)
		Sfx.haptic(20)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_close()


func _close() -> void:
	if _closing:
		return
	_closing = true
	finished.emit()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)


# ---------------------------------------------------------------- drawing

func _pop(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 + 2.7 * pow(u - 1.0, 3.0) + 1.7 * pow(u - 1.0, 2.0)


## Centred text with an outline, shrunk to fit `max_w`.
func _text(text: String, at: Vector2, px: int, col: Color, max_w := 0.0, outline := INK) -> void:
	var f := UiTheme.font()
	if max_w > 0.0:
		while px > 20 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
			px -= 2
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if outline.a > 0.0:
		_hud.draw_string_outline(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(px / 5, 6), Color(outline, col.a * outline.a))
	_hud.draw_string(f, at + Vector2(-w / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


## A caption that pops in at `from` and fades by `to`.
func _caption(text: String, from: float, to: float, y: float, px: int, col: Color, outline := INK) -> void:
	if _t < from or _t >= to:
		return
	var grow := _pop((_t - from) / 0.35)
	var fade := 1.0 - smoothstep(to - 0.25, to, _t)
	_text(text, Vector2(_hud.size.x / 2.0, y), maxi(int(px * grow), 8), Color(col, fade), _hud.size.x - 90.0, outline)


func _draw_back() -> void:
	var r := _root
	var s := r.size
	match kind:
		"fun":
			r.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
				PackedColorArray([Color("ffe9d2"), Color("ffe9d2"), Color("ffd3e2"), Color("ffd3e2")]))
			for i in 9:
				var u := fmod(_t * 0.08 + i * 0.137, 1.0)
				var at := Vector2(s.x * fmod(i * 0.29 + 0.1, 1.0), s.y * (1.05 - u * 1.1))
				_heart(r, at, 18.0 + (i % 3) * 8.0, Color(Palette.pkg("red"), 0.12))
		"bait":
			r.draw_rect(Rect2(Vector2.ZERO, s), YELLOW)
			var off := fmod(_t * 120.0, 160.0)
			for k in 20:
				var x := -s.y + k * 160.0 + off
				r.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 70, 0), Vector2(x + 70 + s.y, s.y), Vector2(x + s.y, s.y)]), Color(1, 0.55, 0.1, 0.12))
		_:
			if _t < 6.9:
				for i in 24:
					var y := i * s.y / 24.0
					r.draw_rect(Rect2(0, y, s.x, s.y / 24.0 + 1.0), NAVY.lerp(Color("1b2f63"), sin(PI * i / 23.0) * 0.8))
				for k in 3:
					var x := fmod(_t * 220.0 + k * 520.0, s.x + 600.0) - 300.0
					r.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 140, 0), Vector2(x - 260, s.y), Vector2(x - 400, s.y)]), Color(1, 1, 1, 0.04))
			elif _t < 8.3 or (_t >= 12.8 and _t < _end_at):
				r.draw_rect(Rect2(Vector2.ZERO, s), Color.BLACK if _t < 8.3 else Color("12060f"))
			else:
				r.draw_rect(Rect2(Vector2.ZERO, s), Color("1a0d2b"))
				if _t < 10.3:
					# Purple-hot flames along the bottom for the slam.
					var pal := AnimeFire.palette(8)
					for k in 7:
						var x := s.x * (k + 0.5) / 7.0
						AnimeFire.draw_flame(r, Vector2(x, s.y + 40.0), 260.0, 620.0 + 120.0 * sin(_t * 3.0 + k), _t, k * 1.3, pal)


## The map: a grass board, its roads, the route drawn so far, and (in the fancam) the road burning behind.
func _draw_ground() -> void:
	var g := _ground
	var sz := Vector2(5, 5) * _tile
	var pad := _tile * 0.14
	var outer := Rect2(-Vector2(pad, pad), sz + Vector2(pad, pad) * 2.0)
	DrawUtil.rrect(g, Rect2(outer.position + Vector2(0, _tile * 0.07), outer.size), Palette.BOARD_SHADOW, _tile * 0.3)
	DrawUtil.rrect(g, outer, Palette.GRASS, _tile * 0.3)
	var m := _tile * 0.12
	var rw := _tile - m * 2.0
	for pass_i in 2:
		var col := Palette.ROAD_EDGE if pass_i == 0 else Palette.ROAD
		var off := Vector2(0, _tile * 0.045) if pass_i == 0 else Vector2.ZERO
		for p in _road:
			var o := Vector2(p) * _tile + off
			DrawUtil.rrect(g, Rect2(o + Vector2(m, m), Vector2(rw, rw)), col, _tile * 0.2)
			if _road.has(p + Vector2i(1, 0)):
				g.draw_rect(Rect2(o + Vector2(_tile * 0.5, m), Vector2(_tile, rw)), col)
			if _road.has(p + Vector2i(0, 1)):
				g.draw_rect(Rect2(o + Vector2(m, _tile * 0.5), Vector2(rw, _tile)), col)
	if kind == "trash" and not _trail.is_empty():
		var pal := AnimeFire.palette(8)
		for i in _trail.size():
			var p: Vector2 = _trail[i]
			g.draw_circle(p, _tile * 0.26, Color("1d1f26"))
			AnimeFire.draw_flame(g, p + Vector2(0, _tile * 0.1), _tile * 0.32, _tile * 0.55, _t, i * 0.77, pal)
	# The route, drawn on as the finger goes.
	if _route.size() >= 2 and _ink > 0.0:
		var pts := PackedVector2Array()
		var reach := _ink * (_route.size() - 1)
		for i in _route.size():
			if i <= reach:
				pts.append(_center(_route[i]))
			else:
				var a := _center(_route[i - 1])
				pts.append(a.lerp(_center(_route[i]), reach - (i - 1)))
				break
		if pts.size() >= 2:
			var col := HOT if kind == "bait" and _route == WRONG else Color.WHITE
			g.draw_polyline(pts, Color(INK, 0.35), _tile * 0.24, true)
			g.draw_polyline(pts, col, _tile * 0.17, true)
			for q in pts:
				g.draw_circle(q, _tile * 0.085, col)


## Over the houses and van: packages in flight, hearts and NOPE crosses, and the drawing finger.
func _draw_air() -> void:
	var a := _air
	for f in _flyers:
		var u := clampf((_t - float(f["t0"])) / 0.4, 0.0, 1.0)
		var at: Vector2 = (f["from"] as Vector2).lerp(f["to"], u) + Vector2(0, -_tile * 0.9 * 4.0 * u * (1.0 - u))
		DrawUtil.package(a, at, _tile * 0.42, f["col"])
	for mk in _marks:
		var u := clampf((_t - float(mk["t0"])) / 1.6, 0.0, 1.0)
		var at: Vector2 = mk["at"]
		if mk["kind"] == "heart":
			_heart(a, at + Vector2(0, -_tile * 0.8 * u), _tile * 0.16 * (0.7 + 0.5 * u), Color(Palette.pkg("red"), 1.0 - u))
		else:
			var s := _tile * 0.55 * _pop(u / 0.2)
			var col := Color(HOT, 1.0 - smoothstep(0.7, 1.0, u))
			a.draw_line(at + Vector2(-s, -s), at + Vector2(s, s), Color.WHITE, _tile * 0.22, true)
			a.draw_line(at + Vector2(s, -s), at + Vector2(-s, s), Color.WHITE, _tile * 0.22, true)
			a.draw_line(at + Vector2(-s, -s), at + Vector2(s, s), col, _tile * 0.14, true)
			a.draw_line(at + Vector2(s, -s), at + Vector2(-s, s), col, _tile * 0.14, true)
	if _route.size() >= 2 and _ink > 0.0 and _ink < 1.0:
		var reach := _ink * (_route.size() - 1)
		var i := int(floor(reach))
		var tip := _center(_route[i]).lerp(_center(_route[mini(i + 1, _route.size() - 1)]), reach - i)
		Icons.draw(a, "finger", tip + Vector2(_tile * 0.28, _tile * 0.42), _tile * 0.8, Color.WHITE)


func _heart(ci: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(at + Vector2(-s * 0.5, 0), s * 0.56, col)
	ci.draw_circle(at + Vector2(s * 0.5, 0), s * 0.56, col)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 1.02, s * 0.22), at + Vector2(s * 1.02, s * 0.22), at + Vector2(0, s * 1.4)]), col)


## Captions, the news, the slams, the IQ meter, the end card, and the ad furniture.
func _draw_hud() -> void:
	var w := _hud.size.x
	var h := _hud.size.y
	var board_top := _board_origin().y
	# Captions sit above the load tray, which sits just above the map.
	var cap_y := maxf(board_top - 290.0, 200.0 + _top)
	var shake := Vector2(sin(_t * 61.0), cos(_t * 47.0)) * 14.0 * _shake
	match kind:
		"fun":
			_caption("Every package has", 0.15, 3.3, cap_y - 60.0, 84, CREAM)
			_caption("someone waiting.", 0.45, 3.3, cap_y + 40.0, 84, CREAM)
			_caption("Draw one route.", 3.4, 5.5, cap_y, 92, CREAM)
			_caption("Top of the stack goes first.", 5.6, 8.7, cap_y, 80, CREAM)
			_caption("Deliver them all!", 8.8, _end_at, cap_y, 96, Color("ffd166"))
			if _t < _end_at:
				_draw_load(Vector2(w / 2.0, board_top - 80.0))
		"bait":
			if _t < 2.2:
				var k := _pop(_t / 0.35)
				_text("99% FAIL", Vector2(w / 2.0, cap_y - 70.0) + shake * 0.5 + Vector2(0, 6.0 * sin(_t * 20.0)), int(140 * k), HOT, w - 60.0, Color.WHITE)
				_text("THIS LEVEL!", Vector2(w / 2.0, cap_y + 60.0), int(120 * k), HOT, w - 60.0, Color.WHITE)
				# A red ring round the map, the way these ads do.
				var c := _board_origin() + Vector2(2.5, 2.5) * _tile
				_hud.draw_arc(c, minf(_tile * 2.85, w / 2.0 - 16.0) + 8.0 * sin(_t * 8.0), 0.0, TAU, 64, HOT, 14.0, true)
			_caption("Most people go this way...", 2.2, 5.2, cap_y, 74, INK, Color.WHITE)
			if _t >= 4.4 and _t < 5.6:
				var mid := _board_origin() + Vector2(2.5, 2.5) * _tile
				_text("NOPE!", mid + shake, int(170 * _pop((_t - 4.4) / 0.3)), HOT, 0.0, Color.WHITE)
			_caption("Only geniuses see it.", 5.6, 9.7, cap_y, 80, INK, Color.WHITE)
			_caption("GENIUS!", 9.8, _end_at, cap_y, 140, Color("35c27a"), Color.WHITE)
			if _t < _end_at:
				if _t >= 2.2:
					_draw_load(Vector2(w / 2.0, board_top - 80.0))
				_draw_iq(Rect2(80.0, _board_origin().y + 5.0 * _tile + 70.0, w - 160.0, 110.0))
		_:
			_draw_trash_hud(w, h, cap_y, shake)
	if _flash > 0.0:
		_hud.draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, _flash))
	if _t >= _end_at:
		_draw_end_card(w, h)
	# Ad furniture: a label, how far through, and the small print.
	var tag := Rect2(36.0, 54.0 + _top, 96.0, 62.0)
	DrawUtil.rrect(_hud, tag, Color(0, 0, 0, 0.35), 31)
	var f := UiTheme.font()
	var tw := f.get_string_size("Ad", HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	_hud.draw_string(f, tag.position + Vector2((tag.size.x - tw) / 2.0, 44), "Ad", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	var left := clampf(_t / _end_at, 0.0, 1.0)
	var bar_y := h - 12.0 - _bottom
	_hud.draw_rect(Rect2(0, bar_y, w, 12.0), Color(0, 0, 0, 0.15))
	_hud.draw_rect(Rect2(0, bar_y, w * left, 12.0), Game.AD_PINK)
	var dark_back := kind == "trash"
	_text("Not a real ad. Nobody paid for this. Real game, though.", Vector2(w / 2.0, bar_y - 44.0), 28,
		Color(CREAM if dark_back or _t >= _end_at else INK, 0.6), w - 60.0, Color(0, 0, 0, 0))


## The load, as the game's chute shows it: a tray of packages, the next one out on the right.
func _draw_load(c: Vector2) -> void:
	var n := 3
	var box := 96.0
	var tray := Rect2(c - Vector2(n * (box + 14.0) / 2.0 + 18.0, box / 2.0 + 14.0), Vector2(n * (box + 14.0) + 36.0, box + 28.0))
	DrawUtil.rrect(_hud, tray, Color(1, 1, 1, 0.55), 30)
	for i in _load.size():
		var at := Vector2(tray.end.x - 18.0 - (i + 0.5) * (box + 14.0) + 7.0, c.y)
		DrawUtil.package(_hud, at, box * (1.12 if i == 0 else 1.0), Palette.pkg(_load[i]))
	var f := UiTheme.font()
	var nx := tray.end.x - 18.0 - (box + 14.0) * 0.5 + 7.0
	var nw := f.get_string_size("NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	DrawUtil.rrect(_hud, Rect2(Vector2(nx - nw / 2.0 - 12.0, tray.position.y - 22.0), Vector2(nw + 24.0, 38.0)), Color("ffd166"), 19)
	_hud.draw_string(f, Vector2(nx - nw / 2.0, tray.position.y + 6.0), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)


## The clickbait's IQ meter.
func _draw_iq(r: Rect2) -> void:
	DrawUtil.rrect(_hud, r, INK, r.size.y / 2.0)
	var f := UiTheme.font()
	_hud.draw_string(f, r.position + Vector2(40, r.size.y * 0.68), "IQ", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, YELLOW)
	var bar := Rect2(r.position + Vector2(150, r.size.y * 0.36), Vector2(r.size.x - 360, r.size.y * 0.28))
	DrawUtil.rrect(_hud, bar, Color(1, 1, 1, 0.15), bar.size.y / 2.0)
	var k := clampf(_iq / 160.0, 0.05, 1.0)
	var col := HOT if _iq < 90.0 else (YELLOW if _iq < 140.0 else Color("35c27a"))
	DrawUtil.rrect(_hud, Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), col, bar.size.y / 2.0)
	var num := str(int(round(_iq)))
	var nw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 70).x
	_hud.draw_string(f, Vector2(r.end.x - 40.0 - nw, r.position.y + r.size.y * 0.7), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 70, Color.WHITE)


## The trash talk: breaking news, the scratch, the slam, the fancam's words, the message for Rockstar.
func _draw_trash_hud(w: float, h: float, cap_y: float, shake: Vector2) -> void:
	if _t < 6.9:
		var bar := Rect2(0, 150.0 + _top, w, 140.0)
		_hud.draw_rect(bar, NEWS_RED)
		_text("BREAKING NEWS", Vector2(w * 0.42, bar.get_center().y), 88, Color.WHITE, w * 0.75, Color(0, 0, 0, 0))
		if int(_t * 2.0) % 2 == 0:
			_hud.draw_circle(Vector2(w - 170.0, bar.get_center().y), 16, Color.WHITE)
		_text("LIVE", Vector2(w - 95.0, bar.get_center().y), 50, Color.WHITE, 0.0, Color(0, 0, 0, 0))
		var lines := [["PUBLISHERS", "DODGE GTA VI'S", "RELEASE DATE"], ["BIG GAMES", "DELAYED TO", "AVOID GTA VI"], ["STUDIOS BRACE", "FOR \"A HUGE", "METEOR\""]]
		for i in 3:
			var t0 := 0.3 + i * 2.2
			if _t < t0 or _t >= t0 + 2.2:
				continue
			var slide := 1.0 - pow(1.0 - clampf((_t - t0) / 0.28, 0.0, 1.0), 3.0)
			var c := Vector2(lerpf(w + 600.0, w / 2.0, slide), h * 0.46)
			var card := Rect2(c - Vector2(w * 0.43, 250.0), Vector2(w * 0.86, 500.0))
			DrawUtil.rrect(_hud, Rect2(card.position + Vector2(0, 18), card.size), Color(0, 0, 0, 0.35), 30)
			DrawUtil.rrect(_hud, card, Color.WHITE, 30)
			_hud.draw_rect(Rect2(card.position.x, card.position.y + 30, 16, card.size.y - 60), NEWS_RED)
			_hud.draw_string(UiTheme.font(), card.position + Vector2(56, 82), "GAMING NEWS", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, NEWS_RED)
			for k in 3:
				_hud.draw_string(UiTheme.font(), card.position + Vector2(56, 190 + k * 108), lines[i][k], HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 100.0, 92, Color("141414"))
		var ty := h - 260.0 - _bottom
		_hud.draw_rect(Rect2(0, ty, w, 100), Color("0a0f1f"))
		var tick := "PUBLISHERS DUCK FOR COVER   •   RELEASE DATES PUSHED   •   NOBODY WANTS THAT SMOKE   •   "
		var f := UiTheme.font()
		var tw := f.get_string_size(tick, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
		var tx := 230.0 - fmod(_t * 300.0, tw)
		for r in 3:
			_hud.draw_string(f, Vector2(tx + r * tw, ty + 66), tick, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
		_hud.draw_rect(Rect2(0, ty, 210, 100), YELLOW)
		_text("GTA VI", Vector2(105, ty + 50), 50, INK, 190.0, Color(0, 0, 0, 0))
	elif _t < 8.3:
		_text("NO GAME", Vector2(w / 2.0, h * 0.42) + shake, int(170 * _pop((_t - 6.95) / 0.25)), Color.WHITE, w - 60.0, Color(0, 0, 0, 0))
		if _t >= 7.45:
			_text("DARES???", Vector2(w / 2.0, h * 0.42 + 190.0), int(170 * _pop((_t - 7.45) / 0.25)), YELLOW, w - 60.0, Color(0, 0, 0, 0))
	elif _t < 10.3:
		var words := [["LAST MILE", Palette.ACCENT, 8.3], ["DOESN'T GIVE A", Color.WHITE, 8.3 + BEAT], ["&@$*&!!!!", YELLOW, 8.3 + 2.0 * BEAT]]
		for i in 3:
			var at: float = words[i][2]
			if _t >= at:
				_text(words[i][0], Vector2(w / 2.0, h * 0.3 + i * 200.0) + shake, int((150 if i != 1 else 110) * _pop((_t - at) / 0.22)), words[i][1], w - 60.0)
	elif _t < 12.8:
		var calls := [["NO BRAKES.", 10.6], ["NO DELAYS.", 11.3], ["DELIVERED!", 12.0]]
		for c in calls:
			if _t >= c[1] and _t < c[1] + 0.7:
				_text(c[0], Vector2(w / 2.0, h * 0.86 - _bottom), int(130 * _pop((_t - c[1]) / 0.2)), YELLOW if c[0] != "DELIVERED!" else Color("35c27a"), w - 60.0)
	else:
		var msg := [["ROCKSTAR.", YELLOW, 12.9, 140], ["DELAY GTA VI", Color.WHITE, 13.4, 110], ["OR BE WRECKED", HOT, 13.9, 110], ["BY THE BEST GAME ON FOUR WHEELS.", Color.WHITE, 14.5, 64]]
		for i in msg.size():
			var at: float = msg[i][2]
			if _t >= at and _t < _end_at:
				_text(msg[i][0], Vector2(w / 2.0, h * 0.27 + i * 190.0) + shake * 0.4, int(msg[i][3] * _pop((_t - at) / 0.22)), msg[i][1], w - 70.0)


func _draw_end_card(w: float, h: float) -> void:
	var u := _t - _end_at
	_hud.draw_rect(Rect2(0, 0, w, h), Color(INK, 0.9 * clampf(u / 0.3, 0.0, 1.0)))
	var grow := _pop(u / 0.45)
	_text("Last Mile", Vector2(w / 2.0, h * 0.3), maxi(int(190 * grow), 8), CREAM, w - 60.0)
	if u > 0.25:
		var a := clampf((u - 0.25) / 0.3, 0.0, 1.0)
		var line: String = {"fun": "Draw the route. Mind the stack.", "bait": "Spoiler: you can. You're playing it.", "trash": "Out now*. You're playing it."}[kind]
		_text(line, Vector2(w / 2.0, h * 0.3 + 170.0), 52, Color(CREAM, a), w - 80.0)
		if kind == "trash":
			_text("*Dropping November 19, 2026, for everyone else.", Vector2(w / 2.0, h * 0.3 + 250.0), 34, Color(CREAM, 0.7 * a), w - 80.0)
	if u > 0.9:
		_text("a Door Bowl game", Vector2(w / 2.0, _cta.position.y + _cta.size.y + 80.0), 36, Color(CREAM, 0.7 * clampf((u - 0.9) / 0.3, 0.0, 1.0)), 0.0, Color(0, 0, 0, 0))
