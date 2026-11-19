#!/usr/bin/env python3
"""Composes and renders the background music: audio/chill.wav (a seamless loop), for everywhere but the title.

    python3 tools/make_chill.py            # writes audio/chill.wav and prints a few checks
    python3 tools/make_chill.py --stems    # also build/chill/<part>.wav

The title theme's band (tools/make_theme.py), sat down: 84 BPM, F major, 32 bars, about a minute and a half.

WHAT IT'S ABOUT
Thinking hard, then getting it, over and over: that's a job in this game. The loop is four thoughts of eight
bars, and each goes the same way:

    bars 1-5   pondering   chords that don't resolve (ii, V, a wrong turn), an electric piano holding them,
                           and the vibes asking a short question, then again a step along (another idea)
    bar 6      nearly...   the chords change twice as fast, the piano starts turning over, the vibes run up
                           the scale to the leading note, and everything stops: a held breath
    bars 7-8   aha         the home chord at last, a bell run up it, and the clarinet plays the title tune's
                           hook (the same notes: getting it sounds like the game), then it settles

Each thought takes a different road there (the second tries a brighter chord and then doubts it, the third
goes round in circles in the minor with a clock ticking, the fourth is quick and sure of itself), so the loop
doesn't wear its welcome out. Nothing is loud, nothing is bright, and the kick is a pat on the shoulder.
"""
import math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_theme as mt

mt.setup(bpm=84, bars=32, sr=24000, swing=0.22)
TAU = mt.TAU
midi, hz = mt.midi, mt.hz

# ------------------------------------------------------------------ the score

# A chord a bar; "X|Y" changes halfway. Four thoughts of eight bars: six to think, two to have got it.
CHORDS = (
    "Gm9 Gm9 Csus C7 Am7|D7 Gm9|C13 Fmaj9 Fmaj9 "
    "Dm9 G13 Bbmaj7 Bbm6 Am7|D7 Gm9|C13 Fmaj9 F6 "
    "Dm9 Dm9 Em7b5 A7 Dm9|Db9 Csus|C13 Fmaj9 Fmaj9 "
    "Gm9 C13 Am7 D7 Bbmaj7|Bbm6 Gm9|C13 Fmaj9 F6|D7"
).split()
# How the electric piano plays each (no root: the bass has it), its bass note, and every note that belongs.
VOICE = {"Gm9": "F4 A4 Bb4 D5", "Csus": "F4 Bb4 D5", "C7": "E4 Bb4 D5", "C13": "E4 A4 Bb4 D5", "Am7": "G4 A4 C5 E5",
         "D7": "F#4 C5 E5", "Fmaj9": "E4 G4 A4 C5", "F6": "A4 C5 D5 F5", "Dm9": "F4 A4 C5 E5", "G13": "F4 A4 B4 E5",
         "Bbmaj7": "A4 D5 F5", "Bbm6": "G4 Bb4 Db5 F5", "Em7b5": "G4 Bb4 D5", "A7": "G4 Bb4 C#5 E5", "Db9": "F4 B4 Eb5"}
ROOT = {"Gm9": "G2", "Csus": "C3", "C7": "C3", "C13": "C3", "Am7": "A2", "D7": "D3", "Fmaj9": "F2", "F6": "F2",
        "Dm9": "D3", "G13": "G2", "Bbmaj7": "Bb2", "Bbm6": "Bb2", "Em7b5": "E3", "A7": "A2", "Db9": "Db3"}
TONES = {"Gm9": "G Bb D F A C", "Csus": "C F G Bb D A", "C7": "C E G Bb D A", "C13": "C E G Bb D A", "Am7": "A C E G D",
         "D7": "D F# A C E", "Fmaj9": "F A C E G D", "F6": "F A C D G", "Dm9": "D F A C E G", "G13": "G B D F A E",
         "Bbmaj7": "Bb D F A C G", "Bbm6": "Bb Db F G C", "Em7b5": "E G Bb D A", "A7": "A C# E G Bb", "Db9": "Db F Ab B Eb"}
mt.SEMI.update({"Db": 1, "Ab": 8, "D#": 3})

# The vibes: the question. A bar a line, note:length in 16ths ("r" rests). (Played an octave lower.)
VIBES = """
r:4 D5:2 F5:2 A5:6 r:2
r:4 A5:2 G5:2 F5:4 r:4
r:4 D5:2 G5:2 Bb5:6 r:2
r:4 Bb5:2 A5:2 G5:4 r:4
r:2 G5:2 A5:2 C6:2        C6:2 A5:2 F#5:4
G5:1 A5:1 Bb5:1 C6:1 D6:2 r:2   E6:2 r:6
r:16
r:16
A5:3 F5:3 E5:2            r:8
B5:3 A5:3 E5:2            r:8
r:2 D5:2 F5:2 A5:2        C6:4 r:4
r:2 Db5:2 F5:2 G5:2       Bb5:4 r:4
A5:2 C6:2 E6:4            D6:2 C6:2 A5:2 F#5:2
D5:1 F5:1 G5:1 Bb5:1 C6:2 r:2   E6:2 r:6
r:16
r:16
r:8                       D5:2 E5:2 F5:4
r:8                       F5:2 E5:2 D5:4
r:8                       E5:2 G5:2 Bb5:4
r:8                       Bb5:2 G5:2 E5:2 C#5:2
D5:4 r:4                  Eb5:2 F5:2 Ab5:2 B5:2
G5:1 A5:1 Bb5:1 C6:1 D6:2 r:2   E6:2 r:6
r:16
r:16
D5:2 F5:2 A5:2 C6:2       Bb5:4 r:4
E5:2 G5:2 Bb5:2 D6:2      A5:4 r:4
C5:2 E5:2 G5:2 C6:2       A5:4 r:4
D5:2 F#5:2 A5:2 C6:2      E6:4 r:4
D6:2 C6:2 A5:2 F5:2       G5:2 F5:2 Db5:2 Bb4:2
G5:1 A5:1 Bb5:1 C6:1 D6:2 r:2   E6:2 r:6
r:16
r:8                       A5:2 F#5:2 D5:2 C5:2
"""
# The clarinet: the answer (written an octave up, like the title's lead). Bars 7-8 of each thought; the first
# of each pair is a bar of the title tune.
AHA = {
    6: "F5:2 A5:1 C6:1 C6:4   A5:2 C6:1 A5:1 F5:4",
    7: "A5:2 C6:2 E6:6 r:6",
    14: "F5:2 A5:1 C6:1 F6:4   E6:2 D6:1 C6:1 A5:4",
    15: "G5:2 A5:2 C6:4 r:8",
    22: "F5:2 A5:1 C6:1 C6:4   D6:2 C6:1 A5:1 C6:4",
    23: "A5:2 G5:2 F5:4 r:8",
    30: "F5:2 A5:1 C6:1 F6:4   E6:2 D6:1 C6:1 A5:4",
    31: "F5:4 r:12",
}


def bar_of(line):
    bar = [(t.split(":")[0], int(t.split(":")[1])) for t in line.split()]
    assert sum(n for _, n in bar) == 16, "a bar of %d sixteenths: %s" % (sum(n for _, n in bar), line)
    return bar


vibes = [bar_of(l) for l in VIBES.strip().splitlines()]
aha = {k: bar_of(v) for k, v in AHA.items()}
assert len(vibes) == mt.BARS and len(CHORDS) == mt.BARS


def chord_at(bar, step):
    c = CHORDS[bar].split("|")
    return c[0] if len(c) == 1 or step < 8 else c[1]


# ------------------------------------------------------------------ the mix

def render():
    STEP, at = mt.STEP, mt.at
    tracks = {k: mt.Track(k) for k in ["keys", "bass", "drums", "vibes", "aha"]}
    cache = {}

    def get(key, make):
        if key not in cache:
            cache[key] = make()
        return cache[key]

    def strike(bar, step, ch, steps, gain, strum=0.012):
        for k, name in enumerate(VOICE[ch].split()):
            m = midi(name)
            tracks["keys"].add(get(("rh", m, steps), lambda: mt.rhodes(hz(m), steps * STEP * 0.96)), at(bar, step) + strum * k, gain, -0.3 + 0.2 * k)

    K, SN, SH, SG = mt.soft_kick(), mt.snap(), mt.shaker(), mt.shaker(0.5)
    tick, tock = mt.tok(1000.0), mt.tok(790.0)
    toms = [mt.tom(110.0), mt.tom(92.0)]
    crash = mt.noise_band(int(1.6 * mt.SR), 2500.0, 8000.0, lambda t: min(1.0, t / 0.01) * math.exp(-t / 0.45))
    for bar in range(mt.BARS):
        thought, p = bar // 8, bar % 8
        two = "|" in CHORDS[bar]
        c0, c1 = chord_at(bar, 0), chord_at(bar, 8)
        r0, r1 = midi(ROOT[c0]), midi(ROOT[c1])
        D, B = tracks["drums"], tracks["bass"]
        bass = lambda m, ln: get(("bass", m, ln), lambda: mt.bass_note(hz(m), ln * STEP * 0.9))
        if p == 5:
            # Nearly: the piano turns over in 8ths, then two beats of held breath (and a heartbeat into the aha).
            for k, s in enumerate((0, 2, 4, 6)):
                strike(bar, s, c0, 2, 0.085 + 0.012 * k, 0.006)
            strike(bar, 8, c1, 2, 0.13, 0.006)
            B.add(bass(r0, 4), at(bar, 0), 0.5)
            B.add(bass(r0 + 7, 4), at(bar, 4), 0.45)
            B.add(bass(r1, 2), at(bar, 8), 0.5)
            for s in (0, 4, 8):
                D.add(K, at(bar, s), 0.5)
            D.add(toms[0], at(bar, 14), 0.2, -0.2)
            D.add(toms[1], at(bar, 15), 0.26, 0.2)
        elif p >= 6:
            # Aha (and the bar after, settling).
            first = p == 6
            strike(bar, 0, c0, 8 if two else 15, 0.15 if first else 0.11, 0.03 if first else 0.012)
            if two:
                strike(bar, 8, c1, 7, 0.1)
            B.add(bass(r0, 10 if not two else 7), at(bar, 0), 0.55)
            if two:
                B.add(bass(r1, 7), at(bar, 8), 0.5)
            else:
                B.add(bass(r0 + 7, 3), at(bar, 12), 0.4)
            for s in ((0, 6, 10) if first else (0, 10)):
                D.add(K, at(bar, s), 0.62 if s == 0 and first else 0.45)
            for s in (4, 12):
                D.add(SN, at(bar, s), 0.3, 0.25)
            for s in range(2, 16, 2):
                D.add(SH if s % 4 == 2 else SG, at(bar, s), 0.6, 0.3)
            if first:
                D.add(crash, at(bar, 0), 0.18 if thought < 3 else 0.26, -0.1)
                # The bell run up the home chord, a little faster than the beat, left to right.
                run = ["F5", "A5", "C6", "E6", "G6"] + (["A6", "C7"] if thought == 3 else [])
                for k, name in enumerate(run):
                    m = midi(name)
                    tracks["aha"].add(get(("bell", m), lambda: mt.boop(hz(m), 0.55)), at(bar, 0) + k * STEP * 0.62, 0.1 + 0.012 * k, -0.5 + k / (len(run) - 1.0))
                for name in ("F3", "A3", "C4", "E4"):
                    m = midi(name)
                    tracks["aha"].add(get(("pad", m), lambda: mt.pad(hz(m), 22 * STEP)), at(bar, 0), 0.05 if thought < 3 else 0.075, 0.2)
        else:
            # Pondering.
            strike(bar, 0, c0, 8 if two else 10, 0.12)
            if two:
                strike(bar, 8, c1, 7, 0.11)
            elif thought != 2:
                strike(bar, 10, c0, 5, 0.07)
            B.add(bass(r0, 6), at(bar, 0), 0.5)
            if two:
                B.add(bass(r1, 6), at(bar, 8), 0.5)
            else:
                B.add(bass(r0 + 7 if thought % 2 else r0, 2), at(bar, 10), 0.36)
                nxt = midi(ROOT[chord_at((bar + 1) % mt.BARS, 0)])
                if nxt != r0:
                    B.add(bass(mt.neighbour(nxt, 1 if nxt < r0 else -1), 2), at(bar, 14), 0.36)
            for s in (0, 10):
                D.add(K, at(bar, s), 0.45)
            if thought % 2 == 0:
                # A clock, while it goes round in the head.
                for s in (0, 4, 8, 12):
                    D.add(tick if s % 8 == 0 else tock, at(bar, s), 0.11, 0.4)
            else:
                for s in (4, 12):
                    D.add(SN, at(bar, s), 0.36, 0.25)
                for s in range(2, 16, 2):
                    D.add(SH if s % 4 == 2 else SG, at(bar, s), 0.5, 0.3)

        # The vibes' question (with an echo), and the clarinet's answer. The vibes sit an octave under where
        # they're written: pondering is low and dark, and it's the aha that's bright.
        step = 0
        for name, ln in vibes[bar]:
            if name != "r":
                m = midi(name) - 12
                v = get(("vibe", m), lambda: mt.boop(hz(m), 0.36))
                tracks["vibes"].add(v, at(bar, step), 0.3, -0.25)
                tracks["vibes"].add(v, at(bar, step) + 3 * STEP, 0.08, 0.45)
            step += ln
        step = 0
        for name, ln in aha.get(bar, []):
            if name != "r":
                m = midi(name) - 12
                dur = ln * STEP * (0.94 if ln > 1 else 0.85)
                vib = 0.006 if ln >= 4 else 0.0
                tracks["aha"].add(get(("clar", m, ln), lambda: mt.clarinet(hz(m), dur, vib)), at(bar, step), 0.17)
                low = mt.third_below(m) if thought == 3 else None
                if low is not None:
                    tracks["aha"].add(get(("harm", low, ln), lambda: mt.brass(hz(low), dur, vib=vib)), at(bar, step), 0.05, 0.3)
            step += ln
    return tracks


def check(tracks, l, r):
    odd = []
    for label, part, shift in (("vibes", dict(enumerate(vibes)), 0), ("clarinet", aha, 0)):
        for bar, notes in part.items():
            step = 0
            for name, ln in notes:
                if name != "r" and ln >= 2:
                    ch = chord_at(bar, step)
                    if mt.SEMI[name[:-1]] not in [mt.SEMI[x] for x in TONES[ch].split()]:
                        odd.append("%s, bar %d step %d: %s over %s" % (label, bar + 1, step, name, ch))
                step += ln
    print("notes (an 8th or longer) outside their chord: %d" % len(odd))
    for o in odd:
        print("   " + o)
    print("length %.3fs (%d bars at %d BPM)   peak %.2f   loudness %.1f dB" % (
        mt.N / mt.SR, mt.BARS, mt.BPM, max(max(map(abs, l)), max(map(abs, r))), mt.rms_db([(l[i] + r[i]) / 2.0 for i in range(0, mt.N, 3)])))
    for name, T in tracks.items():
        print("   %-8s %.1f dB" % (name, mt.rms_db([(T.l[i] + T.r[i]) / 2.0 for i in range(0, mt.N, 3)])))
    # The shape it's meant to have: quiet in the breath, loudest on the aha.
    bar_n = mt.N // mt.BARS
    def level(a, b):
        return mt.rms_db([(l[i] + r[i]) / 2.0 for i in range(int(a * bar_n), int(b * bar_n), 2)])
    for t in range(4):
        print("   thought %d: pondering %.1f dB, the breath %.1f dB, the aha %.1f dB" % (
            t + 1, level(t * 8, t * 8 + 5), level(t * 8 + 5.6, t * 8 + 5.85), level(t * 8 + 6, t * 8 + 7)))
    print("seam: last sample %.4f, first %.4f" % (l[-1], l[0]))


if __name__ == "__main__":
    tracks = render()
    l, r = mt.master(tracks, eq=[(60.0, 3.0, 0.9), (420.0, -3.5, 0.8), (2500.0, 2.0, 0.8)], ducked=False, top=9000.0)
    mt.write(os.path.join(mt.ROOT, "audio", "chill.wav"), l, r)
    check(tracks, l, r)
    if "--stems" in sys.argv:
        for name, T in tracks.items():
            mt.write(os.path.join(mt.ROOT, "build", "chill", name + ".wav"), T.l, T.r)
    print("wrote audio/chill.wav")
