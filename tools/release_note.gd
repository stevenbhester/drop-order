extends SceneTree
## Writes release/latest.json, which tells players' games a newer build is in TestFlight (UpdateCheck reads
## it from GitHub). tools/testflight.sh runs this after each archive, from Version's number, name and the top
## of its notes. The build is offered from `ready_at` (unix time): an hour after the archive by default, to give
## the upload time to go through Apple's processing.
##   godot --headless --path . --script res://tools/release_note.gd -- --build=12 [--ready-in=3600]

func _initialize() -> void:
	# Loaded here rather than named, so it compiles once the game's autoloads (which it mentions) exist.
	var V: Script = load("res://scripts/version.gd")
	var build: int = V.BUILD
	var ready_in := 3600
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--build="):
			build = a.trim_prefix("--build=").to_int()
		elif a.begins_with("--ready-in="):
			ready_in = a.trim_prefix("--ready-in=").to_int()
	var notes: Array = V.NOTES[0]["notes"] if V.NOTES[0]["version"] == V.NUMBER else []
	var d := {
		"version": V.NUMBER,
		"name": V.NAME,
		"build": build,
		"ready_at": int(Time.get_unix_time_from_system()) + ready_in,
		"notes": notes.slice(0, 3),
	}
	var f := FileAccess.open("res://release/latest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t") + "\n")
	f.close()
	print("release/latest.json: v%s \"%s\", build %d, offered from %s" % [d.version, d.name, build,
		Time.get_datetime_string_from_unix_time(d.ready_at, true) + " UTC"])
	quit()
