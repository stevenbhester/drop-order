extends SceneTree
## Regenerates the placeholder sounds into res://audio/*.wav.
##   godot --headless --path . --script res://tools/gen_sfx.gd
## (Then open the editor or run `godot --headless --path . --import` to import them.)

func _init() -> void:
	seed(1234)
	for n in SfxSynth.NAMES:
		var path := "res://audio/%s.wav" % n
		var err := SfxSynth.make(n).save_to_wav(path)
		print("%s -> %s" % [path, "ok" if err == OK else error_string(err)])
	quit()
