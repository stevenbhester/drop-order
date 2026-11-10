class_name PackageBox
extends Node2D
## A single package sprite (stack view + flying deliveries).

var color := Color.WHITE
var size := 64.0


func _draw() -> void:
	DrawUtil.package(self, Vector2.ZERO, size, color)
