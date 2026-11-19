#!/usr/bin/env python3
"""Picks the best candidate for every slot of the plan and writes levels/levels.json.

  python3 tools/engine/assemble.py [--dry] [-v] [slots...]
  (slots given: only those take a new candidate; every other level stays exactly as it is.)

Reads tools/level_plan.json, the candidates tools/engine/gen_all.py left in build/engine/, and the
current levels.json (for titles, hints, challenge flags, presents, and the levels the plan keeps). A slot
with no candidate that passes keeps its current level and is listed at the end, so nothing is ever lost.
"""
import glob, json, os, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
plan = json.load(open(os.path.join(ROOT, "tools", "level_plan.json")))["slots"]
cur = json.load(open(os.path.join(ROOT, "levels", "levels.json")))["levels"]
dry = "--dry" in sys.argv
verbose = "-v" in sys.argv
only = {int(a) for a in sys.argv[1:] if a.isdigit()}
NAMES = {"r": "red", "b": "blue", "g": "green", "y": "yellow", "p": "purple", "o": "orange"}

# The line under each level's name. Not clues: a joke, a bit of the road, or a glimpse of the Baron (Hoardly
# Inc. is buying up the city, and we're the last independent courier in it). The rules themselves are taught
# by the spotlight on the level that brings each one in (scripts/spotlight.gd), and by tapping a symbol.
HINTS = {
    6: "Rush hour. The first house you see isn't always first.",
    7: "Not every street goes somewhere.",
    9: "Someone ordered two of the same thing. Again.",
    11: "Bulk buyers tip in exposure.",
    12: "Hoardly Inc. bought the sign shop. Signs are now one-way.",
    13: "Every house here swears it was first in line.",
    14: "Downtown traffic, uptown attitude.",
    15: "Over, under, over. The city planners had a long lunch.",
    16: "Built by the lowest bidder. Guess who bid.",
    17: "Locals call it the Spaghetti. Nobody knows why.",
    18: "Rainbow Row: three colours, strong opinions.",
    19: "The scenic route is the only route.",
    20: "The last mile is always the longest.",
    21: "A little shop that refuses to sell to Hoardly.",
    22: "Fresh stock every morning. Mind where it lands.",
    23: "Two shops, one grudge.",
    24: "High Street, low patience.",
    25: "Toll booths: the Baron's favourite invention.",
    26: "Exact change only. Hoardly keeps the change.",
    27: "The locksmith's on holiday. Improvise.",
    28: "Papers, please. The papers are packages.",
    29: "Clock out on time for once.",
    30: "Home in time for dinner. Allegedly.",
    31: "Time and a half. Mostly the half.",
    32: "The night shift sees everything.",
    33: "The sorting office got a new toy.",
    34: "Shuffle up and deal.",
    35: "Somebody moved the cheese. And the parcels.",
    36: "The Baron's sorting machine has opinions.",
    37: "Rush order. Everything's a rush order.",
    38: "Mixed bag, mixed feelings.",
    39: "Doors open at six. So does the chaos.",
    40: "Everyone wants it by Christmas. Everyone.",
    41: "Black ice. White knuckles.",
    42: "Bundle up. The van won't.",
    43: "Plough first, deliver later. Or the other way.",
    44: "Don't sneeze.",
    45: "Warm hands, cold roads.",
    46: "Somebody stole the street signs. Guess who.",
    47: "You can't see a thing. Neither can they.",
    48: "The tide goes out. The parcels don't.",
    49: "Fresh fish, fresher gossip.",
    50: "The keeper says she saw the Baron's yacht.",
    51: "The gulls know the route better than you.",
    52: "The ferry waits for no one. Except the Baron.",
    53: "Déjà vu, with seagulls.",
    54: "Batten down the parcels.",
    55: "Lockers: the Baron calls them 'the competition'.",
    56: "Insert coin. Get it back later. Maybe.",
    57: "Night owls tip in riddles.",
    58: "Last train's leaving. The parcels are staying.",
    59: "It kept your dollar. It'll keep your package, for a while.",
    60: "Sing it like you mean it.",
    61: "The neon never sleeps. Neither will you.",
    62: "One bad apple. Several bad turns.",
    63: "The cider's strong. The roads are stronger.",
    64: "The scarecrow saw the whole thing.",
    65: "Easy does it. Does it?",
    66: "Pick of the patch.",
    67: "No return address. No return.",
    68: "A harvest moon brings out the Baron's trucks.",
    69: "Hoardly Roadworks: we dig so you can't.",
    70: "Diversion ahead. And behind.",
    71: "Rush hour. Again. Still.",
    72: "Cones are temporary. The Baron is forever.",
    73: "That other van is a Hoardly van. Don't wave.",
    74: "Take five. Then take twelve corners.",
    75: "Gridlock, deluxe edition.",
    76: "Sand in the gearbox, ice on the road.",
    77: "Flash flood warning: also a parcel warning.",
    78: "Tumbleweeds have the right of way.",
    79: "The cactus signed for it.",
    80: "Lightning never strikes twice. Couriers do.",
    81: "Shade and a short route. Short-ish.",
    82: "Is that the depot, or a mirage?",
    83: "The Baron's thunder rolls in from the east.",
    84: "The view's better up here. The roads aren't.",
    85: "The penthouse has its own postcode.",
    86: "Big pick-ups (+N) hand over everything at once. Pack smart.",
    87: "The air's thin. The margins are thinner.",
    88: "Window washers: the only witnesses.",
    89: "Mile Zero. You've driven a few more than that.",
    90: "Top of the world. Bottom of the Baron's list.",
    91: "One needle, a lot of hay.",
    92: "Last orders. Make them count.",
    93: "Three neighbourhoods, one shift, no shortcuts.",
    94: "Night freight. The Baron's trucks run silent.",
    95: "The grand tour of everything you know.",
    96: "Big pick-ups (+N) load everything at once. Mind the stack.",
    97: "Peak season: every parcel is someone's emergency.",
    98: "Overstocked, overbooked, over it.",
    99: "Cyber Monday. The Baron's favourite holiday.",
    100: "The last mile. Bring it home, driver.",
}

# Titles that no longer suit what the slot holds.
TITLES = {13: "Second Thoughts", 55: "Park It"}

def passes(s, c):
    """Does a candidate still meet today's plan? Returns '' or the reason it doesn't."""
    m, a = c["m"], s["args"]
    who = s["who"]
    if not c["need_ok"]: return "mechanic idle"
    if not (a.get("rmin", 1) <= m["routes"] <= a["rmax"]): return "routes %d" % m["routes"]
    if m["ptries"] < a["pelo"] * 0.85: return "too few plans to work through (%.1f)" % m["ptries"]
    if m["ptries"] > a["pehi"] * 1.25: return "too many plans to work through (%.1f)" % m["ptries"]
    if m["pnodes"] < a["pnmin"] * 0.8: return "too little to hold (%d partial plans)" % m["pnodes"]
    if m["pfirst"] > a["pfmax"] + 0.08: return "first plan right %.0f%%" % (m["pfirst"] * 100)
    if m["tries3"][who] > a["ehi"] * 1.3: return "a wall for its player (%.1f drives)" % m["tries3"][who]
    if m["nodes"] > a["nodes_max"] * 1.5: return "solver cost %d" % m["nodes"]
    if s.get("gift") and "gift" not in c: return "no spot for the present"
    if m["over"] or m["capped"]: return "too big to measure"
    return ""

def candidates():
    out = {}
    for f in glob.glob(os.path.join(ROOT, "build", "engine", "slot_*.txt")):
        for line in open(f):
            if line.startswith("CAND "):
                c = json.loads(line[5:])
                out.setdefault(int(c["slot"]), []).append(c)
    for n in out:
        out[n].sort(key=lambda c: -c["fit"])
    return out

def town(c):
    return "/".join(" ".join("#" if t in "#S+@~^>v<" or t[0] in "=c" else "." for t in row.split(" ")) for row in c["map"].split("/"))

def fmt_level(d):
    keys = ["title", "hint", "no_revisit", "challenge", "return", "flavor"]
    parts = []
    for k in keys:
        if k in d:
            parts.append('      %s: %s' % (json.dumps(k), json.dumps(d[k], ensure_ascii=False)))
    width = max(len(t) for row in d["map"] for t in row.split())
    rows = ['        "%s"' % " ".join(t.ljust(width) for t in row.split()).rstrip() for row in d["map"]]
    parts.append('      "map": [\n%s\n      ]' % ",\n".join(rows))
    if "gift" in d:
        parts.append('      "gift": {"at": [%d, %d], "item": %s}' % (d["gift"]["at"][0], d["gift"]["at"][1], json.dumps(d["gift"]["item"])))
    parts.append('      "stack": [%s]' % ", ".join(json.dumps(c) for c in d["stack"]))
    return "    {\n" + ",\n".join(parts) + "\n    }"

cands = candidates()
levels, missing, picked, seen = [], [], {}, set()
for s in plan:
    n = s["n"]
    old = cur[n - 1]
    if s.get("keep"):
        d = dict(old)
        d["flavor"] = old.get("flavor", "intro")
        levels.append(d)
        continue
    if only and n not in only:
        levels.append(dict(old))
        continue
    pick, why = None, {}
    # The flavour is a wish: take the best candidate that has it, else the best that passes everything else.
    for want_flavor in (True, False):
        for c in cands.get(n, []):
            r = passes(s, c)
            if not r and town(c) in seen:
                r = "town already used"
            if not r and want_flavor and not c["flavor_ok"]:
                r = "flavour"
            if r:
                if want_flavor: why[r] = why.get(r, 0) + 1
                continue
            pick = c
            break
        if pick: break
    if pick is None:
        missing.append((n, s["tier"], s["flavor"], len(cands.get(n, [])), why))
        levels.append(dict(old))
        continue
    seen.add(town(pick))
    picked[n] = pick
    d = {"title": TITLES.get(n, old["title"])}
    hint = HINTS.get(n, "")
    if hint:
        d["hint"] = hint
    d["no_revisit"] = True
    if old.get("challenge"):
        d["challenge"] = True
    if pick["ret"]:
        d["return"] = True
    d["flavor"] = s["flavor"] if s["tier"] != "melter" else "melter"
    d["map"] = pick["map"].split("/")
    if s.get("gift"):
        d["gift"] = {"at": pick["gift"], "item": s["gift"]}
    d["stack"] = [NAMES[x] for x in pick["stack"] if x in NAMES]
    levels.append(d)

text = '{\n  "levels": [\n' + ",\n".join(fmt_level(d) for d in levels) + "\n  ]\n}\n"
json.loads(text)
if not dry:
    open(os.path.join(ROOT, "levels", "levels.json"), "w").write(text)
    # A level whose layout changed gets a new version number (sent with ratings).
    import subprocess
    godot = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
    out = subprocess.run([godot, "--headless", "--path", ROOT, "--script", "res://tools/level_versions.gd"], capture_output=True, text=True).stdout
    print("\n".join(l for l in out.splitlines() if l.startswith("level versions")))
if verbose:
    for s in plan:
        c = picked.get(s["n"])
        if c:
            m = c["m"]
            print("%3d %-7s %-8s%s fit %5.2f routes %d | plan: partial %3d wrong %2d tries %5.2f first %3.0f%% | road tries %5.1f | picks %d doors1 %d/%d last %d pk %2d len %2d quiet %2d nodes %4d  %s" % (
                s["n"], s["tier"], s["flavor"], " " if c["flavor_ok"] else "*", c["fit"], m["routes"], m["pnodes"], m["plans"] - 1, m["ptries"], m["pfirst"] * 100,
                m["tries3"][s["who"]], m["picks"], m["doors1"], m["houses"], m["last_doors"], m["packages"], m["len"], m["quiet"], m["nodes"], c["matters"]))
print("%d levels %s. New: %d. No candidate passed (current level left in): %d" % (
    len(levels), "checked (dry run)" if dry else "written", len(picked), len(missing)))
for n, tier, fl, k, why in missing:
    print("   slot %d (%s %s): %d candidates; rejected for: %s" % (n, tier, fl, k, why or "none made"))
