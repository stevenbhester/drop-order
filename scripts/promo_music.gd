class_name PromoMusic
extends RefCounted
## The trash-talk ad's sound (PromoAd), synthesized, the way the GTA VI trailer's was made
## (tools/ads/gta_director.gd), minus the commercial song: a newsroom bed with a stab on each headline, a
## record scratch, and a half-time trap beat (kicks, claps, hats, an 808 line) with extra kicks on the
## fancam's hits. Pure number crunching, so PromoAd builds it on a worker thread while the news plays.

const RATE := 22050


static func _wav(b: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	return w


## The newsroom: a low drone and a clock tick, with a bright stab at each of `stabs` (seconds).
static func news_bed(seconds: float, stabs: Array) -> AudioStreamWAV:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * 55.0 / RATE
		var drone := (sin(ph) + 0.5 * sin(ph * 1.5) + 0.3 * sin(ph * 2.0)) * 0.12
		var beat := fmod(t, 0.25)
		var tick := sin(TAU * 1800.0 * beat) * exp(-beat * 90.0) * (0.12 if int(t * 4.0) % 4 == 0 else 0.06)
		b[i] = drone * minf(1.0, t * 3.0) * minf(1.0, (seconds - t) * 4.0) + tick
	for t0 in stabs:
		for n in [43, 50, 55, 59]:
			var f := 440.0 * pow(2.0, (n - 69.0) / 12.0)
			var s0 := int(float(t0) * RATE)
			for i in int(0.7 * RATE):
				if s0 + i >= b.size():
					break
				var t := float(i) / RATE
				var env := minf(1.0, t * 200.0) * exp(-t * 4.0)
				var saw := 2.0 * fmod(f * t, 1.0) - 1.0
				b[s0 + i] += (saw * 0.5 + sin(TAU * f * t)) * env * 0.07
	for i in b.size():
		b[i] = tanh(b[i] * 1.3)
	return _wav(b)


## A record scratch.
static func scratch() -> AudioStreamWAV:
	var b := PackedFloat32Array()
	b.resize(int(0.42 * RATE))
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 300.0 + 1500.0 * absf(sin(t * 18.0))
		ph += TAU * f / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.35
		b[i] = (sin(ph) * 0.4 + lp * 0.5) * minf(1.0, (0.42 - t) * 10.0) * 0.8
	return _wav(b)


## The beat: `beat` seconds a beat, the first at `beat0`, after a short riser; kicks on the downbeats and
## on each of `hits`, a clap backbeat, hats (rolling every eighth beat), and an 808 sliding under each bar.
static func hype(seconds: float, beat0: float, beat: float, hits: Array) -> AudioStreamWAV:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	var total := b.size()
	var beats := int((seconds - beat0) / beat) + 1
	for i in int(beat0 * RATE):
		var t := float(i) / RATE
		b[i] += randf_range(-1.0, 1.0) * 0.18 * (t / beat0) + sin(TAU * (200.0 + 900.0 * t / beat0) * t) * 0.08 * (t / beat0)
	var kicks := []
	var claps := []
	var hats := []
	for k in beats:
		var bt := beat0 + k * beat
		if k % 2 == 0:
			kicks.append(bt)
		else:
			claps.append(bt)
		hats.append(bt)
		hats.append(bt + beat * 0.5)
		if k % 8 == 7:
			hats.append(bt + beat * 0.25)
			hats.append(bt + beat * 0.75)
	kicks.append_array(hits)
	for t0 in kicks:
		var s0 := int(float(t0) * RATE)
		var ph := 0.0
		for i in int(0.45 * RATE):
			if s0 + i >= total:
				break
			var t := float(i) / RATE
			ph += TAU * (45.0 + 110.0 * exp(-t * 30.0)) / RATE
			b[s0 + i] += sin(ph) * exp(-t * 7.0) * 0.75
	for t0 in claps:
		var s0 := int(float(t0) * RATE)
		var lp := 0.0
		for i in int(0.22 * RATE):
			if s0 + i >= total:
				break
			var t := float(i) / RATE
			var n := randf_range(-1.0, 1.0)
			lp += (n - lp) * 0.6
			var env := exp(-t * 18.0) * (1.0 if t > 0.012 or int(t * 900.0) % 2 == 0 else 0.4)
			b[s0 + i] += (n - lp) * env * 0.42
	for t0 in hats:
		var s0 := int(float(t0) * RATE)
		var prev := 0.0
		for i in int(0.05 * RATE):
			if s0 + i >= total:
				break
			var n := randf_range(-1.0, 1.0)
			b[s0 + i] += (n - prev) * exp(-float(i) / RATE * 70.0) * 0.12
			prev = n
	var roots := [29, 29, 25, 27]
	var ph8 := 0.0
	for i in range(int(beat0 * RATE), total):
		var t := float(i) / RATE
		var bar := int((t - beat0) / (beat * 4.0))
		var in_bar := fmod(t - beat0, beat * 4.0)
		var f := 440.0 * pow(2.0, (roots[bar % roots.size()] + 12 - 69.0) / 12.0)
		ph8 += TAU * f * (1.0 + 0.6 * exp(-in_bar * 9.0)) / RATE
		b[i] += sin(ph8) * 0.42 * minf(1.0, in_bar * 30.0) * (0.6 + 0.4 * exp(-in_bar * 0.8))
	for i in total:
		b[i] = tanh(b[i] * 1.2) * 0.9 * minf(1.0, (seconds - float(i) / RATE) * 3.0)
	return _wav(b)


# ---------------------------------------------------------------- the clickbait's

static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## The clickbait's bed (the trailer's AdMusic.bait): 150 bpm, kick, clap backbeat, a buzzy saw on the
## offbeats and a shaker.
static func bait(seconds: float) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var beat := 60.0 / 150.0
	var beats := int(seconds / beat) + 1
	var roots := [45, 45, 41, 43]
	for k in beats:
		var t0 := k * beat
		_kick(b, t0, 0.5)
		if k % 2 == 1:
			_clap(b, t0, 0.22)
		var root: int = roots[(k / 4) % 4]
		_saw(b, t0 + beat * 0.5, _hz(root), beat * 0.45, 0.13)
		_shaker(b, t0 + beat * 0.25, 0.03)
		_shaker(b, t0 + beat * 0.75, 0.03)
	for i in n:
		var t := float(i) / RATE
		b[i] = tanh(b[i] * 1.4) * minf(1.0, t * 20.0) * minf(1.0, (seconds - t) * 2.0)
	return _wav(b)


## The classic "wah wah wah waaah".
static func sad_trombone() -> AudioStreamWAV:
	var notes := [[63, 0.32], [62, 0.32], [61, 0.32], [60, 1.0]]
	var total := 0.0
	for nt in notes:
		total += nt[1]
	var b := PackedFloat32Array()
	b.resize(int(total * RATE))
	var t0 := 0.0
	var ph := 0.0
	for nt in notes:
		var f := _hz(nt[0] - 12)
		var d: float = nt[1]
		for i in int(d * RATE):
			var t := float(i) / RATE
			var vib := 1.0 + (0.025 * sin(TAU * 6.0 * t) * minf(1.0, t * 3.0) if d > 0.5 else 0.0)
			ph += TAU * f * vib / RATE
			var env := minf(1.0, t * 25.0) * minf(1.0, (d - t) * 12.0)
			var v := (sin(ph) + 0.5 * sin(2.0 * ph) + 0.3 * sin(3.0 * ph) + 0.2 * sin(4.0 * ph)) * 0.22 * env
			var idx := int((t0 + t) * RATE)
			if idx < b.size():
				b[idx] += v
		t0 += d
	return _wav(b)


static func _kick(b: PackedFloat32Array, t0: float, amp: float) -> void:
	var start := int(t0 * RATE)
	var ph := 0.0
	for i in int(0.22 * RATE):
		var idx := start + i
		if idx >= b.size():
			return
		var t := float(i) / RATE
		ph += TAU * (48.0 + 110.0 * exp(-t * 35.0)) / RATE
		b[idx] += sin(ph) * exp(-t * 14.0) * amp


static func _clap(b: PackedFloat32Array, t0: float, amp: float) -> void:
	var start := int(t0 * RATE)
	var lp := 0.0
	for i in int(0.14 * RATE):
		var idx := start + i
		if idx >= b.size():
			return
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.6
		var burst := 1.0 if fmod(t, 0.012) < 0.006 or t > 0.03 else 0.4
		b[idx] += lp * exp(-t * 28.0) * amp * burst


static func _shaker(b: PackedFloat32Array, t0: float, amp: float) -> void:
	var start := int(t0 * RATE)
	var prev := 0.0
	for i in int(0.05 * RATE):
		var idx := start + i
		if idx >= b.size():
			return
		var t := float(i) / RATE
		var w := randf_range(-1.0, 1.0)
		b[idx] += (w - prev) * 0.5 * exp(-t * 70.0) * amp
		prev = w


static func _saw(b: PackedFloat32Array, t0: float, f: float, d: float, amp: float) -> void:
	var start := int(t0 * RATE)
	var lp := 0.0
	for i in int(d * RATE):
		var idx := start + i
		if idx >= b.size():
			return
		var t := float(i) / RATE
		var raw := 2.0 * fmod(f * t, 1.0) - 1.0 + 2.0 * fmod(f * 1.005 * t, 1.0) - 1.0
		lp += (raw - lp) * 0.25
		b[idx] += lp * amp * minf(1.0, t * 300.0) * minf(1.0, (d - t) * 60.0)
