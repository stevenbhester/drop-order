class_name PackageBox
extends Node2D
## A single package sprite (the chute's load and flying deliveries): `size` tall, `aspect` times as wide.

var color := Color.WHITE
var size := 64.0
var aspect := 1.0


func _draw() -> void:
	DrawUtil.parcel(self, Vector2.ZERO, Vector2(size * aspect, size), color)
