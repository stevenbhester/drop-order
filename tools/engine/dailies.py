#!/usr/bin/env python3
"""Fills levels/daily.json with the level engine: the 38 dailies, in the order they come round.

A daily is played with no hints and six tries, by anyone past job 10, so it earns its keep by being
clever, not by piling on rules: each has at most ONE kind of hazard (most have none, or one-way streets),
and only kinds met by the middle of the main road (no ice, lockers, roadworks or warehouses). How hard is
its spice: 1 mild, 2 medium, 3 spicy, each a band of the plan view (design/level_engine.md), with a ceiling
on failed drives so six tries is fair.

  python3 tools/engine/dailies.py gen [--seed N] [--time X] [numbers...]   candidates -> build/engine/daily_NNN.<seed>.txt
  python3 tools/engine/dailies.py write [--dry]                            the best of them -> levels/daily.json
A slot with no candidate that passes keeps the puzzle it has, and is listed.
"""
import glob, json, os, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
PATH = os.path.join(ROOT, "levels", "daily.json")
NAMES = {"r": "red", "b": "blue", "g": "green", "y": "yellow", "p": "purple", "o": "orange"}

# (title, hint, spice, mechanic, flavour). Mechanics: "" none, xN bigger orders, 1w one-ways, br a bridge,
# pick pickups, R back to the depot, gate, hub.
DAILIES = [
    ("Pancake Stack", "Breakfast in order: the top one goes first.", 1, "", "decoy"),
    ("Lost Mittens", "One-way streets, two cold hands.", 1, "1w", "twodoor"),
    ("Snow Day", "The roads are clear. Is your plan?", 2, "", "longcon"),
    ("Two Doors Down", "Small map. Big ideas. Watch what you pass.", 2, "", "twodoor"),
    ("Sock Drawer", "The spinner swaps your top two. Pair them up.", 3, "hub", "sorter"),
    ("Library Run", "Return the books, then park back at the depot.", 2, "R", "longcon"),
    ("Night Market", "Pick up at the stalls. It lands on top.", 3, "pick", "restock"),
    ("Switchbacks", "The first turn decides the last one.", 3, "", "longcon"),
    ("Pothole Patrol", "Mind the holes you leave behind.", 1, "", "twodoor"),
    ("Bakery Dash", "Pick up the buns on the way. They land on top.", 2, "pick", "restock"),
    ("Rubber Ducks", "Somebody ordered a lot of ducks.", 3, "xN", "decoy"),
    ("Red Tape", "A coloured gate opens for its colour on top.", 3, "gate", "knot"),
    ("Rainy Tuesday", "Short trip. Mind the puddles.", 1, "", "longcon"),
    ("Birthday Rush", "Some houses want two. Party logistics!", 3, "xN", "twodoor"),
    ("Llama Drama", "Arrows know best. Usually.", 2, "1w", "decoy"),
    ("The Big Map", "Lots of packages, one way through. Take your time.", 3, "", "gauntlet"),
    ("Lunchbox Shuffle", "Packed in the wrong order. Naturally.", 2, "", "knot"),
    ("Kite Festival", "Over the bridge and round again. Strings attached.", 2, "br", "twodoor"),
    ("Hot Cocoa Run", "Warm cup, cold one-way streets.", 2, "1w", "longcon"),
    ("Cul-de-Sac", "Not every street goes somewhere.", 2, "", "decoy"),
    ("Moving Day", "Everything out, then back to the depot.", 2, "R", "twodoor"),
    ("Garden Gnomes", "They're watching. Deliver anyway.", 1, "", "decoy"),
    ("Science Fair", "Coloured gates. Bring the right project.", 3, "gate", "twodoor"),
    ("Sort It Out", "One spinner. Use it at the right moment.", 3, "hub", "sorter"),
    ("Fridge Raid", "Grab it on the way. It lands on top.", 3, "pick", "restock"),
    ("Laundry Day", "Fold it right the first time.", 1, "", "twodoor"),
    ("Pet Parade", "Over the bridge. Wave at the dogs.", 3, "br", "knot"),
    ("The Scenic Route", "The long way round is the only way round.", 3, "", "longcon"),
    ("Cheese Wheel", "A whole wheel for one house.", 2, "xN", "longcon"),
    ("Owl Post", "Night delivery. Follow the arrows.", 2, "1w", "twodoor"),
    ("Garage Sale", "Sell the lot, then back to the depot.", 2, "R", "decoy"),
    ("Short Cut", "There isn't one.", 2, "", "knot"),
    ("Postcard Season", "Round trip. Back by teatime.", 1, "R", "twodoor"),
    ("Bubble Wrap", "Big orders. Pop, pop, pop.", 3, "xN", "knot"),
    ("Tooth Fairy", "Pick up the coins. Leave no trace.", 2, "pick", "restock"),
    ("Toll Booth", "Pay in the right colour.", 3, "gate", "decoy"),
    ("Thunderstorm", "One-way streets in a storm. Hold on.", 3, "1w", "gauntlet"),
    ("Ring Road", "Round and round. Once.", 3, "", "knot"),
]
GIFTS = {}                        # (no presents on dailies while toppers are shelved)

# Per spice: the plan-view band (wrong plans worked through), the least to hold, how often the first plan
# may be right, the ceiling on failed drives, and the search.
SPICE = {
    1: dict(pelo=1.3, pehi=2.5, pnmin=13, pfmax=0.4, ehi=3.5, hmin=4, hmax=5, ncol=3, colmin=2, pkmin=4, pkmax=6, rmax=2, len_min=11,
            cover_min=0.6, nodes_max=1500, qmax=7, mono=0.6, pickmin=1, secs=20, sizes=[(5, 6), (6, 6)]),
    2: dict(pelo=2.6, pehi=4.2, pnmin=25, pfmax=0.2, ehi=6.0, hmin=5, hmax=6, ncol=3, colmin=3, pkmin=5, pkmax=7, rmax=1, len_min=15,
            cover_min=0.65, nodes_max=2500, qmax=9, mono=0.5, d1max=2, pickmin=3, secs=45, sizes=[(6, 7), (5, 7)]),
    3: dict(pelo=4.2, pehi=6.2, pnmin=36, pfmax=0.08, ehi=8.5, hmin=5, hmax=7, ncol=3, colmin=3, pkmin=6, pkmax=8, rmax=1, len_min=15,
            cover_min=0.6, nodes_max=3000, qmax=9, mono=0.5, d1max=1, open_end=1, pickmin=3, melter=1, secs=80, sizes=[(6, 7), (6, 8)]),
}
MECH = {
    "": {},
    "xN": dict(maxorder=3, need="multi"),
    "1w": dict(amax=2, need="oneway"),
    "br": dict(bmax=1, need="bridge"),
    "pick": dict(smin=1, smax=2, need="pickup"),
    "R": dict(ret=1, need="return"),
    "gate": dict(gmax=2, need="gate"),
    "hub": dict(umax=2, need="hub"),
}


def slot(i):
    title, hint, spice, mech, flavor = DAILIES[i]
    a = dict(SPICE[spice])
    sizes = a.pop("sizes")
    w, h = sizes[i % len(sizes)]
    a.update(MECH[mech])
    if mech == "xN":
        a["pkmax"] += 2
    a.update(w=w, h=h, who=0, elo=0.3, fmax=1.0, twmin=0, flavor=flavor)
    if i + 1 in GIFTS:
        a["gift"] = 1
    return {"n": i + 1, "title": title, "hint": hint, "spice": spice, "mech": mech, "args": a}


def opt(args, name, default):
    if name in args:
        k = args.index(name); v = args[k + 1]; del args[k:k + 2]
        return v
    return default


def gen(args):
    seed = int(opt(args, "--seed", 1)); scale = float(opt(args, "--time", 1.0)); keep = int(opt(args, "--keep", 12))
    want = [int(a) for a in args]
    todo = [slot(i) for i in range(len(DAILIES)) if not want or i + 1 in want]
    os.makedirs(os.path.join(ROOT, "build", "engine"), exist_ok=True)

    def run(s):
        a = dict(s["args"])
        secs = a.pop("secs") * scale
        cmd = [os.path.join(ROOT, "build", "lm"), "gen", "slot=%d" % (1000 + s["n"]), "seed=%d" % seed, "secs=%g" % secs, "keep=%d" % keep]
        cmd += ["%s=%s" % kv for kv in a.items()]
        r = subprocess.run(cmd, capture_output=True, text=True)
        open(os.path.join(ROOT, "build", "engine", "daily_%03d.%d.txt" % (s["n"], seed)), "w").write(r.stdout)
        return s["n"], r.stdout.count("CAND "), r.stderr.strip().splitlines()[-1] if r.stderr.strip() else ""

    t0 = time.time()
    todo.sort(key=lambda s: -s["args"]["secs"])
    with ThreadPoolExecutor(10) as ex:
        for n, k, note in ex.map(run, todo):
            print("daily %d: %d candidates  %s" % (n, k, note if k == 0 else ""))
    print("%d dailies in %.0fs" % (len(todo), time.time() - t0))


def passes(s, c):
    m, a = c["m"], s["args"]
    if not c["need_ok"]: return "mechanic idle"
    if not (1 <= m["routes"] <= a["rmax"]): return "routes %d" % m["routes"]
    if m["ptries"] < a["pelo"] * 0.85: return "too few plans (%.1f)" % m["ptries"]
    if m["ptries"] > a["pehi"] * 1.25: return "too many plans (%.1f)" % m["ptries"]
    if m["pnodes"] < a["pnmin"] * 0.8: return "too little to hold (%d)" % m["pnodes"]
    if m["pfirst"] > a["pfmax"] + 0.08: return "first plan right %.0f%%" % (m["pfirst"] * 100)
    if m["tries3"][0] > a["ehi"] * 1.3: return "a wall (%.1f drives)" % m["tries3"][0]
    if a.get("gift") and "gift" not in c: return "no spot for the present"
    if m["over"] or m["capped"]: return "too big to measure"
    return ""


def town(c):
    return "/".join(" ".join("#" if t in "#S+@~^>v<" or t[0] in "=c" else "." for t in row.split(" ")) for row in c["map"].split("/"))


def fmt(d):
    parts = []
    for k in ["title", "hint", "spice", "return", "no_revisit"]:
        if k in d:
            parts.append('      %s: %s' % (json.dumps(k), json.dumps(d[k], ensure_ascii=False)))
    width = max(len(t) for row in d["map"] for t in row.split())
    rows = ['        "%s"' % " ".join(t.ljust(width) for t in row.split()).rstrip() for row in d["map"]]
    parts.append('      "map": [\n%s\n      ]' % ",\n".join(rows))
    if "gift" in d:
        parts.append('      "gift": {"at": [%d, %d], "item": %s}' % (d["gift"]["at"][0], d["gift"]["at"][1], json.dumps(d["gift"]["item"])))
    parts.append('      "stack": [%s]' % ", ".join(json.dumps(c) for c in d["stack"]))
    return "    {\n" + ",\n".join(parts) + "\n    }"


def write(args):
    dry = "--dry" in args
    cur = json.load(open(PATH))["levels"]
    cands = {}
    for f in glob.glob(os.path.join(ROOT, "build", "engine", "daily_*.txt")):
        for line in open(f):
            if line.startswith("CAND "):
                c = json.loads(line[5:])
                cands.setdefault(int(c["slot"]) - 1000, []).append(c)
    out, seen, missing = [], set(), []
    for i in range(len(DAILIES)):
        s = slot(i)
        old = cur[i] if i < len(cur) else None
        pick, why = None, {}
        for want_flavor in (True, False):
            for c in sorted(cands.get(s["n"], []), key=lambda c: -c["fit"]):
                r = passes(s, c)
                if not r and town(c) in seen: r = "town already used"
                if not r and want_flavor and not c["flavor_ok"]: r = "flavour"
                if r:
                    if want_flavor: why[r] = why.get(r, 0) + 1
                    continue
                pick = c
                break
            if pick: break
        if pick is None:
            missing.append((s["n"], s["title"], s["spice"], s["mech"], len(cands.get(s["n"], [])), why))
            out.append(old)
            continue
        seen.add(town(pick))
        d = {"title": s["title"], "hint": s["hint"], "spice": s["spice"]}
        if pick["ret"]: d["return"] = True
        d["no_revisit"] = True
        d["map"] = pick["map"].split("/")
        if s["args"].get("gift") and old and old.get("gift"):
            d["gift"] = {"at": pick["gift"], "item": old["gift"]["item"]}
        d["stack"] = [NAMES[x] for x in pick["stack"] if x in NAMES]
        out.append(d)
        m = pick["m"]
        print("daily %2d %-18s spice %d %-4s plans %.1f hold %3d first %2.0f%% drives %.1f answers %d %dx%d %d pkg" % (
            s["n"], s["title"], s["spice"], s["mech"], m["ptries"], m["pnodes"], 100 * m["pfirst"], m["tries3"][0], m["routes"],
            m["size"][0], m["size"][1], m["packages"]))
    for n, title, spice, mech, k, why in missing:
        print("KEPT daily %d %s (spice %d %s): %d candidates; %s" % (n, title, spice, mech, k, why))
    text = '{\n  "levels": [\n' + ",\n".join(fmt(d) for d in out) + "\n  ]\n}\n"
    json.loads(text)
    if not dry:
        open(PATH, "w").write(text)
        print("wrote levels/daily.json (%d new, %d kept)" % (len(out) - len(missing), len(missing)))


if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "gen": gen(a[1:])
    elif a and a[0] == "write": write(a[1:])
    else: print(__doc__)
