class_name SfxSynth
extends RefCounted
## Synthesised placeholder sounds. tools/gen_sfx.gd writes these to res://audio/*.wav;
## replace any wav there with a real asset (same name) and the game picks it up.

const RATE := 44100
const NAMES := ["tick", "untick", "thunk", "bonk", "whoosh", "pop", "win", "fail", "click", "rewind", "pickup", "swap", "gate",
		"coin", "star", "kaching", "jingle", "empty", "hint", "sparkle", "punch", "slam", "whoomp",
		"crunch", "crash", "screech", "beep"]


static func make(sound: String) -> AudioStreamWAV:
	var b: PackedFloat32Array
	match sound:
		"tick": b = _blip(1650.0, 0.05, 110.0, 0.28)
		"untick": b = _blip(1000.0, 0.05, 110.0, 0.2)
		"click": b = _blip(900.0, 0.035, 140.0, 0.25)
		"thunk": b = _thunk()
		"bonk": b = _bonk()
		"whoosh": b = _whoosh()
		"pop": b = _pop()
		"win": b = _notes([523.25, 659.25, 783.99, 1046.5], 0.075, 1.0, 0.22, 5.5)
		"fail": b = _notes([392.0, 293.66], 0.15, 0.6, 0.22, 7.0)
		"rewind": b = _rewind()
		"pickup": b = _notes([783.99, 1046.5], 0.06, 0.24, 0.2, 14.0)
		"swap": b = _swap()
		"gate": b = _gate()
		"coin": b = _notes([1318.5, 1975.5], 0.04, 0.2, 0.15, 18.0)
		"star": b = _notes([1046.5, 1568.0, 2093.0], 0.045, 0.5, 0.17, 8.0)
		"kaching": b = _notes([1568.0, 2093.0, 2637.0, 3136.0], 0.05, 0.7, 0.15, 7.0)
		"jingle": b = _notes([523.25, 659.25, 783.99, 659.25, 880.0, 1046.5, 1318.5], 0.13, 1.6, 0.17, 4.0)
		"empty": b = _notes([233.08, 174.61], 0.13, 0.42, 0.24, 8.0)
		"hint": b = _notes([880.0, 1174.66, 1396.91], 0.06, 0.4, 0.16, 10.0)
		"sparkle": b = _notes([2093.0, 2637.0], 0.03, 0.22, 0.1, 16.0)
		"punch": b = _impact(70.0, 0.45, 0.9)
		"slam": b = _impact(110.0, 0.3, 0.6)
		"whoomp": b = _whoomp()
		"crunch": b = _crunch()
		"crash": b = _crash()
		"screech": b = _screech()
		"beep": b = _beep()
		_: b = PackedFloat32Array([0.0])
	return _wav(b)


static func _wav(b: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


static func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


static func _attack(t: float, ms := 1.0) -> float:
	return minf(1.0, t * 1000.0 / ms)


static func _blip(freq: float, dur: float, decay: float, amp: float) -> PackedFloat32Array:
	var b := _buf(dur)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = amp * exp(-t * decay) * _attack(t, 0.5) * (sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.0 * t))
	return b


## Low body drop + papery click + a tonal "ding" that carries the combo pitch.
static func _thunk() -> PackedFloat32Array:
	var b := _buf(0.26)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 85.0 + 160.0 * exp(-t * 30.0)
		ph += TAU * f / RATE
		var body := sin(ph) * exp(-t * 17.0) * 0.8
		lp += (randf_range(-1.0, 1.0) - lp) * 0.18
		var click := lp * exp(-t * 80.0) * 0.7
		var ding := sin(TAU * 1318.5 * t) * exp(-t * 22.0) * 0.14 + sin(TAU * 659.25 * t) * exp(-t * 16.0) * 0.14
		b[i] = (body + click + ding) * _attack(t, 0.4)
	return b


## Muted, slightly square "bonk".
static func _bonk() -> PackedFloat32Array:
	var b := _buf(0.2)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (175.0 - 200.0 * t) / RATE
		var raw := tanh(3.0 * sin(ph)) * exp(-t * 24.0)
		lp += (raw - lp) * 0.12
		b[i] = lp * 0.75 * _attack(t)
	return b


static func _whoosh() -> PackedFloat32Array:
	var dur := 0.22
	var b := _buf(dur)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := sin(PI * t / dur)
		lp += (randf_range(-1.0, 1.0) - lp) * (0.03 + 0.2 * k)
		b[i] = lp * k * k * 0.9
	return b


static func _pop() -> PackedFloat32Array:
	var dur := 0.11
	var b := _buf(dur)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * lerpf(380.0, 1000.0, t / dur) / RATE
		b[i] = sin(ph) * exp(-t * 30.0) * 0.4 * _attack(t)
	return b


static func _notes(freqs: Array, step: float, dur: float, amp: float, decay: float) -> PackedFloat32Array:
	var b := _buf(dur)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for n in freqs.size():
			var lt := t - n * step
			if lt < 0.0:
				continue
			var f: float = freqs[n]
			s += (sin(TAU * f * lt) + 0.3 * sin(TAU * f * 2.0 * lt) + 0.1 * sin(TAU * f * 3.0 * lt)) * exp(-lt * decay) * _attack(lt, 2.0)
		b[i] = s * amp * minf(1.0, (dur - t) * 20.0)
	return b


## A heavy hit: a falling sine thump plus a short burst of noise.
static func _impact(freq: float, dur: float, noise: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := freq * (1.0 + 2.5 * exp(-t * 30.0))
		ph += TAU * f / RATE
		var body := sin(ph) * exp(-t * 9.0)
		var hiss := randf_range(-1.0, 1.0) * exp(-t * 40.0) * noise
		b[i] = 0.55 * (body + hiss) * _attack(t, 1.0)
	return b


## Fire catching: a rising, roaring noise swell.
static func _whoomp() -> PackedFloat32Array:
	var b := _buf(0.7)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(t * 8.0, 1.0) * exp(-t * 4.0)
		var cut := 0.04 + 0.25 * minf(t * 3.0, 1.0)
		lp += (randf_range(-1.0, 1.0) - lp) * cut
		b[i] = lp * env * 0.9 + sin(TAU * 55.0 * t) * env * 0.25
	return b


## Tape-rewind warble: falling pitch with fast vibrato.
static func _rewind() -> PackedFloat32Array:
	var dur := 0.38
	var b := _buf(dur)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := lerpf(1100.0, 280.0, t / dur) * (1.0 + 0.12 * sin(TAU * 28.0 * t))
		ph += TAU * f / RATE
		b[i] = (sin(ph) + 0.3 * sin(2.0 * ph)) * 0.28 * _attack(t, 3.0) * minf(1.0, (dur - t) * 12.0)
	return b


## Two tones sliding past each other.
static func _swap() -> PackedFloat32Array:
	var dur := 0.22
	var b := _buf(dur)
	var p1 := 0.0
	var p2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := t / dur
		p1 += TAU * lerpf(500.0, 1000.0, k) / RATE
		p2 += TAU * lerpf(1000.0, 500.0, k) / RATE
		b[i] = (sin(p1) + sin(p2)) * 0.16 * sin(PI * k) * _attack(t)
	return b


## Barrier clack: short filtered noise tick on a low knock.
static func _gate() -> PackedFloat32Array:
	var b := _buf(0.12)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.35
		b[i] = (lp * exp(-t * 90.0) * 0.5 + sin(TAU * 210.0 * t) * exp(-t * 40.0) * 0.4) * _attack(t, 0.3)
	return b


## Asphalt tearing up: a low thud under a spray of gravelly grains.
static func _crunch() -> PackedFloat32Array:
	var b := _buf(0.24)
	var lp := 0.0
	var grain := 0.0
	for i in b.size():
		var t := float(i) / RATE
		if randf() < 0.004:
			grain = randf_range(0.5, 1.0)
		grain *= 0.996
		lp += (randf_range(-1.0, 1.0) - lp) * 0.3
		var thud := sin(TAU * (60.0 + 90.0 * exp(-t * 40.0)) * t) * exp(-t * 22.0) * 0.6
		b[i] = (thud + lp * grain * 0.8 * exp(-t * 9.0)) * _attack(t, 0.6)
	return b


## Driving into your own wreckage: a crunch, a metallic clang and rattling bits.
static func _crash() -> PackedFloat32Array:
	var b := _buf(0.9)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (55.0 + 140.0 * exp(-t * 18.0)) / RATE
		var body := sin(ph) * exp(-t * 7.0) * 0.7
		lp += (randf_range(-1.0, 1.0) - lp) * (0.5 * exp(-t * 3.0) + 0.05)
		var noise := lp * exp(-t * 5.0) * 0.8
		var clang := (sin(TAU * 523.0 * t) + 0.7 * sin(TAU * 811.0 * t) + 0.5 * sin(TAU * 1263.0 * t)) * exp(-t * 6.0) * 0.12
		var rattle := 0.0
		if t > 0.18 and fmod(t * 23.0, 1.0) < 0.12:
			rattle = randf_range(-0.3, 0.3) * exp(-(t - 0.18) * 5.0)
		b[i] = tanh(1.6 * (body + noise + clang + rattle)) * 0.7 * _attack(t, 0.5)
	return b


## Tyres locking up: a wailing, falling squeal with a rubbery rasp, then a soft thump as it settles.
static func _screech() -> PackedFloat32Array:
	var dur := 0.55
	var b := _buf(dur)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := t / dur
		var f := lerpf(1750.0, 1150.0, k) * (1.0 + 0.03 * sin(TAU * 31.0 * t))
		ph += TAU * f / RATE
		var squeal := (sin(ph) + 0.5 * sin(2.01 * ph) + 0.3 * sin(3.02 * ph)) * 0.2
		lp += (randf_range(-1.0, 1.0) - lp) * 0.5
		var env := minf(1.0, t * 40.0) * pow(1.0 - k, 0.7)
		var thump := sin(TAU * 70.0 * t) * exp(-maxf(t - 0.4, 0.0) * 30.0) * (0.5 if t > 0.4 else 0.0)
		b[i] = (squeal * (0.75 + 0.25 * lp) + lp * 0.08) * env + thump
	return b


## A car horn: two buzzy tones a third apart, short.
static func _beep() -> PackedFloat32Array:
	var b := _buf(0.16)
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(1.0, t * 300.0) * minf(1.0, (0.16 - t) * 60.0)
		var v := signf(sin(TAU * 415.0 * t)) * 0.5 + signf(sin(TAU * 523.0 * t)) * 0.5
		b[i] = v * env * 0.16
	return b
