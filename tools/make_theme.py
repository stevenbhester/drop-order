#!/usr/bin/env python3
"""Composes and renders the title theme: audio/theme.wav (a seamless loop).

    python3 tools/make_theme.py            # writes audio/theme.wav and prints a few checks
    python3 tools/make_theme.py --stems    # also build/theme/<part>.wav, one per part

No samples and no libraries: every sound is synthesised here, so the tune is edited as text.

THE BEAT AND THE TITLE SCREEN
The title's little street is the rhythm section. One lap of the van is LAP_BEATS (16) beats, four bars, at
BPM, and the van drives it at a steady speed, so what it passes lands on these beats (scripts/title_screen.gd
has the same table: keep the two in step):

    beat  0  the depot: the van loads up            a rising two-note blip
    beat  3  the red house                          boop, F
    beat  4  the bridge on the top road             to-tok (front wheels, back wheels)
    beat  5  the blue house                         boop, A
    beat  8  the gate on the right-hand road        ka-chunk
    beat 11  the green house                        boop, C
    beat 12  the bridge on the bottom road          to-tok
    beat 13  the yellow house                       boop, D

Those gaps (3, 2, 3) are simply where a rounded loop puts two houses a side: a tresillo, twice a lap. A colour
is always the same note (COLOUR_NOTE: the F major pentatonic, so any of them sits over any chord here) and a
hazard always the same sound. The tune on top changes; this never does, so the street always matches it.

THE TUNE
F major, 132 BPM, 32 bars (eight laps): A A' B A''. The band is an electro swing one, after the reference
Steven gave (Marina & The Kats' "Ponder", Betty Booom's remix: indie swing turned club track, house drums,
breakdowns, a brass section): a clarinet has the tune, a brass section plays the Charleston under it and a
third below, a muted trumpet answers, an upright bass walks, a guitar chops the off-beats, over a four-on-the-
floor kick, a clap and a shaker. B is the breakdown (D minor, 3 + 3 + 2, finger snaps, no kick) and builds
back into the last A. The tune itself is a bouncy route march, and is this file's own. Every bar's chord keeps
that lap's boops in tune (see CHORDS).
"""
import math, os, random, struct, sys, wave

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SR = 32000
BPM = 132
BEAT = 60.0 / BPM
STEP = BEAT / 4.0                 # a 16th
BARS = 32
LAP_BEATS = 16
N = int(round(BARS * 4 * BEAT * SR))


def setup(bpm, bars, sr=SR, swing=None):
    """Another tune on the same band (tools/make_chill.py): its tempo, length, sample rate and swing."""
    global BPM, BEAT, STEP, BARS, N, SR, SWING
    BPM, BARS, SR = bpm, bars, sr
    BEAT = 60.0 / BPM
    STEP = BEAT / 4.0
    N = int(round(BARS * 4 * BEAT * SR))
    if swing is not None:
        SWING = swing
TAU = 2.0 * math.pi

COLOUR_NOTE = {"red": "F4", "blue": "A4", "green": "C5", "yellow": "D5", "purple": "G4", "orange": "F5"}
# (beat in the lap, what, pan: where it is on the street, -1 left .. 1 right)
LAP = [(0, "load", -0.5), (3, "red", -0.35), (4, "bridge", 0.0), (5, "blue", 0.35),
       (8, "gate", 0.5), (11, "green", 0.35), (12, "bridge", 0.0), (13, "yellow", -0.35)]

# ------------------------------------------------------------------ the score

# A chord a half bar: "F" is the whole bar, "Bb|C" changes halfway.
CHORDS = (
    "F Dm C Bb|C   F Dm C Bb|C "          # A
    "F Dm C Bb|C   F Dm C Bb|A7 "         # A'
    "Dm Am F Gm    Dm Am Bb|C Gm|C7 "     # B
    "F Dm C Bb|C   F Dm C Bb|C"           # A''
).split()
TRIAD = {"F": "F A C", "Dm": "D F A", "C": "C E G", "Bb": "Bb D F", "Am": "A C E", "Gm": "G Bb D",
         "A7": "A C# E G", "C7": "C E G Bb"}
# Off-beat stabs (mid register) and the bass's root, per chord.
STAB = {"F": "A4 C5 F5", "Dm": "A4 D5 F5", "C": "G4 C5 E5", "Bb": "Bb4 D5 F5", "Am": "A4 C5 E5",
        "Gm": "G4 Bb4 D5", "A7": "A4 C#5 G5", "C7": "G4 Bb4 E5"}
BASS = {"F": "F3", "Dm": "D3", "C": "C3", "Bb": "Bb2", "Am": "A2", "Gm": "G2", "A7": "A2", "C7": "C3"}

# The lead, a bar a line: note:length in 16ths ("r" rests). Each bar is 16.
A1 = """
F5:2 A5:1 C6:1 C6:4   A5:2 C6:1 A5:1 F5:4
D5:2 F5:1 A5:1 A5:4   A5:2 G5:1 F5:1 E5:2 D5:2
E5:2 G5:1 C6:1 C6:4   Bb5:2 A5:2 G5:2 E5:2
D5:2 F5:1 Bb5:1 D6:4  C6:2 Bb5:1 A5:1 G5:2 C6:2
F5:2 A5:1 C6:1 F6:4   E6:2 D6:1 C6:1 A5:4
D6:2 C6:1 A5:1 F5:4   A5:2 G5:1 F5:1 D5:4
E5:2 G5:2 C6:2 E6:2   D6:2 C6:2 Bb5:2 G5:2
F5:2 Bb5:2 D6:2 F6:2  E6:3 D6:1 C6:2 r:2
"""
A2_END = """
E6:2 C6:2 G5:2 C6:2   E6:2 D6:1 C6:1 Bb5:2 G5:2
D6:2 Bb5:2 F5:2 Bb5:2 A5:2 C#6:2 E6:2 A5:2
"""
B = """
A5:3 A5:3 F5:2        D5:2 F5:2 A5:2 D6:2
C6:3 C6:3 A5:2        E5:2 A5:2 C6:2 E6:2
F6:3 E6:3 C6:2        A5:2 C6:2 F5:2 A5:2
Bb5:3 A5:3 G5:2       D5:2 G5:2 Bb5:2 D6:2
D6:3 D6:3 A5:2        F5:1 G5:1 A5:2 D6:2 F6:2
E6:3 E6:3 C6:2        A5:1 Bb5:1 C6:2 E6:2 A5:2
D6:2 Bb5:2 F5:2 Bb5:2 E6:2 C6:2 G5:2 C6:2
Bb5:2 D6:2 G6:4       E6:1 D6:1 C6:1 Bb5:1 G5:1 E5:1 D5:1 C5:1
"""
A3_END = """
F5:2 Bb5:2 D6:2 F6:2  G6:2 E6:2 r:4
"""


def bars_of(text):
    out = []
    for line in text.strip().splitlines():
        bar = [(t.split(":")[0], int(t.split(":")[1])) for t in line.split()]
        assert sum(n for _, n in bar) == 16, "a bar of %d sixteenths: %s" % (sum(n for _, n in bar), line)
        out.append(bar)
    return out


a1 = bars_of(A1)
LEAD = a1 + a1[:6] + bars_of(A2_END) + bars_of(B) + a1[:7] + bars_of(A3_END)
assert len(LEAD) == BARS and len(CHORDS) == BARS

SEMI = {"C": 0, "C#": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "Bb": 10, "B": 11}
SCALE = [5, 7, 9, 10, 0, 2, 4]            # F major's pitch classes, from F


def midi(name):
    return 12 * (int(name[-1]) + 1) + SEMI[name[:-1]]


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def chord_at(bar, step):
    c = CHORDS[bar].split("|")
    return c[0] if len(c) == 1 or step < 8 else c[1]


def third_below(m):
    """The scale note a third under `m` (a harmony line); None off the scale."""
    pc = m % 12
    if pc not in SCALE:
        return None
    k = SCALE.index(pc)
    low = SCALE[(k - 2) % 7]
    d = (pc - low) % 12
    return m - d


def neighbour(m, d):
    """The scale note next to `m`, above (d = 1) or below (-1)."""
    m += d
    while m % 12 not in SCALE:
        m += d
    return m


# ------------------------------------------------------------------ the instruments
# An electro swing band, kept warm: nothing here is a bare pulse wave, and every voice goes through a low-pass.
# (The first draft was a Game Boy's pulse leads an octave up. Steven: "a little shrill/piercing. Annoying
# quickly." Measured against his reference track it had 3 dB more above 250 Hz and far less under 120.)

RNG = random.Random(1997)


def lp_coef(fc):
    return 1.0 - math.exp(-TAU * fc / SR)


def horn(f, dur, wave="saw", fc_hi=3000.0, fc_lo=1500.0, fdec=0.06, att=0.012, rel=0.04, vib=0.0, scoop=0.0,
         fall=0.0, hp=0.0, sus=0.8):
    """A wind voice: a band-limited saw (brass) or square (clarinet) through a 12 dB low-pass whose cutoff
    falls from fc_hi to fc_lo (the blat at the front of a brass note). `scoop` starts it that many semitones
    off, `fall` drops it that many through its second half (a brass fall), `hp` thins it (a mute)."""
    n = int((dur + rel) * SR)
    out = [0.0] * n
    ph = l1 = l2 = h = 0.0
    a = lp_coef(fc_hi)
    ah = lp_coef(hp) if hp else 0.0
    square = wave == "square"
    for i in range(n):
        t = i / SR
        ff = f
        if scoop:
            ff *= 2.0 ** (scoop * math.exp(-t / 0.03) / 12.0)
        if vib and t > 0.18:
            ff *= 1.0 + vib * math.sin(TAU * 5.4 * (t - 0.18)) * min(1.0, (t - 0.18) / 0.15)
        if fall and t > dur * 0.4:
            ff *= 2.0 ** (-fall * ((t - dur * 0.4) / (dur * 0.6 + rel)) ** 1.4 / 12.0)
        dt = ff / SR
        ph += dt
        if ph >= 1.0:
            ph -= 1.0
        if square:
            v = 1.0 if ph < 0.5 else -1.0
            p2 = ph - 0.5 if ph >= 0.5 else ph + 0.5
            if p2 < dt:
                x = p2 / dt
                v -= x + x - x * x - 1.0
            elif p2 > 1.0 - dt:
                x = (p2 - 1.0) / dt
                v -= x * x + x + x + 1.0
        else:
            v = 2.0 * ph - 1.0
        if ph < dt:
            x = ph / dt
            v += (x + x - x * x - 1.0) * (1.0 if square else -1.0)
        elif ph > 1.0 - dt:
            x = (ph - 1.0) / dt
            v += (x * x + x + x + 1.0) * (1.0 if square else -1.0)
        if i % 16 == 0:
            a = lp_coef(fc_lo + (fc_hi - fc_lo) * math.exp(-t / fdec))
        l1 += a * (v - l1)
        l2 += a * (l1 - l2)
        y = l2
        if hp:
            h += ah * (y - h)
            y -= h
        e = min(1.0, t / att) * (sus + (1.0 - sus) * math.exp(-t / 0.15))
        if t > dur:
            e *= max(0.0, 1.0 - (t - dur) / rel)
        out[i] = y * e
    return out


def clarinet(f, dur, vib=0.0):
    return horn(f, dur, "square", fc_hi=min(6500.0, f * 13.0), fc_lo=min(4500.0, f * 9.0), fdec=0.1, att=0.02, rel=0.05, vib=vib, scoop=-0.35)


def brass(f, dur, fall=0.0, vib=0.0):
    return horn(f, dur, "saw", fc_hi=6500.0, fc_lo=2700.0, fdec=0.07, att=0.014, rel=0.05, vib=vib, scoop=-0.5, fall=fall)


def muted(f, dur, vib=0.0):
    """A trumpet with a mute in: nasal, small, close."""
    return horn(f, dur, "saw", fc_hi=3600.0, fc_lo=2600.0, fdec=0.05, att=0.01, rel=0.04, vib=vib, scoop=-0.6, hp=650.0)


def chick(f):
    """The comp: one short muted note of a guitar or piano chord on the off-beat."""
    n = int(0.16 * SR)
    out = [0.0] * n
    ph = l1 = 0.0
    dt = f / SR
    a = lp_coef(2900.0)
    for i in range(n):
        t = i / SR
        ph += dt
        if ph >= 1.0:
            ph -= 1.0
        tri = 4.0 * abs(ph - 0.5) - 1.0
        if i % 8 == 0:
            a = lp_coef(1300.0 + 4000.0 * math.exp(-t / 0.03))
        l1 += a * (tri + 0.35 * (2.0 * ph - 1.0) - l1)
        out[i] = l1 * min(1.0, t / 0.003) * math.exp(-t / 0.055)
    return out


def bass_note(f, dur):
    """An upright, more or less: a thump, then a round note that dies away. The saw under it is filtered right
    down, but it's what a phone's speaker has to go on."""
    n = int((dur + 0.05) * SR)
    out = [0.0] * n
    ph = l1 = l2 = 0.0
    a = lp_coef(900.0)
    for i in range(n):
        t = i / SR
        ph += f * (1.0 + 0.25 * math.exp(-t / 0.012)) / SR
        if ph >= 1.0:
            ph -= 1.0
        if i % 16 == 0:
            a = lp_coef(260.0 + 900.0 * math.exp(-t / 0.07))
        l1 += a * ((2.0 * ph - 1.0) - l1)
        l2 += a * (l1 - l2)
        e = min(1.0, t / 0.006) * (0.35 + 0.65 * math.exp(-t / 0.3))
        if t > dur:
            e *= max(0.0, 1.0 - (t - dur) / 0.05)
        out[i] = (l2 * 1.1 + 0.9 * math.sin(TAU * ph)) * e
    return out


def kick():
    n = int(0.34 * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        ph += (43.0 + 95.0 * math.exp(-t / 0.035)) / SR
        out[i] = math.sin(TAU * ph) * math.exp(-t / 0.15) * min(1.0, t / 0.001)
    return out


def noise_band(n, lo, hi, shape):
    """Noise between `lo` and `hi` Hz, shaped by shape(t)."""
    out = [0.0] * n
    a, b = lp_coef(hi), lp_coef(lo)
    l1 = l2 = 0.0
    for i in range(n):
        x = RNG.uniform(-1.0, 1.0)
        l1 += a * (x - l1)
        l2 += b * (l1 - l2)
        out[i] = (l1 - l2) * shape(i / SR)
    return out


def clap():
    return noise_band(int(0.2 * SR), 900.0, 5000.0, lambda t: sum(math.exp(-(t - d) / 0.006) for d in (0.0, 0.01, 0.02) if t >= d) * 0.6 + 0.5 * math.exp(-t / 0.05))


def snap():
    """Fingers, on two and four."""
    return noise_band(int(0.08 * SR), 1500.0, 5500.0, lambda t: math.exp(-t / 0.011))


def shaker(amp=1.0):
    return noise_band(int(0.09 * SR), 3500.0, 10000.0, lambda t: amp * min(1.0, t / 0.004) * math.exp(-t / 0.022))


def tom(f):
    n = int(0.3 * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        ph += f * (1.0 + 0.5 * math.exp(-t / 0.03)) / SR
        out[i] = math.sin(TAU * ph) * math.exp(-t / 0.11) * min(1.0, t / 0.002)
    return out


def boop(f, tau=0.14):
    """A delivery: a round little mallet note (vibes, near enough) that drops into pitch as the package lands."""
    n = int((tau * 4.0) * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        ph += f * (1.0 + 0.6 * math.exp(-t / 0.011)) / SR
        a = (1.0 - math.exp(-t / 0.0015)) * math.exp(-t / tau)
        out[i] = a * (math.sin(TAU * ph) + 0.4 * math.sin(TAU * 2.0 * ph) * math.exp(-t / 0.05)
                      + 0.1 * math.sin(TAU * 4.0 * ph) * math.exp(-t / 0.02))
    return out


def drop(f):
    """A package landing: the mallet note, the same an octave up (what a phone's speaker carries), and the
    knock of the box. It has to read over the whole band: the street's deliveries are the point."""
    low, high = boop(f), boop(f * 2.0, 0.1)
    knock = noise_band(int(0.03 * SR), 1200.0, 4500.0, lambda t: math.exp(-t / 0.004))
    return [low[i] + (0.6 * high[i] if i < len(high) else 0.0) + (0.55 * knock[i] if i < len(knock) else 0.0) for i in range(len(low))]


def tok(f):
    """A wheel on a plank."""
    n = int(0.1 * SR)
    return [(math.sin(TAU * f * i / SR) * math.exp(-(i / SR) / 0.02) + 0.3 * math.sin(TAU * f * 1.51 * i / SR) * math.exp(-(i / SR) / 0.01))
            * min(1.0, i / 30.0) for i in range(n)]


def gate():
    """The barrier going up: a clack, a falling buzz and a little ring."""
    n = int(0.3 * SR)
    click = noise_band(n, 500.0, 2500.0, lambda t: math.exp(-t / 0.005))
    out = [0.0] * n
    ph = l1 = 0.0
    a = lp_coef(1200.0)
    for i in range(n):
        t = i / SR
        ph += (120.0 + 160.0 * math.exp(-t / 0.035)) / SR
        l1 += a * ((1.0 if (ph % 1.0) < 0.5 else -1.0) - l1)
        out[i] = (click[i] * 1.5 + 0.6 * l1 * math.exp(-t / 0.05)
                  + 0.3 * (math.sin(TAU * 698.5 * t) + 0.5 * math.sin(TAU * 1046.5 * t)) * math.exp(-t / 0.09))
    return out


# ------------------------------------------------------------------ the quiet tunes' instruments
# (tools/make_chill.py and tools/make_sunrise.py: the same band, sat down.)

def rhodes(f, dur):
    """An electric piano: a sine bent by itself (hard at the front, so the note barks a little, then round),
    a tine's ping on top, and a slow tremolo."""
    n = int((dur + 0.3) * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        ph = TAU * f * t
        e = min(1.0, t / 0.004) * (0.22 + 0.78 * math.exp(-t / 0.9))
        if t > dur:
            e *= max(0.0, 1.0 - (t - dur) / 0.3)
        y = math.sin(ph + 0.85 * math.exp(-t / 0.22) * math.sin(ph)) + 0.1 * math.sin(4.0 * ph) * math.exp(-t / 0.07)
        out[i] = y * e * (1.0 + 0.12 * math.sin(TAU * 4.3 * t))
    return out


def pad(f, dur, fc=1500.0):
    """Brass, breathed in: no front to the note at all. `fc` is how bright."""
    return horn(f, dur, "saw", fc_hi=fc, fc_lo=fc, att=0.35, rel=0.5, sus=1.0)


def soft_kick():
    return [v * math.exp(-(i / SR) / 0.09) for i, v in enumerate(kick())]


def pluck(f, dur, damp=0.996, bright=0.5):
    """A plucked string (Karplus and Strong's: a burst of noise going round a delay line that dulls it a
    little each lap). `damp` is how long it rings, `bright` how hard it was plucked."""
    n = int(dur * SR)
    period = SR / f - 0.5                 # (the averaging below is half a sample of delay itself)
    di = int(period)
    frac = period - di
    size = di + 2
    buf = [0.0] * size
    lp = 0.0
    a = 0.15 + 0.85 * bright
    for k in range(size):
        lp += a * (RNG.uniform(-1.0, 1.0) - lp)
        buf[k] = lp
    out = [0.0] * n
    w = 0
    prev = 0.0
    fade = int(0.04 * SR)
    rise = 0.0015 * SR                    # (a pick has a front, but not a click)
    for i in range(n):
        r0 = buf[(w - di) % size]
        y = r0 + frac * (buf[(w - di - 1) % size] - r0)
        buf[w] = damp * 0.5 * (y + prev)
        prev = y
        w += 1
        if w == size:
            w = 0
        out[i] = y * (min(1.0, (n - i) / fade) if n - i < fade else min(1.0, i / rise))
    return out


def glide_bass(f_from, f, dur):
    """A round bass that slides into its note from the last one."""
    n = int((dur + 0.06) * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        ph += (f + (f_from - f) * math.exp(-t / 0.035)) / SR
        e = min(1.0, t / 0.008) * (0.5 + 0.5 * math.exp(-t / 0.5))
        if t > dur:
            e *= max(0.0, 1.0 - (t - dur) / 0.06)
        x = TAU * ph
        out[i] = (math.sin(x) + 0.28 * math.sin(2.0 * x) + 0.1 * math.sin(3.0 * x)) * e
    return out


# ------------------------------------------------------------------ the mix

SWING = 0.16          # how late the off 16ths are, in 16ths (the big events are all on 8ths: they don't move)


class Track:
    def __init__(self, name):
        self.name = name
        self.l = [0.0] * N
        self.r = [0.0] * N

    def add(self, buf, t, gain=1.0, pan=0.0):
        """Mixes `buf` in at `t` seconds, wrapping past the end so the loop has no seam."""
        gl = gain * math.sqrt(0.5 * (1.0 - pan))
        gr = gain * math.sqrt(0.5 * (1.0 + pan))
        s = int(round(t * SR)) % N
        l, r = self.l, self.r
        for v in buf:
            l[s] += v * gl
            r[s] += v * gr
            s += 1
            if s == N:
                s = 0


def at(bar, step):
    return (bar * 16 + step + (SWING if step % 2 else 0.0)) * STEP


def section(bar):
    return "A" if bar < 8 else ("A2" if bar < 16 else ("B" if bar < 24 else "A3"))


def render():
    tracks = {k: Track(k) for k in ["beat", "drums", "bass", "comp", "brass", "lead", "answers"]}
    cache = {}

    def get(key, make):
        if key not in cache:
            cache[key] = make()
        return cache[key]

    # The street: the same every lap.
    T = tracks["beat"]
    for lap in range(BARS * 4 // LAP_BEATS):
        t0 = lap * LAP_BEATS * BEAT
        for beat, what, pan in LAP:
            t = t0 + beat * BEAT
            if what == "load":
                T.add(get("load1", lambda: boop(hz(midi("C5")), 0.07)), t, 0.3, pan)
                T.add(get("load2", lambda: boop(hz(midi("F5")), 0.1)), t + STEP, 0.3, pan)
            elif what == "bridge":
                T.add(get("tok1", lambda: tok(740.0)), t, 0.4, pan - 0.1)
                T.add(get("tok2", lambda: tok(622.0)), t + STEP, 0.33, pan + 0.1)
            elif what == "gate":
                T.add(get("gate", gate), t, 0.3, pan)
            else:
                b = get("drop" + what, lambda: drop(hz(midi(COLOUR_NOTE[what]))))
                T.add(b, t, 0.95, pan)
                T.add(b, t + 3 * STEP, 0.22, -pan)          # an echo, across the street

    # Drums: a house kick, a clap, a shaker. B is the breakdown: fingers and shaker, then the kick creeps back
    # and the toms build into the last A.
    T = tracks["drums"]
    K, C, SN, SH, SG = kick(), clap(), snap(), shaker(), shaker(0.5)
    toms = [tom(f) for f in (196.0, 156.0, 123.0, 98.0)]
    for bar in range(BARS):
        sec = section(bar)
        k = bar - 16
        for step in range(16):
            t = at(bar, step)
            if sec != "B":
                kick_on = step % 4 == 0
            else:
                kick_on = (k >= 7 and step % 2 == 0) or (k == 6 and step % 4 == 0) or (k in (4, 5) and step % 8 == 0)
            if kick_on:
                T.add(K, t, 0.85 if sec != "B" or k < 7 else 0.55 + 0.035 * step)
            if step in (4, 12):
                T.add(C if sec != "B" else SN, t, 0.75 if sec != "B" else 0.9, 0.0 if sec != "B" else 0.25)
            if step % 4 == 2:
                T.add(SH, t, 1.0, 0.3)
            elif step % 2 == 1:
                T.add(SG, t, 0.7, 0.3)
            # Toms down into each new lap; all the way through the last bar of the build.
            fill_from = 0 if bar == 23 else (8 if bar % 8 == 7 else 12)
            if bar % 4 == 3 and step >= fill_from and (step % 2 == 0 or step >= 12 or bar == 23):
                k4 = min(3, (step - fill_from) * 4 // (16 - fill_from))
                # (Down into a lap; up through the build.)
                T.add(toms[3 - k4 if bar == 23 else k4], t, (0.3 + 0.02 * step) * (0.6 if step in (4, 12) else 1.0), -0.3 + 0.04 * step)

    # Bass: it walks (root, third, fifth, then a step into the next root), a note a beat. In the breakdown it
    # just marks the 3 + 3 + 2, and pumps 8ths through the build.
    T = tracks["bass"]
    for bar in range(BARS):
        sec = section(bar)
        ch0, ch1 = chord_at(bar, 0), chord_at(bar, 8)
        nxt = midi(BASS[chord_at((bar + 1) % BARS, 0)]) - 12
        r0, r1 = midi(BASS[ch0]) - 12, midi(BASS[ch1]) - 12
        third = 3 if (ch0.endswith("m")) else 4
        lean = neighbour(nxt, 1 if nxt <= r1 else -1) if nxt != r1 else r1 + 7
        if sec == "B" and bar < 20:
            pat = [(0, r0, 3), (6, r0, 2), (8, r1, 3), (14, lean, 2)]
        elif sec == "B":
            pat = [(s, (r0 if s < 8 else r1) + (12 if s % 4 == 2 and bar >= 22 else 0), 2) for s in range(0, 16, 2)]
        elif ch0 == ch1:
            pat = [(0, r0, 4), (4, r0 + third, 4), (8, r0 + 7, 4), (12, lean, 3), (15, lean + (1 if lean < nxt else -1), 1)]
        else:
            pat = [(0, r0, 4), (4, r0 + 7, 4), (8, r1, 4), (12, lean, 4)]
        for s, m, ln in pat:
            T.add(get(("bass", m, ln), lambda: bass_note(hz(m), ln * STEP * 0.9)), at(bar, s), 0.62)

    # The comp: the chord, short and muted, on every off-beat.
    T = tracks["comp"]
    for bar in range(BARS):
        for step in (2, 6, 10, 14):
            for k, name in enumerate(STAB[chord_at(bar, step)].split()):
                m = midi(name) - 12
                T.add(get(("chick", m), lambda: chick(hz(m))), at(bar, step), 0.22, -0.35 + 0.1 * k)

    # The brass section: the Charleston (a short one, then a long one) from A', hits through the build, and a
    # fall off the end of a section. In the first A it only answers at the end of each lap.
    T = tracks["brass"]
    for bar in range(BARS):
        sec = section(bar)
        if sec == "A":
            hits = [(6, 1.2), (10, 2.6)] if bar % 4 == 3 else []
        elif sec == "B":
            hits = {22: [(0, 1.2), (6, 1.2), (12, 2.0)], 23: [(0, 1.2), (4, 1.2), (8, 1.2), (12, 3.0)]}.get(bar, [])
        else:
            hits = [(6, 1.2), (10, 2.6)]
        for s, ln in hits:
            last = bar % 8 == 7 and s == hits[-1][0]
            gain = 0.2 if bar != 23 else 0.14 + 0.02 * s / 4.0
            for k, name in enumerate(STAB[chord_at(bar, s)].split()):
                m = midi(name)
                T.add(get(("stab", m, ln, last), lambda: brass(hz(m) * (1.0 + 0.002 * (k - 1)), ln * STEP, fall=5.0 if last else 0.0)), at(bar, s), gain, -0.3 + 0.3 * k)
            m = midi(BASS[chord_at(bar, s)]) + 12
            T.add(get(("bone", m, ln, last), lambda: brass(hz(m), ln * STEP, fall=5.0 if last else 0.0)), at(bar, s), gain * 0.9, 0.1)

    # The lead: a clarinet has the tune, a muted trumpet the breakdown. From A' a horn plays a third under it,
    # and in the last A a second clarinet doubles it an octave up, well back.
    T = tracks["lead"]
    for bar in range(BARS):
        sec = section(bar)
        step = 0
        for name, ln in LEAD[bar]:
            if name != "r":
                m = midi(name) - 12
                dur = ln * STEP * (0.92 if ln > 1 else 0.85)
                v = 0.006 if ln >= 3 else 0.0
                if sec == "B":
                    T.add(get(("mute", m, ln), lambda: muted(hz(m), dur, v)), at(bar, step), 0.36, -0.1)
                else:
                    T.add(get(("clar", m, ln), lambda: clarinet(hz(m), dur, v)), at(bar, step), 0.15)
                    if sec == "A3":
                        T.add(get(("clar", m + 12, ln), lambda: clarinet(hz(m + 12), dur, v)), at(bar, step), 0.07, 0.35)
                    low = third_below(m) if (8 <= bar < 15 or bar >= 24) and not (bar == 31 and step >= 8) else None
                    if low is not None:
                        tracks["brass"].add(get(("harm", low, ln), lambda: brass(hz(low), dur, vib=v)), at(bar, step), 0.11, 0.3)
            step += ln
    # Answers: while the lead holds a long note in A' and A'', the muted trumpet runs up (or down) the chord.
    T = tracks["answers"]
    for bar in list(range(8, 15)) + list(range(24, 31)):
        step = 0
        for name, ln in LEAD[bar]:
            if name != "r" and ln == 4 and step % 8 == 4:
                notes = [midi(x) for x in STAB[chord_at(bar, step)].split()]
                run = [notes[0], notes[1], notes[2], notes[1] + 12] if bar % 2 == 0 else [notes[2], notes[1], notes[0], notes[1]]
                for k, m in enumerate(run):
                    T.add(get(("run", m), lambda: muted(hz(m), STEP * 0.85)), at(bar, step + k) + STEP * 0.5 * (k == 0), 0.5, -0.45)
            step += ln
    # A swell of air through the end of the build, cut dead on the last A's downbeat.
    n = int(16 * STEP * SR)
    swell = noise_band(n, 300.0, 2500.0, lambda t: (t / (16 * STEP)) ** 2.5)
    tracks["drums"].add(swell, at(23, 0), 0.6)
    # Meep meep: the horn, into the top of the loop.
    for s in (12, 14):
        for m in (midi("C5"), midi("E5")):
            T.add(get(("honk", m), lambda: horn(hz(m), STEP * 1.3, "square", fc_hi=2600.0, fc_lo=2200.0, att=0.006, rel=0.02, sus=1.0)), at(31, s), 0.16, -0.15)
    return tracks


def peak_eq(x, f0, db, q):
    """A bell filter (RBJ's): `db` up or down around `f0`."""
    A = 10.0 ** (db / 40.0)
    w = TAU * f0 / SR
    al = math.sin(w) / (2.0 * q)
    c = math.cos(w)
    a0 = 1.0 + al / A
    b0, b1, b2, a1, a2 = (1.0 + al * A) / a0, -2.0 * c / a0, (1.0 - al * A) / a0, -2.0 * c / a0, (1.0 - al / A) / a0
    x1 = x2 = y1 = y2 = 0.0
    # Twice round, keeping the second pass: the loop has no start, so the filter shouldn't either.
    for _ in range(2):
        for i in range(len(x) if _ else len(x) // 8):
            j = i if _ else len(x) - len(x) // 8 + i
            v = x[j]
            y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1, y2, y1 = x1, v, y1, y
            if _:
                x[j] = y


# The master's tone, set by measuring against the reference track (its share of energy per octave): under it
# through the middle, where a small speaker honks, and no brighter than it on top.
MASTER_EQ = [(50.0, 2.5, 0.9), (450.0, -4.0, 0.8), (2200.0, 2.5, 0.8)]


def duck(tracks):
    """The band steps back as each package lands (a third of its level, back up over a fifth of a second), so
    the delivery is the loudest thing in its moment."""
    a0, hold, rel = int(0.008 * SR), int(0.07 * SR), int(0.2 * SR)
    for lap in range(BARS * 4 // LAP_BEATS):
        for beat, what, _ in LAP:
            if what not in COLOUR_NOTE:
                continue
            s0 = int(round((lap * LAP_BEATS + beat) * BEAT * SR)) - a0
            for name in DUCKED:
                tl, tr = tracks[name].l, tracks[name].r
                for k in range(a0 + hold + rel):
                    g = 1.0 - DUCK * (k / a0 if k < a0 else (1.0 if k < a0 + hold else 1.0 - (k - a0 - hold) / rel))
                    j = (s0 + k) % N
                    tl[j] *= g
                    tr[j] *= g


DUCKED = ["lead", "brass", "comp", "answers", "bass"]
DUCK = 0.65


def master(tracks, eq=None, ducked=True, top=13000.0):
    if ducked:
        duck(tracks)
    l = [0.0] * N
    r = [0.0] * N
    for T in tracks.values():
        tl, tr = T.l, T.r
        for i in range(N):
            l[i] += tl[i]
            r[i] += tr[i]
    for f0, db, q in (MASTER_EQ if eq is None else eq):
        peak_eq(l, f0, db, q)
        peak_eq(r, f0, db, q)
    # Round the top off a little, soft clip, then bring the peak to just under full scale.
    drive = 1.15
    peak = 0.0
    a = lp_coef(top)
    yl = yr = 0.0
    for i in range(N):
        yl += a * (l[i] - yl)
        yr += a * (r[i] - yr)
        l[i] = math.tanh(yl * drive)
        r[i] = math.tanh(yr * drive)
        peak = max(peak, abs(l[i]), abs(r[i]))
    g = 0.89 / peak
    return [v * g for v in l], [v * g for v in r]


def write(path, l, r):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    w = wave.open(path, "wb")
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    data = bytearray(len(l) * 4)
    for i in range(len(l)):
        struct.pack_into("<hh", data, i * 4, int(max(-1.0, min(1.0, l[i])) * 32767), int(max(-1.0, min(1.0, r[i])) * 32767))
    w.writeframes(bytes(data))
    w.close()


def rms_db(a):
    return 10.0 * math.log10(sum(v * v for v in a) / len(a) + 1e-12)


def check(tracks, l, r):
    """What a listener would otherwise have to catch: clashes on strong beats, level, and the loop's seam."""
    odd = []
    for bar in range(BARS):
        step = 0
        for name, ln in LEAD[bar]:
            if name != "r" and step % 4 == 0 and ln >= 2:
                tones = [SEMI[x] for x in TRIAD[chord_at(bar, step)].split()]
                if midi(name) % 12 not in tones:
                    odd.append("bar %d step %d: %s over %s" % (bar + 1, step, name, chord_at(bar, step)))
            step += ln
    print("lead notes on a beat that aren't in the chord (passing notes are fine, a list of them isn't): %d" % len(odd))
    for o in odd:
        print("   " + o)
    for lap in range(BARS // 4):
        for beat, what, _ in LAP:
            if what in COLOUR_NOTE:
                bar, step = lap * 4 + beat // 4, (beat % 4) * 4
                ch = chord_at(bar, step)
                if SEMI[COLOUR_NOTE[what][:-1]] not in [SEMI[x] for x in TRIAD[ch].split()]:
                    print("   boop out of the chord: lap %d %s (%s) over %s" % (lap + 1, what, COLOUR_NOTE[what], ch))
    print("length %.3fs (%d bars, a lap every %.3fs)   peak %.2f   loudness %.1f dB" % (
        N / SR, BARS, LAP_BEATS * BEAT, max(max(map(abs, l)), max(map(abs, r))), rms_db([(l[i] + r[i]) / 2.0 for i in range(0, N, 3)])))
    for name, T in tracks.items():
        print("   %-8s %.1f dB" % (name, rms_db([(T.l[i] + T.r[i]) / 2.0 for i in range(0, N, 3)])))
    print("seam: last sample %.4f, first %.4f" % (l[-1], l[0]))


if __name__ == "__main__":
    tracks = render()
    l, r = master(tracks)
    write(os.path.join(ROOT, "audio", "theme.wav"), l, r)
    check(tracks, l, r)
    if "--stems" in sys.argv:
        for name, T in tracks.items():
            write(os.path.join(ROOT, "build", "theme", name + ".wav"), T.l, T.r)
    print("wrote audio/theme.wav")
