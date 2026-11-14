extends Node
## Звуки создаются кодом (без файлов): удар при установке, искристые аккорды
## при очистке (выше с каждым комбо), бас на больших очистках, фанфары победы.
## Плюс вибрация телефона с силой и «узорами».

const NAMES := ["pick", "place", "bad", "button", "clear0", "clear1", "clear2", "clear3", "clear4",
	"clear5", "clear6", "clear7", "whoosh", "boom", "win", "lose", "coin", "swap", "build"]

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for n in NAMES:
		var path := "res://sounds/%s.wav" % n
		if ResourceLoader.exists(path):
			_sounds[n] = load(path)
	if _sounds.size() < NAMES.size():
		_sounds = SoundGen.build_all()


func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not Save.setting("sound") or not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[name]
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()


## Звук очистки: чем больше комбо, тем выше; 3+ линии — с басом.
func clear(combo: int, lines := 1) -> void:
	play("clear%d" % clampi(combo - 1, 0, 7))
	if lines >= 2:
		play("whoosh", 1.0 + 0.1 * lines)
	if lines >= 3 or combo >= 4:
		play("boom")


func place() -> void:
	play("place", randf_range(0.92, 1.08))


## Вибрация. amp — сила 0..1 (на Android 8+).
func vibro(ms := 30, amp := 0.7) -> void:
	if Save.setting("vibro") and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amp)


## Двойной/тройной толчок — для комбо и побед.
func vibro_pattern(pulses: Array) -> void:
	if not (Save.setting("vibro") and OS.has_feature("mobile")):
		return
	for p in pulses:
		Input.vibrate_handheld(int(p[0]), float(p[1]))
		await get_tree().create_timer((p[0] + 70) / 1000.0).timeout
