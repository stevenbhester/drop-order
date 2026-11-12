class_name Palette
extends RefCounted
## One place for every colour, so the placeholder art reads as a single style.
## The scenery and text colours are static vars so night mode can swap them (apply()); everything reads
## them when it draws, so a redraw picks the new ones up.

static var BG: Color = Color("f3ead9")
static var BOARD_SHADOW: Color = Color(0.36, 0.29, 0.2, 0.18)
static var GRASS: Color = Color("a8d98a")
static var GRASS_ALT: Color = Color("9ed17f")
static var YARD: Color = Color("c4e8a9")
static var TREE: Color = Color("5fae5b")
static var TREE_HI: Color = Color("7cc472")
static var ROAD: Color = Color("596273")
static var ROAD_EDGE: Color = Color("444b59")
static var ROAD_MARK: Color = Color(1, 1, 1, 0.32)
const DEPOT := Color("ffd166")
const PATH := Color(1, 1, 1, 0.94)
const HINT := Color("ffc53d")
const CRASH := Color("ff3b3b")
const STAR_GOLD := Color("ffc53d")
const STAR_EDGE := Color("e0941a")
static var TRAIL: Color = Color(0.12, 0.13, 0.17, 0.7)
const ARROW := Color(1, 0.97, 0.88, 0.95)
static var RAIL: Color = Color("efe7d8")
static var BRIDGE_SHADOW: Color = Color(0, 0, 0, 0.3)
static var BRIDGE_DECK: Color = Color("6a7487")
static var HUB: Color = Color("48506a")
static var TEXT: Color = Color("3b3346")
static var TEXT_SOFT: Color = Color(0.23, 0.2, 0.27, 0.6)
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


## Each package colour is a class of parcel (see DrawUtil.parcel).
const KINDS := {"red": "gift", "yellow": "biohazard", "blue": "caution", "purple": "mystery", "green": "organic", "orange": "hot"}


## The class of a package drawn in `col` (matched against the package colours), or "".
static func kind_of(col: Color) -> String:
	for n in PKG:
		var p: Color = PKG[n]
		if absf(p.r - col.r) < 0.01 and absf(p.g - col.g) < 0.01 and absf(p.b - col.b) < 0.01:
			return KINDS.get(n, "")
	return ""


static func confetti() -> Array:
	return PKG.values() + [Color.WHITE]


## Buttons, chips and cards: the surface they're drawn on, its pressed/disabled shade, and its lip.
static var SURFACE: Color = Color.WHITE
static var SURFACE_DIM: Color = Color("ddd6ca")
static var CARD: Color = Color("fffaf0")
static var night := false

const _DAY := {
	"BG": Color("f3ead9"), "BOARD_SHADOW": Color(0.36, 0.29, 0.2, 0.18), "GRASS": Color("a8d98a"), "GRASS_ALT": Color("9ed17f"),
	"YARD": Color("c4e8a9"), "TREE": Color("5fae5b"), "TREE_HI": Color("7cc472"), "ROAD": Color("596273"),
	"ROAD_EDGE": Color("444b59"), "ROAD_MARK": Color(1, 1, 1, 0.32), "TRAIL": Color(0.12, 0.13, 0.17, 0.7),
	"RAIL": Color("efe7d8"), "BRIDGE_SHADOW": Color(0, 0, 0, 0.3), "BRIDGE_DECK": Color("6a7487"), "HUB": Color("48506a"),
	"TEXT": Color("3b3346"), "TEXT_SOFT": Color(0.23, 0.2, 0.27, 0.6),
	"SURFACE": Color.WHITE, "SURFACE_DIM": Color("ddd6ca"), "CARD": Color("fffaf0"),
}
## Night: moonlit lawns, darker asphalt, cards like slate, warm text.
const _NIGHT := {
	"BG": Color("1b1838"), "BOARD_SHADOW": Color(0, 0, 0, 0.35), "GRASS": Color("2f5a4b"), "GRASS_ALT": Color("2a5244"),
	"YARD": Color("3b6b58"), "TREE": Color("1f4436"), "TREE_HI": Color("2c5a48"), "ROAD": Color("3a4052"),
	"ROAD_EDGE": Color("262a37"), "ROAD_MARK": Color(1, 0.95, 0.8, 0.28), "TRAIL": Color(0.05, 0.05, 0.08, 0.7),
	"RAIL": Color("8b8fa6"), "BRIDGE_SHADOW": Color(0, 0, 0, 0.45), "BRIDGE_DECK": Color("4a5166"), "HUB": Color("2d3245"),
	"TEXT": Color("f3ead9"), "TEXT_SOFT": Color(0.95, 0.92, 0.85, 0.62),
	"SURFACE": Color("343050"), "SURFACE_DIM": Color("2a2742"), "CARD": Color("2b2747"),
}


static func apply(at_night: bool) -> void:
	night = at_night
	var c: Dictionary = _NIGHT if at_night else _DAY
	BG = c["BG"]
	BOARD_SHADOW = c["BOARD_SHADOW"]
	GRASS = c["GRASS"]
	GRASS_ALT = c["GRASS_ALT"]
	YARD = c["YARD"]
	TREE = c["TREE"]
	TREE_HI = c["TREE_HI"]
	ROAD = c["ROAD"]
	ROAD_EDGE = c["ROAD_EDGE"]
	ROAD_MARK = c["ROAD_MARK"]
	TRAIL = c["TRAIL"]
	RAIL = c["RAIL"]
	BRIDGE_SHADOW = c["BRIDGE_SHADOW"]
	BRIDGE_DECK = c["BRIDGE_DECK"]
	HUB = c["HUB"]
	TEXT = c["TEXT"]
	TEXT_SOFT = c["TEXT_SOFT"]
	SURFACE = c["SURFACE"]
	SURFACE_DIM = c["SURFACE_DIM"]
	CARD = c["CARD"]
	Backdrop.apply(at_night)
