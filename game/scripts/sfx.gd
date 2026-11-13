extends Node
## Звуки создаются кодом (без файлов): короткие мягкие «щелчки» и аккорды.
## Плюс вибрация телефона.

const RATE := 22050

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_sounds["pick"] = _tone([880.0], 0.05, 0.25, 0.0)
	_sounds["place"] = _tone([196.0, 392.0], 0.09, 0.45, 0.002, true)
	_sounds["bad"] = _tone([150.0], 0.12, 0.3, 0.0, true)
	_sounds["button"] = _tone([660.0], 0.04, 0.2, 0.0)
	for i in 6:
		var base := 523.25 * pow(2.0, i * 2.0 / 12.0)
		_sounds["clear%d" % i] = _tone([base, base * 1.25, base * 1.5], 0.35, 0.35, 0.004)
	_sounds["win"] = _arp([523.25, 659.25, 783.99, 1046.5], 0.11)
	_sounds["lose"] = _arp([392.0, 329.63, 261.63], 0.16)
	_sounds["swap"] = _arp([700.0, 900.0], 0.05)
	_sounds["coin"] = _arp([1318.5, 1760.0], 0.06)


func play(name: String, pitch := 1.0) -> void:
	if not Save.setting("sound") or not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[name]
	p.pitch_scale = pitch
	p.play()


func clear(combo: int) -> void:
	play("clear%d" % clampi(combo - 1, 0, 5))


func vibro(ms := 25) -> void:
	if Save.setting("vibro") and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func _tone(freqs: Array, dur: float, vol: float, glide := 0.0, soft := false) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := []
	for f in freqs:
		ph.append(0.0)
	for i in n:
		var t := float(i) / RATE
		var env: float = exp(-t * (6.0 / dur)) * minf(1.0, t * 400.0)
		var s := 0.0
		for k in freqs.size():
			var f: float = freqs[k] * (1.0 + glide * t * 100.0)
			ph[k] += TAU * f / RATE
			var v := sin(ph[k])
			if soft:
				v = v * 0.7 + sin(ph[k] * 0.5) * 0.3
			s += v / freqs.size()
		data.encode_s16(i * 2, int(clamp(s * env * vol, -1.0, 1.0) * 32000))
	return _wav(data)


func _arp(freqs: Array, step: float) -> AudioStreamWAV:
	var note := int(step * RATE)
	var tail := int(0.25 * RATE)
	var n := note * freqs.size() + tail
	var data := PackedByteArray()
	data.resize(n * 2)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for k in freqs.size():
		var start := k * note
		var ph := 0.0
		for i in range(start, n):
			var t := float(i - start) / RATE
			ph += TAU * freqs[k] / RATE
			buf[i] += sin(ph) * exp(-t * 9.0) * min(1.0, t * 400.0) * 0.3
	for i in n:
		data.encode_s16(i * 2, int(clamp(buf[i], -1.0, 1.0) * 32000))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
