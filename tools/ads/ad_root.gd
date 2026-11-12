extends Node
## Renders a demo ad: the real game (Main) runs inside a 1080x1920 SubViewport, an AdDirector drives it and
## draws the ad's beats on top, and every rendered frame is saved as a PNG for tools/ads/encode_mp4.swift.
## Run through tools/ads/render.sh, which uses --write-movie for fixed 30 fps timing and the soundtrack (wav).
##   godot --path . res://tools/ads/ad.tscn --fixed-fps 30 --write-movie <tmp>/m.png -- --ad=fun|bait --out=<dir> ...

const SIZE := Vector2i(1080, 1920)

var _vp: SubViewport
var _out := ""
var _frame := 0
var director: AdDirector


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_4X
	_vp.audio_listener_enable_2d = true
	add_child(_vp)
	# No pop-in for the first level: the video's first frame (its thumbnail) is the level, fully there.
	Progress.auto = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(main)
	Progress.auto = false
	var layer := CanvasLayer.new()
	layer.layer = 60
	_vp.add_child(layer)
	director = AdDirector.new()
	director.main = main
	layer.add_child(director)
	director.finished.connect(func(): get_tree().quit())
	# A small preview of the frame in the window.
	var tr := TextureRect.new()
	tr.texture = _vp.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(tr)
	RenderingServer.frame_post_draw.connect(_grab)


func _grab() -> void:
	if _out == "":
		return
	var img := _vp.get_texture().get_image()
	img.save_png("%s/%05d.png" % [_out, _frame])
	_frame += 1
