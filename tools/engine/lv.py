#!/usr/bin/env python3
"""Level files <-> the one-line text the C engine (tools/engine/lm.c) reads.

  python3 tools/engine/lv.py levels/levels.json            # every level as a line on stdout
  python3 tools/engine/lv.py levels/side.json              # side roads (parts of mega routes are skipped)

A line is tab-separated: id, width, height, return (0/1), the map (rows joined by '/', tokens by spaces),
the stack as colour letters (bottom first).
"""
import json, sys

CODE = {"red": "r", "blue": "b", "green": "g", "yellow": "y", "purple": "p", "orange": "o"}
NAME = {v: k for k, v in CODE.items()}

def to_line(ident, d):
    rows = [" ".join(str(r).split()) for r in d["map"]]
    w = len(rows[0].split())
    stack = "".join(CODE.get(str(c), str(c)) for c in d.get("stack", []))
    return "%s\t%d\t%d\t%d\t%s\t%s" % (ident, w, len(rows), 1 if d.get("return") else 0, "/".join(rows), stack or "-")

def levels_of(path):
    data = json.load(open(path))
    if isinstance(data, dict) and "levels" in data:
        return [(str(i + 1), d) for i, d in enumerate(data["levels"])]
    if isinstance(data, dict) and "side" in data:
        return [(d["id"], d) for d in data["side"] if "map" in d]
    if isinstance(data, list):
        return [(str(i + 1), d) for i, d in enumerate(data)]
    return []

if __name__ == "__main__":
    for path in sys.argv[1:]:
        for ident, d in levels_of(path):
            print(to_line(ident, d))
