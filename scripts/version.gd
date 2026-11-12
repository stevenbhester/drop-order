class_name Version
extends RefCounted
## The game's version, shown as a badge on the title screen, and the patch notes the badge opens (newest
## first). Bump NUMBER and add a release to the top of NOTES with each TestFlight version; the build number
## lives in export_presets.cfg (tools/testflight.sh bumps it).

const NUMBER := "0.4"
const NAME := "The Chute Update"

const NOTES := [
	{"version": "0.4", "name": "The Chute Update", "notes": [
		"Your load rides in a package chute now. Pick left, right, top or bottom in Options.",
		"Every colour is its own kind of package (gifts, biohazard, caution, mystery, organic, hot stuff) and its own kind of place: a home, a lab, a factory, a tower, a barn, a diner.",
		"Deliveries drop out of the chute into the van, then fly to the house.",
		"Challenge levels! Eight extra-spicy levels get hazard tape on the map, a big intro, and 500 Dollaroos for crushing them.",
		"The start is a pit stop. A checkered flag in the chute means you finish back there.",
		"Depots show their stock bouncing inside. The houses next in line glow in their colour.",
		"The thinking bubble is off the map and off by default (Options, Route preview).",
		"This badge. Hi!",
	]},
	{"version": "0.3", "name": "Before that", "notes": [
		"Options: night mode, play sideways, sound and haptics sliders, and a left-hand D-pad.",
		"A bigger D-pad that clicks, sinks and buzzes like real buttons. Hint takes two taps there.",
		"Death Valley: five insane warehouse levels (46 to 50). Big loads scroll.",
		"The road-trip map, daily puzzles with streaks, and the Garage (hi, Kuma's Monster Truck).",
		"The road tears up behind you, and the van brakes before it crashes.",
		"Gas, hints and (pretend) Dollaroos.",
	]},
]


## Is there a version the player hasn't opened the notes for yet?
static func unseen() -> bool:
	return Progress.seen_version != NUMBER
