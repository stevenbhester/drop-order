class_name Spotlight
extends Control
## The first time a level has something new (a road hazard, a building, a rule), the level fades back and
## the new pieces stay lit, each in a ring, with a card: "NEW ROAD HAZARD!", its name, and one line on how
## it works (SymbolCard's). Any tap dismisses it. Each kind is shown once (Progress.seen_new).
##
## Player-facing names: road tiles are "road hazards", new kinds of building are "new buildings", and the
## rest (bigger orders, ending the shift at the depot) are "new rules".

signal closed

## [kind, category, name, line]: the order they're checked in, and how they're introduced.
const KINDS := {
	"multi": ["NEW RULE!", "Big orders", "Some drop-offs want more than one: ×{n} means {words} of its colour, each on top."],
	"oneway": ["NEW ROAD HAZARD!", "One-way street", "Go the way the arrow points. You can turn onto it, but leave it its way."],
	"bridge": ["NEW ROAD HAZARD!", "Bridge", "Drive straight across: once over, once under."],
	"pickup": ["NEW BUILDING!", "Pick-up", "Drop-offs take packages; pick-ups give them. Drive past and it loads one on TOP of your stack."],
	"gate": ["NEW ROAD HAZARD!", "Colour gate", "Only lifts while your top package is its colour."],
	"return": ["NEW RULE!", "End of shift", "Deliver everything, then park back at the depot."],
	"hub": ["NEW ROAD HAZARD!", "Spinner", "Drive over it and your top two packages swap."],
	"ice": ["NEW ROAD HAZARD!", "Ice", "No turning on it. You slide straight across."],
	"locker": ["NEW BUILDING!", "Locker", "A drop-off that takes whatever package is on top. Any colour at all."],
	"park": ["NEW BUILDING!", "Parking locker", "Stop by and tap it to leave your top package. Tap again later to take it back."],
	"works": ["NEW ROAD HAZARD!", "Roadworks", "Closed until you've made that many deliveries. The sign counts down."],
	"warehouse": ["NEW BUILDING!", "Big pick-up", "A warehouse: it loads all its parcels at once (+N), one after another on top."],
}

var kind := ""
var in_daily := false          # shown inside a daily (it is remembered apart: see new_kind)
## Where the new pieces are on screen, and how big a ring each gets.
var spots: Array = []
var radius := 80.0

var _t := 0.0
var _closing := false
var _dim: ColorRect
var _fg: Control        # the rings and the card, drawn over the dimming
var _pic: SymbolPicture   # the looping demo on the card
## What the demo shows: SymbolCard's kind for this, and a colour for gates, pickups and houses.
const PIC_KIND := {"multi": "houses", "oneway": "oneway", "bridge": "bridge", "pickup": "pickup", "gate": "gate", "return": "pitstop",
	"hub": "hub", "ice": "ice", "locker": "locker", "park": "park", "works": "works", "warehouse": "warehouse"}
var pic_color := Color("e03131")
var pic_color_name := "red"
## For big orders: the order of the house it points at (the picture and the words say the same number).
var count := 0


## Which new kind (if any) this level shows first that the player hasn't been shown: "" if none.
## (In a daily, one already shown in a daily doesn't come again; but the main road shows its own the first
## time it's met there even if a daily showed it first, so nobody learns a rule only from the daily.)
static func new_kind(L: LevelData, in_daily := false) -> String:
	var have := {}
	if L.houses.any(func(h): return h.order > 1 and h.color != "any"):
		have["multi"] = true
	if not L.oneway.is_empty(): have["oneway"] = true
	if not L.bridges.is_empty(): have["bridge"] = true
	if L.shops.any(func(s): return s.count <= 1): have["pickup"] = true
	if L.shops.any(func(s): return s.count > 1): have["warehouse"] = true
	if not L.gates.is_empty(): have["gate"] = true
	if L.return_depot: have["return"] = true
	if not L.hubs.is_empty(): have["hub"] = true
	if not L.ice.is_empty(): have["ice"] = true
	if L.houses.any(func(h): return h.color == "any"): have["locker"] = true
	if not L.lockers.is_empty(): have["park"] = true
	if not L.works.is_empty(): have["works"] = true
	for k in KINDS:
		if have.has(k) and not Progress.seen_new.has(k) and not (in_daily and Progress.seen_new.has("daily_" + k)):
			return k
	return ""


## The tiles to light for a kind.
static func tiles_of(L: LevelData, k: String) -> Array:
	var out: Array = []
	match k:
		"multi":
			for h in L.houses:
				if h.order > 1 and h.color != "any": out.append(h.pos)
		"oneway": out = L.oneway.keys()
		"bridge": out = L.bridges.keys()
		"pickup":
			for s in L.shops:
				if s.count <= 1: out.append(s.pos)
		"warehouse":
			for s in L.shops:
				if s.count > 1: out.append(s.pos)
		"gate": out = L.gates.keys()
		"return": out = [L.start]
		"hub": out = L.hubs.keys()
		"ice": out = L.ice.keys()
		"locker":
			for h in L.houses:
				if h.color == "any": out.append(h.pos)
		"park":
			for lk in L.lockers: out.append(lk.pos)
		"works": out = L.works.keys()
	return out.slice(0, 8)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec2 rect_size;
uniform vec4 holes[8];
uniform int n = 0;
uniform float k = 0.0;
void fragment() {
	vec2 p = UV * rect_size;
	float lit = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= n) break;
		float d = distance(p, holes[i].xy);
		lit = max(lit, 1.0 - smoothstep(holes[i].z * 0.92, holes[i].z * 1.08, d));
	}
	COLOR = vec4(0.07, 0.05, 0.13, 0.78 * k * (1.0 - lit));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.material = mat
	add_child(_dim)
	_fg = Control.new()
	_fg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fg.draw.connect(_draw_fg)
	add_child(_fg)
	_pic = SymbolPicture.new()
	_pic.kind = PIC_KIND.get(kind, "")
	_pic.col = pic_color
	_pic.col_name = pic_color_name
	_pic.count = count if count > 0 else (2 if kind in ["multi", "works"] else (3 if kind == "warehouse" else 1))
	add_child(_pic)
	Sfx.play("sparkle", 1.0, -3.0)
	Sfx.haptic(16, 1.0, "spotlight:_ready")


func _input(e: InputEvent) -> void:
	var pointer: bool = e is InputEventMouseButton or e is InputEventMouseMotion or e is InputEventScreenTouch or e is InputEventScreenDrag
	if not pointer:
		return
	get_viewport().set_input_as_handled()
	var press: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if press and _t > 0.4:
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	Progress.seen_new[("daily_" + kind) if in_daily else kind] = true
	Progress.set_option("seen_new", Progress.seen_new)
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


func _process(delta: float) -> void:
	_t += delta
	if Progress.auto and _t > 0.6 and not OS.get_cmdline_user_args().has("--spotlight-hold"):
		close()
	var mat := _dim.material as ShaderMaterial
	var holes := PackedVector4Array()
	for p in spots:
		holes.append(Vector4(p.x, p.y, radius * (1.0 + 0.04 * sin(_t * 4.0)), 0))
	while holes.size() < 8:
		holes.append(Vector4.ZERO)
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("holes", holes)
	mat.set_shader_parameter("n", mini(spots.size(), 8))
	mat.set_shader_parameter("k", clampf(_t / 0.35, 0.0, 1.0))
	_fg.queue_redraw()


func _draw_fg() -> void:
	var ci := _fg
	var a := clampf((_t - 0.2) / 0.3, 0.0, 1.0)
	# Rings round the new pieces, pulsing out.
	for p in spots:
		for k0 in [0.0, 0.5]:
			var u := fmod(_t / 1.3 + k0, 1.0)
			ci.draw_arc(p, radius * (1.05 + 0.5 * u), 0, TAU, 48, Color(Palette.STAR_GOLD, 0.9 * (1.0 - u) * a), 8.0, true)
		ci.draw_arc(p, radius * 1.02, 0, TAU, 48, Color(Palette.STAR_GOLD, a), 6.0, true)
	var info: Array = KINDS.get(kind, ["NEW!", kind, ""])
	var v := size
	var f := UiTheme.font()
	# The card sits right by the new pieces: just under them, or just over them if there's no room below.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in spots:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var w := minf(v.x - 60.0, 860.0)
	var h := 300.0
	var gap := radius * 1.6 + 30.0
	var y := hi.y + gap
	if y + h > v.y - 40.0:
		y = lo.y - gap - h
	y = clampf(y, 120.0, v.y - h - 40.0)
	var cx := clampf((lo.x + hi.x) / 2.0, w / 2.0 + 30.0, v.x - w / 2.0 - 30.0)
	# A pointer from the card toward the pieces.
	var aim := Vector2((lo.x + hi.x) / 2.0, (lo.y + hi.y) / 2.0)
	var from := Vector2(clampf(aim.x, cx - w / 2.0 + 40.0, cx + w / 2.0 - 40.0), y if aim.y < y else y + h)
	var tip := from + (aim - from).normalized() * minf(from.distance_to(aim) - radius * 1.1, 70.0)
	var side := (aim - from).normalized().orthogonal() * 26.0
	ci.draw_colored_polygon(PackedVector2Array([from + side, from - side, tip]), Color(Palette.CARD, a))
	var pop := 1.0 + 0.12 * sin(clampf((_t - 0.2) / 0.3, 0.0, 1.0) * PI)
	ci.draw_set_transform(Vector2(cx, y + h / 2.0), 0.0, Vector2.ONE * pop)
	var r := Rect2(-w / 2.0, -h / 2.0, w, h)
	DrawUtil.rrect(ci, Rect2(r.position + Vector2(0, 12), r.size), Color(0, 0, 0, 0.3 * a), 44)
	DrawUtil.rrect(ci, r, Color(Palette.CARD, a), 44)
	# The tag, slanted, across the top edge.
	var tag: String = info[0]
	var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
	ci.draw_set_transform(Vector2(cx, y + 6.0), -0.04, Vector2.ONE * pop)
	DrawUtil.rrect(ci, Rect2(-tw / 2.0 - 30, -40, tw + 60, 80), Color(Palette.ACCENT, a), 24)
	ci.draw_string(f, Vector2(-tw / 2.0, 18), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(1, 1, 1, a))
	ci.draw_set_transform(Vector2(cx, y + h / 2.0), 0.0, Vector2.ONE * pop)
	# The little looping picture on the left (the same one a tap on the symbol shows); the words beside it.
	var pw := h - 70.0
	var tx := -w / 2.0 + pw + 50.0
	var tw2 := w / 2.0 - 30.0 - tx
	ci.draw_string(f, Vector2(tx, -40), info[1], HORIZONTAL_ALIGNMENT_LEFT, tw2, 54, Color(Palette.TEXT, a))
	var line: String = info[2]
	var n := count if count > 0 else 2
	line = line.replace("{n}", str(n)).replace("{words}", ["", "one", "two", "three", "four", "five"][clampi(n, 0, 5)])
	ci.draw_multiline_string(f, Vector2(tx, 6), line, HORIZONTAL_ALIGNMENT_LEFT, tw2, 32, 4, Color(Palette.TEXT_SOFT, a))
	ci.draw_string(f, Vector2(-w / 2.0, h / 2.0 - 18), "Tap anywhere to start", HORIZONTAL_ALIGNMENT_CENTER, w, 26, Color(Palette.TEXT_SOFT, a * (0.6 + 0.4 * sin(_t * 4.0))))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _pic:
		_pic.modulate.a = a
		_pic.position = Vector2(cx - w / 2.0 + 26.0, y + 24.0)
		_pic.size = Vector2(pw, pw)
		_pic.queue_redraw()


## The symbol card's looping picture on its own, in a rounded panel (no card, no words, no taps).
class SymbolPicture:
	extends SymbolCard

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _input(_e: InputEvent) -> void:
		pass

	func _draw() -> void:
		_box = Rect2(Vector2.ZERO, size)
		var c := size / 2.0
		_scl = 1.0
		_org = c
		draw_set_transform(c, 0.0, Vector2.ONE)
		var p := Rect2(-size / 2.0, size)
		DrawUtil.rrect(self, p, Color("eaf6e1"), 26)
		_picture(p)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
