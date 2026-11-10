extends SceneTree
## Rasterises icon.svg to assets/icon/ios_1024.png for the iOS export: square corners (iOS rounds them) and no
## transparency (the App Store refuses it).
##   godot --headless --path . --script res://tools/make_ios_icon.gd


func _init() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg").replace('rx="28"', 'rx="0"')
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1024.0 / 128.0)
	if err != OK:
		push_error("couldn't rasterise icon.svg: %s" % err)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Palette.GRASS)
	out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	out.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute("res://assets/icon")
	out.save_png("res://assets/icon/ios_1024.png")
	print("wrote assets/icon/ios_1024.png (%dx%d)" % [out.get_width(), out.get_height()])
	quit()
