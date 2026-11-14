class_name TrailPreview
extends Node2D
## A short stretch of road with a trail torn into it (Wreckage in the given `style`), for the garage and the
## unlock card. Origin at the strip's centre; `tile` is one road tile. replay() tears it up again.

var style := "wreck"
var tile := 64.0
## Tiles along the strip (a gentle L, so the trail turns a corner).
const PATH := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, 1)]

var _wreck: Wreckage


func _ready() -> void:
	_wreck = Wreckage.new()
	_wreck.tile = tile
	_wreck.style = style
	_wreck.loud = false
	_wreck.position = -Vector2(2.0, 1.0) * tile
	add_child(_wreck)
	replay()


func replay() -> void:
	if _wreck:
		_wreck.set_route([], 0)
		_wreck.set_route(PATH, PATH.size())


func _draw() -> void:
	var o := -Vector2(2.0, 1.0) * tile
	var m := tile * 0.12
	for pass_i in 2:
		var col := Palette.ROAD_EDGE if pass_i == 0 else Palette.ROAD
		var off := Vector2(0, tile * 0.045) if pass_i == 0 else Vector2.ZERO
		for i in PATH.size():
			var p: Vector2i = PATH[i]
			var r := Rect2(o + Vector2(p) * tile + off + Vector2(m, m), Vector2(tile - 2.0 * m, tile - 2.0 * m))
			DrawUtil.rrect(self, r, col, tile * 0.2)
			if i + 1 < PATH.size():
				var q: Vector2i = PATH[i + 1]
				var a := o + (Vector2(p) + Vector2(0.5, 0.5)) * tile + off
				var b := o + (Vector2(q) + Vector2(0.5, 0.5)) * tile + off
				draw_line(a, b, col, tile - 2.0 * m)
