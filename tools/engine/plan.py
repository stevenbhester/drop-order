#!/usr/bin/env python3
"""Writes tools/level_plan.json: what each of the 100 levels is for, and what the generator is asked for.

The plan is the design. Each slot has a flavour (what kind of puzzle), a tier (how hard), the mechanics it
may use and the ones that must matter, a size, and the player it's scored for. tools/engine/gen_all.py
fills the slots with `build/lm gen`; design/level_engine.md explains the ideas.

  python3 tools/engine/plan.py
"""
import json, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
levels = json.load(open(os.path.join(ROOT, "levels", "levels.json")))["levels"]

# n: (flavour, tier, mechanics, must-matter)
# Tiers: easy (a breather, but it costs a try), medium, hard, melter (a mind-melter: small, plain-looking,
# one answer, the natural lines all fail), end (the last ten: bigger maps).
# Mechanics: 1w one-way, br bridge, xN bigger orders, pick pickups, wh warehouses, gate, hub, ice, lock
# lockers, works roadworks, R return to the depot.
T = {
  1: ("keep", "easy", "", ""), 2: ("keep", "easy", "", ""), 3: ("keep", "easy", "", ""), 4: ("keep", "easy", "", ""),
  # The Suburbs. 5, 8 and 10 are practice (nothing new: what was just taught, used); 7 is hand-made (the Undo
  # and gas lesson, scripts/undo_lesson.gd). All four are kept as they are.
  5: ("longcon", "easy", "", ""), 6: ("decoy", "easy", "", ""), 7: ("keep", "easy", "", ""), 8: ("keep", "easy", "", ""),
  9: ("intro", "easy", "xN", "multi"), 10: ("keep", "easy", "xN", "multi"),
  11: ("twodoor", "medium", "xN", "multi"),
  # Downtown
  12: ("intro", "easy", "1w", "oneway"),
  13: ("decoy", "melter", "1w", "oneway"),
  14: ("longcon", "medium", "1w xN", ""),
  15: ("intro", "easy", "br", "bridge"),
  16: ("gauntlet", "hard", "br", "bridge"),
  # Sunflower Farms
  17: ("breather", "easy", "1w br", ""),
  18: ("longcon", "melter", "1w", ""),
  19: ("knot", "medium", "", ""),
  20: ("knot", "hard", "1w br xN", ""),
  # The City
  21: ("intro", "easy", "pick", "pickup"),
  22: ("restock", "medium", "pick", "pickup"),
  23: ("twodoor", "melter", "pick", "pickup"),
  24: ("decoy", "easy", "1w pick", ""),
  25: ("intro", "easy", "gate", "gate"),
  26: ("twodoor", "medium", "1w gate", "gate"),
  27: ("restock", "medium", "gate pick", "pickup"),
  28: ("gauntlet", "hard", "1w gate xN", "gate"),
  29: ("intro", "easy", "R", ""),
  30: ("twodoor", "easy", "R", "return"),
  31: ("decoy", "melter", "pick R", ""),
  32: ("longcon", "hard", "1w R", ""),
  33: ("intro", "easy", "hub", "hub"),
  34: ("sorter", "medium", "hub", "hub"),
  35: ("twodoor", "medium", "hub pick", "pickup"),
  36: ("sorter", "hard", "gate hub", "hub"),
  37: ("decoy", "easy", "gate pick R", ""),
  38: ("twin", "medium", "br hub pick", ""),
  39: ("twodoor", "melter", "pick", ""),
  40: ("gauntlet", "hard", "gate hub pick R", ""),
  # Frostbite Pass
  41: ("intro", "easy", "1w ice", "ice"),
  42: ("decoy", "easy", "1w ice xN", "ice"),
  43: ("twodoor", "medium", "1w ice xN", "ice"),
  44: ("longcon", "melter", "ice pick", ""),
  45: ("breather", "easy", "ice xN", ""),
  46: ("decoy", "medium", "1w ice xN", "ice"),
  47: ("longcon", "hard", "1w ice xN", "ice"),
  # Harbour Lights
  48: ("restock", "medium", "ice pick", "ice pickup"),
  49: ("twodoor", "easy", "br ice pick", ""),
  50: ("decoy", "melter", "ice pick", ""),
  51: ("longcon", "medium", "ice pick", "pickup"),
  52: ("twodoor", "medium", "br ice pick", "pickup"),
  53: ("breather", "easy", "br ice pick", ""),
  54: ("knot", "hard", "br ice pick", "ice pickup"),
  # Neon Alley
  55: ("intro", "easy", "1w lock", "locker"),
  56: ("park", "medium", "gate lock", "locker"),
  57: ("twodoor", "melter", "lock", ""),
  58: ("park", "medium", "1w gate lock", "locker"),
  59: ("twodoor", "medium", "gate lock", "locker"),
  60: ("breather", "easy", "1w gate lock", ""),
  61: ("gauntlet", "hard", "1w gate lock", "gate locker"),
  # Orchard Hills
  62: ("decoy", "medium", "lock R", "locker"),
  63: ("restock", "melter", "pick R", ""),
  64: ("twodoor", "medium", "lock", "locker"),
  65: ("decoy", "easy", "lock pick", ""),
  66: ("restock", "medium", "lock pick R", "pickup"),
  67: ("knot", "medium", "lock R", ""),
  68: ("park", "hard", "lock pick R", "locker"),
  # Detour City
  69: ("intro", "easy", "1w works", "works"),
  70: ("longcon", "medium", "hub works", "works"),
  71: ("decoy", "melter", "works", ""),
  72: ("sorter", "medium", "1w hub works", "hub"),
  73: ("twodoor", "medium", "1w hub works", "works"),
  74: ("breather", "easy", "hub works", ""),
  75: ("gauntlet", "hard", "1w hub works", "works"),
  # Thunder Mesa
  76: ("decoy", "easy", "ice lock works", "ice works locker"),
  77: ("park", "medium", "ice lock works", "locker"),
  78: ("decoy", "melter", "works hub lock", ""),
  79: ("twodoor", "medium", "lock works", "works"),
  80: ("decoy", "medium", "ice lock works", ""),
  81: ("breather", "easy", "lock works", ""),
  82: ("decoy", "melter", "ice lock", ""),
  83: ("longcon", "hard", "ice lock works", "ice locker works"),
  # Skyline Summit
  84: ("restock", "medium", "gate pick works", "pickup"),
  85: ("longcon", "medium", "gate pick works", ""),
  86: ("hoard", "medium", "br gate wh works", "warehouse"),
  87: ("twodoor", "easy", "gate pick works", ""),
  88: ("decoy", "melter", "gate pick hub", ""),
  89: ("twin", "medium", "gate pick works", ""),
  90: ("gauntlet", "hard", "br gate pick works", "gate"),
  # The Long Haul
  91: ("decoy", "end", "1w pick", "pickup"),
  92: ("longcon", "end", "1w br hub pick R", "pickup"),
  93: ("twodoor", "melter", "pick R", ""),
  94: ("sorter", "end", "1w gate hub pick", "hub"),
  95: ("gauntlet", "end", "1w br gate hub pick xN R", "pickup"),
  # Death Valley
  96: ("hoard", "end", "1w gate hub wh xN", "warehouse"),
  97: ("gauntlet", "end", "1w gate hub wh xN", "warehouse"),
  98: ("twodoor", "end", "1w gate wh xN", "warehouse"),
  99: ("sorter", "end", "1w gate hub wh xN", "warehouse"),
  100: ("hoard", "end", "1w gate hub wh xN", "warehouse"),
}

def part(n):
    return 1 if n <= 20 else 2 if n <= 40 else 3 if n <= 68 else 4 if n <= 90 else 5

def player(n):       # 0 new (hasn't learned the single-door signal), 1 regular, 2 expert
    return 0 if n <= 12 else 1 if n <= 60 else 2

# What each tier asks for, by part of the game. Two measures (design/level_engine.md):
#   the PLAN view, for a player who thinks in stops and doors and rules out what they can see coming:
#     pt    wrong plans to work through before the answer (lo, hi)
#     pn    partial plans that survive that pruning, at least (what there is to hold in your head)
#     pf    the most the first plan that comes to mind may be right
#   the ROAD view, for a player who has to drive it to find out (new players to level 12, regulars to 60):
#     rt    failed drives to expect, at most (so a level that's fair to an expert isn't a wall for a beginner)
# For scale, in the plan view (Steven's verdicts on samples, 15 Nov 2026):
#   18 partial plans, 2.0-2.6 wrong plans    "trivial, solved in my head" / "fairly okay as an easy level"
#   37 partial plans, 4.6 wrong plans        "fun, pretty tricky but solvable in my head"      -> medium
#   98-198 partial plans, 10.5 wrong plans   "don't see an immediate path, pretty great!"      -> hard, melter
#   (one miss: 70 partial plans and 7.4 wrong plans, where his first idea was right)
# OG 23 "Corner Shops" is 14 and 2.3; the OG finale levels are 200-330 and 12-18.
def band(pt, pn, pf, rt):
    return dict(pelo=pt[0], pehi=pt[1], pnmin=pn, pfmax=pf, ehi=rt)
BANDS = {
    # Levels 5-12, the on-ramp: whoever is playing these has just finished the tutorial, so the road-view
    # ceiling is tight (OG 22, the one that "seemed impossible" to a new player, was 3.2 failed drives).
    0: {"intro": band((0.5, 1.5), 7, 0.6, 1.8), "easy": band((0.8, 1.8), 9, 0.5, 2.2), "medium": band((1.5, 2.6), 16, 0.3, 3.4),
        "melter": band((2.6, 4.2), 26, 0.12, 5.0)},
    1: {"intro": band((0.6, 1.8), 8, 0.6, 2.5), "easy": band((1.3, 2.5), 13, 0.4, 3.5), "medium": band((2.6, 4.2), 25, 0.2, 6.5),
        "hard": band((5.0, 7.5), 45, 0.05, 11.0), "melter": band((4.5, 7.0), 40, 0.05, 10.0)},
    2: {"intro": band((0.8, 2.0), 10, 0.55, 3.0), "easy": band((1.7, 3.0), 16, 0.35, 4.2), "medium": band((3.8, 5.8), 36, 0.15, 12.0),
        "hard": band((7.5, 11.0), 75, 0.04, 20.0), "melter": band((5.5, 9.0), 50, 0.03, 19.0)},
    3: {"intro": band((0.8, 2.2), 10, 0.55, 3.5), "easy": band((1.9, 3.3), 18, 0.33, 4.6), "medium": band((4.4, 6.6), 44, 0.12, 13.0),
        "hard": band((8.5, 12.5), 90, 0.03, 22.0), "melter": band((7.0, 11.0), 70, 0.03, 21.0)},
    4: {"intro": band((1.0, 2.4), 12, 0.5, 3.5), "easy": band((2.1, 3.6), 20, 0.3, 5.0), "medium": band((5.0, 7.5), 52, 0.1, 14.0),
        "hard": band((9.5, 14.0), 110, 0.03, 24.0), "melter": band((8.0, 12.5), 85, 0.02, 23.0)},
    5: {"end": band((12.0, 18.0), 180, 0.02, 32.0), "melter": band((10.0, 14.0), 110, 0.02, 24.0)},
}
PEAKS = {95: band((14.0, 22.0), 240, 0.01, 38.0), 100: band((14.0, 22.0), 240, 0.01, 38.0)}

# Every level in a zone shows the zone's own mechanic doing a job (a Frostbite level with no ice isn't one).
# Where a zone has several, they take turns.
def zone_need(n, m):
    if 41 <= n <= 47: return "ice"
    if 48 <= n <= 54: return ["pickup", "ice"][n % 2]
    if 55 <= n <= 68: return "locker" if "lock" in m else ""
    if 69 <= n <= 75: return "works"
    if 76 <= n <= 83: return [k for k, t in (("ice", "ice"), ("locker", "lock"), ("works", "works")) if t in m][n % max(1, sum(t in m for t in ("ice", "lock", "works")))]
    if 84 <= n <= 90: return [k for k, t in (("gate", "gate"), ("pickup", "pick"), ("works", "works")) if t in m][n % max(1, sum(t in m for t in ("gate", "pick", "works")))]
    return ""

SIZES = {
    (1, "intro"): [(5, 6)], (1, "easy"): [(5, 7), (5, 6)], (1, "medium"): [(6, 7), (5, 7)], (1, "hard"): [(6, 8), (7, 8)], (1, "melter"): [(6, 7), (6, 8)],
    (2, "intro"): [(5, 6)], (2, "easy"): [(6, 7), (5, 7)], (2, "medium"): [(6, 8), (7, 8)], (2, "hard"): [(7, 8), (7, 9)], (2, "melter"): [(6, 8), (7, 8)],
    (3, "intro"): [(5, 6), (6, 7)], (3, "easy"): [(6, 7), (5, 7)], (3, "medium"): [(6, 8), (7, 8), (6, 7)], (3, "hard"): [(7, 9), (7, 8)], (3, "melter"): [(6, 8), (7, 8)],
    (4, "intro"): [(5, 6)], (4, "easy"): [(6, 7), (5, 7)], (4, "medium"): [(6, 8), (7, 8), (7, 9)], (4, "hard"): [(7, 9), (8, 9)], (4, "melter"): [(6, 8), (7, 8)],
    (5, "end"): [(8, 11), (8, 12), (9, 11)], (5, "melter"): [(7, 8)],
}
# Size and furniture by tier. Harder tiers get more same-coloured houses to choose between (mono caps how
# much one colour may hog), fewer one-door houses (they're giveaways), and no one-door house for the last
# package (it tells you where the drive ends).
TIER = {
    "intro": dict(hmin=3, hmax=4, ncol=3, colmin=2, pkmin=3, pkmax=5, rmax=2, len_min=9, cover_min=0.6, nodes_max=1200, qmax=7, secs=12),
    "easy": dict(hmin=4, hmax=5, ncol=3, colmin=2, pkmin=4, pkmax=6, rmax=2, len_min=11, cover_min=0.6, nodes_max=1500, qmax=7, mono=0.6, pickmin=1, secs=20),
    "medium": dict(hmin=5, hmax=7, ncol=3, colmin=3, pkmin=5, pkmax=8, rmax=1, len_min=15, cover_min=0.65, nodes_max=2500, qmax=9, mono=0.5, d1max=2, pickmin=3, secs=45),
    "hard": dict(hmin=6, hmax=8, ncol=4, colmin=3, pkmin=7, pkmax=10, rmax=1, len_min=19, cover_min=0.65, nodes_max=4000, qmax=10, mono=0.45, d1max=1, open_end=1, pickmin=4, secs=80),
    "melter": dict(hmin=5, hmax=7, ncol=3, colmin=3, pkmin=6, pkmax=8, rmax=1, len_min=15, cover_min=0.6, nodes_max=3000, qmax=9, mono=0.5, d1max=1, open_end=1, pickmin=3, melter=1, secs=80),
    "end": dict(hmin=8, hmax=11, ncol=5, colmin=4, pkmin=10, pkmax=14, rmax=1, len_min=30, cover_min=0.55, nodes_max=8000, qmax=14, mono=0.4, d1max=3, open_end=1, pickmin=5, secs=130),
}
ASKS = {
    "intro": "Introduces a rule, gently",
    "breather": "A breather: a couple of ways to win, and one way to lose",
    "decoy": "The obvious first stop is the wrong one",
    "twodoor": "Drive past a house now, deliver from another street later",
    "longcon": "An early, innocent turn decides the ending",
    "gauntlet": "One trap after another, all the way along",
    "knot": "One long winding drive; don't box yourself in",
    "park": "Park a package in the locker to get it out of the way, fetch it later",
    "restock": "Fetch the pickup when you want it on top, not before",
    "sorter": "The hub decides the order: choose when to cross it",
    "twin": "Two different answers",
    "hoard": "Make room before the warehouse",
}

# The rule for new mechanics: a level that introduces one is followed by a level that uses it in an
# interesting way (it must matter there), and two introductions never come back to back.
INTROS = [n for n in T if T[n][0] == "intro"]
for n in INTROS:
    nxt = T.get(n + 1)
    assert nxt and nxt[0] != "intro", "level %d introduces something and so does %d" % (n, n + 1)
    assert nxt[3].strip(), "level %d introduces a mechanic; level %d must use it (its must-matter list is empty)" % (n, n + 1)

slots = []
for n in range(1, 101):
    flavor, tier, mech, need = T[n]
    cur = levels[n - 1]
    s = {"n": n, "title": cur["title"], "flavor": "intro" if flavor == "keep" else flavor, "tier": tier, "who": player(n)}
    if cur.get("challenge"): s["challenge"] = True
    if cur.get("gift"): s["gift"] = cur["gift"]["item"]
    if flavor == "keep":
        s["keep"] = True
        slots.append(s)
        continue
    p = part(n)
    kind = "intro" if flavor == "intro" else tier
    a = dict(TIER[kind])
    bd = PEAKS.get(n) or BANDS[0 if n <= 12 else p][kind]
    sizes = SIZES[(p, kind)]
    w, h = sizes[n % len(sizes)]
    m = mech.split()
    needs = set(need.split())
    if flavor == "restock": needs.add("pickup")
    if flavor == "sorter": needs.add("hub")
    if flavor == "park": needs.add("locker")
    z = zone_need(n, m)
    if z: needs.add(z)
    if "wh" in m:                      # Death Valley and the crane: lots of packages, fed in by warehouses
        if tier == "end":
            w, h = 9, 12
            a.update(hmin=8, hmax=11, ncol=4, colmin=3, pkmin=25, pkmax=34, smin=4, smax=6, stock=5, maxorder=4, qmax=16, nodes_max=9000, rmax=2, len_min=34, secs=180)
        else:
            a.update(hmin=4, hmax=6, pkmin=9, pkmax=14, smin=1, smax=2, stock=4, maxorder=4, qmax=10)
    if p >= 3 and kind == "medium": a.update(ncol=4)
    if "1w" in m: a["amax"] = 2 if tier != "end" else 3
    if "br" in m: a["bmax"] = 1
    if "xN" in m and "wh" not in m: a["maxorder"] = 3; a["pkmax"] = a["pkmax"] + 2
    if "pick" in m: a["smax"] = 2 if tier != "end" else 3; a["smin"] = 1 if "pickup" in needs else 0
    if "gate" in m: a["gmax"] = 2
    if "hub" in m: a["umax"] = 2
    if "ice" in m: a["imax"] = 3
    if "lock" in m: a["lmax"] = 1 if kind in ("intro", "easy") else 2; a["lmin"] = 1 if "locker" in needs else 0
    if "works" in m: a["wmax"] = 2
    if "R" in m: a["ret"] = 1
    if flavor == "breather": a.update(rmin=2, rmax=6)
    if flavor == "twin": a.update(rmin=2, rmax=4)
    if flavor == "knot": a["cover_min"] = 0.78
    a.update(w=w, h=h, who=player(n), elo=0.3, fmax=1.0, twmin=0)
    a.update(bd)
    if n <= 12:        # the on-ramp: small loads
        if kind == "easy": a.update(hmin=3, hmax=4, pkmin=3, pkmax=5, pickmin=1)
        if kind == "medium": a.update(hmin=4, hmax=5, pkmin=4, pkmax=6, pickmin=2, colmin=2)
        if kind == "melter": a.update(hmin=4, hmax=6, pkmin=5, pkmax=6, pickmin=2, colmin=2)
    if n == 10:        # the first mind-melter teaches the one-door signal (its hint says so): it needs a one-door house
        a.update(d1min=1, d1max=2, open_end=0)
    if flavor != "intro": a["flavor"] = flavor
    if needs: a["need"] = ",".join(sorted(needs))
    if s.get("gift"): a["gift"] = 1
    s.update({"mech": m, "need": sorted(needs), "band": [bd["pelo"], bd["pehi"]], "w": w, "h": h, "asks": ASKS[s["flavor"]], "args": a})
    slots.append(s)

json.dump({"slots": slots, "asks": ASKS}, open(os.path.join(ROOT, "tools", "level_plan.json"), "w"), indent=1)
from collections import Counter
print("wrote tools/level_plan.json:", dict(Counter(s["tier"] for s in slots if not s.get("keep"))))
prev = None
for s in slots:
    if prev and s["flavor"] == prev["flavor"] and s["flavor"] != "intro":
        print("  ! levels %d and %d are both %s" % (prev["n"], s["n"], s["flavor"]))
    prev = s
print("  mind-melters:", [s["n"] for s in slots if s["tier"] == "melter"])
