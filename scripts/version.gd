class_name Version
extends RefCounted
## The game's version, shown as a badge on the title screen, and the patch notes the badge opens (newest
## first). Bump NUMBER and add a release to the top of NOTES with each TestFlight version; the build number
## lives in export_presets.cfg (tools/testflight.sh bumps it).

const NUMBER := "0.7"
const NAME := "The Long Road"
## The iOS build number (export_presets.cfg's application/version), for bug reports. tools/testflight.sh
## keeps the two in step.
const BUILD := 21
## What changed in this build since the last one, for the "new build" card (UpdateCard, via
## tools/release_note.gd). Empty means the card shows the version's top notes instead. Rewrite it for each
## build; clear it when NUMBER goes up.
const BUILD_NOTES := [
	"Trails! Unlock new things for the road to turn into behind you with stars: a river, mountains, hearts, meteors, lava and zombies.",
	"Drop-offs stand on a bullseye in their colour, so they're easy to tell from pickups.",
]

const NOTES := [
	{"version": "0.7", "name": "The Long Road", "notes": [
		"50 new levels (41 to 90) across seven new zones, each with its own mix of mechanics.",
		"New on the road: ice (no turning on it), parcel lockers (they take whatever's on top) and roadworks (open after enough deliveries).",
		"The old Long Haul and Death Valley levels are now the endgame, 91 to 100. Your progress on them moved with them.",
		"Speedrun mode! Three courses of quick puzzles against the clock. Opens after level 18.",
		"28 new daily puzzles, and each day says how spicy it is.",
		"More treasure chests, every ten levels, and a Traffic Cone hat at 70.",
		"Somebody else's van has been seen on the map.",
		"Feedback / Bug report in Options: tell Steven what broke, with a screenshot if you like.",
		"The game lets you know when a newer build is waiting in TestFlight.",
		"3 hints per level; a quick (pretend) ad makes them unlimited for that level, or there's an Unlimited hints option.",
		"The way on to the next part is a road off the map, with a gate that opens once everything's delivered.",
	]},
	{"version": "0.6", "name": "Road Signs", "notes": [
		"Forgot what a symbol means? Tap it (or hold it) for a one-line reminder with a little picture.",
		"Pickups look nothing like houses now: a dark loading dock in a chunky dashed outline, big bouncing packages, and +N for how many they give.",
		"Pickups empty out and show a tick once collected (and fade while your planned route is going to take them).",
		"Package queue: Auto (the new default) puts it wherever gives the map the most room. You can still pin it left, right, top or bottom.",
		"Hints don't restart anything: at a dead end they tell you so (Retry to start over), and cost no star.",
		"Side roads hand out power-ups once a day: spare gas tanks (used only when you run dry), or free hints or undos for a while.",
	]},
	{"version": "0.5", "name": "Side Roads", "notes": [
		"Mega routes: big deliveries in parts. Clear a part, drive into its exit and the map pans on to the next. Saved as you go. Twin Towns (2 parts) and The Big Map (4) each win a paint job.",
		"Package trail: the next three packages follow the van on little drones (Options, Package trail).",
		"Side roads! Four detours branch off the road trip, each with a twist: a tiny tank, a melting clock, no brakes, thick fog.",
		"Beat a side road to win its ride: Zippy Scooter, Mr. Frosty, Rocket Van and Hover Van.",
		"Treasure chests at levels 10, 20, 30, 40 and 50: gas, Dollaroos, and sometimes a hat (Party Hat, Hard Hat, Gold Crown).",
		"Paint jobs work on every ride now, Kuma's Monster Truck included.",
		"Colorblind mode (aka Paul mode): bold marks on every package, and a matching sign on every building and gate.",
		"The side chute reads like a puzzle game's next column: next on top, the rest below. Its boxes stand tall, so the board gets more room.",
		"Every colour is its own kind of place: a home, a lab, a factory, a tower, a barn and a diner.",
		"Much bigger ×N badges on buildings and warehouses.",
	]},
	{"version": "0.4", "name": "The Chute Update", "notes": [
		"Your load rides in a package chute now. Pick left, right, top or bottom in Options.",
		"Every colour is its own kind of package: gifts, biohazard, caution, mystery, organic and hot stuff.",
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
