class_name PadPulse
extends Node2D
## The soft waves on a drop-off's pad: faint rings in the house's colour drifting in from the rim toward
## the building ("bring it here"). They stop once the house has everything it wants. (Pickups do the
## opposite: Shop draws waves going out from the dock to its square outline.)

const PERIOD := 2.6

var tile := 100.0
var color := Color.WHITE
var house: House
var _t := 0.0


func _ready() -> void:
	_t = randf() * PERIOD


func _process(delta: float) -> void:
	var on := house == null or not house.is_full()
	if visible != on:
		visible = on
	if on:
		_t += delta
		queue_redraw()


func _draw() -> void:
	for k in 2:
		var u := fmod(_t / PERIOD + k * 0.5, 1.0)
		var r := tile * lerpf(0.42, 0.2, u)
		draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(color, 0.4 * sin(PI * u)), tile * 0.035, true)
