class_name Palette
extends RefCounted
## One place for every colour, so the placeholder art reads as a single style.

const BG := Color("f3ead9")
const BOARD_SHADOW := Color(0.36, 0.29, 0.2, 0.18)
const GRASS := Color("a8d98a")
const GRASS_ALT := Color("9ed17f")
const YARD := Color("c4e8a9")
const TREE := Color("5fae5b")
const TREE_HI := Color("7cc472")
const ROAD := Color("596273")
const ROAD_EDGE := Color("444b59")
const ROAD_MARK := Color(1, 1, 1, 0.32)
const DEPOT := Color("ffd166")
const PATH := Color(1, 1, 1, 0.94)
const TEXT := Color("3b3346")
const TEXT_SOFT := Color(0.23, 0.2, 0.27, 0.6)
const ACCENT := Color("ff7a59")
const GOOD := Color("35c27a")
const CHECK := Color("35c27a")
const VAN_BODY := Color("fffaf2")
const VAN_CAB := Color("3b4a6b")
const VAN_GLASS := Color("9cc4ea")
const WHEEL := Color("2b2f38")

const PKG := {
	"red": Color("ff5d5d"),
	"blue": Color("4d8dff"),
	"green": Color("2fbf71"),
	"yellow": Color("ffc53d"),
	"purple": Color("a26bf5"),
	"orange": Color("ff9233"),
}


static func pkg(name: String) -> Color:
	return PKG.get(name, Color.MAGENTA)


static func confetti() -> Array:
	return PKG.values() + [Color.WHITE]
