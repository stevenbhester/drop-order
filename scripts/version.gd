class_name Version
extends RefCounted
## The game's version, shown as a badge on the title screen, and the patch notes the badge opens (newest
## first). Bump NUMBER and add a release to the top of NOTES with each TestFlight version; the build number
## lives in export_presets.cfg (tools/testflight.sh bumps it).

const NUMBER := "0.7a"
const NAME := "Park & Ride"
## The iOS build number (export_presets.cfg's application/version), for bug reports. tools/testflight.sh
## keeps the two in step.
const BUILD := 34
## What changed in this build since the last one, for the "new build" card (UpdateCard, via
## tools/release_note.gd). Empty means the card shows the version's top notes instead. Rewrite it for each
## build; clear it when NUMBER goes up.
const BUILD_NOTES := []

const NOTES := [
	{"version": "0.7a", "name": "Park & Ride", "notes": [
		"Parking lockers! Stop beside a P and tap it to stash your top package. Swing back later and tap again to grab it. Jobs 55 to 83 are brand new to go with them.",
		"The title screen has a theme tune, and the little street is its rhythm section: every house is a note, the bridges and the gate are the percussion, and each package lands on the beat.",
		"Background music everywhere else: up before everyone, watching the sun come up on a big day. It builds a layer at a time and steps aside for ads and the Baron. (Music has its own switch in Options.)",
		"Every ride has its own swagger: Zoom! with Zero, Dive in! with the shark, Hop in! with Violet's Tower. Win, and the camera pushes in on the celebration.",
		"No more guessing who gets the package: two houses of one colour never share a stop, and neither do a pickup and a house of its colour. And the van pulls up to the curb, so every package lands right where it belongs.",
		"Awaiting pickup: packages still out there sit beside the chute, ×N per colour. Empty the van with some left and it flashes red at you.",
		"The daily got serious: a clock that runs across every try, a Rules button where Hint used to be, undos per try (gas can't buy more), a Stats button with a live chart, and a heads-up on your last three tries.",
		"All 38 dailies are new, and most have more than one way through. Find a way, then check your badges: Straight shot says whether you found the shortest. Mild isn't a freebie any more.",
		"The Baron learned some manners: he lets you read his parting shot, skips the grand entrance when you retry, and stops standing on your next package.",
		"Dead-end hints pin the last spot you could still win from, not the start of your whole drag. One Undo lands you there.",
		"Put on a new ride or paint job and you get a green Continue, straight back to the road. Changed your mind? Undo on its tile (or Wear it, if you said Maybe later).",
		"Trails get their own buttons: Move mountains, Make a splash, Raise the dead, Make it rain. The garage says where to find each thing in two short lines, with a progress bar.",
		"Night mode, properly: dark fog over locked zones, cream text on dark bubbles everywhere, and greyed-out buttons and paint names you can actually read.",
		"Finish card glow-up: no gas pump peeking through Replay, solid reward cards, and a new ride waits to be unwrapped before it shows off.",
		"Next to a full locker with every road gone? You're not stuck: tap the locker. A quick tap always uses it; hold to read what it is. Hints show a finger pressing it.",
		"Headlights on? Undo back past a park and your package stays parked.",
		"Stuck says more: \"Stuck! 2 packages left.\" or \"Can't reach the exit.\"",
		"Unlimited gas flips hints and calls together, never just one. The daily score card's X just closes it.",
		"Vibrations calm down when you reopen the game (one tester's phone buzzed nonstop). Play stats now note which notifications you picked.",
	]},
	{"version": "0.7", "name": "The Long Road", "notes": [
		"50 new jobs (41 to 90) across seven new zones, each with its own mix of mechanics.",
		"New on the road: ice (no turning on it), parcel lockers (they take whatever's on top) and roadworks (open after enough deliveries).",
		"The old Long Haul and Death Valley jobs are now the endgame, 91 to 100. Your progress on them moved with them.",
		"Speedrun mode! Three courses of quick puzzles against the clock. Opens after job 18.",
		"28 new daily puzzles, and each day says how spicy it is.",
		"More treasure chests, every ten jobs, and a new ride every few jobs.",
		"Somebody else's van has been seen on the map.",
		"Feedback / Bug report in Options: tell Steven what broke, with a screenshot if you like.",
		"The game lets you know when a newer build is waiting in TestFlight.",
		"Hints and calls are free while you learn. After job 11 the Baron meters them: a few to carry from job to job, more from chests and wins, and gas for the rest.",
		"The way on to the next part is a road off the map, with a gate that opens once everything's delivered.",
	]},
	{"version": "0.6", "name": "Road Signs", "notes": [
		"Forgot what a symbol means? Tap it (or hold it) for a one-line reminder with a little picture.",
		"Pickups look nothing like houses now: a dark loading dock in a chunky dashed outline, big bouncing packages, and +N for how many they give.",
		"Pickups empty out and show a tick once collected (and fade while your planned route is going to take them).",
		"Package queue: Auto (the new default) puts it wherever gives the map the most room. You can still pin it left, right, top or bottom.",
		"Hints don't restart anything: at a dead end they tell you so (Retry to start over), and cost no star.",
		"Detours hand out power-ups once a day: spare gas tanks (used only when you run dry), or free hints or undos for a while.",
	]},
	{"version": "0.5", "name": "Side Roads", "notes": [
		"Mega routes: big deliveries in parts. Clear a part, drive into its exit and the map pans on to the next. Saved as you go. Twin Towns (2 parts) and The Big Map (4) each win a paint job.",
		"Package trail: the next three packages follow the van on little drones (Options, Package trail).",
		"Detours! Four detours branch off the road trip, each with a twist: a tiny tank, a melting clock, no brakes, thick fog.",
		"Beat a detour to win its ride: Zippy Scooter, Mr. Frosty, Rocket Van and Hover Van.",
		"Treasure chests at jobs 10, 20, 30, 40 and 50: gas, Dollaroos, and sometimes a hat (Party Hat, Hard Hat, Gold Crown).",
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
		"Challenge jobs! Eight extra-spicy jobs get hazard tape on the map, a big intro, and 500 Dollaroos for crushing them.",
		"The start is a depot. A checkered flag in the chute means you finish back there.",
		"Depots show their stock bouncing inside. The houses next in line glow in their colour.",
		"The thinking bubble is off the map and off by default (Options, Route preview).",
		"This badge. Hi!",
	]},
	{"version": "0.3", "name": "Before that", "notes": [
		"Options: night mode, play sideways, sound and haptics sliders, and a left-hand D-pad.",
		"A bigger D-pad that clicks, sinks and buzzes like real buttons. Hint takes two taps there.",
		"Death Valley: five insane warehouse jobs (46 to 50). Big loads scroll.",
		"The road-trip map, daily puzzles with streaks, and the Garage (hi, Kuma's Monster Truck).",
		"The road tears up behind you, and the van brakes before it crashes.",
		"Gas, hints and (pretend) Dollaroos.",
	]},
]


## Is there a version the player hasn't opened the notes for yet?
static func unseen() -> bool:
	# (Nothing's new to someone who's only just arrived: no jobs done, no notes ever opened.)
	if Progress.seen_version == "" and Progress.completed.is_empty():
		return false
	return Progress.seen_version != NUMBER
