class_name Sfx
extends Node
## Procedurally synthesised sound effects (no audio files needed).

const RATE := 22050

var streams := {}
var pool3d: Array = []
var pool2d: Array = []
var _i3 := 0
var _i2 := 0
var ambience: AudioStreamPlayer
var _mb_thread: Thread


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	streams["thud"] = _wav(_thud(rng))
	streams["knock"] = _wav(_knock(rng, 1.0))
	streams["clink"] = _wav(_knock(rng, 3.2))
	streams["step"] = _wav(_step(rng))
	streams["whoosh"] = _wav(_whoosh(rng))
	streams["click"] = _wav(_click())
	streams["grab"] = _wav(_grab(rng))
	streams["squeak"] = _wav(_squeak())
	streams["pop"] = _wav(_pop())
	streams["boing"] = _wav(_boing())
	streams["chime"] = _wav(_chime())
	streams["button"] = _wav(_button(rng))
	streams["ambience"] = _wav(_ambience(rng), true)
	streams["tick"] = _wav(_tick(rng), true)
	streams["birds"] = _wav(_birds(rng), true)
	for i in 16:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 4.0
		p.max_distance = 40.0
		p.attenuation_filter_cutoff_hz = 12000.0
		add_child(p)
		pool3d.append(p)
	for i in 8:
		var p2 := AudioStreamPlayer.new()
		add_child(p2)
		pool2d.append(p2)
	ambience = AudioStreamPlayer.new()
	ambience.stream = streams["ambience"]
	ambience.volume_db = -16.0
	add_child(ambience)
	# the music box tune takes a moment to synthesise, so do it in the background
	_mb_thread = Thread.new()
	_mb_thread.start(_musicbox)


func start_ambience() -> void:
	if not ambience.playing:
		ambience.play()


func get_stream(n: String) -> AudioStream:
	if n == "musicbox" and not streams.has(n):
		var samples: PackedFloat32Array
		if _mb_thread and _mb_thread.is_started():
			samples = _mb_thread.wait_to_finish()
		else:
			samples = _musicbox()
		_mb_thread = null
		streams[n] = _wav(samples, true)
	return streams.get(n)


func _exit_tree() -> void:
	if _mb_thread and _mb_thread.is_started():
		_mb_thread.wait_to_finish()


func play_at(n: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(n):
		return
	var p: AudioStreamPlayer3D = pool3d[_i3]
	_i3 = (_i3 + 1) % pool3d.size()
	p.stream = streams[n]
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func play2d(n: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(n):
		return
	var p: AudioStreamPlayer = pool2d[_i2]
	_i2 = (_i2 + 1) % pool2d.size()
	p.stream = streams[n]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func impact(pos: Vector3, speed: float, mass: float, kind: String) -> void:
	var n := "thud"
	var pitch := 1.0
	match kind:
		"crate", "small_crate", "chair", "domino", "book", "plank", "music_box":
			n = "knock"
			pitch = 1.3 if kind == "domino" else 1.0
		"ball", "cube", "pin", "lamp", "confetti":
			n = "clink"
		"beach_ball":
			n = "boing"
			pitch = 1.8
		"duck":
			n = "squeak" if randf() < 0.35 else "clink"
	var vol := linear_to_db(clampf(speed / 7.0, 0.06, 1.0)) + clampf(log(maxf(mass, 0.05)) * 2.0, -8.0, 4.0) - 2.0
	play_at(n, pos, vol, pitch * randf_range(0.85, 1.15) / clampf(sqrt(mass) * 0.5 + 0.5, 0.6, 1.8))


# --- synthesis helpers ---------------------------------------------------------------

func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _buf(sec: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(sec * RATE))
	return a


func _thud(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var a := _buf(0.3)
	var lp := 0.0
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 60.0 + 70.0 * exp(-t * 30.0)
		ph += TAU * f / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.12
		a[i] = (0.7 * sin(ph) * exp(-t * 16.0) + 0.6 * lp * exp(-t * 35.0)) * 0.9
	return a


func _knock(rng: RandomNumberGenerator, k: float) -> PackedFloat32Array:
	var a := _buf(0.16)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.35
		var s := sin(TAU * 210.0 * k * t) * exp(-t * 40.0) + 0.6 * sin(TAU * 540.0 * k * t) * exp(-t * 60.0)
		s += lp * exp(-t * 90.0) * 0.8
		a[i] = s * 0.55
	return a


func _step(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var a := _buf(0.11)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.08
		a[i] = (lp * 2.2 + 0.4 * sin(TAU * 85.0 * t)) * exp(-t * 45.0) * 0.7
	return a


func _whoosh(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var a := _buf(0.55)
	var lp := 0.0
	var lp2 := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var u := t / 0.55
		var cut := 0.02 + 0.25 * sin(PI * u)
		lp += (rng.randf_range(-1, 1) - lp) * cut
		lp2 += (lp - lp2) * cut
		a[i] = lp2 * sin(PI * u) * 2.2
	return a


func _click() -> PackedFloat32Array:
	var a := _buf(0.04)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = sin(TAU * 2400.0 * t) * exp(-t * 180.0) * 0.6
	return a


func _grab(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var a := _buf(0.08)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.3
		a[i] = (lp + 0.3 * sin(TAU * 600.0 * t)) * exp(-t * 60.0) * 0.6
	return a


func _squeak() -> PackedFloat32Array:
	var a := _buf(0.32)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 950.0 + 450.0 * minf(t * 8.0, 1.0) + 90.0 * sin(TAU * 11.0 * t)
		ph += TAU * f / RATE
		var env := minf(t * 60.0, 1.0) * exp(-t * 5.0)
		a[i] = tanh(2.5 * sin(ph)) * env * 0.35
	return a


func _pop() -> PackedFloat32Array:
	var a := _buf(0.14)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		ph += TAU * (900.0 * exp(-t * 18.0) + 160.0) / RATE
		a[i] = sin(ph) * exp(-t * 26.0) * 0.6
	return a


func _boing() -> PackedFloat32Array:
	var a := _buf(0.5)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		ph += TAU * (150.0 + 120.0 * exp(-t * 6.0) + 25.0 * sin(TAU * 18.0 * t)) / RATE
		a[i] = sin(ph) * exp(-t * 6.0) * 0.55
	return a


func _chime() -> PackedFloat32Array:
	var a := _buf(1.6)
	var notes := [880.0, 1108.7, 1318.5]
	for i in a.size():
		var t := float(i) / RATE
		var s := 0.0
		for j in notes.size():
			var tt := t - j * 0.09
			if tt > 0.0:
				s += sin(TAU * notes[j] * tt) * exp(-tt * 3.0) + 0.3 * sin(TAU * notes[j] * 2.01 * tt) * exp(-tt * 6.0)
		a[i] = s * 0.22
	return a


func _button(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var a := _buf(0.18)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.2
		a[i] = (sin(TAU * 140.0 * t) * exp(-t * 30.0) + lp * exp(-t * 50.0)) * 0.6
	return a


func _ambience(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var sec := 8.0
	var a := _buf(sec)
	var n := a.size()
	var brown := 0.0
	for i in n:
		var t := float(i) / RATE
		brown = brown * 0.996 + rng.randf_range(-1, 1) * 0.02
		var hum := sin(TAU * 55.0 * t) * 0.35 + sin(TAU * 110.0 * t) * 0.12
		var swell := 0.7 + 0.3 * sin(TAU * t / sec)
		a[i] = (brown * 1.6 + hum * 0.25) * swell * 0.5
	# crossfade the loop seam
	var fade := int(0.4 * RATE)
	for i in fade:
		var w := float(i) / fade
		a[i] = a[i] * w + a[n - fade + i] * (1.0 - w)
	return a.slice(0, n - fade)


func _tick(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var a := _buf(2.0)
	for i in a.size():
		var t := fmod(float(i) / RATE, 1.0)
		var k := 1.0 if i < RATE else 0.82
		a[i] = (sin(TAU * 1700.0 * k * t) * 0.5 + rng.randf_range(-0.3, 0.3)) * exp(-t * 90.0) * 0.4
	return a


func _birds(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var a := _buf(9.0)
	for c in 16:
		var start := rng.randf_range(0.0, 8.6)
		var f0 := rng.randf_range(2400.0, 4200.0)
		var dur := rng.randf_range(0.05, 0.14)
		var sweep := rng.randf_range(-1.0, 1.0) * 1500.0
		var i0 := int(start * RATE)
		var n := int(dur * RATE)
		var ph := 0.0
		for k in n:
			var u := float(k) / n
			ph += TAU * (f0 + sweep * u) / RATE
			a[i0 + k] += sin(ph) * sin(PI * u) * 0.25
	return a


func _musicbox() -> PackedFloat32Array:
	# An original little waltz, three beats per bar.
	var melody := [
		[76, 1], [79, 1], [84, 1], [83, 2], [79, 1],
		[81, 1], [79, 1], [76, 1], [74, 3],
		[72, 1], [76, 1], [79, 1], [81, 2], [77, 1],
		[76, 1], [74, 1], [71, 1], [72, 3],
		[76, 1], [79, 1], [84, 1], [86, 2], [84, 1],
		[83, 1], [81, 1], [79, 1], [77, 3],
		[76, 1], [74, 1], [72, 1], [74, 2], [71, 1],
		[72, 3], [-1, 3],
	]
	var bass := [48, 43, 45, 43, 48, 41, 43, 48, 48, 43, 45, 40, 41, 43, 43, 48]
	var beat := 0.32
	var total := 0
	for m in melody:
		total += m[1]
	var a := _buf(total * beat + 0.01)
	var pos := 0.0
	for m in melody:
		if m[0] > 0:
			_pluck(a, pos, 440.0 * pow(2.0, (m[0] - 69) / 12.0), 0.32, 1.0)
		pos += m[1] * beat
	for bi in bass.size():
		_pluck(a, bi * 3 * beat, 440.0 * pow(2.0, (bass[bi] + 12 - 69) / 12.0), 0.16, 0.9)
	return a


func _pluck(a: PackedFloat32Array, start: float, f: float, amp: float, dur: float) -> void:
	var i0 := int(start * RATE)
	var n := mini(int(dur * RATE), a.size() - i0)
	for k in n:
		var t := float(k) / RATE
		var s := sin(TAU * f * t) + 0.45 * sin(TAU * f * 2.0 * t) * exp(-t * 4.0) + 0.2 * sin(TAU * f * 4.02 * t) * exp(-t * 9.0)
		a[i0 + k] += s * amp * exp(-t * 3.2) * minf(t * 400.0, 1.0)
