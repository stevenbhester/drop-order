extends Node2D
## Design preview: every trail look torn along an S-shaped road, at no momentum (left) and a hot run
## (right), driven a tile at a time. Render with:
##   godot --path . --write-movie out/f.png --fixed-fps 30 --quit-after 150 res://tools/preview/trails.tscn

const STYLES := ["wreck", "lava", "river", "mountains", "meteors", "zombies", "hearts", "money"]
const PATH := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1), Vector2i(2, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]
const T := 52.0

var _w: Array = []
var _t := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.GRASS)
	for r in STYLES.size():
		for m in 2:
			var o := Vector2(30 + m * 280, 20 + r * 186)
			var road := Node2D.new()
			road.position = o
			road.draw.connect(func():
				for p in PATH:
					road.draw_rect(Rect2(Vector2(p) * T + Vector2(4, 4), Vector2(T - 8, T - 8)), Palette.ROAD)
				for i in PATH.size() - 1:
					road.draw_line((Vector2(PATH[i]) + Vector2(0.5, 0.5)) * T, (Vector2(PATH[i + 1]) + Vector2(0.5, 0.5)) * T, Palette.ROAD, T - 8))
			add_child(road)
			var w := Wreckage.new()
			w.tile = T
			w.style = STYLES[r]
			w.momentum = 0 if m == 0 else 9
			w.loud = false
			w.position = o
			add_child(w)
			_w.append(w)


func _process(delta: float) -> void:
	_t += delta
	var n := mini(int(_t / 0.16) + 1, PATH.size())
	for w in _w:
		w.set_route(PATH, n)
