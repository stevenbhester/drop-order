#!/usr/bin/env python3
"""Writes design/level_scores.md from the scorecard: every level's flavour and four scores, the series
checks (the difficulty curve, flavours not repeating, connect-the-dots levels), and a summary by zone.

  tools/score_all.sh > build/levelgen/scores.jsonl && python3 tools/level_review.py build/levelgen/scores.jsonl
  python3 tools/level_review.py after.jsonl --before before.jsonl      (adds a before/after comparison)
"""
import json, os, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
rows = [json.loads(l) for l in open(sys.argv[1])]
before = None
if "--before" in sys.argv:
    before = [json.loads(l) for l in open(sys.argv[sys.argv.index("--before") + 1])]
plan = {s["n"]: s for s in json.load(open(os.path.join(ROOT, "tools", "level_plan.json")))["slots"]}

ASKS = {
    "intro": "Introduces a rule: the way you'd go without it doesn't work",
    "fork": "One real choice; the top few packages settle it",
    "freerun": "Open town, several ways to win",
    "decoy": "The obvious first stop is the wrong one",
    "sorter": "Open roads; the order is the puzzle",
    "twodoor": "Drive past a house now, deliver from another street later",
    "dump": "A locker takes a package a house wanted: choose which",
    "restock": "Fetch the pickup when you want it on top, not before",
    "knot": "One long winding drive; don't box yourself in",
    "longcon": "An early, innocent turn decides the ending",
    "twin": "Two different answers",
    "hoard": "Make room before the warehouse",
    "districts": "Neighbourhoods and doors: clear one, leave the right way",
}
ZONES = [(1, 20, "Part 1 · The Suburbs"), (21, 40, "Part 2 · The City"), (41, 47, "Frostbite Pass"), (48, 54, "Harbour Lights"),
         (55, 61, "Neon Alley"), (62, 68, "Orchard Hills"), (69, 75, "Detour City"), (76, 83, "Thunder Mesa"),
         (84, 90, "Skyline Summit"), (91, 95, "The Long Haul"), (96, 100, "Death Valley")]

def top_kind(r):
    p = r.get("profile", {})
    if not p:
        return ""
    k = max(p, key=lambda x: p[x])
    return {"foresight": "foresight", "lateral": "lateral", "trick": "one trick", "juggling": "juggling", "search": "search"}[k] if p[k] >= 0.25 else "gentle"

def stats(rs):
    ok = [r for r in rs if r.get("ok")]
    n = max(len(ok), 1)
    return {
        "fun": sum(r["fun"] for r in ok) / n, "clv": sum(r["cleverness"] for r in ok) / n, "cpx": sum(r["complexity"] for r in ok) / n,
        "dif": sum(r["difficulty"] for r in ok) / n, "dots": sum(1 for r in ok if 0 <= r["free_orders"] <= 3),
        "dec": sum(r["decisions"] for r in ok) / n, "share": sum(r["decisions"] / max(r["len"], 1) for r in ok) / n,
        "orders": sorted(r["free_orders"] for r in ok)[len(ok) // 2] if ok else 0, "n": len(ok),
        "idle": sum(r["idle"] for r in ok), "tiles": sum(r["mech_tiles"] for r in ok),
    }

out = ["# Level scores", "",
       "Written by `tools/level_review.py` from the scorecard (`tools/score_all.sh`). What the numbers mean is in",
       "`design/level_engine.md`. Scores are 0–10 and come from a model of a player, not from players: treat them",
       "as a way to compare levels with each other until tester data can calibrate them.", ""]
a = stats(rows)
out += ["## The whole set", ""]
if before:
    b = stats(before)
    out += ["| | Before | Now |", "|---|---|---|",
            "| Connect-the-dots levels (3 or fewer delivery orders the map allows) | %d of %d | %d of %d |" % (b["dots"], b["n"], a["dots"], a["n"]),
            "| Delivery orders the map allows, median | %d | %d |" % (b["orders"], a["orders"]),
            "| Real decisions per level, average | %.1f | %.1f |" % (b["dec"], a["dec"]),
            "| Share of steps that are a real decision | %.0f%% | %.0f%% |" % (b["share"] * 100, a["share"] * 100),
            "| Fun, average | %.1f | %.1f |" % (b["fun"], a["fun"]),
            "| Cleverness, average | %.1f | %.1f |" % (b["clv"], a["clv"]),
            "| Complexity, average | %.1f | %.1f |" % (b["cpx"], a["cpx"]),
            "| Difficulty, average | %.1f | %.1f |" % (b["dif"], a["dif"]),
            "| Mechanic tiles that change nothing | %d of %d | %d of %d |" % (b["idle"], b["tiles"], a["idle"], a["tiles"]), ""]
else:
    out += ["%d levels. Fun %.1f, cleverness %.1f, complexity %.1f, difficulty %.1f on average. %d connect-the-dots." % (
        a["n"], a["fun"], a["clv"], a["cpx"], a["dif"], a["dots"]), ""]

out += ["## By zone", "", "| Zone | Levels | Fun | Clever | Complex | Difficulty | Flavours |", "|---|---|---|---|---|---|---|"]
for lo, hi, name in ZONES:
    rs = [r for r in rows if lo <= r["n"] <= hi]
    s = stats(rs)
    fl = []
    for r in rs:
        f = r.get("flavor", "")
        if f and f not in fl:
            fl.append(f)
    out.append("| %s | %d–%d | %.1f | %.1f | %.1f | %.1f | %s |" % (name, lo, hi, s["fun"], s["clv"], s["cpx"], s["dif"], ", ".join(fl)))
out.append("")

problems = []
prev = None
for r in rows:
    if not r.get("ok"):
        problems.append("Level %d is not solved by the scorer." % r["n"])
        continue
    if 0 <= r["free_orders"] <= 3 and r.get("flavor") not in ("intro", "knot") and r["n"] > 4:
        problems.append("Level %d (%s) is connect-the-dots: the map allows %d delivery orders." % (r["n"], r["title"], r["free_orders"]))
    if prev and r.get("flavor") and r.get("flavor") == prev.get("flavor") and r["flavor"] != "intro":
        problems.append("Levels %d and %d are both %s." % (prev["n"], r["n"], r["flavor"]))
    band = plan.get(r["n"], {}).get("diff")
    if band and not (band[0] - 1.2 <= r["difficulty"] <= band[1] + 1.2):
        problems.append("Level %d (%s) scores %.1f for difficulty; the plan wanted %.1f–%.1f." % (r["n"], r["title"], r["difficulty"], band[0], band[1]))
    prev = r
out += ["## Series checks", ""]
out += ["- " + p for p in problems] if problems else ["Nothing flagged: no flavour twice running, no connect-the-dots level outside the tutorial and Knot levels, every level within reach of its planned difficulty."]
out.append("")

out += ["## Every level", "",
        "Kind is the sort of difficulty the level leans on most. Routes are winning routes; plans are the distinct",
        "ideas among them; orders is how many delivery orders the map would allow if colours didn't matter.", "",
        "| # | Title | Flavour | What it asks | Fun | Clever | Complex | Difficulty | Kind | Routes / plans / orders |",
        "|---|---|---|---|---|---|---|---|---|---|"]
for r in rows:
    if not r.get("ok"):
        out.append("| %d | %s | | NOT SOLVED | | | | | | |" % (r["n"], r["title"]))
        continue
    f = r.get("flavor", "")
    out.append("| %d | %s%s | %s | %s | %.1f | %.1f | %.1f | %.1f | %s | %d / %d / %d |" % (
        r["n"], r["title"], " ★" if plan.get(r["n"], {}).get("challenge") else "", f, ASKS.get(f, ""), r["fun"], r["cleverness"], r["complexity"],
        r["difficulty"], top_kind(r), r["solutions"], r["plans"], r["free_orders"]))
out += ["", "★ marks a challenge level (the spike of its zone)."]
open(os.path.join(ROOT, "design", "level_scores.md"), "w").write("\n".join(out) + "\n")
print("wrote design/level_scores.md;", len(problems), "series flags")
