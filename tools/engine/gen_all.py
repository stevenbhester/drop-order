#!/usr/bin/env python3
"""Fills slots of the plan with `build/lm gen`, ten at a time. Candidates land in
build/engine/slot_NNN.<seed>.txt as `CAND {json}` lines.

  python3 tools/engine/gen_all.py [--seed N] [--time X] [--keep K] [slots...]
  (no slots: every slot that isn't "keep". --time scales each slot's search time; 1 is the plan's.)
"""
import json, os, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
args = sys.argv[1:]
def opt(name, default):
    if name in args:
        i = args.index(name); v = args[i + 1]; del args[i:i + 2]
        return v
    return default
seed = int(opt("--seed", 1)); scale = float(opt("--time", 1.0)); keep = int(opt("--keep", 12)); jobs = int(opt("--jobs", 10))
plan = json.load(open(os.path.join(ROOT, "tools", "level_plan.json")))["slots"]
want = [int(a) for a in args]
todo = [s for s in plan if not s.get("keep") and (not want or s["n"] in want)]
os.makedirs(os.path.join(ROOT, "build", "engine"), exist_ok=True)

def run(s):
    a = dict(s["args"])
    secs = a.pop("secs") * scale
    cmd = [os.path.join(ROOT, "build", "lm"), "gen", "slot=%d" % s["n"], "seed=%d" % seed, "secs=%g" % secs, "keep=%d" % keep]
    cmd += ["%s=%s" % kv for kv in a.items()]
    out = os.path.join(ROOT, "build", "engine", "slot_%03d.%d.txt" % (s["n"], seed))
    r = subprocess.run(cmd, capture_output=True, text=True)
    open(out, "w").write(r.stdout)
    return s["n"], r.stdout.count("CAND "), r.stderr.strip().splitlines()[-1] if r.stderr.strip() else ""

t0 = time.time()
todo.sort(key=lambda s: -s["args"]["secs"])       # the long ones first
with ThreadPoolExecutor(jobs) as ex:
    for n, k, note in ex.map(run, todo):
        if k == 0:
            print("slot %d: NO candidates  %s" % (n, note))
print("%d slots in %.0fs" % (len(todo), time.time() - t0))
