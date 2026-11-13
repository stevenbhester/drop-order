class_name VideoAd
extends CanvasLayer
## A pretend ad: one of the game's three trailers (fun, clickbait, the GTA VI trash talk), picked at random
## (never the same one twice running), played full screen. Skip is there from the first frame; skipping
## counts the same as watching. `finished` fires either way. The videos are rendered from the ad scenes in
## tools/ads (render.sh / render_gta.sh with OGV=1) into assets/ads/video.

signal finished

const VIDEOS := ["res://assets/ads/video/fun.ogv", "res://assets/ads/video/clickbait.ogv", "res://assets/ads/video/gta.ogv"]

static var _last := -1
## Debug: play this one next (-1: pick at random).
static var force := -1

var _root: Control
var _player: VideoStreamPlayer
## Over the video: the "Ad" tag and the progress bar.
var _over: Control
var _done := false
var _t := 0.0
var _length := 30.0


## Which video plays next: any but the last one.
static func pick() -> int:
	if force >= 0 and force < VIDEOS.size() and ResourceLoader.exists(VIDEOS[force]):
		return force
	var choices := []
	for i in VIDEOS.size():
		if i != _last and ResourceLoader.exists(VIDEOS[i]):
			choices.append(i)
	if choices.is_empty():
		return _last if _last >= 0 and ResourceLoader.exists(VIDEOS[_last]) else -1
	return choices.pick_random()


func _ready() -> void:
	layer = 88
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.theme()
	_root.draw.connect(func(): _root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color.BLACK))
	add_child(_root)
	var i := pick()
	if i < 0:
		# No videos in this build: nothing to sit through.
		_finish.call_deferred()
		return
	_last = i
	_player = VideoStreamPlayer.new()
	_player.stream = load(VIDEOS[i])
	_player.expand = true
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.finished.connect(_finish)
	_root.add_child(_player)
	_fit()
	_root.resized.connect(_fit)
	_over = Control.new()
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	_root.add_child(_over)
	_player.play()
	_length = maxf(_player.get_stream_length(), 1.0)
	print("[ad] playing %s" % VIDEOS[i].get_file())

	var skip := JuicyButton.new()
	skip.label = "Skip"
	skip.icon_name = "next"
	skip.font_px = 40
	skip.custom_minimum_size = Vector2(230, 104)
	skip.size = skip.custom_minimum_size
	skip.pressed.connect(func():
		Sfx.play("click")
		_finish())
	_root.add_child(skip)
	var vp := _root.get_viewport_rect().size
	skip.position = Vector2(vp.x - skip.size.x - 36.0, 40.0 + UiTheme.insets(_root.get_viewport()).x)
	_root.modulate.a = 0.0
	_root.create_tween().tween_property(_root, "modulate:a", 1.0, 0.18)


## The video as big as fits, centred, at its own shape (9:16).
func _fit() -> void:
	if _player == null:
		return
	var vp := _root.size
	var ar := 9.0 / 16.0
	var w := minf(vp.x, vp.y * ar)
	var h := w / ar
	_player.size = Vector2(w, h)
	_player.position = (vp - Vector2(w, h)) / 2.0


func _process(delta: float) -> void:
	_t += delta
	if _over:
		_over.queue_redraw()


## Over the video: an "Ad" tag, and how far through it is.
func _draw_over() -> void:
	var s := _over.size
	var f := UiTheme.font()
	var top := 40.0 + UiTheme.insets(_over.get_viewport()).x
	var tag := Rect2(Vector2(36, top + 22), Vector2(96, 58))
	DrawUtil.rrect(_over, tag, Color(0, 0, 0, 0.55), 18)
	var tw := f.get_string_size("Ad", HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	_over.draw_string(f, Vector2(tag.position.x + (tag.size.x - tw) / 2.0, tag.position.y + 41), "Ad", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	var k := clampf(_player.stream_position / _length, 0.0, 1.0)
	var bar := Rect2(0, s.y - 10.0, s.x, 10.0)
	_over.draw_rect(bar, Color(1, 1, 1, 0.2))
	_over.draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Game.AD_PINK)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _player:
		_player.stop()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := _root.create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		finished.emit()
		queue_free())
