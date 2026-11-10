extends Node
## Screen switcher: title <-> level select <-> game. Caches solver results per level.

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
	var direct := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			start = a.trim_prefix("--level=").to_int() - 1
			direct = true
		elif a.begins_with("--auto"):
			direct = true
	if OS.get_cmdline_user_args().has("--select"):
		show_select()
	elif direct:
		play(start)
	else:
		show_title()
		# Once a launch, the studio card plays over the title and dives through its door into it.
		if StudioCard.due() and not OS.get_cmdline_user_args().has("--no-intro"):
			var card := StudioCard.new()
			(screen as TitleScreen).quiet = true
			card.draining.connect(_title_audible)
			add_child(card)


func show_title() -> void:
	var t := TitleScreen.new()
	t.setup(levels)
	t.play_pressed.connect(func(): play(Progress.first_incomplete(levels.size())))
	t.levels_pressed.connect(show_select)
	_swap(t)


func _title_audible() -> void:
	if screen is TitleScreen:
		(screen as TitleScreen).quiet = false


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
