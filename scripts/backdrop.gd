class_name Backdrop
extends CanvasLayer
## The warm background behind every screen: a soft cream-to-peach gradient with big, slow pastel bubbles
## drifting up it. Lives in Main on a layer under everything, so it carries on between screens.

const DAY_TOP := Color("fff4dd")
const DAY_BOTTOM := Color("ffdcc6")
const NIGHT_TOP := Color("1b1838")
const NIGHT_BOTTOM := Color("2c2152")
## The current gradient ends (night mode swaps them).
static var TOP: Color = DAY_TOP
static var BOTTOM: Color = DAY_BOTTOM


static func apply(at_night: bool) -> void:
	TOP = NIGHT_TOP if at_night else DAY_TOP
	BOTTOM = NIGHT_BOTTOM if at_night else DAY_BOTTOM
const TINTS := [Color("ffd166"), Color("ff9fb2"), Color("9be7c4"), Color("a5d8ff"), Color("ffffff"), Color("ffffff")]
const BUBBLES := 11

var _canvas: Node2D
var _bubbles: Array = []
var _t := 0.0


func _ready() -> void:
	layer = -10
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)
	for i in BUBBLES:
		_bubbles.append({
			"x": randf(), "y": randf(), "r": randf_range(70.0, 230.0), "c": TINTS[i % TINTS.size()],
			"v": randf_range(0.006, 0.016), "sway": randf_range(0.5, 1.4), "ph": randf() * TAU,
		})


func _process(delta: float) -> void:
	_t += delta
	for b in _bubbles:
		b["y"] -= b["v"] * delta
		if b["y"] < -0.2:
			b["y"] = 1.2
			b["x"] = randf()
	_canvas.queue_redraw()


func _draw_canvas() -> void:
	var size := _canvas.get_viewport_rect().size
	_canvas.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([TOP, TOP, BOTTOM, BOTTOM]))
	for b in _bubbles:
		var p := Vector2(b["x"] * size.x + sin(_t * 0.25 * b["sway"] + b["ph"]) * 40.0, b["y"] * size.y)
		var white: bool = b["c"] == Color.WHITE
		var dim := 0.4 if Palette.night else 1.0
		_canvas.draw_circle(p, b["r"], Color(b["c"], (0.3 if white else 0.16) * dim))
		_canvas.draw_circle(p + Vector2(-b["r"] * 0.3, -b["r"] * 0.3), b["r"] * 0.22, Color(1, 1, 1, 0.22 * dim))
