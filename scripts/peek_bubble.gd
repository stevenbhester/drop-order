class_name PeekBubble
extends Node2D
## The route preview (an option, off by default): while a route is being planned, a small chip by the top
## corner of the board shows the next three packages as they'll be when the van gets to the end of it.
## It stays off the board. The next one is biggest and on the right.

## Size of the next package in the chip.
var unit := 54.0

var _cols: Array = []            # Colors, next first (at most three)
var _on := false
var _alpha := 0.0
var _pop := 1.0


func show_cols(cols: Array) -> void:
	if cols != _cols and _on:
		_pop = 1.15
	_cols = cols
	_on = true
	visible = true
	queue_redraw()


func clear() -> void:
	_on = false


func _process(delta: float) -> void:
	if not visible:
		return
	_alpha = move_toward(_alpha, 1.0 if _on else 0.0, delta * 9.0)
	_pop = lerpf(_pop, 1.0, 1.0 - exp(-14.0 * delta))
	if not _on and _alpha <= 0.0:
		visible = false
	queue_redraw()


## The chip's size (its origin is its right-bottom corner, so it can be pinned there).
func size() -> Vector2:
	var w := unit * 0.34 * 2.0 + unit * 1.2
	for i in range(1, _cols.size()):
		w += unit * 0.6 * StackView.ASPECT + unit * 0.1
	w += unit * 0.82 * StackView.ASPECT + unit * 0.3
	return Vector2(w, unit * 1.05)


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var a := _alpha
	var sz := size() * _pop
	var r := Rect2(Vector2(-sz.x, -sz.y), sz)
	DrawUtil.rrect(self, Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.12 * a), sz.y * 0.5)
	DrawUtil.rrect(self, r, Color(Palette.SURFACE, 0.95 * a), sz.y * 0.5)
	var f := UiTheme.font()
	var fs := int(unit * 0.36)
	draw_string(f, Vector2(r.position.x + unit * 0.34, r.get_center().y + fs * 0.36), "then", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Palette.TEXT_SOFT, a))
	var x := -unit * 0.3
	var y := r.get_center().y
	if _cols.is_empty():
		draw_circle(Vector2(x - unit * 0.4, y), unit * 0.34, Color(Palette.GOOD, a))
		draw_polyline(PackedVector2Array([Vector2(x - unit * 0.55, y), Vector2(x - unit * 0.44, y + unit * 0.11), Vector2(x - unit * 0.22, y - unit * 0.11)]),
			Color(1, 1, 1, a), unit * 0.08, true)
		return
	for i in _cols.size():
		var s := unit * (0.82 if i == 0 else 0.6)
		var w := s * StackView.ASPECT
		DrawUtil.parcel(self, Vector2(x - w / 2.0, y), Vector2(w, s), Color(_cols[i], a), false)
		x -= w + unit * 0.1
