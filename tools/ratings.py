#!/usr/bin/env python3
"""Pulls the level ratings testers sent (the "Rate levels" option) and sets them beside what the level
engine expected of each level.

  python3 tools/ratings.py                 fetch everything new, then print the summary
  python3 tools/ratings.py --no-fetch      just the summary, from what's already been fetched
  python3 tools/ratings.py --level 23      every rating of one level, notes and all
  python3 tools/ratings.py --csv out.csv   one row per rating, stats spread into columns
  python3 tools/ratings.py --url http://localhost:5077/lm/ratings     another server (testing)

The ratings live in the MusicGrid server's database (table lm_level_ratings); reading them needs that
server's admin key. Put it in the file ~/.lastmile_admin_key (one line), or in the environment as
LM_ADMIN_KEY. It is never written anywhere by this script.

Fetched ratings are kept in build/ratings.jsonl (build/ is not in git), so each run only asks for what's new.
"""
import csv, json, os, subprocess, sys, urllib.request, urllib.parse
from collections import Counter, defaultdict

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
URL = "https://music-grid-io-42616e204fd3.herokuapp.com/lm/ratings"
STORE = os.path.join(ROOT, "build", "ratings.jsonl")
args = sys.argv[1:]

def opt(name, default=None):
    if name in args:
        return args[args.index(name) + 1]
    return default

def key():
    k = os.environ.get("LM_ADMIN_KEY", "").strip()
    path = os.path.expanduser("~/.lastmile_admin_key")
    if not k and os.path.exists(path):
        k = open(path).read().strip()
    if not k:
        sys.exit("No admin key. Put the MusicGrid server's ADMIN_KEY in ~/.lastmile_admin_key (one line), or set LM_ADMIN_KEY.")
    return k

def load():
    rows = {}
    if os.path.exists(STORE):
        for line in open(STORE):
            r = json.loads(line)
            rows[r["id"]] = r
    return rows

def fetch(rows):
    url = opt("--url", URL)
    since = max((r["receivedAt"] for r in rows.values()), default="")
    n = 0
    while True:
        q = {"limit": 5000}
        if since:
            q["since"] = since
        req = urllib.request.Request(url + "?" + urllib.parse.urlencode(q), headers={"x-admin-key": key()})
        try:
            got = json.load(urllib.request.urlopen(req, timeout=30))["ratings"]
        except urllib.error.HTTPError as e:
            sys.exit("The server said %d: %s" % (e.code, e.read().decode()[:200]))
        new = [r for r in got if r["id"] not in rows]
        for r in new:
            rows[r["id"]] = r
        n += len(new)
        if len(got) < 5000 or not new:
            break
        since = max(r["receivedAt"] for r in got)
    os.makedirs(os.path.dirname(STORE), exist_ok=True)
    with open(STORE, "w") as f:
        for r in sorted(rows.values(), key=lambda r: r["receivedAt"]):
            f.write(json.dumps(r) + "\n")
    print("%d new rating(s); %d in all (%s)" % (n, len(rows), os.path.relpath(STORE, ROOT)))

def expected():
    """What the plan and the engine say about each level today: tier, flavour, and the model's numbers."""
    out = {}
    try:
        plan = {s["n"]: s for s in json.load(open(os.path.join(ROOT, "tools", "level_plan.json")))["slots"]}
        sys.path.insert(0, os.path.join(ROOT, "tools", "engine"))
        import lv
        lines = "".join(lv.to_line(i, d) + "\n" for i, d in lv.levels_of(os.path.join(ROOT, "levels", "levels.json")))
        res = subprocess.run([os.path.join(ROOT, "build", "lm"), "score"], input=lines, capture_output=True, text=True).stdout
        for line in res.splitlines():
            m = json.loads(line)
            n = int(m["id"])
            s = plan.get(n, {})
            out[n] = {"tier": "tutorial" if s.get("keep") else s.get("tier", ""), "flavor": s.get("flavor", ""), "ptries": m.get("ptries", 0),
                      "pnodes": m.get("pnodes", 0), "drives": m.get("tries", 0)}
    except Exception as e:      # the summary still works without the engine built
        print("(no engine numbers: %s)" % e)
    return out

# The current version of each level (levels/level_versions.json: the layouts each level has had, oldest
# first), and which version a rating was on: its own record (sent since build 24), else its fingerprint.
HIST = json.load(open(os.path.join(ROOT, "levels", "level_versions.json"))) if os.path.exists(os.path.join(ROOT, "levels", "level_versions.json")) else {}

def current_version(n):
    return len(HIST.get(str(n), [])) or 0

def version_of(r):
    v = r["stats"].get("level_version")
    if v:
        return int(v)
    seen = HIST.get(str(r["level"]), [])
    fp = int(r["levelFp"]) if str(r["levelFp"]).lstrip("-").isdigit() else None
    for i in range(len(seen) - 1, -1, -1):
        if seen[i] == fp:
            return i + 1
    return 0

def mean(xs):
    xs = [x for x in xs if x]
    return sum(xs) / len(xs) if xs else 0.0

def med(xs):
    xs = sorted(xs)
    return xs[len(xs) // 2] if xs else 0

def rank(xs):
    order = sorted(range(len(xs)), key=lambda i: xs[i])
    r = [0.0] * len(xs)
    i = 0
    while i < len(order):
        j = i
        while j + 1 < len(order) and xs[order[j + 1]] == xs[order[i]]:
            j += 1
        for k in range(i, j + 1):
            r[order[k]] = (i + j) / 2.0
        i = j + 1
    return r

def spearman(a, b):
    if len(a) < 4:
        return None
    ra, rb = rank(a), rank(b)
    ma, mb = sum(ra) / len(ra), sum(rb) / len(rb)
    num = sum((x - ma) * (y - mb) for x, y in zip(ra, rb))
    den = (sum((x - ma) ** 2 for x in ra) * sum((y - mb) ** 2 for y in rb)) ** 0.5
    return num / den if den else None

rows = load()
if "--no-fetch" not in args:
    fetch(rows)
# The deploy check and the game's own self-tests mark themselves; they aren't anyone's opinion.
real = [r for r in rows.values() if not r["stats"].get("test") and not r["note"].startswith("Autotest note")]
main = [r for r in real if r["where"].startswith("Level ")]

if opt("--csv"):
    stat_keys = sorted({k for r in real for k in r["stats"]})
    with open(opt("--csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["received_at", "device", "session", "where", "level", "level_version", "current_version", "level_fp", "title", "flavor", "version", "difficulty", "fun", "frustration", "tags", "note"] + stat_keys)
        for r in sorted(real, key=lambda r: r["receivedAt"]):
            w.writerow([r["receivedAt"], r["device"][:8], r["session"][:8], r["where"], r["level"], version_of(r), current_version(r["level"]), r["levelFp"], r["title"], r["flavor"], r["version"],
                        r["difficulty"], r["fun"], r["frustration"], " ".join(r["tags"]), r["note"]] + [r["stats"].get(k, "") for k in stat_keys])
    print("wrote", opt("--csv"))
    sys.exit()

if opt("--level"):
    n = int(opt("--level"))
    for r in sorted((r for r in main if r["level"] == n), key=lambda r: r["receivedAt"]):
        s = r["stats"]
        v = version_of(r)
        tagv = ("level v%d" % v if v else "level v?") + ("" if v == current_version(n) else " (OLD LAYOUT; now v%d)" % current_version(n))
        print("%s  %s  %s  device %s  difficulty %d fun %d frustration %d  [%s]" % (r["receivedAt"][:16], r["version"], tagv, r["device"][:6], r["difficulty"],
                                                                         r["fun"], r["frustration"], ", ".join(r["tags"])))
        print("     wrong moves %s, restarts %s, undos %s, hints %s, stuck %s, %.0fs playing (%.0fs on the winning try), level layout %s" % (
            s.get("wrong_moves", 0), s.get("restarts", 0), s.get("undos", 0), s.get("hints", 0), s.get("stuck", 0), s.get("seconds_active", 0),
            s.get("seconds_winning_try", 0), r["levelFp"]))
        if r["note"]:
            print("     note: %s" % r["note"])
    sys.exit()

print("%d rating(s) from %d device(s) over %d session(s); %d of main levels" % (len(real), len({r["device"] for r in real}), len({r["session"] for r in real}), len(main)))
if not main:
    sys.exit()
exp = expected()
# A level that's been redesigned has a new version: only ratings of the current layout count here.
by = defaultdict(list)
for r in main:
    by[r["level"]].append(r)
print()
print("%-4s %-22s %-7s %-9s %2s  %-5s %-4s %-5s  %-6s %-6s %-5s %-5s %-6s  %-6s %-6s  %s" % (
    "#", "title", "tier", "kind", "n", "diff", "fun", "frust", "wrong", "retry", "undo", "hint", "secs", "plans", "drives", "said"))
pairs = []
flags = []
for n in sorted(by):
    cur = current_version(n)
    rs = [r for r in by[n] if version_of(r) == cur] if cur else by[n]
    if not rs:
        print("%-4d (only ratings of older layouts: %d; now v%d)" % (n, len(by[n]), cur))
        continue
    e = exp.get(n, {})
    st = lambda k: [r["stats"].get(k, 0) for r in rs]
    tags = Counter(t for r in rs for t in r["tags"])
    d, fu, fr = mean(r["difficulty"] for r in rs), mean(r["fun"] for r in rs), mean(r["frustration"] for r in rs)
    print("%-4d %-22s %-7s %-9s %2d  %-5s %-4s %-5s  %-6s %-6s %-5s %-5s %-6.0f  %-6s %-6s  %s%s" % (
        n, rs[0]["title"][:22], e.get("tier", ""), e.get("flavor", "")[:9], len(rs), "%.1f" % d if d else "-", "%.1f" % fu if fu else "-",
        "%.1f" % fr if fr else "-", med(st("wrong_moves")), med(st("restarts")), med(st("undos")), med(st("hints")), med(st("seconds_active")),
        "%.1f" % e["ptries"] if e else "", "%.1f" % e["drives"] if e else "", ", ".join("%s%s" % (t, "×%d" % c if c > 1 else "") for t, c in tags.most_common(4)),
        ("  v%d" % cur) + ("  (+%d on older layouts)" % (len(by[n]) - len(rs)) if len(by[n]) > len(rs) else "")))
    if d and e:
        pairs.append((e["ptries"], d, med(st("wrong_moves")) + med(st("restarts"))))
        tier = e.get("tier")
        if tier in ("hard", "melter", "end") and (d <= 2 or "too_easy" in tags):
            flags.append("Level %d (%s, planned %s) played easy: difficulty %.1f%s." % (n, rs[0]["title"], tier, d, ", " + ", ".join(tags) if tags else ""))
        if tier in ("easy", "tutorial") and d >= 4:
            flags.append("Level %d (%s, planned easy) played hard: difficulty %.1f." % (n, rs[0]["title"], d))
        if fr >= 4 and fu and fu <= 2:
            flags.append("Level %d (%s): frustrating (%.1f) and not fun (%.1f)." % (n, rs[0]["title"], fr, fu))
        if tier == "melter" and len(rs) >= 2 and "thought_bugged" not in tags and "aha" not in tags:
            flags.append("Level %d (%s) is meant to be a mind-melter and nobody said aha or bugged." % (n, rs[0]["title"]))
        if "unfair" in tags:
            flags.append("Level %d (%s) felt unfair." % (n, rs[0]["title"]))
print()
if flags:
    print("Worth a look:")
    for f in flags:
        print("  -", f)
r1 = spearman([p[0] for p in pairs], [p[1] for p in pairs])
r2 = spearman([p[0] for p in pairs], [p[2] for p in pairs])
if r1 is not None:
    print("\nDoes the model agree with the players? Rank correlation over %d rated levels (1 = same order, 0 = unrelated):" % len(pairs))
    print("  model's wrong plans vs rated difficulty:           %.2f" % r1)
    if r2 is not None:
        print("  model's wrong plans vs wrong moves plus restarts:  %.2f" % r2)
else:
    print("(The model-against-players check needs at least four rated levels.)")
