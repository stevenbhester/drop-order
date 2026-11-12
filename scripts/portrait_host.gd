class_name PortraitHost
extends CanvasLayer
## Sideways play: the menus and pop-ups are designed for a tall screen, so they live in a portrait column
## (a 1080 x 1920 SubViewport) shown in the middle of the wide screen, scaled to its height. Anything added
## with `put()` thinks it's on a portrait phone (get_viewport_rect is 1080 x 1920) and gets input as usual.
## `dim`: a dark sheet over the rest of the screen while something's in it (for pop-ups over the game).
## With `auto_hide`, the host hides itself whenever it's empty.

const SIZE := Vector2i(1080, 1920)

var dim := false
var auto_hide := false

var _shade: ColorRect
var _box: SubViewportContainer
var vp: SubViewport


func _ready() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0.08, 0.06, 0.14, 0.62) if dim else Color(0, 0, 0, 0)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP if dim else Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_box = SubViewportContainer.new()
	_box.stretch = false
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_box)
	vp = SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.msaa_2d = Viewport.MSAA_4X
	vp.handle_input_locally = true
	_box.add_child(vp)
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	var v := get_viewport().get_visible_rect().size
	var k := v.y / float(SIZE.y)
	_box.size = Vector2(SIZE)
	_box.scale = Vector2(k, k)
	_box.position = Vector2(round((v.x - SIZE.x * k) / 2.0), 0)


func put(node: Node) -> void:
	vp.add_child(node)
	visible = true


func _process(_delta: float) -> void:
	if auto_hide:
		visible = vp.get_child_count() > 0
