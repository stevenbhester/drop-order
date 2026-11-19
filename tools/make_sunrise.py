#!/usr/bin/env python3
"""Composes and renders the background music: audio/sunrise.wav (a seamless loop), for everywhere but the title.

    python3 tools/make_sunrise.py            # writes audio/sunrise.wav and prints a few checks
    python3 tools/make_sunrise.py --stems    # also build/sunrise/<part>.wav

WHAT IT'S ABOUT
Steven's brief: "you're awake before the rest of your family watching the sun rise, excited for a busy crazy
day, but for now all there is to do is wait and prepare yourself." Looking forward, not melancholy. After two
tracks he named: "Tadow" (Masego and FKJ: a jam built by looping, a guitar figure and finger snaps first, then
bass, keys and sax a layer at a time) and "Paspatou" (Parra for Cuva: silky plucked guitar over a soft
electronic pulse). So:

  - A plucked guitar figure that never stops, in the game's 3 + 3 + 2, with an echo: energy, held in.
  - It's built a layer at a time, eight bars each, and the pad under it gets brighter with every layer: that's
    the sun. Guitar alone; then snaps, a round sliding bass and an electric piano; then a sax with the tune;
    then a soft kick on every beat and a kalimba (the day's nearly here); then it thins back to the guitar,
    which is where the loop starts again.
  - The harmony only ever climbs: IV, V, vi, I, the bass a step up each bar, and at the top ii, iii, IV, V,
    which stops on the V and doesn't resolve. The tune's phrases end going up, on the 9th or the 5th. Nothing
    lands; it's all about to.
  - F major and mostly its pentatonic, like the title theme: no semitone rubs, nothing sad in it.

104 BPM with the snap on three (so it sits back like a 52), 40 bars, about a minute and a half.
"""
import math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_theme as mt

mt.setup(bpm=104, bars=40, sr=24000, swing=0.14)
TAU = mt.TAU
midi, hz = mt.midi, mt.hz

# ------------------------------------------------------------------ the score

RISE = "Bbmaj9 C69 Dm7 Fadd9".split()            # IV V vi I: the bass climbs a step a bar
PEAK = "Gm9 Am7 Bbmaj9 Csus|C".split()           # ii iii IV V: and stops on the V
CHORDS = RISE * 6 + PEAK * 2 + RISE * 2
# What the guitar picks (low to high), the piano's voicing, the pad's, the bass note, and every note that fits.
ARP = {"Bbmaj9": "D4 F4 A4 C5", "C69": "E4 G4 A4 D5", "Dm7": "F4 A4 C5 D5", "Fadd9": "G4 A4 C5 F5",
       "Gm9": "F4 A4 Bb4 D5", "Am7": "G4 A4 C5 E5", "Csus": "F4 G4 C5 D5", "C": "E4 G4 C5 D5"}
KEYS = {"Bbmaj9": "A3 C4 D4 F4", "C69": "A3 D4 E4 G4", "Dm7": "A3 C4 F4", "Fadd9": "A3 C4 G4",
        "Gm9": "Bb3 D4 F4 A4", "Am7": "C4 E4 G4", "Csus": "Bb3 D4 F4 G4", "C": "Bb3 D4 E4 G4"}
PAD = {"Bbmaj9": "Bb2 F3 D4", "C69": "C3 G3 E4", "Dm7": "D3 A3 F4", "Fadd9": "F3 C4 G4",
       "Gm9": "G2 D3 Bb3", "Am7": "A2 E3 C4", "Csus": "C3 G3 F4", "C": "C3 G3 E4"}
ROOT = {"Bbmaj9": "Bb1", "C69": "C2", "Dm7": "D2", "Fadd9": "F2", "Gm9": "G1", "Am7": "A1", "Csus": "C2", "C": "C2"}
TONES = {"Bbmaj9": "Bb D F A C G", "C69": "C E G A D", "Dm7": "D F A C G E", "Fadd9": "F A C G D",
         "Gm9": "G Bb D F A C", "Am7": "A C E G D", "Csus": "C F G Bb D A", "C": "C E G D A"}

# The sax: the tune, from the third layer (bar 17). A bar a line, note:length in 16ths ("r" rests), written an
# octave up. Each phrase ends on its way up.
SAX = """
r:4 F5:2 A5:2 C6:6 r:2
r:4 G5:2 A5:2 D6:6 r:2
r:2 A5:2 C6:2 D6:2 F6:6 r:2
A5:2 C6:2 F6:4 G6:6 r:2
r:4 A5:2 C6:2 D6:4 C6:2 A5:2
G5:2 A5:2 C6:2 D6:2 E6:6 r:2
F6:6 D6:2 C6:2 D6:2 F6:4
G6:8 r:8
D6:2 F6:2 A6:4 G6:2 F6:2 D6:4
E6:2 G6:2 A6:4 G6:2 E6:2 C6:4
F6:2 A6:2 C7:4 A6:2 F6:2 D6:4
F6:4 G6:4          E6:2 G6:2 C7:4
Bb6:3 A6:3 F6:2 D6:4 F6:4
C7:3 A6:3 G6:2 E6:4 G6:4
A6:3 C7:3 A6:2 F6:4 A6:4
G6:4 F6:4          G6:2 A6:2 C7:4
A6:6 F6:2 D6:8
r:4 E6:2 G6:2 A6:8
r:4 D6:2 F6:2 A6:6 r:2
G6:10 r:6
"""
SAX_FROM = 16
SAX_DOWN = 24                 # it sounds two octaves under where it's written: a tenor's middle


def bar_of(line):
    bar = [(t.split(":")[0], int(t.split(":")[1])) for t in line.split()]
    assert sum(n for _, n in bar) == 16, "a bar of %d sixteenths: %s" % (sum(n for _, n in bar), line)
    return bar


sax = [bar_of(l) for l in SAX.strip().splitlines()]
assert len(CHORDS) == mt.BARS and SAX_FROM + len(sax) <= mt.BARS
mt.SEMI.update({"Db": 1, "Ab": 8})


def chord_at(bar, step):
    c = CHORDS[bar].split("|")
    return c[0] if len(c) == 1 or step < 8 else c[1]


def sax_note(f, dur, vib):
    """A tenor, soft: a saw with most of its edge filtered off, a slow front, a scoop up into the note."""
    return mt.horn(f, dur, "saw", fc_hi=2600.0, fc_lo=1500.0, fdec=0.12, att=0.035, rel=0.09, vib=vib, scoop=-0.8, sus=0.85)


# ------------------------------------------------------------------ the mix

# How bright the pad is in each layer of eight bars: the sun coming up, then the loop's quiet end.
LIGHT = [700.0, 1000.0, 1500.0, 2400.0, 1300.0]


def render():
    STEP, at = mt.STEP, mt.at
    tracks = {k: mt.Track(k) for k in ["guitar", "pad", "keys", "bass", "drums", "sax", "kalimba"]}
    cache = {}

    def get(key, make):
        if key not in cache:
            cache[key] = make()
        return cache[key]

    K, SN, SH, SG, C = mt.soft_kick(), mt.snap(), mt.shaker(), mt.shaker(0.5), mt.clap()
    prev_root = midi(ROOT[CHORDS[-1].split("|")[-1]])
    for bar in range(mt.BARS):
        layer, k8 = bar // 8, bar % 8
        last = layer == 4
        G, D, B = tracks["guitar"], tracks["drums"], tracks["bass"]

        # The guitar: 3 + 3 + 2, up the chord and back, with an echo a dotted 8th behind and across.
        for k, s in enumerate((0, 3, 6, 8, 11, 14)):
            names = ARP[chord_at(bar, s)].split()
            m = midi(names[(0, 1, 2, 3, 2, 1)[k]])
            g = get(("pl", m), lambda: mt.pluck(hz(m), 1.1, 0.9965, 0.55))
            loud = 0.95 if k in (0, 3) else 0.75
            G.add(g, at(bar, s), loud, -0.35)
            G.add(g, at(bar, s) + 3 * STEP, loud * 0.36, 0.45)
        # A second guitar an octave down in the full layers, on the off-beats (Tadow's chop).
        if layer in (2, 3):
            for s in (6, 14):
                for j, name in enumerate(ARP[chord_at(bar, s)].split()[:3]):
                    m = midi(name) - 12
                    G.add(get(("chop", m), lambda: mt.pluck(hz(m), 0.22, 0.99, 0.75)), at(bar, s) + 0.007 * j, 0.42, 0.15)

        # The pad: there from the first bar, brighter each layer.
        for half in ((0, 8) if "|" in CHORDS[bar] else (0,)):
            ch = chord_at(bar, half)
            steps = 8 if "|" in CHORDS[bar] else 16
            for j, name in enumerate(PAD[ch].split()):
                m = midi(name)
                tracks["pad"].add(get(("pad", m, steps, layer), lambda: mt.pad(hz(m), steps * STEP, LIGHT[layer])),
                                  at(bar, half) - 0.2, 0.085 + 0.012 * min(layer, 3), -0.3 + 0.3 * j)

        # From the second layer: the electric piano (the chord, and a push into the next bar) and the bass.
        if layer >= 1 and not (last and k8 >= 4):
            for half in ((0, 8) if "|" in CHORDS[bar] else (0,)):
                ch = chord_at(bar, half)
                for j, name in enumerate(KEYS[ch].split()):
                    m = midi(name)
                    tracks["keys"].add(get(("rh", m, 9), lambda: mt.rhodes(hz(m), 9 * STEP)), at(bar, half) + 0.014 * j, 0.085, 0.1 + 0.15 * j)
            if "|" not in CHORDS[bar]:
                for j, name in enumerate(KEYS[chord_at(bar, 14)].split()):
                    m = midi(name)
                    tracks["keys"].add(get(("rh", m, 2), lambda: mt.rhodes(hz(m), 2 * STEP)), at(bar, 14) + 0.008 * j, 0.05, 0.1 + 0.15 * j)
            r0, r1 = midi(ROOT[chord_at(bar, 0)]), midi(ROOT[chord_at(bar, 8)])
            B.add(get(("b", prev_root, r0, 6), lambda: mt.glide_bass(hz(prev_root), hz(r0), 6 * STEP)), at(bar, 0), 0.3)
            B.add(get(("b", r0, r0 + 12, 2), lambda: mt.glide_bass(hz(r0), hz(r0 + 12), 2 * STEP)), at(bar, 10), 0.18)
            if r1 != r0:
                B.add(get(("b", r0, r1, 4), lambda: mt.glide_bass(hz(r0), hz(r1), 4 * STEP)), at(bar, 8), 0.28)
            prev_root = r1

        # Drums, a layer at a time: snaps on three; then a soft kick and a shaker; a kick on every beat at the top.
        snaps = (layer == 0 and k8 >= 4) or layer in (1, 2, 3) or (last and k8 < 4)
        if snaps:
            D.add(SN, at(bar, 8), 0.5, 0.2)
            if layer == 3:
                D.add(C, at(bar, 8), 0.2, -0.1)
        if layer in (1, 2):
            for s in (0, 10):
                D.add(K, at(bar, s), 0.5)
        elif layer == 3:
            for s in (0, 4, 8, 12):
                D.add(K, at(bar, s), 0.5 if s else 0.58)
        elif last and k8 < 4:
            D.add(K, at(bar, 0), 0.42)
        if layer in (2, 3):
            for s in range(2, 16, 2):
                D.add(SH if s % 4 == 2 else SG, at(bar, s), 0.45 if layer == 3 else 0.34, 0.3)
            if layer == 3:
                for s in range(1, 16, 2):
                    D.add(SG, at(bar, s), 0.22, 0.3)

        # The kalimba at the top (and a few glints of it in the first and last layers: first light).
        if layer == 3:
            scale = [midi(n) for n in ("C5", "D5", "F5", "G5", "A5", "C6")]
            for k, s in enumerate((2, 5, 10, 13)):
                m = scale[(bar * 3 + k * 2) % len(scale)]
                if (m % 12) in [mt.SEMI[x] for x in TONES[chord_at(bar, s)].split()]:
                    v = get(("kal", m), lambda: mt.boop(hz(m), 0.18))
                    tracks["kalimba"].add(v, at(bar, s), 0.22, 0.5)
                    tracks["kalimba"].add(v, at(bar, s) + 3 * STEP, 0.08, -0.5)
        elif layer in (0, 4) and k8 % 2 == 1:
            m = midi(("A5", "C6", "F5", "G5")[(bar // 2) % 4])
            tracks["kalimba"].add(get(("glint", m), lambda: mt.boop(hz(m), 0.5)), at(bar, 12), 0.14, 0.4 - 0.2 * (bar % 4))

        # The sax.
        if SAX_FROM <= bar < SAX_FROM + len(sax):
            step = 0
            for name, ln in sax[bar - SAX_FROM]:
                if name != "r":
                    m = midi(name) - SAX_DOWN
                    dur = ln * STEP * 0.95
                    vib = 0.007 if ln >= 4 else 0.0
                    tracks["sax"].add(get(("sax", m, ln), lambda: sax_note(hz(m), dur, vib)), at(bar, step), 0.26, -0.05)
                    if layer == 3 and ln >= 2:
                        low = mt.third_below(m)
                        if low is not None and (low % 12) in [mt.SEMI[x] for x in TONES[chord_at(bar, step)].split()]:
                            tracks["sax"].add(get(("sax", low, ln), lambda: sax_note(hz(low), dur, vib)), at(bar, step), 0.11, 0.3)
                step += ln
    return tracks


def check(tracks, l, r):
    odd = []
    for i, notes in enumerate(sax):
        bar, step = SAX_FROM + i, 0
        for name, ln in notes:
            if name != "r" and ln >= 2 and mt.SEMI[name[:-1]] not in [mt.SEMI[x] for x in TONES[chord_at(bar, step)].split()]:
                odd.append("sax, bar %d step %d: %s over %s" % (bar + 1, step, name, chord_at(bar, step)))
            step += ln
    print("sax notes (an 8th or longer) outside their chord: %d" % len(odd))
    for o in odd:
        print("   " + o)
    print("length %.3fs (%d bars at %d BPM)   peak %.2f   loudness %.1f dB" % (
        mt.N / mt.SR, mt.BARS, mt.BPM, max(max(map(abs, l)), max(map(abs, r))), mt.rms_db([(l[i] + r[i]) / 2.0 for i in range(0, mt.N, 3)])))
    for name, T in tracks.items():
        print("   %-8s %.1f dB" % (name, mt.rms_db([(T.l[i] + T.r[i]) / 2.0 for i in range(0, mt.N, 3)])))
    bar_n = mt.N // mt.BARS
    print("   the build, layer by layer: " + "  ".join("%.1f" % mt.rms_db([(l[i] + r[i]) / 2.0 for i in range(k * 8 * bar_n, (k + 1) * 8 * bar_n, 3)]) for k in range(5)) + " dB")
    print("seam: last sample %.4f, first %.4f" % (l[-1], l[0]))


if __name__ == "__main__":
    tracks = render()
    l, r = mt.master(tracks, eq=[(60.0, 2.5, 0.9), (400.0, -2.5, 0.8), (3000.0, 1.5, 0.8)], ducked=False, top=10000.0)
    mt.write(os.path.join(mt.ROOT, "audio", "sunrise.wav"), l, r)
    check(tracks, l, r)
    if "--stems" in sys.argv:
        for name, T in tracks.items():
            mt.write(os.path.join(mt.ROOT, "build", "sunrise", name + ".wav"), T.l, T.r)
    print("wrote audio/sunrise.wav")
