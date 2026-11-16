class_name Version
extends RefCounted
## The game's version, shown as a badge on the title screen, and the patch notes the badge opens (newest
## first). Bump NUMBER and add a release to the top of NOTES with each TestFlight version; the build number
## lives in export_presets.cfg (tools/testflight.sh bumps it).

const NUMBER := "0.7"
const NAME := "The Long Road"
## The iOS build number (export_presets.cfg's application/version), for bug reports. tools/testflight.sh
## keeps the two in step.
const BUILD := 27
## What changed in this build since the last one, for the "new build" card (UpdateCard, via
## tools/release_note.gd). Empty means the card shows the version's top notes instead. Rewrite it for each
## build; clear it when NUMBER goes up.
const BUILD_NOTES := [
	"Headlights: you can only plan a short way ahead of the van now, and it follows your finger. Beat the Baron for brighter lights. (The old way is in Options, Testers.)",
	"Dollaroos are gone for now (nothing to spend them on). The gas station gives gas for watching a (pretend) ad.",
	"Playing and retrying jobs is free. Gas pays for extra help: on a job, one tank makes undos and hints both unlimited for the rest of the level. Tanks refill one an hour. Out of gas? A (pretend) ad gives you two.",
	"Every job from 5 to 100 is new again, and this time they bite: one answer each, and plenty of roads that look right and aren't.",
	"A mind-melter turns up every six jobs or so. If you think one is bugged, the hint will show you it isn't.",
	"The first few after the tutorial are gentle on purpose. It doesn't last.",
	"Jobs you'd already beaten show UPDATED on the map until you beat the new one.",
	"Rate jobs (in Options, and offered after job 5): a five-second card after each win tells Steven how the job went.",
	"Zones open at toll gates on the map.",
	"New road hazards and buildings get a spotlight the first time you meet them.",
	"Presents come wrapped: tap to open. The finish card keeps a tag you can tap to see it again.",
	"Tap to hurry the win. Momentum takes three wins to catch fire. Sam's race car does proper donuts.",
	"Every zone now ends in a boss fight, and the Baron turns up early: beat him on jobs 6 and 11 for two more undos on every job, for good (five in all).",
	"The Baron says what he's after now. On the map, anything you can tap is a pinned ticket (detours and chests too); the rest is pencil.",
	"In the garage, tap your ride to see its win.",
	"Beat a boss and he drops his prizes as he runs: one package each, tap to open.",
	"Every boss now pays out one of Hoardly Inc.'s fleet paint jobs (sixteen of them, Gold Card to The Baron's Own). Bosses you've already beaten pay up too.",
	"The gas gauge sits by Hint and Undo now. Spending a tank takes a short hold: a fuel line fills both buttons, and they go turbo for the rest of the level.",
	"While you plan, the queue shows what the plan will do: a ghost tick on what it delivers, a + on what it picks up. Solid means it really happened.",
	"Houses are drop-offs, shops are pick-ups. Detours fork off the map on their own dirt roads, and the first one shows you around.",
	"Five new rides, early on the road: Howard's Shark, Sheena's Eazy Van, Tay's Dreamsicle, Cole's Classic and Twinkle's Lab. Each has its own win.",
	"Detours never use a building before the main road has taught it. Dailies teach anything new right there, and are hint-free: just you and the map.",
	"Settings moved to the top right, everywhere.",
	"Hoardly Inc. has started advertising. (Options, Extras turns it off.)",
	"Job 4 is new (Save the Road): the quick way wrecks a road you need. Get it wrong and it explains, with a free hint on offer.",
	"Boss rewards open one after another on their own pages; tapping hurries everything along.",
	"Tapping a detour on the map always opens the detour's own card. A new detour draws itself in when it appears.",
	"A tap on an ad lights up Skip (it doesn't skip).",
	"New players find their first headlights in a present on job 2's road (job 1 just says to look out for them).",
	"The daily has its own ribbon on the map: a calendar where your car moves a day along with each solve. It opens after job 11.",
	"You choose what we remind you about. At most one daily reminder a day.",
	"The daily now scores you: badges for a first try, no undos, the shortest route, speed and more, dealt onto your score. Stats shows how everyone did today.",
	"Your daily streak keeps going as long as you solve it, however many tries it takes (six a day).",
	"Zero the Steed joins the rides (job 13). His win is a card game.",
	"Presents are spread out: friends' rides come first, a couple of jobs apart, and the rest follow later.",
	"Boss fights show their loot as items, so it all fits.",
	"A new ride shows in its own colours, and you pick: your paint job, or its Classic look.",
	"New zones now open with a road checkpoint: one short ad, and a tank of gas for your trouble. Watched an ad lately? You're waved through. (Officially, it's the government.)",
	"The daily: six tries a day (Play and Retry show what's left), and still no hints. Your first daily explains the rules.",
	"Sharing a daily shows how each of your tries went, never the answer.",
	"No more stars. Every package you deliver counts, once per job (and every daily and detour too): the total opens zones and unlocks trails and looks. Hints and undos cost gas, nothing else.",
	"The first twenty jobs are re-planned: three practice jobs (5, 8, 10) that teach nothing new, and three weak ones cut. The Baron's early fights are jobs 6 and 11 now; your progress carries over.",
	"Job 7 is new: \"Dead End Drive\". The van makes the mistake for you, then teaches Undo, free undos, and what gas is for (with a free tank).",
	"Hold Undo to keep undoing, faster and faster. Undo shakes when you're plainly stuck; Hint does when you've been staring a while.",
	"The dailies are all new: cleverer, one kind of hazard at most each, and no ice, lockers or roadworks until the main road's taught them.",
	"Daily score: badges land one at a time and the total counts up. A big Get back to work, and a red X. The share card has its buttons on it, and Send opens the iPhone's share sheet.",
	"How everyone did: thirty simulated test drivers have driven every daily, so the numbers mean something from day one.",
	"A new zone's gate stays taped until you're through its checkpoint; then the tape snaps, the fog rolls back, and the van drives in.",
	"The notification question waits a few jobs after your first daily. Hoardly ads end with Acknowledge. It's Full license now.",
	"The jobs button in a job is now a ribbon on the left edge: pull it out and hold Give up to leave.",
	"Jump jets: a present on the ribbon from job 13 (it says so before then). Open it, then hold the jets to skip a job for 1 gas and come back later. Not the Baron's jobs. The old Skip for now button is gone.",
	"Jobs now come in order: you can play one once every job before it is delivered or jumped.",
	"Chests open themselves on the map the moment you earn them, with a better pop. The next-up job on the map is much harder to miss.",
	"Checkpoints say it straight: Watch ad, for the new jobs and a tank. The daily's first pop-up is shorter. Text boxes have a cursor you can see and move.",
	"Job 2 shows its rule now: the first house you pass says Not on top yet! Job 6, the first Baron fight, is tougher than the job before it. Tap the momentum flame to see what it is.",
	"Hints always settle a real choice now (never just the only move there is). At a dead end, Hint says so.",
	"Job 5 gets the Roads don't grow back card too if it goes wrong. A present no longer hides a one-way arrow on job 14.",
	"Gas is scarce now: five spare tanks at most, one per chest or first detour win, two for an ad, and the station only refills an empty tank.",
	"Presents are spread out: the monster truck, then the shark, then a ride every few jobs. Toppers are shelved (taped off in the garage).",
	"Jobs 1 to 8: Hint waves sooner, and goes free if a job is taking too long. The Baron's jobs get one more free hint.",
	"Two houses wanting the same package: the one it's the last chance for gets it. Keys, and parking back at the depot, are explained on the road.",
	"It's jobs, detours and depots everywhere now. Headlights say what they're for: plan N tiles ahead before the van drives.",
	"A retry gives your undos back but not your hints: those are capped per job. A hint that finds a dead end counts as one, and now puts up a DEAD END sign over the way out.",
	"On reward cards, Maybe later sits where Next was, so tapping through never changes your ride by accident. The white flashes between rewards and screens are gone.",
	"Job 7 dims everything but Undo. End of shift points at the depot and the flag. The headlights card is slower and says less.",
	"Jump jets: the row fills the moment you hold it, and says to hold. The chest after job 10 sits on the road, not on job 11.",
	"Job 7's scripted drive looks like one now: black bars and a push in while the van drives itself.",
	"Skipped a present? There's a Wear it button beside it on the finish card. The route preview chip is retired.",
	"Job 2 (now Next In Line) walks you through the line of packages: only the one marked NEXT can be delivered.",
]

const NOTES := [
	{"version": "0.7", "name": "The Long Road", "notes": [
		"50 new jobs (41 to 90) across seven new zones, each with its own mix of mechanics.",
		"New on the road: ice (no turning on it), parcel lockers (they take whatever's on top) and roadworks (open after enough deliveries).",
		"The old Long Haul and Death Valley jobs are now the endgame, 91 to 100. Your progress on them moved with them.",
		"Speedrun mode! Three courses of quick puzzles against the clock. Opens after job 18.",
		"28 new daily puzzles, and each day says how spicy it is.",
		"More treasure chests, every ten jobs, and a Traffic Cone hat at 70.",
		"Somebody else's van has been seen on the map.",
		"Feedback / Bug report in Options: tell Steven what broke, with a screenshot if you like.",
		"The game lets you know when a newer build is waiting in TestFlight.",
		"Each job starts with a hint (the chests at 10 and 20 add one each); a quick (pretend) ad makes them unlimited for that job, or there's an Unlimited hints option.",
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
