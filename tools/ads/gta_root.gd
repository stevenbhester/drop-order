extends Node
## Renders the "GTA VI" trash-talk ad (just for fun with friends). The real game runs in its own 1080x1920
## SubViewport; that picture is shown through `view`, a Sprite2D the GtaDirector can zoom, tilt, shake and
## run through a fancam shader (RGB split, flash, invert, desaturate, zoom blur). The director draws the news
## cards and title cards on top, and every frame is saved as a PNG for tools/ads/encode_mp4.swift.
##   tools/ads/render_gta.sh  (uses --write-movie for fixed 30 fps and the soundtrack)

const SIZE := Vector2i(1080, 1920)

const FANCAM := """
shader_type canvas_item;
uniform float split = 0.0;
uniform float flash = 0.0;
uniform float sat = 1.0;
uniform float contrast = 1.0;
uniform float invert = 0.0;
uniform float blur = 0.0;
uniform float vignette = 0.0;
void fragment() {
	vec2 c = vec2(0.5);
	vec2 d = UV - c;
	vec3 col = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float k = float(i) / 8.0 * blur;
		vec2 u = c + d * (1.0 - k);
		col.r += texture(TEXTURE, u + vec2(split, 0.0) * TEXTURE_PIXEL_SIZE).r;
		col.g += texture(TEXTURE, u).g;
		col.b += texture(TEXTURE, u - vec2(split, 0.0) * TEXTURE_PIXEL_SIZE).b;
	}
	col /= 8.0;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, sat);
	col = (col - 0.5) * contrast + 0.5;
	col = mix(col, 1.0 - col, invert);
	col *= 1.0 - vignette * smoothstep(0.35, 0.85, length(d * vec2(1.0, 0.65)));
	col = mix(col, vec3(1.0), flash);
	COLOR = vec4(col, 1.0);
}
"""

var _vp: SubViewport
var _out := ""
var _frame := 0
var director: GtaDirector


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
	add_child(_vp)

	# The game, in its own viewport.
	var game_vp := SubViewport.new()
	game_vp.size = SIZE
	game_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game_vp.msaa_2d = Viewport.MSAA_4X
	_vp.add_child(game_vp)
	Progress.auto = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	game_vp.add_child(main)
	Progress.auto = false

	var view := Sprite2D.new()
	view.texture = game_vp.get_texture()
	view.position = Vector2(SIZE) / 2.0
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FANCAM
	mat.shader = sh
	view.material = mat
	_vp.add_child(view)

	var layer := CanvasLayer.new()
	layer.layer = 60
	_vp.add_child(layer)
	director = GtaDirector.new()
	director.main = main
	director.view = view
	director.game_vp = game_vp
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
