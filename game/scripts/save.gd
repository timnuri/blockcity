extends Node
## Сохранение прогресса: рекорд, монеты, усилители, медали уровней, настройки,
## и незаконченная партия бесконечного режима.

const PATH := "user://save.json"

var data := {}


func _ready() -> void:
	load_data()


func _defaults() -> Dictionary:
	return {
		"best": 0,
		"coins": 0,
		"boosters": {"swap": 3},
		"levels": {},          # "5": {"medal": 2, "moves": 18}
		"stats": {"games": 0, "lines": 0, "levels_won": 0},
		"settings": {"sound": true, "vibro": true},
		"seen_intro": [],      # номера уровней, где подсказка уже показана
		"endless": null,       # сохранённая партия
	}


func load_data() -> void:
	data = _defaults()
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				data[k] = d[k]
	# Новые поля, которых не было в старых сохранениях.
	var def := _defaults()
	for k in ["boosters", "stats", "settings"]:
		for kk in def[k]:
			if not data[k].has(kk):
				data[k][kk] = def[k][kk]


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func setting(name: String) -> bool:
	return bool(data.settings.get(name, true))


func set_setting(name: String, v: bool) -> void:
	data.settings[name] = v
	save()


func coins() -> int:
	return int(data.coins)


func add_coins(n: int) -> void:
	data.coins = coins() + n
	save()


func boosters(kind: String) -> int:
	return int(data.boosters.get(kind, 0))


func add_booster(kind: String, n: int) -> void:
	data.boosters[kind] = boosters(kind) + n
	save()


func level_medal(n: int) -> int:
	var e = data.levels.get(str(n))
	return int(e.medal) if e else 0


func level_moves(n: int) -> int:
	var e = data.levels.get(str(n))
	return int(e.moves) if e else 0


## Самый дальний открытый уровень.
func unlocked() -> int:
	var u := 1
	for n in range(1, Levels.count() + 1):
		if level_medal(n) > 0:
			u = n + 1
	return min(u, Levels.count())


## Записывает результат уровня. Возвращает награду в монетах (только за улучшение).
func record_level(n: int, medal: int, moves: int) -> int:
	var old := level_medal(n)
	var reward_for := [0, 10, 25, 50]  # бронза / серебро / золото — монет всего
	var reward: int = max(0, reward_for[medal] - reward_for[old])
	var e = data.levels.get(str(n))
	if e == null:
		data.levels[str(n)] = {"medal": medal, "moves": moves}
		data.stats.levels_won = int(data.stats.levels_won) + 1
	else:
		e.medal = max(int(e.medal), medal)
		e.moves = min(int(e.moves), moves) if int(e.moves) > 0 else moves
	data.coins = coins() + reward
	if medal == 3 and old < 3:
		data.boosters.swap = boosters("swap") + 1
	save()
	return reward


func intro_seen(n: int) -> bool:
	return data.seen_intro.has(n) or data.seen_intro.has(float(n))


func mark_intro(n: int) -> void:
	if not intro_seen(n):
		data.seen_intro.append(n)
		save()
