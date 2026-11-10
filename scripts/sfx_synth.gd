class_name SfxSynth
extends RefCounted
## Synthesised placeholder sounds. tools/gen_sfx.gd writes these to res://audio/*.wav;
## replace any wav there with a real asset (same name) and the game picks it up.

const RATE := 44100
const NAMES := ["tick", "untick", "thunk", "bonk", "whoosh", "pop", "win", "fail", "click", "rewind", "pickup", "swap", "gate"]


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
