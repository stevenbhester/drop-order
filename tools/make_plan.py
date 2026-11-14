#!/usr/bin/env python3
"""Writes tools/level_plan.json: what each of the 100 levels is for.

The plan is the design. Each slot says which flavour of puzzle it is, how hard it should be, which
mechanics it uses (and which of them must matter), and how big. tools/gen_levels.gd fills the slots.
Edit the table below and run this again; design/level_engine.md explains the flavours and the curve.

  python3 tools/make_plan.py
"""
import json, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
levels = json.load(open(os.path.join(ROOT, "levels", "levels.json")))["levels"]

# n: (flavour, tier, mechanics, must-matter, extras)
# mechanics: 1w one-way, br bridge, xN bigger orders, pick pickups, wh warehouses, gate, hub, ice, lock
# lockers, works roadworks, R return to the depot.
T = {
  1: ("keep", "easy", "", "", {}), 2: ("keep", "easy", "", "", {}), 3: ("keep", "easy", "", "", {}), 4: ("keep", "easy", "", "", {}),
  5: ("decoy", "medium", "", "", {}),
  6: ("freerun", "easy", "", "", {}),
  7: ("intro", "easy", "xN", "", {"intro": "multi"}),
  8: ("twin", "medium", "xN", "", {}),
  9: ("intro", "easy", "1w", "oneway", {"intro": "oneway"}),
  10: ("fork", "easy", "1w", "oneway", {}),
  11: ("twodoor", "medium", "1w xN", "", {}),
  12: ("knot", "medium", "", "", {}),
  13: ("intro", "easy", "br", "bridge", {"intro": "bridge"}),
  14: ("longcon", "hard", "br", "", {}),
  15: ("freerun", "easy", "1w br", "", {}),
  16: ("twin", "medium", "xN", "", {}),
  17: ("decoy", "medium", "1w", "", {}),
  18: ("twodoor", "medium", "br xN", "", {}),
  19: ("fork", "easy", "1w br", "", {}),
  20: ("knot", "hard", "1w br xN", "", {}),
  21: ("intro", "easy", "pick", "pickup", {"intro": "pickup"}),
  22: ("restock", "medium", "pick", "pickup", {}),
  23: ("fork", "easy", "1w pick", "pickup", {}),
  24: ("sorter", "medium", "1w pick", "pickup", {}),
  25: ("intro", "easy", "gate", "gate", {"intro": "gate"}),
  26: ("twin", "medium", "1w gate", "gate", {}),
  27: ("restock", "medium", "gate pick", "gate pickup", {}),
  28: ("districts", "hard", "1w gate xN", "gate", {"doors": 2}),
  29: ("intro", "easy", "R", "", {"intro": "return"}),
  30: ("freerun", "easy", "R", "", {}),
  31: ("decoy", "medium", "gate pick R", "pickup", {}),
  32: ("longcon", "hard", "1w R", "", {}),
  33: ("intro", "easy", "hub", "hub", {"intro": "hub"}),
  34: ("sorter", "medium", "hub", "hub", {}),
  35: ("twodoor", "medium", "hub pick", "pickup", {}),
  36: ("sorter", "hard", "gate hub", "hub", {}),
  37: ("fork", "easy", "gate pick R", "pickup", {}),
  38: ("twin", "medium", "br hub pick", "pickup", {}),
  39: ("restock", "hard", "1w gate pick xN", "pickup", {}),
  40: ("districts", "hard", "gate hub pick R", "gate", {"doors": 2}),
  41: ("intro", "easy", "1w ice", "ice", {"intro": "ice"}),
  42: ("fork", "easy", "1w ice xN", "ice", {}),
  43: ("twodoor", "medium", "1w ice xN", "ice", {}),
  44: ("knot", "medium", "1w ice xN", "ice", {}),
  45: ("freerun", "easy", "ice xN", "", {"theme": "ice", "theme_n": 3}),
  46: ("decoy", "medium", "1w ice xN", "ice", {}),
  47: ("longcon", "hard", "1w ice xN", "ice", {}),
  48: ("restock", "medium", "ice pick", "ice pickup", {}),
  49: ("twin", "medium", "br ice pick", "pickup", {}),
  50: ("sorter", "medium", "br ice pick", "pickup", {}),
  51: ("fork", "easy", "ice pick", "pickup", {}),
  52: ("twodoor", "medium", "br ice pick", "pickup", {}),
  53: ("knot", "hard", "br ice pick", "ice pickup", {}),
  54: ("freerun", "easy", "br ice pick", "pickup", {}),
  55: ("intro", "easy", "1w lock", "locker", {"intro": "locker"}),
  56: ("dump", "medium", "gate lock", "locker", {}),
  57: ("fork", "easy", "1w gate lock", "locker", {}),
  58: ("districts", "hard", "1w gate lock", "gate locker", {"doors": 2}),
  59: ("twodoor", "medium", "gate lock", "locker", {}),
  60: ("freerun", "easy", "1w gate lock", "locker", {}),
  61: ("dump", "hard", "1w gate lock", "locker", {}),
  62: ("decoy", "medium", "lock R", "locker", {}),
  63: ("sorter", "medium", "lock pick R", "pickup", {}),
  64: ("twin", "medium", "lock R", "locker", {}),
  65: ("fork", "easy", "lock pick", "pickup", {}),
  66: ("restock", "medium", "lock pick R", "pickup", {}),
  67: ("dump", "hard", "lock pick R", "locker", {}),
  68: ("knot", "medium", "lock R", "locker", {}),
  69: ("intro", "easy", "1w works", "works", {"intro": "works"}),
  70: ("districts", "medium", "hub works", "works", {}),
  71: ("sorter", "medium", "1w hub works", "hub", {}),
  72: ("decoy", "medium", "1w hub works", "works", {}),
  73: ("longcon", "hard", "1w hub works", "works", {}),
  74: ("freerun", "easy", "hub works", "", {}),
  75: ("twodoor", "medium", "1w hub works", "works", {}),
  76: ("fork", "easy", "ice works", "ice works", {}),
  77: ("dump", "medium", "ice lock works", "locker", {}),
  78: ("twin", "medium", "works", "works", {}),
  79: ("districts", "medium", "lock works", "works", {"doors": 2}),
  80: ("decoy", "medium", "ice lock works", "locker", {}),
  81: ("freerun", "easy", "lock works", "locker", {}),
  82: ("knot", "hard", "ice lock works", "locker", {}),
  83: ("longcon", "hard", "ice lock works", "ice locker works", {}),
  84: ("restock", "medium", "gate pick works", "pickup", {}),
  85: ("twodoor", "medium", "gate pick works", "pickup", {}),
  86: ("hoard", "medium", "br gate wh works", "warehouse", {}),
  87: ("fork", "easy", "gate pick works", "pickup", {}),
  88: ("sorter", "hard", "gate pick works", "pickup", {}),
  89: ("twin", "medium", "gate pick works", "pickup", {}),
  90: ("districts", "hard", "br gate pick works", "gate", {"doors": 2}),
  91: ("decoy", "end", "1w pick", "pickup", {}),
  92: ("knot", "end", "1w br hub pick R", "pickup", {}),
  93: ("districts", "end", "1w br hub pick R", "pickup", {"districts": 3, "doors": 2}),
  94: ("sorter", "end", "1w gate hub pick", "hub", {}),
  95: ("longcon", "end", "1w br gate hub pick xN R", "pickup", {}),
  96: ("hoard", "end", "1w gate hub wh xN", "warehouse", {"minpkg": 25}),
  97: ("districts", "end", "1w gate hub wh xN", "warehouse", {"minpkg": 25, "doors": 2}),
  98: ("twodoor", "end", "1w gate wh xN", "warehouse", {"minpkg": 25}),
  99: ("sorter", "end", "1w gate hub wh xN", "warehouse", {"minpkg": 25}),
  100: ("hoard", "end", "1w gate wh xN", "warehouse", {"minpkg": 25}),
}

def part(n):
    return 1 if n <= 20 else 2 if n <= 40 else 3 if n <= 68 else 4 if n <= 90 else 5

BANDS = {  # difficulty wanted, by part of the game and tier
    1: {"easy": [0.8, 2.8], "medium": [2.8, 4.6], "hard": [4.6, 6.2]},
    2: {"easy": [1.8, 3.4], "medium": [3.6, 5.4], "hard": [5.6, 7.0]},
    3: {"easy": [2.4, 3.8], "medium": [4.2, 6.0], "hard": [6.2, 7.8]},
    4: {"easy": [2.6, 4.0], "medium": [4.6, 6.4], "hard": [6.6, 8.2]},
    5: {"end": [7.6, 9.6]},
}
# The last ten climb to the finale; 95 and 100 are the peaks.
END_BANDS = {91: [7.4, 8.4], 92: [7.4, 8.4], 93: [7.6, 8.6], 94: [8.0, 9.0], 95: [8.6, 9.6],
             96: [7.8, 8.8], 97: [7.8, 8.8], 98: [8.2, 9.2], 99: [8.4, 9.4], 100: [9.0, 10.0]}
TIER = {
    # len_min: easy isn't trivial. cover_min: the route uses the town.
    "easy": {"houses": [3, 5], "colors": 3, "free_min": 4, "plans": [1, 2], "nodes_max": 1500, "loops": [55, 85], "len_min": 11, "cover_min": 0.45},
    "medium": {"houses": [4, 6], "colors": 4, "free_min": 6, "plans": [1, 2], "nodes_max": 3000, "loops": [65, 95], "len_min": 13, "cover_min": 0.45},
    "hard": {"houses": [5, 7], "colors": 4, "free_min": 10, "plans": [1, 2], "nodes_max": 5000, "loops": [70, 100], "len_min": 16, "cover_min": 0.5},
    "end": {"houses": [7, 10], "colors": 5, "free_min": 12, "plans": [1, 2], "nodes_max": 8000, "loops": [65, 95], "routes_max": 55, "len_min": 26, "cover_min": 0.45},
}
FLAVOR = {
    "fork": {"plans": [1, 1], "late": 0.1},
    "freerun": {"plans": [3, 14], "routes_max": 58, "free_min_add": 2, "late": 0.15, "bits_max": 3.2},
    "decoy": {"plans": [1, 1]},
    "sorter": {"plans": [1, 1]},
    "twodoor": {"late": 0.65, "ext": [3, 7], "two_door": 3.0, "late_min": 2},
    "dump": {},
    "restock": {},
    "knot": {"plans": [1, 1], "free_min_set": 2, "loops": [30, 65], "ext": [0, 1], "late": 0.15},
    "longcon": {"plans": [1, 1], "doom_min": 7},
    "twin": {"plans": [2, 2], "overlap_max": 0.7},
    "hoard": {"stock": 4, "max_order": 4, "load_min": 8},
    "districts": {"districts": 2, "doors": 1},
    "intro": {"plans": [1, 1], "free_min_set": 2, "houses": [2, 4], "nodes_max": 800, "len_min": 8},
}

slots = []
for n in range(1, 101):
    flavor, tier, mech, need, extra = T[n]
    cur = levels[n - 1]
    w = len(cur["map"][0].split()); h = len(cur["map"])
    s = {"n": n, "w": w, "h": h, "tier": tier, "flavor": flavor, "title": cur["title"]}
    if flavor == "keep":
        s["keep"] = True
        slots.append(s)
        continue
    s.update(TIER[tier])
    s["diff"] = BANDS[part(n)][tier]
    fl = dict(FLAVOR[flavor])
    if "free_min_add" in fl: s["free_min"] += fl.pop("free_min_add")
    if "free_min_set" in fl: s["free_min"] = fl.pop("free_min_set")
    s.update(fl)
    m = mech.split()
    if "1w" in m: s["oneway"] = [0, 2]
    if "br" in m: s["bridge"] = [1, 1]
    if "xN" in m: s["multi"] = [1, 3]
    if "pick" in m: s["shops"] = [1, 2]
    if "wh" in m: s["shops"] = [2, 4]; s["stock"] = 4; s["max_order"] = 4; s["multi"] = [3, 8]
    # The zone's other mechanics are optional (they stay only where they change the answer)...
    if "gate" in m: s["gate"] = [0, 2]
    if "hub" in m: s["hub"] = [0, 2]
    if "ice" in m: s["ice"] = [0, 3]
    if "lock" in m: s["lockers"] = [1, 2]
    if "works" in m: s["works"] = [0, 2]
    if "R" in m: s["ret"] = True
    s["need"] = need.split()
    for fam in s["need"]:   # ...but one the slot is about must be there, and matter
        if fam in ("oneway", "gate", "hub", "works"): s[fam] = [1, 2]
        if fam == "ice": s["ice"] = [1, 3]
    if tier == "end":
        s["repaints"] = 6
        if extra.get("minpkg"):
            s["houses"] = [8, 11]; s["multi"] = [14, 22]; s["shops"] = [4, 6]; s["stock"] = 5; s["max_order"] = 4; s["colors"] = 4
    if cur.get("challenge"): s["challenge"] = True
    if cur.get("gift"): s["gift"] = cur["gift"]["item"]
    s.update(extra)
    if flavor == "intro":
        s["diff"] = [0.5, 3.6]
    if n in END_BANDS:
        s["diff"] = END_BANDS[n]
    if n <= 12:
        s["len_min"] = min(s.get("len_min", 0), 10)   # the first maps are small
    slots.append(s)

out = os.path.join(ROOT, "tools", "level_plan.json")
json.dump({"slots": slots}, open(out, "w"), indent=1)
print("wrote", out, len(slots), "slots")
