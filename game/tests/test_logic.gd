extends SceneTree
## Проверка логики поля. Запуск: godot --headless --path game -s res://tests/test_logic.gd

var fails := 0

func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", msg)

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var b := Board.new()
	b.setup(8, 8)
	var line4: Array = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0)]
	check(b.can_place(line4, 0, 0), "можно поставить в пустое поле")
	b.place(line4, 0, 0, 1)
	check(not b.can_place(line4, 0, 0), "занято")
	var r := b.place(line4, 4, 0, 2)
	check(r.lines == 1, "ряд очищен")
	check(b.kind[b.idx(0, 0)] == Board.EMPTY, "клетки ряда пусты")
	check(b.score > 100, "очки за линию")

	# Камень: линия очищается, камень остаётся.
	b.load_layout(["#.......", "........", "........", "........", "........", "........", "........", "........"], rng)
	var seven: Array = []
	for x in range(1, 8): seven.append(Vector2i(x - 1, 0))
	b.place(seven, 1, 0, 0)
	check(b.lines_total == 1, "линия через камень")
	check(b.kind[0] == Board.STONE, "камень остался")

	# Яма: линия короче.
	b.load_layout(["xx......", "........", "........", "........", "........", "........", "........", "........"], rng)
	var six: Array = []
	for x in 6: six.append(Vector2i(x, 0))
	b.place(six, 2, 0, 0)
	check(b.lines_total == 1, "линия с ямой")
	check(not b.can_place([Vector2i(0,0)], 0, 0), "в яму нельзя")

	# Лёд.
	b.load_layout(["iiii....", "........", "........", "........", "........", "........", "........", "........"], rng)
	check(b.count_ice() == 4, "4 льда")
	var eight: Array = []
	for x in 8: eight.append(Vector2i(x, 0))
	b.place(eight, 0, 0, 0)
	check(b.ice_broken == 4 and b.count_ice() == 0, "лёд разбит")

	# Ящик с 2 этажами.
	b.load_layout(["2.......", "........", "........", "........", "........", "........", "........", "........"], rng)
	var seven2: Array = []
	for x in 7: seven2.append(Vector2i(x, 0))
	b.place(seven2, 1, 0, 0)
	check(b.kind[0] == Board.BOX and b.floors[0] == 1, "ящик потерял этаж")
	b.place(seven2, 1, 0, 0)
	check(b.kind[0] == Board.EMPTY and b.boxes_destroyed == 1, "ящик разбит")

	# Две линии сразу (крест).
	b.setup(8, 8)
	for x in 7: b.kind[b.idx(x + 1, 0)] = Board.BLOCK
	for y in 7: b.kind[b.idx(0, y + 1)] = Board.BLOCK
	var pr := b.preview_lines([Vector2i(0,0)], 0, 0)
	check(pr.rows.size() == 1 and pr.cols.size() == 1, "подсветка двух линий")
	r = b.place([Vector2i(0,0)], 0, 0, 0)
	check(r.lines == 2, "две линии")

	# Сохранение/загрузка.
	var d := b.to_dict()
	var b2 := Board.new()
	b2.from_dict(JSON.parse_string(JSON.stringify(d)))
	check(b2.score == b.score and b2.kind == b.kind, "сохранение")

	# Все уровни загружаются, раскладки 8×8.
	for n in range(1, Levels.count() + 1):
		var lv := Levels.get_level(n)
		check(lv.layout.size() == 8, "уровень %d: 8 строк" % n)
		for row in lv.layout:
			check(row.length() == 8, "уровень %d: строка 8" % n)

	print("RESULT OK" if fails == 0 else "RESULT FAIL %d" % fails)
	quit(1 if fails else 0)
