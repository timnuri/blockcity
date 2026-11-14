class_name SoundGen
extends RefCounted
## Синтез всех звуков кодом. Запускается один раз скриптом tests/make_sounds.gd,
## результат лежит в game/sounds/*.wav (так игра запускается быстрее).

const RATE := 22050

# ---------------------------------------------------------------- синтез

static func build_all() -> Dictionary:
	var _sounds := {}
	var b: PackedFloat32Array

	b = _buf(0.09)
	_sine(b, 0.0, 0.07, 320.0, 820.0, 0.7, 40.0)
	_noise(b, 0.0, 0.015, 0.25, 200.0, 0.5)
	_sounds["pick"] = _wav(b)

	# Установка: глухой «тук» + щелчок.
	b = _buf(0.22)
	_sine(b, 0.0, 0.18, 190.0, 70.0, 1.0, 22.0)
	_sine(b, 0.0, 0.06, 520.0, 380.0, 0.35, 60.0)
	_noise(b, 0.0, 0.04, 0.55, 90.0, 0.25)
	_sounds["place"] = _wav(b)

	b = _buf(0.25)
	_square(b, 0.0, 0.18, 140.0, 110.0, 0.35, 12.0)
	_sounds["bad"] = _wav(b)

	b = _buf(0.08)
	_sine(b, 0.0, 0.06, 900.0, 700.0, 0.5, 60.0)
	_noise(b, 0.0, 0.01, 0.2, 300.0, 0.6)
	_sounds["button"] = _wav(b)

	# Очистка: быстрый аккорд-колокольчик + искры. 8 ступеней по высоте.
	var steps := [0, 2, 4, 5, 7, 9, 11, 12]
	for i in 8:
		var base := 392.0 * pow(2.0, steps[i] / 12.0)
		b = _buf(0.75)
		_bell(b, 0.00, base, 0.55)
		_bell(b, 0.045, base * 1.25, 0.5)
		_bell(b, 0.09, base * 1.5, 0.5)
		_bell(b, 0.135, base * 2.0, 0.45)
		for k in 6:
			_sine(b, 0.05 + k * 0.035, 0.05, base * 4.0 * randf_range(0.9, 1.3), base * 5.0, 0.12, 50.0)
		_sounds["clear%d" % i] = _wav(b)

	b = _buf(0.45)
	_noise_sweep(b, 0.0, 0.4, 0.5)
	_sounds["whoosh"] = _wav(b)

	b = _buf(0.6)
	_sine(b, 0.0, 0.55, 110.0, 38.0, 1.0, 7.0)
	_noise(b, 0.0, 0.08, 0.4, 30.0, 0.15)
	_sounds["boom"] = _wav(b)

	b = _buf(1.6)
	var fan := [523.25, 659.25, 783.99, 1046.5]
	for k in fan.size():
		_bell(b, k * 0.12, fan[k], 0.55)
	for f in fan:
		_bell(b, 0.55, f, 0.35)
	_sounds["win"] = _wav(b)

	b = _buf(1.0)
	var down := [392.0, 349.23, 311.13, 261.63]
	for k in down.size():
		_sine(b, k * 0.16, 0.3, down[k], down[k] * 0.98, 0.5, 8.0)
	_sounds["lose"] = _wav(b)

	b = _buf(0.5)
	_bell(b, 0.0, 1318.5, 0.5)
	_bell(b, 0.07, 1975.5, 0.45)
	_sounds["coin"] = _wav(b)

	b = _buf(0.35)
	_noise_sweep(b, 0.0, 0.25, 0.4)
	_sine(b, 0.05, 0.2, 500.0, 1200.0, 0.35, 15.0)
	_sounds["swap"] = _wav(b)

	b = _buf(0.7)
	_bell(b, 0.0, 784.0, 0.45)
	_bell(b, 0.08, 1174.7, 0.45)
	_bell(b, 0.16, 1568.0, 0.4)
	_sounds["build"] = _wav(b)
	return _sounds


static func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b


## Синус со скольжением частоты f0→f1 и экспоненциальным затуханием.
static func _sine(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, vol: float, decay: float) -> void:
	var s := int(start * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	for i in n:
		if s + i >= b.size():
			break
		var t := float(i) / RATE
		var f := lerpf(f0, f1, minf(1.0, t / dur))
		ph += TAU * f / RATE
		var env := exp(-t * decay) * minf(1.0, t * 600.0)
		b[s + i] += sin(ph) * env * vol


static func _square(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, vol: float, decay: float) -> void:
	var s := int(start * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	for i in n:
		if s + i >= b.size():
			break
		var t := float(i) / RATE
		ph += TAU * lerpf(f0, f1, t / dur) / RATE
		var v := 1.0 if sin(ph) > 0.0 else -1.0
		b[s + i] += v * exp(-t * decay) * vol * minf(1.0, t * 600.0)


## Шум, сглаженный (lp: 0..1, меньше — глуше).
static func _noise(b: PackedFloat32Array, start: float, dur: float, vol: float, decay: float, lp: float) -> void:
	var s := int(start * RATE)
	var n := int(dur * RATE)
	var y := 0.0
	for i in n:
		if s + i >= b.size():
			break
		var t := float(i) / RATE
		y += (randf() * 2.0 - 1.0 - y) * lp
		b[s + i] += y * exp(-t * decay) * vol


## «Вжух»: шум, который становится ярче, потом стихает.
static func _noise_sweep(b: PackedFloat32Array, start: float, dur: float, vol: float) -> void:
	var s := int(start * RATE)
	var n := int(dur * RATE)
	var y := 0.0
	for i in n:
		if s + i >= b.size():
			break
		var k := float(i) / n
		y += (randf() * 2.0 - 1.0 - y) * lerpf(0.03, 0.5, k)
		b[s + i] += y * sin(PI * k) * vol


## Колокольчик: основной тон + неровный обертон.
static func _bell(b: PackedFloat32Array, start: float, f: float, vol: float) -> void:
	_sine(b, start, 0.6, f, f, vol, 6.0)
	_sine(b, start, 0.25, f * 2.76, f * 2.76, vol * 0.35, 14.0)
	_sine(b, start, 0.12, f * 5.4, f * 5.4, vol * 0.15, 30.0)


static func _wav(b: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for v in b:
		peak = maxf(peak, absf(v))
	var g := 0.92 / peak
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i] * g, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
