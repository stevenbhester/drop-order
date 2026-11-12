class_name AdMusic
extends RefCounted
## Little synthesized music beds and stingers for the demo ads (no voiceover).

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


static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## Warm and bouncy: a plucked arpeggio over C - G - Am - F, soft kick and shaker, 100 bpm.
static func fun(seconds: float) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var beat := 60.0 / 100.0
	var chords := [[60, 64, 67, 72], [55, 59, 62, 67], [57, 60, 64, 69], [53, 57, 60, 65]]
	var bass := [36, 43, 45, 41]
	var step := beat / 2.0
	var steps := int(seconds / step) + 1
	for s in steps:
		var t0 := s * step
		var bar := int(t0 / (beat * 4.0)) % 4
		var ch: Array = chords[bar]
		var note: int = ch[[0, 1, 2, 3, 2, 1, 2, 3][s % 8]] + 12
		_pluck(b, t0, _hz(note), 0.11, 0.9)
		if s % 4 == 0:
			_pluck(b, t0, _hz(bass[bar]), 0.16, 1.6)
		if s % 4 == 0:
			_kick(b, t0, 0.3)
		_shaker(b, t0 + step * 0.5, 0.035)
	# Soft fade in and out.
	for i in n:
		var t := float(i) / RATE
		b[i] *= minf(1.0, t * 6.0) * minf(1.0, (seconds - t) * 1.5)
	return _wav(b)


## Frantic: four-on-the-floor, claps, offbeat saw bass, a riser, 150 bpm.
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


static func _pluck(b: PackedFloat32Array, t0: float, f: float, amp: float, decay_s: float) -> void:
	var start := int(t0 * RATE)
	var len := int(decay_s * RATE)
	for i in len:
		var idx := start + i
		if idx >= b.size():
			return
		var t := float(i) / RATE
		var env := minf(1.0, t * 400.0) * exp(-t * 5.0 / decay_s)
		b[idx] += (sin(TAU * f * t) + 0.35 * sin(TAU * 2.0 * f * t) + 0.12 * sin(TAU * 3.0 * f * t)) * env * amp


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
