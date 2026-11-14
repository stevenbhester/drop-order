extends Node2D
## Design preview: the boss running off after a win (BossOutro), over a plain backdrop, on loop.

func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.GRASS)
	_again()


func _again() -> void:
	var o := BossOutro.new()
	add_child(o)
	get_tree().create_timer(BossOutro.TIME + 0.4).timeout.connect(_again)
