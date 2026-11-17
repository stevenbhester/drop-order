class_name BackUpMark
extends Node2D
## A dead-end hint's "back up to here", on the board (a child of Board): the stretch of driven road that has to
## be taken back, as a red dashed line with arrowheads running back along it, and at its far end (the last
## stop the job can still be finished from) a red pin that bobs, with "BACK TO HERE" under it. Game puts it
## up (_dead_end_hint) and takes it down when the van gets there, drives on, or the hint's dropped.

const RED := Color("ef4034")

## Board points, from the stop to go back to (first) along the road to where the van is (last).
var pts: PackedVector2Array = PackedVector2Array()
var tile := 180.0

var _t := 0.0


func _ready() -> void:
	z_index = 25


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if pts.size() < 2:
		return
	var a := clampf(_t / 0.25, 0.0, 1.0)
	var w := tile * 0.1
	# The road to take back: dashes that crawl toward the pin.
	var dash := tile * 0.3
	var crawl := fmod(_t * tile * 0.9, dash * 2.0)
	for i in range(pts.size() - 1, 0, -1):
		var from := pts[i]
		var to := pts[i - 1]
		var len := from.distance_to(to)
		var dir := (to - from) / maxf(len, 0.001)
		var d := -dash * 2.0 + crawl
		while d < len:
			var s := maxf(d, 0.0)
			var e := minf(d + dash, len)
			if e > s:
				draw_line(from + dir * s, from + dir * e, Color(1, 1, 1, 0.9 * a), w + 8.0, true)
				draw_line(from + dir * s, from + dir * e, Color(RED, a), w, true)
			d += dash * 2.0
		# An arrowhead mid-way, pointing back.
		var mid := from.lerp(to, 0.5)
		var side := Vector2(-dir.y, dir.x)
		var head := PackedVector2Array([mid + dir * tile * 0.16, mid - dir * tile * 0.1 + side * tile * 0.14, mid - dir * tile * 0.1 - side * tile * 0.14])
		draw_colored_polygon(head, Color(RED, a))
	# The pin.
	var c := pts[0] + Vector2(0, -tile * 0.2 - absf(sin(_t * 3.4)) * tile * 0.12)
	var r := tile * 0.26 * (0.6 + 0.4 * a)
	draw_circle(pts[0], tile * 0.34 * (1.0 + 0.1 * sin(_t * 3.4)), Color(RED, 0.22 * a))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, r * 0.6), c + Vector2(r * 0.6, r * 0.6), c + Vector2(0, r * 1.7)]), Color(RED, a))
	draw_circle(c, r + 5.0, Color(1, 1, 1, a))
	draw_circle(c, r, Color(RED, a))
	Icons.draw(self, "undo", c, r * 1.5, Color(1, 1, 1, a))
	var f := UiTheme.font()
	var txt := "BACK TO HERE"
	var px := int(tile * 0.17)
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var plate := Rect2(pts[0] + Vector2(-tw / 2.0 - px * 0.5, tile * 0.3), Vector2(tw + px, px * 1.6))
	DrawUtil.rrect(self, plate, Color(RED, a), px * 0.5)
	draw_string(f, plate.position + Vector2(px * 0.5, px * 1.18), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 1, 1, a))
