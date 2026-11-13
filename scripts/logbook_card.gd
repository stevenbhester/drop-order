class_name LogbookCard
extends Control
## A page from the driver's logbook, found on a side road's first win: a lined notebook page tipped onto
## the screen, with the entry in the driver's words and a little van doodle. A few lines at a time, the
## pages hint at who the driver is and what the deliveries are really for. Tap anywhere to put it away.
## Every page found is kept in the garage's Logbook.

signal closed

var side_id := ""

var _t := 0.0
var _closing := false


static func page_of(id: String) -> int:
	var all := SideRoads.defs()
	for i in all.size():
		if all[i].get("id", "") == id:
			return i + 1
	return 0


func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	Sfx.play("whoosh", 0.9, -6.0)
	Sfx.play("sparkle", 0.8, -8.0)


func _gui_input(e: InputEvent) -> void:
	if _t > 0.5 and e is InputEventMouseButton and e.pressed:
		accept_event()
		_close()


func _close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## A logbook page drawn at `r` (also used by the garage's Logbook list, smaller).
static func draw_page(ci: CanvasItem, r: Rect2, title: String, text: String, px: int) -> void:
	DrawUtil.rrect(ci, Rect2(r.position + Vector2(0, 12), r.size), Color(0, 0, 0, 0.25), 18)
	DrawUtil.rrect(ci, r, Color("fdf8ec"), 18)
	var line_h := px * 1.45
	var y := r.position.y + px * 3.0
	while y < r.end.y - 20.0:
		ci.draw_line(Vector2(r.position.x + 20.0, y), Vector2(r.end.x - 20.0, y), Color("bcd3f2"), 2.0)
		y += line_h
	ci.draw_line(Vector2(r.position.x + px * 2.4, r.position.y + 10.0), Vector2(r.position.x + px * 2.4, r.end.y - 10.0), Color("f2a0a0"), 3.0)
	var f := UiTheme.font()
	ci.draw_string(f, Vector2(r.position.x + px * 3.0, r.position.y + px * 2.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(px * 0.8), Color("8a6a4a"))
	# The entry, wrapped onto the lines.
	var words := text.split(" ")
	var cur := ""
	var ly := r.position.y + px * 3.0 + line_h - px * 0.35
	var w := r.size.x - px * 3.0 - 30.0
	for wd in words:
		var tryl := wd if cur == "" else cur + " " + wd
		if f.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w and cur != "":
			ci.draw_string(f, Vector2(r.position.x + px * 3.0, ly), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("2f3a66"))
			ly += line_h
			cur = wd
		else:
			cur = tryl
	ci.draw_string(f, Vector2(r.position.x + px * 3.0, ly), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("2f3a66"))


func _draw() -> void:
	var v := size
	var a := clampf(_t / 0.25, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, v), Color(0.08, 0.05, 0.14, 0.8 * a))
	var d := SideRoads.get_def(side_id)
	var k := 1.0 - pow(1.0 - clampf(_t / 0.45, 0.0, 1.0), 3.0)
	var w := minf(v.x - 80.0, 900.0)
	var r := Rect2(Vector2((v.x - w) / 2.0, v.y * 0.3 + (1.0 - k) * v.y * 0.6), Vector2(w, 560))
	var f := UiTheme.font()
	var head := "LOGBOOK PAGE FOUND!"
	var hw := f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
	draw_string_outline(f, Vector2((v.x - hw) / 2.0, r.position.y - 50.0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, 10, Color("2b2233"))
	draw_string(f, Vector2((v.x - hw) / 2.0, r.position.y - 50.0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color("fff3c4"))
	draw_set_transform(r.get_center(), -0.03 * k, Vector2.ONE)
	draw_page(self, Rect2(-r.size / 2.0, r.size), "Page %d · %s" % [page_of(side_id), str(d.get("title", ""))], str(d.get("log", "")), 40)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _t > 0.8:
		var tip := "Tap to put it away · every page is in the Garage"
		var tw := f.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(f, Vector2((v.x - tw) / 2.0, r.end.y + 80.0), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.7))
