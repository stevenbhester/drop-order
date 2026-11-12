class_name Cosmetics
extends RefCounted
## Things to wear on the van, found on the road in some levels. Paints recolour the body (with a pattern);
## toppers sit on the cab roof; rides swap the whole vehicle (the topper still rides on the roof). Most are from Frontiers Celestia, the studio's other game.
## Everything here is drawn in code, top-down, in the van's own space (facing +x).

const ITEMS := {
	"classic": {"kind": "paint", "name": "Classic Cream", "from": "", "body": Color("fffaf2"), "cab": Color("3b4a6b"), "pattern": ""},
	"deep_field": {"kind": "paint", "name": "Deep Field", "from": "Frontiers Celestia", "body": Color("2a2150"), "cab": Color("15112c"), "pattern": "stars"},
	"gloaming": {"kind": "paint", "name": "Gloaming", "from": "Frontiers Celestia", "body": Color("ff9a7a"), "cab": Color("8a4fa8"), "pattern": "dusk"},
	"duskwood": {"kind": "paint", "name": "Duskwood", "from": "Frontiers Celestia", "body": Color("5fb39a"), "cab": Color("2f5e5a"), "pattern": "leaves"},
	"mosaic_moth": {"kind": "paint", "name": "Mosaic Moth", "from": "Frontiers Celestia", "body": Color("f2e6ff"), "cab": Color("5b3f8f"), "pattern": "mosaic"},
	"racing": {"kind": "paint", "name": "Racing Stripes", "from": "", "body": Color("ff5d5d"), "cab": Color("2b2f38"), "pattern": "stripes"},
	"monster_truck": {"kind": "ride", "name": "Kuma's Monster Truck", "from": "", "body": Color("e8473c"), "cab": Color("23222b")},
	"drizzlet": {"kind": "topper", "name": "Drizzlet", "from": "Frontiers Celestia"},
	"bonkle": {"kind": "topper", "name": "Bonkle Ears", "from": "Frontiers Celestia"},
	"sprout": {"kind": "topper", "name": "Sprout & Orbit", "from": "Frontiers Celestia"},
	"rivet": {"kind": "topper", "name": "Rivet", "from": "Frontiers Celestia"},
	"puffball": {"kind": "topper", "name": "Puffball", "from": "Frontiers Celestia"},
	"soup_bowl": {"kind": "topper", "name": "Door Bowl", "from": "Door Bowl"},
}
## Garage order.
const ORDER := ["monster_truck", "classic", "deep_field", "gloaming", "duskwood", "mosaic_moth", "racing",
	"drizzlet", "bonkle", "sprout", "rivet", "puffball", "soup_bowl"]


static func name_of(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)


static func kind_of(id: String) -> String:
	return ITEMS.get(id, {}).get("kind", "")


## A colour that stands for the item (for gift sparkles and garage tiles).
static func tint(id: String) -> Color:
	match id:
		"drizzlet": return Color(0.5, 0.78, 0.98)
		"bonkle": return Color(0.98, 0.66, 0.46)
		"sprout": return Color(0.5, 0.9, 0.74)
		"rivet": return Color(0.75, 0.78, 0.86)
		"puffball": return Color(1.0, 0.8, 0.9)
		"soup_bowl": return Color(0.66, 0.29, 0.28)
	return ITEMS.get(id, {}).get("body", Palette.ACCENT)


static func body_color(paint: String) -> Color:
	return ITEMS.get(paint, ITEMS["classic"]).get("body", Palette.VAN_BODY)


static func cab_color(paint: String) -> Color:
	return ITEMS.get(paint, ITEMS["classic"]).get("cab", Palette.VAN_CAB)


## Pattern on the body rect `r` (the cargo part, behind the cab).
static func draw_pattern(ci: CanvasItem, paint: String, r: Rect2) -> void:
	var p: String = ITEMS.get(paint, {}).get("pattern", "")
	var s := r.size.y
	match p:
		"stars":
			var pts := [Vector2(0.12, 0.2), Vector2(0.35, 0.72), Vector2(0.55, 0.3), Vector2(0.8, 0.78), Vector2(0.88, 0.18), Vector2(0.25, 0.48)]
			for i in pts.size():
				var c: Vector2 = r.position + pts[i] * r.size
				if i % 2 == 0:
					Icons.star(ci, c, s * 0.09, Color("ffe9a8"))
				else:
					ci.draw_circle(c, s * 0.03, Color(1, 1, 1, 0.8))
		"dusk":
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.55), Vector2(r.size.x, r.size.y * 0.3)), Color("ffd27a", 0.75))
			ci.draw_circle(r.position + Vector2(r.size.x * 0.3, r.size.y * 0.5), s * 0.16, Color("fff1b8"))
		"leaves":
			for i in 4:
				var c := r.position + Vector2(r.size.x * (0.15 + i * 0.22), r.size.y * (0.3 if i % 2 == 0 else 0.7))
				ci.draw_colored_polygon(_ellipse(c, s * 0.12, s * 0.06, 0.7 if i % 2 == 0 else -0.7), Color("2f5e5a", 0.6))
		"mosaic":
			var cols := [Color("ff8fb1"), Color("8fd3ff"), Color("ffd166"), Color("a78bfa")]
			var n := 4
			for gx in n:
				for gy in 2:
					var cell := Rect2(r.position + Vector2(gx * r.size.x / n, gy * r.size.y / 2.0), Vector2(r.size.x / n, r.size.y / 2.0)).grow(-s * 0.05)
					DrawUtil.rrect(ci, cell, Color(cols[(gx + gy * 3) % cols.size()], 0.7), s * 0.06)
		"stripes":
			for sy in [-0.12, 0.12]:
				ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * (0.5 + sy) - s * 0.05), Vector2(r.size.x, s * 0.1)), Color.WHITE)


static func _ellipse(c: Vector2, rx: float, ry: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


## Topper on the cab roof, centred on `c`, `s` = the van's width.
static func draw_topper(ci: CanvasItem, id: String, c: Vector2, s: float, t := 0.0) -> void:
	var u := s * 0.3
	match id:
		"drizzlet":
			var col := Color(0.5, 0.78, 0.98)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.5, -0.55) * u, c + Vector2(-1.35, 0) * u, c + Vector2(-0.5, 0.55) * u]), col)
			ci.draw_circle(c, u * 0.82, col)
			ci.draw_circle(c + Vector2(0.15, -0.22) * u, u * 0.18, Color.WHITE)
			ci.draw_circle(c + Vector2(0.15, 0.22) * u, u * 0.18, Color.WHITE)
			ci.draw_circle(c + Vector2(0.2, -0.22) * u, u * 0.09, Color(0.05, 0.04, 0.12))
			ci.draw_circle(c + Vector2(0.2, 0.22) * u, u * 0.09, Color(0.05, 0.04, 0.12))
		"bonkle":
			var col := Color(0.98, 0.66, 0.46)
			for sy in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(0, sy * 0.62) * u, u * 0.5, col)
				ci.draw_circle(c + Vector2(0, sy * 0.62) * u, u * 0.26, col.lightened(0.35))
		"sprout":
			var leaf := Color(0.5, 0.9, 0.74)
			var orbit := PackedVector2Array()
			for k in 25:
				var a := t * 1.5 + TAU * 0.85 * k / 24.0
				orbit.append(c + Vector2(cos(a) * u * 1.1, sin(a) * u * 0.5))
			ci.draw_polyline(orbit, Color(0.74, 0.62, 0.94), u * 0.16, true)
			for sy in [-1.0, 1.0]:
				ci.draw_colored_polygon(_ellipse(c + Vector2(0, sy * u * 0.5), u * 0.55, u * 0.26, sy * 0.9), leaf)
			Icons.star(ci, c, u * (0.55 + 0.08 * sin(t * 5.0)), Color(1.0, 0.9, 0.6), t)
		"rivet":
			DrawUtil.rrect(ci, Rect2(c - Vector2(0.7, 0.7) * u, Vector2(1.4, 1.4) * u), Color(0.75, 0.78, 0.86), u * 0.35)
			ci.draw_circle(c + Vector2(0.25, -0.32) * u, u * 0.2, Color(0.3, 0.95, 0.85))
			ci.draw_circle(c + Vector2(0.25, 0.32) * u, u * 0.2, Color(0.3, 0.95, 0.85))
			ci.draw_line(c + Vector2(-0.4, 0) * u, c + Vector2(-1.2, 0) * u, Color(0.5, 0.52, 0.6), u * 0.14, true)
			ci.draw_circle(c + Vector2(-1.25, 0) * u, u * 0.24, Color(1.0, 0.82, 0.3) if fmod(t, 1.0) < 0.6 else Color(1.0, 0.5, 0.4))
		"puffball":
			var col := Color(1.0, 0.86, 0.93)
			for k in 6:
				var a := TAU * k / 6.0 + t * 0.4
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * u * 0.55, u * 0.5, col)
			ci.draw_circle(c, u * 0.62, Color(1.0, 0.94, 0.97))
		"soup_bowl":
			ci.draw_circle(c, u * 0.95, Color(0.8, 0.76, 0.7))
			ci.draw_circle(c, u * 0.72, Color(0.45, 0.2, 0.32))
			ci.draw_arc(c, u * 0.95, 0, TAU, 24, Color(0.27, 0.36, 0.6), u * 0.12, true)
			DrawUtil.rrect(ci, Rect2(c + Vector2(0.55, -0.22) * u, Vector2(0.5, 0.44) * u), Color(0.66, 0.29, 0.28), u * 0.1)
			ci.draw_circle(c + Vector2(-0.2, -0.2) * u, u * 0.12, Color(0.82, 0.76, 0.56))


## A whole vehicle in place of the van, facing +x, `L` long and `W` wide (the van's own size). Returns where
## the topper goes. `cargo` is the top package's colour (or null for an empty bed).
static func draw_ride(ci: CanvasItem, id: String, L: float, W: float, cargo: Variant, t := 0.0) -> Vector2:
	match id:
		"monster_truck":
			return _monster_truck(ci, L, W, cargo, t)
	return Vector2.ZERO


static func _monster_truck(ci: CanvasItem, L: float, W: float, cargo: Variant, t: float) -> Vector2:
	var red := Color("e8473c")
	var black := Color("23222b")
	var gold := Color("ffc53d")
	var tire := Color("1b1b20")
	var bob := sin(t * 9.0) * W * 0.015
	# Big shadow, then four huge tyres sticking out past the body, with chunky treads and gold hubs.
	DrawUtil.rrect(ci, Rect2(-L * 0.6, -W * 0.82, L * 1.2, W * 1.74), Color(0, 0, 0, 0.18), W * 0.4)
	for sx in [-0.32, 0.32]:
		for sy in [-1.0, 1.0]:
			var c := Vector2(L * sx, sy * W * 0.56)
			var r := Rect2(c - Vector2(L * 0.19, W * 0.25), Vector2(L * 0.38, W * 0.5))
			DrawUtil.rrect(ci, r, tire, W * 0.14)
			for k in 6:
				var x := r.position.x + r.size.x * (k + 0.5) / 6.0
				ci.draw_line(Vector2(x, r.position.y + W * 0.03), Vector2(x, r.end.y - W * 0.03), Color("3a3a44"), W * 0.05)
			ci.draw_circle(c, W * 0.1, gold)
			ci.draw_circle(c, W * 0.045, black)
	# Axles and suspension.
	for sx in [-0.32, 0.32]:
		DrawUtil.rrect(ci, Rect2(Vector2(L * sx - W * 0.05, -W * 0.5), Vector2(W * 0.1, W)), Color("55565f"), W * 0.04)
	# Body, raised (a little bob), the open bed behind and the cab in front.
	var o := Vector2(0, bob)
	DrawUtil.rrect(ci, Rect2(o + Vector2(-L * 0.46, -W * 0.4), Vector2(L * 0.92, W * 0.8)), red.darkened(0.25), W * 0.2)
	DrawUtil.rrect(ci, Rect2(o + Vector2(-L * 0.45, -W * 0.38), Vector2(L * 0.9, W * 0.76)), red, W * 0.2)
	# Gold flame licks down both sides.
	for sy in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		pts.append(o + Vector2(L * 0.3, sy * W * 0.36))
		for k in 5:
			var x := L * (0.2 - k * 0.12)
			pts.append(o + Vector2(x, sy * W * (0.18 if k % 2 == 0 else 0.3)))
		pts.append(o + Vector2(-L * 0.36, sy * W * 0.36))
		ci.draw_colored_polygon(pts, gold)
	# Bed: dark floor, roll bar, the cargo.
	var bed := Rect2(o + Vector2(-L * 0.42, -W * 0.27), Vector2(L * 0.44, W * 0.54))
	DrawUtil.rrect(ci, bed, black.lightened(0.08), W * 0.08)
	ci.draw_line(o + Vector2(L * 0.0, -W * 0.36), o + Vector2(L * 0.0, W * 0.36), Color("c9ccd6"), W * 0.08, true)
	var cargo_c := bed.get_center()
	if cargo is Color:
		DrawUtil.package(ci, cargo_c, W * 0.46, cargo, false)
	# Cab with windscreen, and a white bear paw on the bonnet (Kuma's).
	DrawUtil.rrect(ci, Rect2(o + Vector2(L * 0.04, -W * 0.34), Vector2(L * 0.26, W * 0.68)), black, W * 0.16)
	DrawUtil.rrect(ci, Rect2(o + Vector2(L * 0.2, -W * 0.27), Vector2(L * 0.08, W * 0.54)), Palette.VAN_GLASS, W * 0.06)
	var paw := o + Vector2(L * 0.385, 0)
	ci.draw_circle(paw + Vector2(-W * 0.02, 0), W * 0.085, Color.WHITE)
	for k in 4:
		var a := -1.1 + k * 0.73
		ci.draw_circle(paw + Vector2(cos(a), sin(a)) * W * 0.13 + Vector2(W * 0.02, 0), W * 0.035, Color.WHITE)
	# Roof lights.
	for sy in [-1.0, 1.0]:
		ci.draw_circle(o + Vector2(L * 0.08, sy * W * 0.24), W * 0.05, Color("ffe28a"))
	return o + Vector2(L * 0.12, 0)
