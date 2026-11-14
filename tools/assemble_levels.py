#!/usr/bin/env python3
"""Picks the best candidate for every slot of the plan and writes levels/levels.json.

  python3 tools/assemble_levels.py [--dry]

Reads tools/level_plan.json, the candidates tools/gen_all.sh left in build/levelgen/, and the current
levels.json (for titles, hints, challenge flags, and the levels the plan keeps). A slot with no candidate
keeps its current level and is listed at the end, so nothing is ever lost by running this.
"""
import glob, json, math, os, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
plan = json.load(open(os.path.join(ROOT, "tools", "level_plan.json")))["slots"]
cur = json.load(open(os.path.join(ROOT, "levels", "levels.json")))["levels"]
dry = "--dry" in sys.argv

# Hints that change with the redesign: the first time each kind of puzzle turns up, a nudge toward the idea
# (never naming the flavour), and the few old hints that described a layout that's gone.
HINTS = {
    6: "Lots of ways to do this one. Take whichever you like.",
    8: "Two ways to win. One of them passes something shiny.",
    11: "You can drive past a house and come back to it from another street.",
    12: "One long winding drive. Don't box yourself in.",
    14: "An early turn decides the ending. Look a long way ahead.",
    17: "The nearest house isn't always the first stop.",
    22: "A pickup lands on TOP. Fetch it when you want it there, not before.",
    24: "The roads are wide open. The order is the puzzle.",
    28: "Two neighbourhoods, and two ways between them.",
    34: "Decide what you want on top before you reach the hub.",
    56: "A locker will happily take a package you needed somewhere else.",
    70: "Finish one side of town before the roadworks let you through.",
    86: "Warehouses (+N) hand over everything at once. Make room first.",
    91: "The nearest drop isn't the first one. Look twice.",
    93: "Three neighbourhoods, one shift. Mind which way you leave each.",
    94: "Get the order right before you get going.",
}

def off(d, band):
    return band[0] - d if d < band[0] else d - band[1] if d > band[1] else 0.0

def best_candidates():
    """Every candidate, best first, judged against today's plan (the difficulty wanted may have moved since
    the candidate was made: its fit is re-based from the band it was made for to the band wanted now)."""
    slot = {s["n"]: s for s in plan}
    out = {}
    for f in glob.glob(os.path.join(ROOT, "build", "levelgen", "slot_*.txt")):
        for line in open(f):
            if not line.startswith("CAND "):
                continue
            c = json.loads(line[5:])
            s = slot[int(c["slot"])]
            made_for = c.get("band") or ([7.6, 9.6] if s["tier"] == "end" else s.get("diff", [0, 10]))
            d = c["m"]["difficulty"]
            c["fit"] = c["fit"] + 2.5 * off(d, made_for) - 2.5 * off(d, s.get("diff", [0, 10]))
            # The game solves a level when it opens and for every hint: mark down the costly ones.
            c["fit"] -= 1.5 * max(0.0, math.log10(c["m"]["nodes"] / 2000.0))
            out.setdefault(int(c["slot"]), []).append(c)
    for n in out:
        out[n].sort(key=lambda c: -c["fit"])
    return out

def fmt_level(d):
    keys = ["title", "hint", "no_revisit", "challenge", "return", "flavor"]
    lines = ["    {"]
    parts = []
    for k in keys:
        if k in d:
            parts.append('      %s: %s' % (json.dumps(k), json.dumps(d[k], ensure_ascii=False)))
    width = max(len(t) for row in d["map"] for t in row.split())
    rows = []
    for row in d["map"]:
        toks = row.split()
        rows.append('        "%s"' % " ".join(t.ljust(width) for t in toks).rstrip())
    parts.append('      "map": [\n%s\n      ]' % ",\n".join(rows))
    if "gift" in d:
        parts.append('      "gift": {"at": [%d, %d], "item": %s}' % (d["gift"]["at"][0], d["gift"]["at"][1], json.dumps(d["gift"]["item"])))
    parts.append('      "stack": [%s]' % ", ".join(json.dumps(c) for c in d["stack"]))
    lines.append(",\n".join(parts))
    lines.append("    }")
    return "\n".join(lines)

cands = best_candidates()
levels = []
missing = []
kept = []
seen_maps = set()
for s in plan:
    n = s["n"]
    old = cur[n - 1]
    if s.get("keep"):
        d = dict(old)
        d["flavor"] = "intro"
        levels.append(d)
        continue
    pick = None
    for c in cands.get(n, []):
        key = "|".join(c["dict"]["map"])
        if key in seen_maps:
            continue
        m = c["m"]      # candidates from an earlier pass still have to meet today's plan
        if m["len"] < s.get("len_min", 0) or m["cover"] < s.get("cover_min", 0) or m["free_orders"] < s.get("free_min", 0):
            continue
        if not (s["plans"][0] <= m["plans"] <= s["plans"][1]):
            continue
        band = s.get("diff", [0, 10])
        if not (band[0] - 1.2 <= m["difficulty"] <= band[1] + 1.2):
            continue
        if any(m["matters"].get(f) is False for f in s.get("need", []) if s["flavor"] != "districts"):
            continue
        pick = c
        break
    if pick is None:
        missing.append(n)
        d = dict(old)
        levels.append(d)
        continue
    seen_maps.add("|".join(pick["dict"]["map"]))
    g = pick["dict"]
    d = {"title": old["title"]}
    hint = HINTS.get(n, old.get("hint", "")) if not pick["kept"] else old.get("hint", "")
    if hint:
        d["hint"] = hint
    d["no_revisit"] = True
    if old.get("challenge"):
        d["challenge"] = True
    if g.get("return"):
        d["return"] = True
    d["flavor"] = s["flavor"]
    d["map"] = g["map"]
    if "gift" in g:
        d["gift"] = g["gift"]
    d["stack"] = g["stack"]
    levels.append(d)
    if pick["kept"]:
        kept.append(n)

text = '{\n  "levels": [\n' + ",\n".join(fmt_level(d) for d in levels) + "\n  ]\n}\n"
json.loads(text)
if not dry:
    open(os.path.join(ROOT, "levels", "levels.json"), "w").write(text)
print("%d levels %s. New: %d. Current level kept on merit: %s. No candidate (current level left in): %s" % (
    len(levels), "checked (dry run)" if dry else "written", len(levels) - len(missing) - len(kept) - sum(1 for s in plan if s.get("keep")),
    kept or "none", missing or "none"))
