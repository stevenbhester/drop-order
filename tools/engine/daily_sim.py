#!/usr/bin/env python3
"""Test-drives every daily with the same 30 simulated drivers, for the "How everyone did" page.

Until real players pile up, a daily's numbers are these: thirty made-up drivers (levels/daily_sim.json),
the same thirty for every daily, so the numbers say how hard that daily is. Each driver has a skill (from
"just finished the tutorial" to "plans the whole thing first") and habits: how fast they drive, whether a
wrong turn means Undo or Retry, whether they dawdle. What happens to them on a daily comes from the level
engine's model of it (`build/lm score`: failed drives by skill, how much there is to hold, how long the
answer is), with dice that are fixed per driver and puzzle, so re-running changes nothing unless a puzzle
did.

  python3 tools/engine/daily_sim.py        writes build/daily_sim_raw.json, then has the game score it
                                           (tools/sim_dailies.gd: badges and points by the game's own rules)
                                           into levels/daily_sim.json
"""
import hashlib, json, math, os, random, subprocess, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lv

MAX_TRIES = 6
FREE_UNDOS = 3

# The thirty: (name, skill 0-1, pace (x time), undo habit (chance a wrong turn is undone, not restarted),
# dawdle (chance of taking a longer way where there is one)).
def drivers():
    rng = random.Random(20261115)
    out = []
    kinds = [("rookie", 0.05, 0.3, 8), ("regular", 0.35, 0.7, 14), ("expert", 0.75, 1.0, 8)]
    for kind, lo, hi, n in kinds:
        for k in range(n):
            out.append({"name": "%s_%d" % (kind, k + 1), "skill": round(rng.uniform(lo, hi), 2), "pace": round(rng.choice([0.7, 0.85, 1.0, 1.0, 1.2, 1.5, 1.9]), 2),
                        "undo": round(rng.uniform(0.1, 0.9), 2), "dawdle": round(rng.uniform(0.0, 0.5), 2)})
    return out


def lerp3(v, s):
    """v = [new, regular, expert] at skill 0, 0.5, 1."""
    return v[0] + (v[1] - v[0]) * s * 2 if s < 0.5 else v[1] + (v[2] - v[1]) * (s - 0.5) * 2


def drive(d, m, key):
    rng = random.Random(int(hashlib.sha1(("%s|%s" % (d["name"], key)).encode()).hexdigest()[:12], 16))
    s = d["skill"]
    # Wrong drives before the right one: the model's mean for this skill; planners (high skill) do some of
    # that failing in their heads instead (the plan view's wrong plans cost them time, not drives).
    mean = max(0.0, lerp3(m["tries3"], s)) * (1.0 - 0.45 * s)
    p_first = min(0.97, max(lerp3(m["first3"], s), m["pfirst"] * s))
    fails = 0
    if rng.random() > p_first:
        fails = 1
        while rng.random() < mean / (mean + 1.0) and fails < 30:
            fails += 1
    attempts, undos, free = 1, 0, FREE_UNDOS
    for _ in range(fails):
        if free > 0 and rng.random() < d["undo"]:
            n = rng.choice([1, 1, 2])
            undos += n
            free -= n
        else:
            attempts += 1
            undos, free = 0, FREE_UNDOS        # (the record keeps the winning try's undos)
    solved = attempts <= MAX_TRIES
    attempts = min(attempts, MAX_TRIES)
    length = m["len"]
    tiles = length
    if m["routes"] > 1 and rng.random() < d["dawdle"]:
        tiles += rng.choice([2, 4, 6, 8])
    think = m["pnodes"] * 1.2 * (1.35 - 0.7 * s) * (1.0 if attempts == 1 else 0.45)
    secs = d["pace"] * (tiles * 0.4 + 4.0 + think + undos * 4.0) * rng.uniform(0.85, 1.25)
    return {"done": solved, "attempts": attempts, "time": round(secs, 1), "tiles": tiles, "undos": undos, "shortest": length}


def main():
    path = os.path.join(ROOT, "levels", "daily.json")
    levels = json.load(open(path))["levels"]
    lines = "".join(lv.to_line(i, d) + "\n" for i, d in lv.levels_of(path))
    out = subprocess.run([os.path.join(ROOT, "build", "lm"), "score"], input=lines, capture_output=True, text=True).stdout
    rows = [json.loads(l) for l in out.splitlines()]
    assert len(rows) == len(levels), "lm scored %d of %d dailies" % (len(rows), len(levels))
    ds = drivers()
    raw = {"drivers": ds, "puzzles": []}
    for L, m in zip(levels, rows):
        key = "/".join(L["map"]) + "|" + ",".join(L["stack"])
        raw["puzzles"].append({"title": L["title"], "fp": hashlib.sha1(key.encode()).hexdigest()[:12], "runs": [drive(d, m, key) for d in ds]})
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    json.dump(raw, open(os.path.join(ROOT, "build", "daily_sim_raw.json"), "w"))
    godot = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
    r = subprocess.run([godot, "--headless", "--path", ROOT, "--script", "res://tools/sim_dailies.gd"], capture_output=True, text=True)
    print("\n".join(l for l in r.stdout.splitlines() if not l.startswith("Godot Engine")))


if __name__ == "__main__":
    main()
