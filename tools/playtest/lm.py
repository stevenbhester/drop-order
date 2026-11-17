#!/usr/bin/env python3
"""Drives a running copy of the game for a playtest (scripts/debug_remote.gd): the real game, played by taps.

  lm.py <name> start [--fresh] [--x N] [--args "..."]   open the game in its own window with its own save ("--fresh" wipes that save)
  lm.py <name> stop
  lm.py <name> state                     what's on screen, as text (screen, cards on top, buttons, the board)
  lm.py <name> shot                      ...and a picture of it (prints the PNG's path: look at it)
  lm.py <name> tap X Y                   tap at window pixels (the picture's pixels)
  lm.py <name> press "Label"             tap the button whose label has that text
  lm.py <name> hold "Label"|X Y SECS     press and hold
  lm.py <name> drive UURRD               in a level: drag a route from the van, a tile per letter (Up Down Left Right)
  lm.py <name> drag X,Y X,Y ... [keep]   a finger along those points ("keep": it stays down; `up X Y` lifts it)
  lm.py <name> up X Y                    lift the finger a "keep" drag left down
  lm.py <name> touch N down|up X Y       a raw finger event (finger N), as a phone sends it
  lm.py <name> resume                    as if the app just came back from the background
  lm.py <name> drag X,Y X,Y ...          (as above)
  lm.py <name> wait SECS
  lm.py <name> solve                     drive the job's answer from the start
Add --shot to any command for a picture after it. Every command prints the screen's text afterwards.
"""
import json, os, signal, subprocess, sys, time

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
USER = os.path.expanduser("~/Library/Application Support/Godot/app_userdata")


def main():
    a = sys.argv[1:]
    if len(a) < 2:
        print(__doc__); return
    name, op, rest = a[0], a[1], a[2:]
    d = os.path.join(ROOT, "build", "playtest", name)
    os.makedirs(d, exist_ok=True)
    pidf = os.path.join(d, "pid")
    if op == "stop" or op == "start":
        if os.path.exists(pidf):
            try: os.kill(int(open(pidf).read()), signal.SIGTERM)
            except Exception: pass
            os.remove(pidf)
        if op == "stop":
            print("stopped"); return
        if "--fresh" in rest:
            for root, _, files in os.walk(USER):
                for f in files:
                    if f == "save_pt_%s.json" % name:
                        os.remove(os.path.join(root, f))
        for f in os.listdir(d):
            if f.startswith(("out_", "cmd", "shot_")): os.remove(os.path.join(d, f))
        x = rest[rest.index("--x") + 1] if "--x" in rest else "40"
        log = open(os.path.join(d, "game.log"), "w")
        p = subprocess.Popen([GODOT, "--path", ROOT, "--resolution", "540x1170", "--position", "%s,40" % x, "--audio-driver", "Dummy", "--",
                              "--remote=" + d, "--profile=pt_" + name, "--ratings-url=http://127.0.0.1:9/x", "--daily-url=http://127.0.0.1:9",
                              "--feedback-url=http://127.0.0.1:9/x"] + (rest[rest.index("--args") + 1].split() if "--args" in rest else []), stdout=log, stderr=log, start_new_session=True)
        open(pidf, "w").write(str(p.pid))
        time.sleep(float(os.environ.get("LM_START_WAIT", "4.0")))
        op, rest = "state", []
    shot = "--shot" in rest or op == "shot"
    rest = [r for r in rest if r != "--shot"]
    cmd = {"op": op if op != "shot" else "state", "shot": shot}
    if op == "tap":
        cmd.update(x=float(rest[0]), y=float(rest[1]))
    elif op == "press":
        cmd.update(label=rest[0])
    elif op == "hold":
        if len(rest) >= 3: cmd.update(x=float(rest[0]), y=float(rest[1]), secs=float(rest[2]))
        else: cmd.update(label=rest[0], secs=float(rest[1]) if len(rest) > 1 else 1.5)
    elif op == "drive":
        cmd.update(moves=rest[0])
    elif op == "drag":
        if rest and rest[-1] == "keep":
            rest = rest[:-1]; cmd["keep"] = True
        cmd.update(points=[[float(v) for v in r.split(",")] for r in rest])
    elif op == "up":
        cmd.update(x=float(rest[0]), y=float(rest[1]))
    elif op == "touch":
        # touch INDEX down|up X Y : a raw finger event, as a phone sends it
        cmd.update(index=int(rest[0]), down=(rest[1] == "down"), x=float(rest[2]), y=float(rest[3]))
    elif op == "wait":
        cmd.update(secs=float(rest[0]) if rest else 1.0)
    seqf = os.path.join(d, "seq")
    n = int(open(seqf).read()) + 1 if os.path.exists(seqf) else 1
    open(seqf, "w").write(str(n))
    cmd["id"] = n
    tmp = os.path.join(d, "cmd.tmp")
    json.dump(cmd, open(tmp, "w"))
    os.replace(tmp, os.path.join(d, "cmd.json"))
    out = os.path.join(d, "out_%d.json" % n)
    t0 = time.time()
    while not os.path.exists(out):
        if time.time() - t0 > 60:
            print("no answer from the game in 60 s (is it running? lm.py %s start)" % name); sys.exit(1)
        time.sleep(0.05)
    r = json.load(open(out))
    os.remove(out)
    if r.get("note"): print("NOTE:", r["note"])
    if not r.get("ok", True): print("(that didn't work)")
    lines = r.get("state", "").split("\n")
    if op not in ("state", "shot"):
        # After an action: the short version (the board, and only what's on the topmost layer).
        ctl = [l for l in lines if l.startswith("  [")]
        top = max([int(l[3:l.index("]")]) for l in ctl], default=0)
        lines = [l for l in lines if not l.startswith("  (VAN the van") and (not l.startswith("  [") or int(l[3:l.index("]")]) == top)]
    print("\n".join(lines))
    if r.get("shot"): print("PICTURE:", r["shot"])


if __name__ == "__main__":
    main()
