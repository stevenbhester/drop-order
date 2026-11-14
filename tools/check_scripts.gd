extends SceneTree
## Loads scripts to show their parse errors (with line numbers), quietly:
##   godot --headless --path . --script res://tools/check_scripts.gd -- res://scripts/a.gd res://scripts/b.gd
## (Handing a non-SceneTree script straight to --script pops a native alert on macOS; this doesn't.)

func _init() -> void:
	# After the first frame, so the autoloads (Progress, Sfx...) exist.
	process_frame.connect(_check, CONNECT_ONE_SHOT)


func _check() -> void:
	for p in OS.get_cmdline_user_args():
		var s = load(p)
		print("%s %s" % [p, "ok" if s != null and s.can_instantiate() else "FAILED"])
	quit()
