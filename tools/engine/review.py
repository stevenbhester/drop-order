#!/usr/bin/env python3
"""Writes design/level_scores.md: every level's scores and the series checks.

  python3 tools/engine/review.py            (scores levels/levels.json with build/lm)
"""
import json, os, subprocess, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lv

def score(path):
    lines = "".join(lv.to_line(i, d) + "\n" for i, d in lv.levels_of(path))
    out = subprocess.run([os.path.join(ROOT, "build", "lm"), "score"], input=lines, capture_output=True, text=True).stdout
    return [json.loads(l) for l in out.splitlines()]

levels = json.load(open(os.path.join(ROOT, "levels", "levels.json")))["levels"]
plan = {s["n"]: s for s in json.load(open(os.path.join(ROOT, "tools", "level_plan.json")))["slots"]}
rows = score(os.path.join(ROOT, "levels", "levels.json"))
og = score(os.path.join(ROOT, "levels", "og.json"))
WHO = ["new player", "regular", "expert"]
ZONES = [(1, 20, "The Suburbs"), (21, 40, "The City"), (41, 47, "Frostbite Pass"), (48, 54, "Harbour Lights"), (55, 61, "Neon Alley"),
         (62, 68, "Orchard Hills"), (69, 75, "Detour City"), (76, 83, "Thunder Mesa"), (84, 90, "Skyline Summit"), (91, 95, "The Long Haul"),
         (96, 100, "Death Valley")]

def med(xs):
    xs = sorted(xs)
    return xs[len(xs) // 2] if xs else 0

def summary(rs, lo, hi):
    b = [r for r in rs if r.get("ok") and lo <= int(r["id"]) <= hi]
    return "%d | %d | %.1f | %.0f%% | %.1f" % (med(r["routes"] for r in b), med(r["pnodes"] for r in b), med(r["ptries"] for r in b),
                                              100 * med(r["pfirst"] for r in b), med(r["tries"] for r in b))

out = ["# Level scores", "",
       "Written by `tools/engine/review.py` from `build/lm score`. What the numbers mean is in `design/level_engine.md`.",
       "They come from a model of a player, not from players: use them to compare levels with each other.", "",
       "## Before and after", "",
       "Medians. **Partial plans**: what an experienced player has to hold in their head. **Wrong plans**: how many they'd work",
       "through before the answer. **First plan**: how often the first idea is right. **Drives**: failed drives for the player",
       "the level is scored for (someone who has to drive it to find out).", "",
       "| Levels | OG 100: answers | partial plans | wrong plans | first plan | drives | Now: answers | partial plans | wrong plans | first plan | drives |",
       "|---|---|---|---|---|---|---|---|---|---|---|"]
for lo, hi in [(5, 20), (21, 40), (41, 68), (69, 90), (91, 100)]:
    out.append("| %d–%d | %s | %s |" % (lo, hi, summary(og, lo, hi), summary(rows, lo, hi)))
out += ["", "## By zone", "", "| Zone | Levels | Difficulty | Devious | Complexity | Fun | Flavours |", "|---|---|---|---|---|---|---|"]
for lo, hi, name in ZONES:
    b = [r for r in rows if r.get("ok") and lo <= int(r["id"]) <= hi]
    av = lambda k: sum(r[k] for r in b) / len(b)
    fl = []
    for n in range(lo, hi + 1):
        f = levels[n - 1].get("flavor", "")
        if f and f not in fl: fl.append(f)
    out.append("| %s | %d–%d | %.1f | %.1f | %.1f | %.1f | %s |" % (name, lo, hi, av("difficulty"), av("devious"), av("complexity"), av("fun"), ", ".join(fl)))

problems = []
last_spike = 4
for r in rows:
    n = int(r["id"]); s = plan[n]
    if not r.get("ok"):
        problems.append("Level %d is not solved by the scorer." % n); continue
    if not s.get("keep"):
        a = s["args"]
        if r["ptries"] < a["pelo"] * 0.8 or r["ptries"] > a["pehi"] * 1.3:
            problems.append("Level %d (%s) has %.1f wrong plans to work through; the plan wanted %.1f–%.1f." % (n, s["title"], r["ptries"], a["pelo"], a["pehi"]))
        if r["tries"] > a["ehi"] * 1.4:
            problems.append("Level %d (%s) is a wall for its player: %.1f failed drives (ceiling %.1f)." % (n, s["title"], r["tries"], a["ehi"]))
        if n > 4 and r["pfirst"] > 0.5:
            problems.append("Level %d (%s): the first plan that comes to mind is right %.0f%% of the time." % (n, s["title"], r["pfirst"] * 100))
    if s["tier"] in ("melter", "hard", "end"):
        if n - last_spike > 8:
            problems.append("No spike between levels %d and %d." % (last_spike, n))
        last_spike = n
    if r["nodes"] > 4000:
        problems.append("Level %d costs the game's solver %d states." % (n, r["nodes"]))
out += ["", "## Series checks", ""]
out += ["- " + p for p in problems] if problems else ["Nothing flagged: every level within reach of its planned difficulty, none a wall for its player, none where the first idea is right more than half the time, a spike at least every 8 levels, and nothing costly for the game's solver."]

out += ["", "## Every level", "",
        "Drives are failed drives for a new player / a regular / an expert who each have to drive it to find out.",
        "Doors: houses with a single door, of all houses. ★ is a hazard-tape challenge level; ◆ a mind-melter.", "",
        "| # | Title | Tier | Kind | Answers | Partial plans | Wrong plans | First plan | Drives (new / regular / expert) | Doors | Packages | Difficulty | Devious | Complexity | Fun | Melt |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
for r in rows:
    n = int(r["id"]); s = plan[n]; d = levels[n - 1]
    if not r.get("ok"):
        out.append("| %d | %s | | NOT SOLVED | | | | | | | | | | | | |" % (n, d["title"])); continue
    mark = (" ★" if d.get("challenge") else "") + (" ◆" if s["tier"] == "melter" else "")
    out.append("| %d | %s%s | %s | %s | %d | %d | %.1f | %.0f%% | %.1f / %.1f / %.1f | %d of %d | %d | %.1f | %.1f | %.1f | %.1f | %.1f |" % (
        n, d["title"], mark, "tutorial" if s.get("keep") else s["tier"], d.get("flavor", ""), r["routes"], r["pnodes"], r["ptries"], r["pfirst"] * 100,
        r["tries3"][0], r["tries3"][1], r["tries3"][2], r["doors1"], r["houses"], r["packages"], r["difficulty"], r["devious"], r["complexity"],
        r["fun"], r["melt"]))
open(os.path.join(ROOT, "design", "level_scores.md"), "w").write("\n".join(out) + "\n")
print("wrote design/level_scores.md;", len(problems), "series flags")
for p in problems[:30]: print("  -", p)
