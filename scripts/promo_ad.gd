class_name PromoAd
extends CanvasLayer
## Pretend ads for Last Mile itself, played when you're out of hints: three short spots drawn live in code
## (like FakeAd's Frontiers Celestia one), each the idea of one of the game's trailers, with the game's own
## van, houses and sounds:
##   fun    Cozy. "Every package has someone waiting." A finger draws one route; the van delivers them all.
##   bait   A clickbait parody. "99% FAIL THIS LEVEL!" The wrong way gets a NOPE and an IQ of 63; the
##          genius way delivers everything and the IQ meter maxes out.
##   trash  Trash talk, after the GTA VI trailer (tools/ads/gta_director.gd): breaking news (publishers
##          dodging GTA VI), a record scratch, "NO GAME DARES???", "LAST MILE DOESN'T GIVE A &@$*&!!!!"
##          slammed on the beat, a fancam of a burning run (the map filmed through the trailer's shader:
##          follow cam, zoom punches, tilts, RGB split, flashes, black-and-white and inverted hits, blur,
##          speed ramps, the fire getting hotter), then a message for Rockstar. Its music is PromoMusic's,
##          synthesized on a worker thread while the news plays (the trailer's song can't ship in the app).
## The clickbait has the trailer's reaction cam too: an emoji face (NOOB, then PRO) reacting in the corner.
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
## Trash talk: the beat comes in (its first downbeat at BEAT_AT, after a riser from SONG_AT), the fancam's
## hits (every half beat), and when the run should be over.
const BEAT_AT := 8.3
const SONG_AT := BEAT_AT - 0.53
const HITS := [10.35, 10.69, 11.03, 11.37, 11.71, 12.05, 12.39]
const WIN_T := 12.5
## The trailer's fancam look (tools/ads/gta_root.gd): RGB split, a radial blur, saturation and contrast,
## invert, vignette, and a white flash.
const FANCAM := """
shader_type canvas_item;
uniform float split = 0.0;
uniform float flash = 0.0;
uniform float sat = 1.0;
uniform float contrast = 1.0;
uniform float invert = 0.0;
uniform float blur = 0.0;
uniform float vignette = 0.0;
void fragment() {
	vec2 c = vec2(0.5);
	vec2 d = UV - c;
	vec3 col = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float k = float(i) / 6.0 * blur;
		vec2 u = c + d * (1.0 - k);
		col.r += texture(TEXTURE, u + vec2(split, 0.0) * TEXTURE_PIXEL_SIZE).r;
		col.g += texture(TEXTURE, u).g;
		col.b += texture(TEXTURE, u - vec2(split, 0.0) * TEXTURE_PIXEL_SIZE).b;
	}
	col /= 6.0;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, sat);
	col = (col - 0.5) * contrast + 0.5;
	col = mix(col, 1.0 - col, invert);
	col *= 1.0 - vignette * smoothstep(0.35, 0.85, length(d * vec2(1.0, 0.65)));
	col = mix(col, vec3(1.0), flash);
	COLOR = vec4(col, 1.0);
}
"""

## The little map every spot drives on (the game's level tokens: # road, S start, letters houses).
const MAP_FUN := [". r . b .", "# # # # #", "# . y . #", "# # # # #", "S . . . ."]
const MAP_BAIT := [". b . r .", "# # # # #", "# . . . #", "# # # # #", "S . y . ."]
## The way round that delivers everything: up, along the middle, up the right, back along the top.
const WAY := [Vector2i(0, 4), Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
	Vector2i(4, 2), Vector2i(4, 1), Vector2i(3, 1), Vector2i(2, 1), Vector2i(1, 1)]
## The clickbait's wrong way: straight up the left, to the blue house with yellow on top.
const WRONG := [Vector2i(0, 4), Vector2i(0, 3), Vector2i(0, 2), Vector2i(0, 1), Vector2i(1, 1)]

static var _last := -1
## The trash talk's music, made once a session (on a worker thread) and kept.
static var _music := {}
static var _music_task := -1
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
# The fancam (trash talk): the map renders into _cam_vp, shown through the FANCAM shader by _view.
var _cam_vp: SubViewport
var _view: Sprite2D
var _cam_pt := Vector2.ZERO
var _zoom := 1.0
var _tilt := 0.0
var _tilt_to := 0.0
var _split := 0.0
var _invert := 0.0
var _mono := 0.0
var _blur := 0.0
var _heat_m := 3
var _words: Array = []           # {text, t0, rot}
var _hit_i := 0
var _last_hit := -10.0
var _bed: AudioStreamPlayer
var _song: AudioStreamPlayer
# The clickbait's reaction cam.
var _face := ""
var _face_name := "NOOB"
var _face_t0 := 0.0
var _say := ""
var _say_t0 := 0.0


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
	_tile = minf(150.0 if kind == "bait" else 170.0, (vp.x - 160.0) / 5.0)
	_stage = Node2D.new()
	if kind == "trash":
		# The map is filmed: it renders into its own viewport, shown through the fancam shader.
		_cam_vp = SubViewport.new()
		_cam_vp.size = Vector2i(vp)
		_cam_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_cam_vp.msaa_2d = Viewport.MSAA_2X
		_root.add_child(_cam_vp)
		var bg := ColorRect.new()
		bg.color = Color("1a0d2b")
		bg.size = vp
		_cam_vp.add_child(bg)
		_cam_vp.add_child(_stage)
		_view = Sprite2D.new()
		_view.texture = _cam_vp.get_texture()
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = FANCAM
		mat.shader = sh
		_view.material = mat
		_view.visible = false
		_root.add_child(_view)
		_cam_pt = vp / 2.0
	else:
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
	return Vector2((vp.x - 5.0 * _tile) / 2.0, vp.y * (0.47 if kind == "bait" else 0.56) - 2.5 * _tile)


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
	for i in 3:
		_cue(0.3 + i * 2.2, "whoosh", 0.8, 0.0)
	_cue(6.95, "slam", 0.9, -4.0)
	_cue(7.45, "slam", 1.0, -4.0)
	for at in [BEAT_AT, BEAT_AT + BEAT, BEAT_AT + 2.0 * BEAT]:
		_cue(at, "slam", 1.0, -6.0)
	for k in 4:
		_cue(BEAT_AT + (7 + k) * BEAT, "slam", 0.9, -6.0)
	_cue(_end_at, "star", 1.0, -3.0)
	_bed = AudioStreamPlayer.new()
	_bed.volume_db = -4.0
	add_child(_bed)
	_song = AudioStreamPlayer.new()
	add_child(_song)
	_make_music()


## The music, on a worker thread (once a session; it's kept for next time).
func _make_music() -> void:
	if not _music.is_empty() or _music_task >= 0:
		return
	var song_hits := []
	for h in HITS:
		song_hits.append(h - SONG_AT)
	var length := _end_at + 1.0 - SONG_AT
	_music_task = WorkerThreadPool.add_task(func():
		var m := {}
		m["bed"] = PromoMusic.news_bed(6.9, [0.3, 2.5, 4.7])
		m["scratch"] = PromoMusic.scratch()
		m["song"] = PromoMusic.hype(length, 0.53, BEAT, song_hits)
		PromoAd._music = m)


func _music_ready() -> bool:
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
	return _music_task < 0 and not _music.is_empty()


## Plays the track (from `from` seconds into the ad), late if it wasn't ready in time.
func _play(p: AudioStreamPlayer, key: String, from: float) -> void:
	if p.playing or not _music_ready():
		return
	p.stream = _music[key]
	p.play(maxf(_t - from, 0.0))
	print("[ad] music: %s from %.2f s" % [key, maxf(_t - from, 0.0)])


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
			if _once("f0", 0.0):
				_react("🙂")
			if _once("f1", 2.2):
				_react("🤔")
			if _once("f2", 3.5):
				_react("😬")
			if _once("f3", 4.45):
				_react("😭", "AWW MAN!")
			if _once("f4", 5.2):
				_face_name = "PRO"
				_react("😎", "PSHAW.")
			if _once("f5", 6.1):
				_react("😎", "TOO EASY.")
			if _once("f6", 7.4):
				_react("😎")
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
				_iq_to = 999.0
				_face_name = ""
				_react("😱", "WHAAATTT?!")
				Sfx.play("win")
				Sfx.haptic(20)
		"trash":
			if _t < 6.9:
				_play(_bed, "bed", 0.0)
			if _once("scratch", 6.9):
				_bed.stop()
				if _music_ready():
					var sc := AudioStreamPlayer.new()
					sc.stream = _music["scratch"]
					add_child(sc)
					sc.play()
				else:
					Sfx.play("screech", 1.0, -2.0)
			if _t >= SONG_AT and _t < _end_at:
				_play(_song, "song", SONG_AT)
			if _once("cam", HITS[0] - 0.05):
				# Cut in: tight on the van, tilted, split, flash.
				_view.visible = true
				_plan(WAY, 0.0, 0.0, {3: ["deliver", _house_at(Vector2i(2, 2))], 8: ["deliver", _house_at(Vector2i(3, 0))],
					10: ["deliver", _house_at(Vector2i(1, 0))]})
				_ink = 1.0
				_go(5.0)
				_cam_pt = _stage.position + _van.position
				_flash = 1.0
				_zoom = 2.0
				_punch = 0.6
				_tilt_to = -0.06
				_split = 22.0
			while _hit_i < HITS.size() and _t >= HITS[_hit_i]:
				_hit(_hit_i)
				_hit_i += 1
			if _once("delivered", WIN_T + 0.05):
				# Snap out to the whole map for the DELIVERED! slam.
				_zoom = 1.0
				_punch = 0.18
				_tilt_to = 0.0
				_flash = 0.8
				_split = 18.0
				_words = [{"text": "DELIVERED!", "t0": _t, "rot": 0.0}]
				Sfx.play("win", 1.0, -4.0)
			if _once("off", BEAT_AT + 7.0 * BEAT - 0.05):
				_view.visible = false


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
		var speed := _speed
		if kind == "trash":
			# Fancam speed: aim to finish by WIN_T, slammed down for a moment after each hit.
			var left := _route.size() - 1.0 - _drive
			var base := clampf(left / maxf(WIN_T - _t, 0.15), 1.5, 16.0)
			var since := _t - _last_hit
			speed = base * (0.3 if since < 0.12 else lerpf(0.75, 1.35, clampf((since - 0.12) / 0.35, 0.0, 1.0)))
		_drive = minf(_drive + dt * speed, _route.size() - 1.0)
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
	_iq = move_toward(_iq, _iq_to, dt * maxf(90.0, absf(_iq_to - _iq) * 2.5))
	_flash = maxf(0.0, _flash - dt * (6.0 if kind == "trash" else 2.5))
	_punch = maxf(0.0, _punch - dt * (2.8 if kind == "trash" else 2.4))
	_shake = maxf(0.0, _shake - dt * 3.0)
	_split = maxf(0.0, _split - dt * 60.0)
	_invert = maxf(0.0, _invert - dt * 12.0)
	_mono = maxf(0.0, _mono - dt * 3.0)
	_blur = maxf(0.0, _blur - dt * 1.6)
	_tilt = lerpf(_tilt, _tilt_to, 0.35)
	_words = _words.filter(func(wd): return _t - float(wd["t0"]) < 0.8)
	_flyers = _flyers.filter(func(f): return _t - float(f["t0"]) < 0.42)
	_marks = _marks.filter(func(m): return _t - float(m["t0"]) < 1.6)
	if _view and _view.visible:
		_apply_view()
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


## A fancam hit, the trailer's way: punch, split, flash, shake and a tilt every time; then, one by one, a
## word, hotter fire, black and white, a word and an inverted frame, hotter still, a word and a blur.
func _hit(i: int) -> void:
	_last_hit = HITS[i]
	_punch = 0.75
	_split = 26.0
	_flash = 0.55
	_shake = 0.6
	_tilt_to = 0.08 if i % 2 == 0 else -0.08
	_blur = 0.12
	match i:
		1:
			_words.append({"text": "NO BRAKES", "t0": _t, "rot": -0.12})
		2:
			_heat_m = 6
			Sfx.play("whoomp", 1.0, 0.0)
		3:
			_mono = 1.0
		4:
			_words.append({"text": "NO FEAR", "t0": _t, "rot": 0.1})
			_invert = 1.0
		5:
			_heat_m = 9
			Sfx.play("whoomp", 1.1, 0.0)
		6:
			_words.append({"text": "NO DELAYS", "t0": _t, "rot": -0.12})
			_blur = 0.25


## The camera on the filmed map: follows the van while it drives, zoomed and tilted, shaken on hits.
func _apply_view() -> void:
	var vp := Vector2(_cam_vp.size)
	var c := vp / 2.0
	if _drive >= 0.0:
		_cam_pt = _cam_pt.lerp(_stage.position + _van.position, 0.2)
	elif _zoom <= 1.0:
		_cam_pt = _cam_pt.lerp(c, 0.25)
	var z := _zoom * (1.0 + _punch * 0.35)
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 30.0 * _shake
	_view.scale = Vector2.ONE * z
	_view.rotation = _tilt
	_view.position = c + off - ((_cam_pt - c) * z).rotated(_tilt)
	var m: ShaderMaterial = _view.material
	m.set_shader_parameter("split", _split)
	m.set_shader_parameter("flash", _flash)
	m.set_shader_parameter("invert", 1.0 if _invert > 0.5 else 0.0)
	m.set_shader_parameter("sat", lerpf(1.25, 0.0, _mono))
	m.set_shader_parameter("contrast", 1.12 + 0.3 * _mono)
	m.set_shader_parameter("blur", _blur)
	m.set_shader_parameter("vignette", 0.55)


## The reaction cam's face changes (it pops), and maybe says something.
func _react(face: String, say := "") -> void:
	_face = face
	_face_t0 = _t
	_say = say
	_say_t0 = _t


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
	if px < 8 or col.a <= 0.0:
		return
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
			elif _t < BEAT_AT or (_t >= BEAT_AT + 7.0 * BEAT and _t < _end_at):
				r.draw_rect(Rect2(Vector2.ZERO, s), Color.BLACK if _t < BEAT_AT else Color("12060f"))
			else:
				r.draw_rect(Rect2(Vector2.ZERO, s), Color("1a0d2b"))
				if _t < HITS[0]:
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
		var pal := AnimeFire.palette(_heat_m)
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
	var cap_y := maxf(board_top - (270.0 if kind == "bait" else 290.0), 200.0 + _top)
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
				var iq := Rect2(80.0, _board_origin().y + 5.0 * _tile + 70.0, w - 160.0, 110.0)
				_draw_iq(iq)
				_draw_cam(Vector2(w - 160.0, iq.end.y + 160.0), 100.0, shake)
		_:
			_draw_trash_hud(w, h, cap_y, shake)
	if _flash > 0.0 and not (_view and _view.visible):
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


## The clickbait's reaction cam: an emoji face in a ring with a name tag (NOOB, then PRO), and whatever
## it's shouting, in big tilted yellow letters beside it.
func _draw_cam(at: Vector2, r: float, shake: Vector2) -> void:
	if _face == "":
		return
	at += shake * 0.5
	var k := _pop((_t - _face_t0) / 0.25)
	_hud.draw_circle(at + Vector2(0, 12), r + 16, Color(0, 0, 0, 0.22))
	_hud.draw_circle(at, r + 16, Color.WHITE)
	var col := Color("8ea2b6") if _face_name == "NOOB" else (Color("ffd166") if _face_name == "PRO" else HOT)
	_hud.draw_circle(at, r, col)
	var f := UiTheme.font()
	var px := int(r * 1.62 * (0.72 + 0.28 * k))
	var fw := f.get_string_size(_face, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_hud.draw_string(f, at + Vector2(-fw / 2.0, px * 0.36 + 4.0 * sin(_t * 9.0)), _face, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
	if _face_name != "":
		var tw := f.get_string_size(_face_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x + 48.0
		var tr := Rect2(at.x - tw / 2.0, at.y + r - 12.0, tw, 64)
		DrawUtil.rrect(_hud, tr.grow(7), INK, 28)
		DrawUtil.rrect(_hud, tr, col, 22)
		_hud.draw_string(f, tr.position + Vector2(24, 47), _face_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, INK if _face_name == "PRO" else Color.WHITE)
	if _say != "":
		var sk := _pop((_t - _say_t0) / 0.25)
		_hud.draw_set_transform(Vector2(at.x - r - 300.0, at.y) + shake, -0.06, Vector2.ONE * sk)
		_text(_say, Vector2.ZERO, 96, YELLOW, 520.0)
		_hud.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	elif _t < BEAT_AT:
		_text("NO GAME", Vector2(w / 2.0, h * 0.42) + shake, int(170 * _pop((_t - 6.95) / 0.25)), Color.WHITE, w - 60.0, Color(0, 0, 0, 0))
		if _t >= 7.45:
			_text("DARES???", Vector2(w / 2.0, h * 0.42 + 190.0), int(170 * _pop((_t - 7.45) / 0.25)), YELLOW, w - 60.0, Color(0, 0, 0, 0))
	elif _t < HITS[0]:
		var words := [["LAST MILE", Palette.ACCENT, BEAT_AT], ["DOESN'T GIVE A", Color.WHITE, BEAT_AT + BEAT], ["&@$*&!!!!", YELLOW, BEAT_AT + 2.0 * BEAT]]
		for i in 3:
			var at: float = words[i][2]
			if _t >= at:
				_text(words[i][0], Vector2(w / 2.0, h * 0.3 + i * 200.0) + shake, int((150 if i != 1 else 110) * _pop((_t - at) / 0.22)), words[i][1], w - 60.0)
	elif _t < BEAT_AT + 7.0 * BEAT:
		# The fancam's words, slammed in tilted over the bottom of the frame.
		for wd in _words:
			var age := _t - float(wd["t0"])
			var k := _pop(age / 0.18)
			var a := 1.0 - smoothstep(0.55, 0.8, age)
			_hud.draw_set_transform(Vector2(w / 2.0, h * 0.8 - _bottom), wd["rot"], Vector2.ONE * k)
			var green: bool = wd["text"] == "DELIVERED!"
			_text(wd["text"], Vector2.ZERO, 160, Color(Color("35c27a") if green else YELLOW, a), w - 60.0)
			_hud.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var msg := [["ROCKSTAR.", YELLOW, BEAT_AT + 7.0 * BEAT, 140], ["DELAY GTA VI", Color.WHITE, BEAT_AT + 8.0 * BEAT, 110],
			["OR BE WRECKED", HOT, BEAT_AT + 9.0 * BEAT, 110], ["BY THE BEST GAME ON FOUR WHEELS.", Color.WHITE, BEAT_AT + 10.0 * BEAT, 64]]
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
