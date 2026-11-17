class_name CanFill
extends Control
## A can of gas has just been poured into a helper's button (Hint or the Radio: Game._buy_with_can). The
## button fills up with fuel, the level sinks away again with a little steam off the top, and `done` says
## it's over: that's when the button's badge shows the new count. A child of the button; it takes no taps and
## frees itself.

signal done

const FILL := 0.32
const HOLD := 0.12
const DRAIN := 0.55

var _t := 0.0
var _puffs: Array = []           # steam: [{x, born, drift, size}]
var _over := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play("whoosh", 0.7, -8.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 9:
		_puffs.append({"x": rng.randf_range(0.12, 0.88), "born": FILL + HOLD + rng.randf_range(0.0, DRAIN * 0.8),
			"drift": rng.randf_range(-18.0, 18.0), "size": rng.randf_range(11.0, 20.0)})


func _process(delta: float) -> void:
	_t += delta
	if not _over and _t >= FILL + HOLD + DRAIN:
		_over = true
		done.emit()
	if _t >= FILL + HOLD + DRAIN + 0.7:
		queue_free()
		return
	queue_redraw()


## How full the button is right now, 0..1.
func _level() -> float:
	if _t < FILL:
		var u := _t / FILL
		return 1.0 - pow(1.0 - u, 2.0)
	if _t < FILL + HOLD:
		return 1.0
	return maxf(0.0, 1.0 - (_t - FILL - HOLD) / DRAIN)


func _draw() -> void:
	var k := _level()
	var face_h := size.y - 8.0
	if k > 0.0:
		var h := face_h * k
		var top := face_h - h
		var rad := minf(30.0, h / 2.0)
		DrawUtil.rrect(self, Rect2(0, top, size.x, h), Color(GasChip.FUEL, 0.86), rad)
		# The surface: a lighter band that rocks a little.
		var wob := sin(_t * 14.0) * 3.0
		if h > 14.0:
			draw_line(Vector2(14, top + 6 + wob), Vector2(size.x - 14, top + 6 - wob), Color(1, 1, 1, 0.55), 5.0, true)
	# Steam off the top as it sinks.
	for p in _puffs:
		var age := _t - float(p["born"])
		if age < 0.0 or age > 0.7:
			continue
		var u := age / 0.7
		var at := Vector2(size.x * float(p["x"]) + float(p["drift"]) * u, -6.0 - 54.0 * u)
		draw_circle(at, float(p["size"]) * (0.6 + 0.8 * u), Color(1, 1, 1, 0.75 * (1.0 - u)))
