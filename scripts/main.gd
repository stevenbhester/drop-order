extends Node
## Screen switcher: level select <-> game. Caches solver results per level.

var levels: Array = []
var solved := {}
var screen: Node


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.BG)
	levels = Levels.load_all()
	if levels.is_empty():
		push_error("No levels loaded")
		return
	var start := Progress.first_incomplete(levels.size())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			start = a.trim_prefix("--level=").to_int() - 1
	play(start)


func play(i: int) -> void:
	i = clampi(i, 0, levels.size() - 1)
	var L: LevelData = levels[i]
	if not solved.has(i):
		solved[i] = Solver.solve(L)
	var g := Game.new()
	g.setup(L, i, levels.size(), solved[i])
	g.level_requested.connect(play)
	g.menu_requested.connect(show_select)
	_swap(g)


func show_select() -> void:
	var s := LevelSelect.new()
	s.setup(levels)
	s.level_chosen.connect(play)
	_swap(s)


func _swap(next: Node) -> void:
	if screen:
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		screen.queue_free()
	screen = next
	add_child(next)
