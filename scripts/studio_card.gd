class_name StudioCard
extends CanvasLayer
## The studio's card, played once a launch over the title: a ceramic bowl with a tiny door set in its side. Something
## kicks at the door from inside, harder each time, until it bursts open and soup gushes out of it straight at the
## camera, band after band of color with noodles and bubbles riding along, until the whole screen is soup and DOOR
## BOWL bobs up in it. Then the last of it sweeps past and leaves the bowl and the name behind, and what's left of
## the juice pulls itself together into "a" and "game" around the name. A beat, and the camera dives through the
## little door into the title. Drawn in code in a 1280x720 frame, scaled to fit (the soup covers whatever screen is
## left over). Any key, click or pad button skips it.
##
## Ported from Frontiers Celestia (ui/studio_card.gd). Changes: the screen check, the font path, the refill
## sound's name (studio_refill) and a local ellipse helper, so it stands alone here.

## Emitted when what's underneath starts to show: the title through the door, or the card being skipped.
signal draining
## Emitted when it's over, just before it frees itself.
signal finished

const FRAME := Vector2(1280, 720)
const MIDDLE := Vector2(640, 360)
const BACKDROP := Color(0.075, 0.05, 0.11)
const SPOT := Color(0.125, 0.08, 0.185)
const SPOT_CORE := Color(0.165, 0.105, 0.24)
const INK := Color(0.09, 0.055, 0.13)
const CERAMIC := Color(0.8, 0.76, 0.7)
const CERAMIC_SHADE := Color(0.62, 0.57, 0.58)
const GLAZE := Color(0.27, 0.36, 0.6)
const DOOR := Color(0.66, 0.29, 0.28)
const DOOR_BACK := Color(0.42, 0.17, 0.2)
const DOOR_FRAME := Color(0.55, 0.36, 0.22)
const DOORWAY := Color(0.17, 0.06, 0.13)
const KNOB := Color(0.82, 0.68, 0.32)
const PASTA := Color(0.82, 0.76, 0.56)
const LETTER := Color(0.93, 0.9, 0.82)
const PEA := Color(0.44, 0.64, 0.38)
const CARROT := Color(0.76, 0.5, 0.26)
## The soup's bands, in the order they pour out.
const SOUP: Array[Color] = [Color(0.45, 0.2, 0.32), Color(0.15, 0.34, 0.36), Color(0.48, 0.38, 0.17), Color(0.28, 0.21, 0.44),
		Color(0.5, 0.28, 0.17)]

## The same juice, left in a thin layer on the dark: richer, so it still reads.
const JUICE: Array[Color] = [Color(0.68, 0.24, 0.47), Color(0.14, 0.53, 0.55), Color(0.76, 0.58, 0.2), Color(0.43, 0.31, 0.72),
		Color(0.77, 0.38, 0.2)]

## The bowl: the middle of its rim, the rim's radii, how deep it is, and the foot it rocks on.
const RIM := Vector2(640, 300)
const RIM_RADII := Vector2(212, 40)
const DEPTH := 168.0
const FOOT := Vector2(640, 486)
## The little door in its side (arched on top).
const DOOR_RECT := Rect2(613, 382, 54, 74)
## The bowl is drawn this much bigger, about this point; MOUTH is where the soup comes out of the door, after that.
const BOWL_SCALE := 1.25
const BOWL_PIVOT := Vector2(640, 380)
const MOUTH := Vector2(640, 440)

## Seconds in: the fade up from black, then the kicks at the door and how hard each one lands. The second leaves the
## door hanging ajar this many degrees and the last bursts it open, flinging it round in OPEN_SECONDS.
const FADE_IN := 0.3
const KICKS: Array[float] = [0.5, 1.05, 1.6]
const KICK_POWER: Array[float] = [0.6, 0.85, 1.3]
const AJAR := 22.0
const OPEN_SECONDS := 0.24
## How far the screen jumps at a full-power kick, and the crack each kick leaves in the door (from its top left).
const SHAKE := 9.0
const DOOR_CRACKS: Array[Array] = [[Vector2(26, 8), Vector2(22, 19), Vector2(29, 27), Vector2(24, 36)],
		[Vector2(24, 36), Vector2(33, 44), Vector2(27, 54), Vector2(35, 63), Vector2(31, 72)], [Vector2(29, 27), Vector2(41, 31), Vector2(48, 25)]]
## The gush: when it starts, a new band of soup every so often, each one's edge growing by e^GROWTH a second
## (so the bands keep their shape as they come at the camera) from a blob this big at the door.
const GUSH_AT := 1.66
const BAND_EVERY := 0.16
const GROWTH := 3.3
const MOUTH_RADIUS := 11.0
## How much a small band sags below the door, and the most its edge wobbles in or out (the wobbles' sum).
const SAG := 1.4
const WOBBLE := 0.205
const EDGE_POINTS := 120
## Things riding each band (bubbles, noodles, peas, carrot coins, pasta stars).
const RIDERS := 4
## The lettering: when the first letter pops up, the gap to the next, its size, and how long a pop takes.
const WORDS: Array[String] = ["DOOR", "BOWL"]
const LETTERS_AT := 2.76
const LETTER_EVERY := 0.085
const LETTER_SIZE := 212
const POP_SECONDS := 0.42
## The drain: when the door runs dry, and how much faster the soup moves while it clears the screen.
const DRAIN_AT := 4.41
const DRAIN_RUSH := 1.9
## Once the soup goes the name shrinks to this size and settles here, to the right, each letter a little after the
## last. The bowl is left over to the left, this much smaller, with BOWL_PIVOT here: there's nothing to see of it
## while the soup has the screen, and the door the soup is coming from drifts there between these seconds of pouring.
const LOCKUP_AT := DRAIN_AT + 0.1
const LOCKUP_SECONDS := 0.6
const LOCKUP_EVERY := 0.015
const LOCKUP_SCALE := 0.72
const LOCKUP := Vector2(892, 352)
const SETTLED_SCALE := 0.76
const SETTLED_AT := Vector2(370, 372)
const MOUTH_MOVES := Vector2(1.35, 2.0)
## Upright (taller than wide), the frame is fitted so UPRIGHT_ROOM of it (around its middle) fills the screen: the
## bowl is kicked at as big as the width allows, and the lockup stands as a column: the bowl left up top, the name
## under it, "a" over the name and "game" under it, as across.
const UPRIGHT_ROOM := Vector2(720, 1280)
const UPRIGHT_SETTLED_AT := Vector2(640, 26)
const UPRIGHT_LOCKUP := Vector2(640, 556)
## The juice left behind: when it starts pulling itself into words, and how long that takes.
const GOO_AT := DRAIN_AT + 0.55
const GOO_SECONDS := 0.95
## The words, "a" over the name and "game" under it: where each starts (the top left of its first letter), and its
## x-height.
const GOO_WORDS: Array[Dictionary] = [{"text": "a", "at": Vector2(668, 110), "height": 64.0},
		{"text": "game", "at": Vector2(754, 530), "height": 64.0}]
## A letter's strokes, in a box an x-height tall (y 0 the top of the x-height, 1 the baseline), and how far along the
## next letter starts.
const GOO_STROKES: Dictionary = {
	"a": [[Vector2(0.94, 0.24), Vector2(0.66, 0.02), Vector2(0.28, 0.08), Vector2(0.04, 0.48), Vector2(0.24, 0.9), Vector2(0.62, 0.98), Vector2(0.92, 0.7)],
			[Vector2(0.95, 0.03), Vector2(0.94, 0.5), Vector2(0.97, 0.88), Vector2(1.14, 1.0)]],
	"g": [[Vector2(0.94, 0.24), Vector2(0.66, 0.02), Vector2(0.28, 0.08), Vector2(0.04, 0.48), Vector2(0.24, 0.9), Vector2(0.62, 0.98), Vector2(0.92, 0.7)],
			[Vector2(0.95, 0.03), Vector2(0.94, 0.7), Vector2(0.92, 1.2), Vector2(0.68, 1.5), Vector2(0.32, 1.52), Vector2(0.08, 1.34)]],
	"m": [[Vector2(0.06, 0.03), Vector2(0.06, 0.5), Vector2(0.06, 1.0)],
			[Vector2(0.06, 0.38), Vector2(0.24, 0.06), Vector2(0.46, 0.04), Vector2(0.62, 0.26), Vector2(0.64, 1.0)],
			[Vector2(0.64, 0.38), Vector2(0.82, 0.06), Vector2(1.04, 0.04), Vector2(1.2, 0.26), Vector2(1.22, 0.76), Vector2(1.34, 1.0)]],
	"e": [[Vector2(0.06, 0.52), Vector2(0.5, 0.5), Vector2(0.94, 0.46), Vector2(0.8, 0.12), Vector2(0.46, 0.0), Vector2(0.12, 0.2),
			Vector2(0.02, 0.56), Vector2(0.18, 0.9), Vector2(0.52, 1.0), Vector2(0.88, 0.84)]],
}
const GOO_ADVANCE: Dictionary = {"a": 1.46, "g": 1.42, "m": 1.76, "e": 1.2}
## Goo's thickness (half across, against the x-height), its ink and how often a stroke is sampled.
const GOO_FATNESS := 0.15
const GOO_INK := 4.5
const GOO_STEP := 3.0
## Drips: [stroke (in the order they're laid), how far along it, how long it gets, how fat, seconds after GOO_AT it
## starts to run].
const GOO_DRIPS: Array[Array] = [[0, 0.72, 18.0, 5.5, 0.62], [1, 0.92, 26.0, 6.0, 0.8], [3, 0.8, 26.0, 5.5, 0.9], [4, 0.74, 52.0, 7.0, 0.58],
		[7, 1.0, 34.0, 6.0, 0.74], [9, 0.84, 40.0, 6.0, 0.68]]
## The beat with everything in place, then the dive through the door: when it starts and how long it takes.
const ZOOM_AT := GOO_AT + GOO_SECONDS + 1.05
const ZOOM_SECONDS := 1.15
## How far inside the doorway's painted edge the title starts.
const DOOR_LINING := 3.0
## Seconds a skip takes to fade the card away.
const SKIP_FADE := 0.28
## Sounds on cue: [seconds in, sound, pitch, volume in dB]. The letters' pops are played as they come up. The creak's
## squeak and knock land on the last kick.
const CUES: Array[Array] = [[KICKS[0], &"studio_kick", 1.08, -8.0], [KICKS[1], &"studio_kick", 1.0, -5.0], [KICKS[1] + 0.13, &"studio_creak", 1.0, -6.0],
		[KICKS[2], &"studio_kick", 0.9, -1.0], [GUSH_AT - 0.05, &"studio_gush", 1.0, -1.0], [DRAIN_AT, &"studio_refill", 0.55, -5.0],
		[GOO_AT, &"studio_goo", 1.0, -3.0], [ZOOM_AT, &"studio_zoom", 1.0, -3.0]]
## The door's see-through part: everything the card draws is cut away inside this arch, where the title shows.
const DOORWAY_CODE := """
shader_type canvas_item;
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform vec2 arch_top = vec2(0.0);
uniform float arch_radius = 1.0;
uniform float arch_foot = 0.0;
uniform float opened = 0.0;
void fragment() {
	vec2 at = SCREEN_UV * screen_size;
	float below = max(abs(at.x - arch_top.x) - arch_radius, max(arch_top.y - at.y, at.y - arch_foot));
	float inside = min(below, distance(at, arch_top) - arch_radius);
	COLOR.a *= mix(1.0, smoothstep(-1.0, 1.0, inside), opened);
}
"""

## Whether it has played since the game was launched.
static var _played: bool = false

var _root: Control
var _time: float = 0.0
var _closing: bool = false
var _told_draining: bool = false
var _font: Font
var _goo: Array[GooStroke] = []
## Whether the goo words were laid out for an upright screen.
var _goo_upright: bool = false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_played = true
	_font = _chunky_font()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.draw.connect(_draw_card)
	var shader := Shader.new()
	shader.code = DOORWAY_CODE
	var doorway := ShaderMaterial.new()
	doorway.shader = shader
	_root.material = doorway
	add_child(_root)
	_lay_goo()


func _process(delta: float) -> void:
	if _closing:
		return
	var before: float = _time
	# A long frame (the game still settling in) doesn't eat the start of it.
	_time += minf(delta, 0.1)
	_play_sounds(before)
	if _time >= ZOOM_AT and not _told_draining:
		_told_draining = true
		draining.emit()
	# Done once the camera's through the door.
	if _time >= ZOOM_AT + ZOOM_SECONDS:
		_closing = true
		finished.emit()
		queue_free()
		return
	_root.queue_redraw()


func _input(event: InputEvent) -> void:
	# Nothing reaches the title underneath until the card is gone.
	get_viewport().set_input_as_handled()
	if _closing:
		return
	var press: bool = event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	if press and event.is_pressed() and not event.is_echo():
		_skip()


## Whether the card should play now: once a launch, never headless (tests and checks), and not when the title
## card underneath is only fading away after a slot switch or a new game.
static func due() -> bool:
	return not _played and DisplayServer.get_name() != "headless"


## Fades the card away early.
func _skip() -> void:
	_closing = true
	if not _told_draining:
		_told_draining = true
		draining.emit()
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, SKIP_FADE)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free())


func _play_sounds(before: float) -> void:
	for cue: Array in CUES:
		var at: float = cue[0]
		var sound: StringName = cue[1]
		var pitch: float = cue[2]
		var volume: float = cue[3]
		if at > before and at <= _time:
			Sfx.play(sound, pitch, volume)
	for i: int in WORDS[0].length() + WORDS[1].length():
		var at: float = LETTERS_AT + i * LETTER_EVERY
		if at > before and at <= _time:
			Sfx.play(&"pop", 0.75 + i * 0.07, -5.0)


## Fredoka at its heaviest, for the lettering.
func _chunky_font() -> Font:
	var path: String = "res://assets/fonts/Fredoka.ttf"
	if not ResourceLoader.exists(path):
		return ThemeDB.fallback_font
	var font := FontVariation.new()
	font.base_font = load(path)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	return font


## The goo words' strokes, ready to draw (upright, moved with the name).
func _lay_goo() -> void:
	_goo.clear()
	_goo_upright = _upright()
	for word: Dictionary in GOO_WORDS:
		var at: Vector2 = (word["at"] as Vector2) + _lockup() - LOCKUP
		var height: float = word["height"]
		var text: String = word["text"]
		for letter: String in text:
			var strokes: Array = GOO_STROKES[letter]
			for knots: Array in strokes:
				var placed: Array[Vector2] = []
				for knot: Vector2 in knots:
					placed.append(at + knot * height)
				_goo.append(GooStroke.new(_smooth(placed), height * GOO_FATNESS, _goo.size()))
			at.x += height * float(GOO_ADVANCE[letter])


## A smooth line through `knots`, a point every GOO_STEP or so.
func _smooth(knots: Array[Vector2]) -> PackedVector2Array:
	var points := PackedVector2Array()
	var last: int = knots.size() - 1
	for i: int in last:
		var from: Vector2 = knots[i]
		var to: Vector2 = knots[i + 1]
		var steps: int = maxi(ceili(from.distance_to(to) / GOO_STEP), 1)
		for step: int in steps:
			points.append(from.cubic_interpolate(to, knots[maxi(i - 1, 0)], knots[mini(i + 2, last)], float(step) / steps))
	points.append(knots[last])
	return points


# --- The soup's clock and shapes -------------------------------------------------------------------------

## Seconds of pouring by time `at`: nothing before the gush, and faster once the door runs dry.
func _flow(at: float) -> float:
	if at <= DRAIN_AT:
		return at - GUSH_AT
	return DRAIN_AT - GUSH_AT + (at - DRAIN_AT) * DRAIN_RUSH


## When the hole behind the last band opens, in seconds of pouring: one band's gap after that band, so the hole's
## edge trails it like one more band would.
func _hole_from() -> float:
	return (floori((DRAIN_AT - GUSH_AT) / BAND_EVERY) + 1) * BAND_EVERY


## How far across a band's edge is, `age` seconds of pouring after it left the door.
func _radius(age: float) -> float:
	return MOUTH_RADIUS * exp(GROWTH * age)


## The whole screen in the frame's coordinates (wider or taller than the frame when the window is).
func _view() -> Rect2:
	var size: Vector2 = _root.size
	var fit: float = _fit()
	return Rect2((FRAME - size / fit) / 2.0, size / fit)


## How big the frame is drawn: the whole 1280x720 frame fitted to the screen, or upright, UPRIGHT_ROOM of it.
func _fit() -> float:
	var size: Vector2 = _root.size
	var room: Vector2 = UPRIGHT_ROOM if _upright() else FRAME
	return minf(size.x / room.x, size.y / room.y)


## Whether the screen stands upright (taller than wide).
func _upright() -> bool:
	return _root != null and _root.size.y > _root.size.x


## Where the bowl is left when the soup has gone, and where the name settles.
func _settled_at() -> Vector2:
	return UPRIGHT_SETTLED_AT if _upright() else SETTLED_AT


func _lockup() -> Vector2:
	return UPRIGHT_LOCKUP if _upright() else LOCKUP


## How far the screen's corners are from its middle.
func _reach(view: Rect2) -> float:
	return (view.size / 2.0).length()


## Whether an edge `radius` across is past every corner of the screen, wobbles and all.
func _covers(radius: float, reach: float) -> bool:
	return radius * (1.0 - WOBBLE) > reach + 20.0


## The middle of band `k`, `radius` across: hanging from the door while it's small, the middle of the screen once
## it's big. The later bands come from where the bowl will be when the soup has gone.
func _center(k: int, radius: float) -> Vector2:
	var settled: Vector2 = _settled_at() + (MOUTH - BOWL_PIVOT) * SETTLED_SCALE
	var mouth: Vector2 = MOUTH.lerp(settled, smoothstep(MOUTH_MOVES.x, MOUTH_MOVES.y, k * BAND_EVERY))
	var hang: Vector2 = mouth + Vector2(0, minf(radius, 110.0) * 0.72)
	return hang.lerp(MIDDLE, smoothstep(110.0, 520.0, radius))


## How far band `k`'s edge is pushed in or out at `angle`: three waves running round it at their own speeds.
func _wobble(k: int, angle: float) -> float:
	return 1.0 + 0.11 * sin(3.0 * angle + k * 1.7 + _time * 2.3) + 0.06 * sin(5.0 * angle - _time * 3.4 + k * 0.9) \
			+ 0.035 * sin(9.0 * angle + _time * 5.1 + k * 2.3)


## Band `k`'s edge, `radius` across: a wobbly blob, sagging under its own weight while it's small.
func _edge(k: int, radius: float) -> PackedVector2Array:
	var center: Vector2 = _center(k, radius)
	var sag: float = lerpf(SAG, 1.0, smoothstep(40.0, 300.0, radius))
	var points := PackedVector2Array()
	points.resize(EDGE_POINTS)
	for i: int in EDGE_POINTS:
		var angle: float = i * TAU / EDGE_POINTS
		var along := Vector2(cos(angle), sin(angle))
		if along.y > 0.0:
			along.y *= sag
		points[i] = center + along * radius * _wobble(k, angle)
	return points


## A steady number from 0 to 1 for `n`.
func _hash(n: int) -> float:
	return fposmod(sin(n * 127.1 + 311.7) * 43758.5453, 1.0)


# --- Drawing ---------------------------------------------------------------------------------------------

func _draw_card() -> void:
	var size: Vector2 = _root.size
	if _goo_upright != _upright():
		_lay_goo()
	var fit: float = _fit()
	var frame := Transform2D(0.0, Vector2(fit, fit), 0.0, (size - FRAME * fit) / 2.0 + _shake() * fit)
	var view: Rect2 = _view()
	var reach: float = _reach(view)
	var flow: float = _flow(_time)
	var hole: bool = flow > _hole_from()
	var shot: Transform2D = frame * _camera(view)
	var stage: Transform2D = shot * _settled() if hole else shot
	var bowl: Transform2D = stage * _bowl_size()
	_open_doorway(bowl)
	_root.draw_set_transform_matrix(frame)
	# Once the soup has the whole screen there's nothing behind it to draw, until the hole it leaves opens up.
	if hole or not _covers(_radius(flow), reach):
		_root.draw_rect(view.grow(SHAKE * 3.0), BACKDROP)
		_root.draw_set_transform_matrix(stage)
		_root.draw_circle(Vector2(640, 372), 318.0, SPOT)
		_root.draw_circle(Vector2(640, 372), 232.0, SPOT_CORE)
		_draw_bowl(bowl)
		_draw_goo(shot)
		_root.draw_set_transform_matrix(frame)
	if flow > 0.0 and not (hole and _covers(_radius(flow - _hole_from()), reach)):
		_draw_soup(view, reach, flow)
	_draw_letters(shot)
	_root.draw_set_transform_matrix(frame)
	if _time < FADE_IN:
		_root.draw_rect(view, Color(0, 0, 0, 1.0 - _time / FADE_IN))
	_root.draw_set_transform_matrix(Transform2D.IDENTITY)


## Upright, where the bowl and the name are on screen, for the layout tests: the bowl while it's kicked at, the name
## once it's up in the soup, both once they've settled; nothing while the camera dives through the door.
func portrait_rects() -> Dictionary:
	if _time >= ZOOM_AT:
		return {"info": {}, "diving": true}
	var size: Vector2 = _root.size
	var fit: float = _fit()
	var frame := Transform2D(0.0, Vector2(fit, fit), 0.0, (size - FRAME * fit) / 2.0)
	var flow: float = _flow(_time)
	var hole: bool = flow > _hole_from()
	var info: Dictionary = {}
	if hole or not _covers(_radius(flow), _reach(_view())):
		var bowl_box := Rect2(RIM.x - RIM_RADII.x, RIM.y - RIM_RADII.y, RIM_RADII.x * 2.0, FOOT.y - RIM.y + RIM_RADII.y)
		info["bowl"] = (frame * (_settled() if hole else Transform2D.IDENTITY) * _bowl_size()) * bowl_box
	if _time >= LETTERS_AT + POP_SECONDS:
		var block: float = 0.0
		for word: String in WORDS:
			block = maxf(block, _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE).x)
		var settled: bool = _time >= LOCKUP_AT + LOCKUP_SECONDS + LOCKUP_EVERY * 8.0
		var scale: float = LOCKUP_SCALE if settled else 1.0
		var middle: Vector2 = _lockup() if settled else MIDDLE
		info["name"] = frame * Rect2(middle - Vector2(block * 0.52, LETTER_SIZE * 0.82) * scale, Vector2(block * 1.04, LETTER_SIZE * 1.64) * scale)
	return {"info": info}


## The whole picture jumping at each kick.
func _shake() -> Vector2:
	var shake := Vector2.ZERO
	for i: int in KICKS.size():
		var since: float = _time - KICKS[i]
		if since >= 0.0 and since < 0.5:
			var fade: float = exp(-since * 11.0) * KICK_POWER[i] * KICK_POWER[i] * SHAKE
			shake += Vector2(sin(since * 67.0), cos(since * 83.0)) * fade
	return shake


## The bowl's wobble: breathing a little, jolting and hopping at each kick from inside, shuddering while the soup
## pours out, and holding still for the camera at the end.
func _bowl_transform() -> Transform2D:
	var squash: float = 0.012 * sin(_time * 5.0) * (1.0 - smoothstep(ZOOM_AT - 0.45, ZOOM_AT - 0.05, _time))
	var tilt: float = 0.0
	var hop: float = 0.0
	for i: int in KICKS.size():
		var since: float = _time - KICKS[i]
		if since >= 0.0:
			var ring: float = exp(-since * 8.0) * sin(since * 38.0)
			squash += 0.085 * KICK_POWER[i] * ring
			tilt += 0.05 * KICK_POWER[i] * ring * (1.0 if i % 2 == 0 else -1.0)
			hop += 16.0 * KICK_POWER[i] * maxf(sin(minf(since / 0.2, 1.0) * PI), 0.0)
	var shudder: float = clampf((_time - KICKS[2]) / 0.3, 0.0, 1.0) * (1.0 - smoothstep(DRAIN_AT - 0.4, DRAIN_AT, _time))
	tilt += 0.024 * shudder * sin(_time * 31.0)
	squash += 0.03 * shudder * sin(_time * 23.0)
	return Transform2D.IDENTITY.translated(-FOOT).scaled(Vector2(1.0 + squash, 1.0 - squash)).rotated(tilt).translated(FOOT + Vector2(0, -hop))


## How far open the door is, in radians: the second kick springs it ajar, where it rattles, and the last flings it
## wide, past where it should stop, and it judders back.
func _door_angle() -> float:
	var flung: float = (_time - KICKS[2]) / OPEN_SECONDS
	if flung >= 0.0:
		return deg_to_rad(AJAR + (128.0 - AJAR) * (1.0 - exp(-flung * 5.0) * cos(flung * 9.0)))
	var sprung: float = _time - KICKS[1]
	if sprung <= 0.0:
		return 0.0
	return deg_to_rad(AJAR * (1.0 - exp(-sprung * 16.0)) + 3.5 * sin(sprung * 46.0) * exp(-sprung * 3.0))


## The newest kick at the door, from its power (just now) down to 0.
func _thump() -> float:
	var thump: float = 0.0
	for i: int in KICKS.size():
		if _time >= KICKS[i]:
			thump = maxf(thump, KICK_POWER[i] * (1.0 - (_time - KICKS[i]) / 0.2))
	return thump


## The bowl's own size, about its pivot.
func _bowl_size() -> Transform2D:
	return Transform2D.IDENTITY.translated(-BOWL_PIVOT).scaled(Vector2.ONE * BOWL_SCALE).translated(BOWL_PIVOT)


## Where the bowl and its spot are left when the soup has gone.
func _settled() -> Transform2D:
	return Transform2D.IDENTITY.translated(-BOWL_PIVOT).scaled(Vector2.ONE * SETTLED_SCALE).translated(_settled_at())


## The camera for the last move: nothing until the zoom, then a little lean back and a dive that keeps speeding up,
## the door sliding to the middle of the screen on the way.
func _camera(view: Rect2) -> Transform2D:
	var u: float = clampf((_time - ZOOM_AT) / ZOOM_SECONDS, 0.0, 1.0)
	if u <= 0.0:
		return Transform2D.IDENTITY
	# Far enough that the doorway has the whole screen, corners and all.
	var doorway: Rect2 = DOOR_RECT.grow(-DOOR_LINING)
	var end: float = maxf(view.size.x / doorway.size.x, view.size.y / (doorway.size.y - doorway.size.x / 2.0)) * 1.15 / (BOWL_SCALE * SETTLED_SCALE)
	var zoom: float = exp(log(end) * pow(u, 2.3)) * (1.0 - 0.05 * sin(minf(u / 0.35, 1.0) * PI))
	var door: Vector2 = _settled() * _bowl_size() * DOOR_RECT.get_center()
	var at: Vector2 = door.lerp(view.get_center(), smoothstep(0.0, 0.6, u))
	return Transform2D.IDENTITY.translated(-door).scaled(Vector2.ONE * zoom).translated(at)


## Tells the card's shader where the doorway is on screen, and how far the title has come up in it.
func _open_doorway(bowl: Transform2D) -> void:
	var doorway: ShaderMaterial = _root.material
	var opened: float = smoothstep(ZOOM_AT + 0.15, ZOOM_AT + 0.6, _time)
	doorway.set_shader_parameter(&"opened", opened)
	if opened <= 0.0:
		return
	var box: Rect2 = DOOR_RECT.grow(-DOOR_LINING)
	var radius: float = box.size.x / 2.0
	doorway.set_shader_parameter(&"screen_size", _root.size)
	doorway.set_shader_parameter(&"arch_top", bowl * Vector2(box.get_center().x, box.position.y + radius))
	doorway.set_shader_parameter(&"arch_radius", radius * bowl.get_scale().x)
	doorway.set_shader_parameter(&"arch_foot", (bowl * box.end).y)


func _draw_bowl(frame: Transform2D) -> void:
	# Its shadow stays put while it wobbles.
	_root.draw_set_transform_matrix(frame)
	_root.draw_colored_polygon(_ellipse(FOOT + Vector2(0, 8), 250, 22), Color(0.045, 0.03, 0.07))
	_root.draw_set_transform_matrix(frame * _bowl_transform())
	# The foot it stands on.
	var foot := PackedVector2Array([RIM + Vector2(-80, 150), RIM + Vector2(80, 150), RIM + Vector2(66, 188), RIM + Vector2(-66, 188)])
	_outlined(foot, CERAMIC_SHADE, 7.0)
	# The body: the lower half of an ellipse hanging from the rim.
	var body := PackedVector2Array()
	for i: int in 41:
		var angle: float = PI * i / 40.0
		body.append(RIM + Vector2(cos(angle) * RIM_RADII.x, sin(angle) * DEPTH))
	_root.draw_colored_polygon(body, CERAMIC)
	# A flat shade down its right side, a shine on its left, and two bands of blue glaze under the rim.
	var shade := PackedVector2Array()
	for i: int in 13:
		var angle: float = PI * (0.02 + 0.44 * i / 12.0)
		shade.append(RIM + Vector2(cos(angle) * RIM_RADII.x, sin(angle) * DEPTH))
	for i: int in 13:
		var angle: float = PI * (0.46 - 0.44 * i / 12.0)
		shade.append(RIM + Vector2(cos(angle) * 160.0, sin(angle) * 150.0))
	_root.draw_colored_polygon(shade, CERAMIC_SHADE)
	_root.draw_polyline(_arc(RIM + Vector2(0, 10), Vector2(207, 44), 0.07, 0.93), GLAZE, 10.0, true)
	_root.draw_polyline(_arc(RIM + Vector2(0, 26), Vector2(199, 42), 0.1, 0.9), GLAZE, 4.0, true)
	var shine: PackedVector2Array = _arc(RIM, Vector2(186, 146), 0.74, 0.9)
	_root.draw_polyline(shine, Color.WHITE, 9.0, true)
	_root.draw_circle(shine[0], 4.5, Color.WHITE)
	_root.draw_circle(shine[shine.size() - 1], 4.5, Color.WHITE)
	_root.draw_polyline(_boil(body, 1, false), INK, 7.0, true)
	# The rim, the far wall inside it, and the soup waiting in there.
	var rim: PackedVector2Array = _arc(RIM, RIM_RADII, 0.0, 2.0, 48)
	_root.draw_colored_polygon(rim, CERAMIC)
	var inside: PackedVector2Array = _arc(RIM + Vector2(0, 3), Vector2(190, 30), 0.0, 2.0, 40)
	_root.draw_colored_polygon(inside, CERAMIC_SHADE)
	_root.draw_polyline(inside, INK, 5.0, true)
	var surface: PackedVector2Array = _arc(RIM + Vector2(0, 9), Vector2(176, 21), 0.0, 2.0, 40)
	_root.draw_colored_polygon(surface, SOUP[0])
	_root.draw_polyline(surface, INK, 5.0, true)
	for i: int in 4:
		var blip: float = fposmod(_time * 1.3 + i * 0.37, 1.0)
		var at: Vector2 = RIM + Vector2(-110 + i * 72 + sin(i * 4.0) * 14.0, 9 + sin(i * 2.3) * 7.0)
		_root.draw_arc(at, 3.0 + blip * 7.0, 0.0, TAU, 16, Color(1, 1, 1, 1.0 - blip), 2.5, true)
	_root.draw_polyline(_boil(rim, 2, true), INK, 7.0, true)
	# Steam off the top, in three lazy curls.
	for i: int in 3:
		var curl := PackedVector2Array()
		var rise: float = fposmod(_time * 0.5 + i * 0.33, 1.0)
		for step: int in 9:
			var up: float = step / 8.0
			curl.append(RIM + Vector2(-70 + i * 70 + sin(up * 5.0 + _time * 2.0 + i * 2.0) * 13.0, -50 - rise * 26.0 - up * 62.0))
		_root.draw_polyline(curl, Color(0.8, 0.72, 0.95, 0.5 * sin(rise * PI)), 6.0, true)
	_draw_door()


## The tiny door: a doorstep, the frame, the dark doorway, and the leaf swinging open on its left-hand hinges.
func _draw_door() -> void:
	var step := Rect2(DOOR_RECT.position.x - 13, DOOR_RECT.end.y + 3, DOOR_RECT.size.x + 26, 9)
	_root.draw_rect(step.grow(3.5), INK)
	_root.draw_rect(step, CERAMIC_SHADE)
	_root.draw_colored_polygon(_arch(DOOR_RECT, 10.0), INK)
	_root.draw_colored_polygon(_arch(DOOR_RECT, 6.0), DOOR_FRAME)
	_root.draw_colored_polygon(_arch(DOOR_RECT, 1.5), INK)
	# Once it's sprung, the soup's right there behind the gap.
	_root.draw_colored_polygon(_arch(DOOR_RECT, -1.5), DOORWAY.lerp(JUICE[0].darkened(0.2), smoothstep(KICKS[1], KICKS[1] + 0.3, _time)
			* (1.0 - smoothstep(GUSH_AT, DRAIN_AT, _time))))
	var angle: float = _door_angle()
	var thump: float = _thump()
	# The leaf, turned on its hinges. A thump from inside bulges it.
	var bulge: float = 1.0 + 0.17 * thump
	var leaf := PackedVector2Array()
	for point: Vector2 in _arch(DOOR_RECT, -2.5):
		leaf.append(_swung(point, angle, bulge))
	var front: bool = cos(angle) > 0.0
	if absf(cos(angle)) > 0.04:
		_root.draw_colored_polygon(leaf, DOOR if front else DOOR_BACK)
		# Two panels on the front of it, and the knob.
		if front:
			for panel: Rect2 in [Rect2(DOOR_RECT.position + Vector2(11, 24), Vector2(32, 16)), Rect2(DOOR_RECT.position + Vector2(11, 46), Vector2(32, 20))]:
				var corners := PackedVector2Array([_swung(panel.position, angle, bulge), _swung(Vector2(panel.end.x, panel.position.y), angle, bulge),
						_swung(panel.end, angle, bulge), _swung(Vector2(panel.position.x, panel.end.y), angle, bulge)])
				_root.draw_colored_polygon(corners, DOOR_BACK)
		var knob: Vector2 = _swung(Vector2(DOOR_RECT.end.x - 9.0, DOOR_RECT.get_center().y + 8.0), angle, bulge)
		knob.x += sin(_time * 70.0) * 2.0 * thump
		_root.draw_circle(knob, 6.0, INK)
		_root.draw_circle(knob, 3.6, KNOB)
		_draw_door_damage(angle, bulge, thump)
	leaf.append(leaf[0])
	_root.draw_polyline(leaf, INK, 4.0, true)
	# Each kick: startled ticks around the door, longer the harder it lands, and what it shakes loose.
	if thump > 0.0:
		for i: int in 5:
			var out := Vector2.from_angle(-PI * (0.08 + 0.21 * i))
			var from: Vector2 = Vector2(DOOR_RECT.get_center().x, DOOR_RECT.position.y + 30.0) + out * (50.0 + (1.0 - thump) * 10.0)
			_root.draw_line(from, from + out * 18.0 * maxf(thump, 0.6), INK, 5.0, true)
	_draw_kicked_loose()
	if _time >= DRAIN_AT:
		var spill := PackedVector2Array()
		var fat := PackedFloat32Array()
		for i: int in 13:
			var share: float = i / 12.0
			spill.append(Vector2(DOOR_RECT.position.x + 2.0 + 50.0 * share, DOOR_RECT.end.y + 6.0 + sin(share * 6.0) * 1.2))
			fat.append(4.0 + 1.5 * sin(share * PI + _time))
		var since: float = _time - GOO_AT
		var ribbons: Array[Array] = [[spill, fat]]
		for trickle: Array in [[Vector2(DOOR_RECT.position.x + 12.0, DOOR_RECT.end.y + 8.0), 28.0, 0.5], [Vector2(DOOR_RECT.end.x - 14.0, DOOR_RECT.end.y + 8.0), 46.0, 0.8]]:
			var run: float = maxf(since - float(trickle[2]), 0.0)
			ribbons.append(_drip(trickle[0], maxf(float(trickle[1]) * (1.0 - exp(-run * 1.2)), 2.0), 4.5))
		_pour(ribbons)


## The door taking a beating: the toe of the boot pushing a dome out of it for a moment, and the cracks each kick
## leaves behind.
func _draw_door_damage(angle: float, bulge: float, thump: float) -> void:
	for crack: int in DOOR_CRACKS.size():
		if _time >= KICKS[crack]:
			var line := PackedVector2Array()
			for point: Vector2 in DOOR_CRACKS[crack]:
				line.append(_swung(DOOR_RECT.position + point, angle, bulge))
			_root.draw_polyline(line, INK, 3.0, true)
	if thump > 0.0 and angle < 0.5:
		var toe: Vector2 = _swung(DOOR_RECT.position + Vector2(25, 40), angle, bulge)
		var dome: PackedVector2Array = _ellipse(toe, 15.0 * minf(thump, 1.0) + 3.0, 12.0 * minf(thump, 1.0) + 3.0)
		_outlined(dome, DOOR.lightened(0.28), 3.0)


## What the kicks shake loose: dust off the door's frame, chips, and soup slopped out of the top of the bowl, up and
## back down.
func _draw_kicked_loose() -> void:
	for kick: int in KICKS.size():
		var since: float = _time - KICKS[kick]
		if since < 0.0 or since > 0.8:
			continue
		var power: float = KICK_POWER[kick]
		for i: int in int(4.0 * power) + 2:
			var pick: int = kick * 53 + i * 11
			var fall := Vector2(0, 640.0 * since * since)
			var out := Vector2.from_angle(-PI * lerpf(0.12, 0.88, _hash(pick)))
			var edge: Vector2 = DOOR_RECT.get_center() + Vector2(out.x * 36.0, out.y * 48.0)
			var dust: float = clampf(since / 0.4, 0.0, 1.0)
			if dust < 1.0:
				_root.draw_circle(edge + out * 26.0 * dust, 4.0 + 9.0 * dust * power, Color(CERAMIC, 0.5 * (1.0 - dust)))
			var chip: Vector2 = edge + out * (lerpf(150.0, 340.0, _hash(pick + 1)) * power * since) + fall
			var turn: float = since * 14.0 + pick
			var sides := PackedVector2Array([chip + Vector2.from_angle(turn) * 4.5, chip + Vector2.from_angle(turn + 2.2) * 3.5,
					chip + Vector2.from_angle(turn + 4.1) * 4.5])
			_outlined(sides, DOOR_FRAME if i % 2 == 0 else CERAMIC, 1.5)
			var slop: Vector2 = RIM + Vector2(lerpf(-150.0, 150.0, _hash(pick + 2)), 4.0 + lerpf(-250.0, -430.0, _hash(pick + 3)) * power * since) + fall
			if slop.y < RIM.y + 12.0:
				_root.draw_circle(slop, 6.5, INK)
				_root.draw_circle(slop, 4.0, SOUP[0].lightened(0.25))


## A point on the door's leaf once it has swung `angle` open on its left-hand hinges: the leaf gets narrower as
## it turns, and a little taller at its free edge as that comes toward the camera.
func _swung(point: Vector2, angle: float, bulge: float) -> Vector2:
	var middle: float = DOOR_RECT.get_center().y
	var across: float = (point.x - DOOR_RECT.position.x) / DOOR_RECT.size.x
	var swing: float = sin(angle) * across
	return Vector2(DOOR_RECT.position.x + cos(angle) * DOOR_RECT.size.x * across * bulge,
			middle + (point.y - middle) * (1.0 + 0.22 * swing) * bulge + 5.0 * swing)


## The soup: every band's edge, oldest (and biggest) first, each drawn over the last; while it drains, rings
## around the hole it leaves, with the title showing through.
func _draw_soup(view: Rect2, reach: float, flow: float) -> void:
	var hole: bool = flow > _hole_from()
	var newest: int = floori(minf(flow, DRAIN_AT - GUSH_AT) / BAND_EVERY)
	# Each edge's radius, oldest first; the hole's edge goes last.
	var radii: Array[float] = []
	for k: int in newest + 1:
		radii.append(_radius(flow - k * BAND_EVERY))
	if hole:
		radii.append(_radius(flow - _hole_from()))
	# Nothing older than the newest edge that's past the whole screen can be seen.
	var first: int = 0
	for k: int in radii.size():
		if _covers(radii[k], reach):
			first = k
	var edges: Array[PackedVector2Array] = []
	for k: int in range(first, radii.size()):
		edges.append(_edge(k, radii[k]))
	for k: int in range(first, newest + 1):
		var radius: float = radii[k]
		var edge: PackedVector2Array = edges[k - first]
		var color: Color = SOUP[k % SOUP.size()]
		var width: float = clampf(radius * 0.035, 5.0, 15.0)
		var whole: bool = _covers(radius, reach)
		if k + 1 < radii.size() and hole:
			if _covers(radii[k + 1], reach):
				continue
			_ring(edge, edges[k + 1 - first], color)
		elif whole:
			_root.draw_rect(view, color)
		else:
			_root.draw_colored_polygon(edge, color)
		if not whole:
			_draw_edge(edge, _center(k, radius), color, width)
		_draw_riders(k, radius, width)
	if hole:
		var rim: PackedVector2Array = edges[edges.size() - 1]
		rim.append(rim[0])
		_root.draw_polyline(rim, INK, clampf(radii[radii.size() - 1] * 0.035, 5.0, 15.0), true)


## A band's inked edge, with a lighter crest running just inside it.
func _draw_edge(edge: PackedVector2Array, center: Vector2, color: Color, width: float) -> void:
	var crest := PackedVector2Array()
	for point: Vector2 in edge:
		crest.append(center + (point - center) * 0.92)
	crest.append(crest[0])
	_root.draw_polyline(crest, color.lightened(0.42), width * 0.75, true)
	var line: PackedVector2Array = edge.duplicate()
	line.append(line[0])
	_root.draw_polyline(line, INK, width, true)


## The soup between two edges (the same number of points on each), as one strip of triangles.
func _ring(outer: PackedVector2Array, inner: PackedVector2Array, color: Color) -> void:
	var count: int = outer.size()
	var points := PackedVector2Array()
	var indices := PackedInt32Array()
	for i: int in count:
		points.append(outer[i])
		points.append(inner[i])
		var next: int = (i + 1) % count
		indices.append_array(PackedInt32Array([2 * i, 2 * i + 1, 2 * next, 2 * i + 1, 2 * next + 1, 2 * next]))
	RenderingServer.canvas_item_add_triangle_array(_root.get_canvas_item(), indices, points, PackedColorArray([color]))


## What's riding band `k`: bubbles, wriggling noodles, peas, carrot coins and pasta stars, bigger as the band
## comes at the camera. The first band also flings a few drops out ahead of itself.
func _draw_riders(k: int, radius: float, width: float) -> void:
	if radius < 30.0:
		return
	var center: Vector2 = _center(k, radius)
	var color: Color = SOUP[k % SOUP.size()]
	for j: int in RIDERS + (3 if k == 0 else 0):
		var pick: int = k * 31 + j * 7
		var angle: float = _hash(pick) * TAU + _time * 0.3 * (1.0 if j % 2 == 0 else -1.0)
		var along := Vector2(cos(angle), sin(angle))
		var size: float = radius * lerpf(0.045, 0.08, _hash(pick + 2))
		if j >= RIDERS:
			# A drop out in front.
			var drop: Vector2 = center + along * radius * _wobble(k, angle) * lerpf(1.12, 1.34, _hash(pick + 1))
			_root.draw_circle(drop, size * 0.8 + width * 0.5, INK)
			_root.draw_circle(drop, size * 0.8, color)
			continue
		var at: Vector2 = center + along * radius * _wobble(k, angle) * lerpf(0.7, 0.86, _hash(pick + 1))
		match int(_hash(pick + 3) * 5.0):
			0:
				_root.draw_circle(at, size + width * 0.5, INK)
				_root.draw_circle(at, size, color.lightened(0.5))
				_root.draw_circle(at + Vector2(-0.34, -0.34) * size, size * 0.3, Color.WHITE)
			1:
				var noodle := PackedVector2Array()
				var across: Vector2 = along.orthogonal()
				for step: int in 25:
					var share: float = step / 24.0 - 0.5
					noodle.append(at + across * share * size * 4.4 + along * sin(share * 9.0 + _time * 7.0 + pick) * size * 0.55)
				for end: Vector2 in [noodle[0], noodle[24]]:
					_root.draw_circle(end, size * 0.3 + width * 0.5, INK)
				_root.draw_polyline(noodle, INK, size * 0.6 + width, true)
				_root.draw_polyline(noodle, PASTA, size * 0.6, true)
				for end: Vector2 in [noodle[0], noodle[24]]:
					_root.draw_circle(end, size * 0.3, PASTA)
			2:
				_root.draw_circle(at, size * 0.8 + width * 0.5, INK)
				_root.draw_circle(at, size * 0.8, PEA)
				_root.draw_circle(at + Vector2(-0.3, -0.3) * size, size * 0.2, PEA.lightened(0.6))
			3:
				_root.draw_circle(at, size + width * 0.5, INK)
				_root.draw_circle(at, size, CARROT if color != SOUP[4] else PEA)
				_root.draw_arc(at, size * 0.55, 0.0, TAU, 20, Color(1, 1, 1, 0.55), size * 0.16, true)
			_:
				_draw_star(at, size * 1.25, _time * 1.5 + pick, width)


## A pasta star, inked.
func _draw_star(at: Vector2, size: float, spin: float, width: float) -> void:
	var ink := PackedVector2Array()
	var star := PackedVector2Array()
	for i: int in 10:
		var out := Vector2.from_angle(spin + i * TAU / 10.0)
		var far: float = 1.0 if i % 2 == 0 else 0.52
		ink.append(at + out * (size * far + width * 0.7))
		star.append(at + out * size * far)
	_root.draw_colored_polygon(ink, INK)
	_root.draw_colored_polygon(star, PASTA)


## DOOR over BOWL, a letter at a time: each pops up past its size and settles, bobbing and tilting in the soup.
## When the soup goes they drop smaller and over to the right of the bowl, and sit still.
func _draw_letters(shot: Transform2D) -> void:
	if _time < LETTERS_AT:
		return
	var cap: float = LETTER_SIZE * 0.7
	# Both words are spread to the same width, so they stack as a block.
	var widths: Array[float] = []
	var block: float = 0.0
	for word: String in WORDS:
		var total: float = 0.0
		for i: int in word.length():
			var width: float = _font.get_string_size(word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE).x
			widths.append(width)
			total += width
		block = maxf(block, total)
	block *= 1.03
	var index: int = 0
	for line: int in WORDS.size():
		var word: String = WORDS[line]
		var total: float = 0.0
		for i: int in word.length():
			total += widths[index + i]
		var gap: float = (block - total) / (word.length() - 1)
		var x: float = MIDDLE.x - block / 2.0
		for i: int in word.length():
			var width: float = widths[index]
			var home := Vector2(x + width / 2.0, MIDDLE.y + (line - 0.5) * LETTER_SIZE * 0.93)
			var since: float = _time - LETTERS_AT - index * LETTER_EVERY
			x += width + gap
			index += 1
			if since <= 0.0:
				continue
			var landed: float = clampf(since / POP_SECONDS, 0.0, 1.0)
			var settled: float = _spring((_time - LOCKUP_AT - index * LOCKUP_EVERY) / LOCKUP_SECONDS)
			var afloat: float = 1.0 - clampf(settled, 0.0, 1.0)
			var at: Vector2 = home.lerp(_lockup() + (home - MIDDLE) * LOCKUP_SCALE, settled) + Vector2(0, sin(_time * 5.5 + index * 1.1) * 7.0 * afloat)
			var tilt: float = sin(_time * 4.2 + index * 1.9) * 0.06 * afloat + (1.0 - landed) * 0.5 * (1.0 if index % 2 == 0 else -1.0)
			_root.draw_set_transform_matrix(shot * Transform2D(tilt, Vector2.ONE * _pop(landed) * lerpf(1.0, LOCKUP_SCALE, settled), 0.0, at))
			var corner := Vector2(-width / 2.0, cap / 2.0)
			var outline: int = int(LETTER_SIZE * 0.13)
			_root.draw_string_outline(_font, corner + Vector2(9, 12), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE, outline, INK)
			_root.draw_string_outline(_font, corner, word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE, outline, INK)
			_root.draw_string(_font, corner, word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE, LETTER)


## A pop: from nothing, past full size, and back (`u` from 0 to 1).
func _pop(u: float) -> float:
	return 1.0 + 3.4 * pow(u - 1.0, 3.0) + 2.4 * pow(u - 1.0, 2.0)


## A springy arrival: 0 before `u` is 0, past 1 and back, and 1 from `u` 1 on.
func _spring(u: float) -> float:
	if u <= 0.0:
		return 0.0
	if u >= 1.0:
		return 1.0
	return 1.0 - exp(-u * 6.0) * cos(u * 11.0) * (1.0 - u)


# --- The goo ---------------------------------------------------------------------------------------------

## What's left of the juice: every stroke of the two words, smeared out the way the soup went and pulling itself in
## with a jelly wobble, then a few drips running off them. All the ink goes down first, so strokes that touch run
## together.
func _draw_goo(shot: Transform2D) -> void:
	if _time < DRAIN_AT:
		return
	_root.draw_set_transform_matrix(shot)
	var since: float = _time - GOO_AT
	var ribbons: Array[Array] = []
	for stroke: GooStroke in _goo:
		ribbons.append(stroke.shaped(_spring((since - stroke.index * 0.03) / GOO_SECONDS), _time))
	for drip: Array in GOO_DRIPS:
		var stroke: int = drip[0]
		var run: float = since - float(drip[4])
		if run > 0.0:
			var line: PackedVector2Array = ribbons[stroke][0]
			var at: Vector2 = line[int(float(drip[1]) * (line.size() - 1))]
			ribbons.append(_drip(at, float(drip[2]) * (1.0 - exp(-run * 1.5)), drip[3]))
	_pour(ribbons)


## Goo along each of `ribbons` ([points, widths]): all the ink first, so ribbons that touch run together.
func _pour(ribbons: Array[Array]) -> void:
	for ribbon: Array in ribbons:
		var points: PackedVector2Array = ribbon[0]
		var widths: PackedFloat32Array = ribbon[1]
		var inked := PackedFloat32Array()
		for width: float in widths:
			inked.append(width + GOO_INK)
		_ribbon(points, inked, INK)
	var salt: int = 0
	for ribbon: Array in ribbons:
		var points: PackedVector2Array = ribbon[0]
		var widths: PackedFloat32Array = ribbon[1]
		_ribbon(points, widths)
		_shine(points, widths, salt)
		salt += 1


## The juice's color at `at`: a marbled field of its bands, slowly turning over, so color runs across strokes like oil.
func _juice(at: Vector2) -> Color:
	var swirl: float = sin(at.x * 0.019 + _time * 0.9) + 0.8 * sin(at.y * 0.043 - _time * 1.2 + sin(at.x * 0.012) * 2.0) \
			+ 0.7 * sin((at.x + at.y) * 0.014 + _time * 0.6)
	var place: float = fposmod(swirl * 1.7, JUICE.size())
	var band: int = floori(place)
	return JUICE[band].lerp(JUICE[(band + 1) % JUICE.size()], smoothstep(0.28, 0.72, place - band))


## A drip from `at`: a neck, thinning, with a fat bead at its end.
func _drip(at: Vector2, length: float, fat: float) -> Array:
	var points := PackedVector2Array()
	var widths := PackedFloat32Array()
	var steps: int = maxi(ceili(length / GOO_STEP), 2)
	for i: int in steps + 1:
		var share: float = float(i) / steps
		points.append(at + Vector2(sin(share * 2.0 + at.x) * 1.5, length * share))
		var neck: float = lerpf(fat, fat * 0.42, smoothstep(0.0, 0.5, share))
		widths.append(lerpf(neck, fat, smoothstep(0.62, 1.0, share)))
	return [points, widths]


## A strip of goo along `points`, `widths` from its middle to each side, with round ends: all in `ink`, or juice-colored
## if that's left clear. A thin smoothed line down each side softens its edge.
func _ribbon(points: PackedVector2Array, widths: PackedFloat32Array, ink: Color = Color.TRANSPARENT) -> void:
	var count: int = points.size()
	var juicy: bool = ink.a == 0.0
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var left_tint := PackedColorArray()
	var right_tint := PackedColorArray()
	var strip := PackedVector2Array()
	var tints := PackedColorArray()
	var indices := PackedInt32Array()
	for i: int in count:
		var across: Vector2 = (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized().orthogonal() * widths[i]
		left.append(points[i] + across)
		right.append(points[i] - across)
		left_tint.append(_juice(left[i]) if juicy else ink)
		right_tint.append(_juice(right[i]) if juicy else ink)
		strip.append(left[i])
		strip.append(right[i])
		tints.append(left_tint[i])
		tints.append(right_tint[i])
		if i + 1 < count:
			indices.append_array(PackedInt32Array([2 * i, 2 * i + 1, 2 * i + 2, 2 * i + 1, 2 * i + 3, 2 * i + 2]))
	RenderingServer.canvas_item_add_triangle_array(_root.get_canvas_item(), indices, strip, tints)
	for end: int in [0, count - 1]:
		_root.draw_circle(points[end], widths[end], _juice(points[end]) if juicy else ink, true, -1.0, true)
	_root.draw_polyline_colors(left, left_tint, 1.5, true)
	_root.draw_polyline_colors(right, right_tint, 1.5, true)


## Wet light on a stroke: a short highlight toward its top left, not all the way along.
func _shine(points: PackedVector2Array, widths: PackedFloat32Array, salt: int) -> void:
	var count: int = points.size()
	if count < 12:
		return
	var from: int = int(_hash(salt + 5) * count * 0.5)
	var to: int = mini(from + int(count * 0.28) + 4, count)
	var line := PackedVector2Array()
	for i: int in range(from, to):
		line.append(points[i] + Vector2(-0.34, -0.34) * widths[i])
	_root.draw_polyline(line, Color(1, 1, 1, 0.55), maxf(widths[from] * 0.26, 1.5), true)
	_root.draw_circle(points[mini(to + 3, count - 1)] + Vector2(-0.34, -0.34) * widths[from], widths[from] * 0.16, Color(1, 1, 1, 0.6), true, -1.0, true)


# --- Shapes ----------------------------------------------------------------------------------------------

## A filled shape with an ink outline `width` thick.
func _outlined(points: PackedVector2Array, color: Color, width: float) -> void:
	_root.draw_colored_polygon(points, color)
	var line: PackedVector2Array = points.duplicate()
	line.append(line[0])
	_root.draw_polyline(line, INK, width, true)


## Points along an ellipse from `from` to `to`, in half turns (0 is the right-hand end, 0.5 the bottom).
func _arc(center: Vector2, radii: Vector2, from: float, to: float, steps: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in steps + 1:
		var angle: float = PI * lerpf(from, to, float(i) / steps)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


## A doorway: `rect`, grown by `grow`, with a round top.
func _arch(rect: Rect2, grow: float) -> PackedVector2Array:
	var box: Rect2 = rect.grow(grow)
	var radius: float = box.size.x / 2.0
	var middle := Vector2(box.get_center().x, box.position.y + radius)
	var points := PackedVector2Array([Vector2(box.position.x, box.end.y), box.end])
	for i: int in 37:
		points.append(middle + Vector2.from_angle(-PI * i / 36.0) * radius)
	return points


## A line redrawn a little differently twelve times a second, as if inked by hand (`closed` joins its ends up).
func _boil(points: PackedVector2Array, salt: int, closed: bool) -> PackedVector2Array:
	var tick: int = int(_time * 12.0) * 97 + salt * 1013
	var line := PackedVector2Array()
	for i: int in points.size():
		line.append(points[i] + Vector2(_hash(tick + i * 2) - 0.5, _hash(tick + i * 2 + 1) - 0.5) * 2.4)
	if closed:
		line.append(line[0])
	return line


## An ellipse's outline (20 points), for the bowl's shadow and the door's dents.
static func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in 20:
		var angle: float = TAU * i / 20.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


## One stroke of a goo word: where its line rests, and where the sweep left it smeared.
class GooStroke:
	## How far out the sweep drags a stroke, at most, and how fat it is while smeared (against its fatness at rest).
	const SMEAR := 120.0
	const SMEAR_FAT := 1.9

	var index: int = 0
	var _rest := PackedVector2Array()
	var _smeared := PackedVector2Array()
	var _fat: float = 0.0

	func _init(points: PackedVector2Array, fat: float, number: int) -> void:
		index = number
		_rest = points
		_fat = fat
		var count: int = points.size()
		for i: int in count:
			var away: Vector2 = (points[i] - MIDDLE).normalized()
			var drag: float = 0.55 + 0.45 * sin(float(i) / count * 5.0 + number * 2.1)
			_smeared.append(points[i] + away * drag * SMEAR)

	## The stroke `pull` of the way from smeared to at rest (past 1 while it overshoots), wobbling at time `time`:
	## its points and widths.
	func shaped(pull: float, time: float) -> Array:
		var points := PackedVector2Array()
		var widths := PackedFloat32Array()
		var count: int = _rest.size()
		var loose: float = clampf(1.0 - pull, 0.0, 1.0)
		for i: int in count:
			var along: float = float(i) / maxf(count - 1, 1)
			var at: Vector2 = _smeared[i].lerp(_rest[i], pull)
			at += Vector2(sin(time * 5.0 + i * 0.3 + index), cos(time * 4.3 + i * 0.23 + index * 2.0)) * (0.5 + 5.0 * loose)
			points.append(at)
			var swell: float = 1.0 + 0.2 * sin(along * 9.0 + index * 1.7 + time * 1.4) + 0.18 * (1.0 - sin(along * PI))
			widths.append(_fat * swell * lerpf(1.0, SMEAR_FAT, loose))
		return [points, widths]
