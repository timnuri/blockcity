class_name Bot
extends RefCounted
## Простой «жадный» игрок. Нужен для проверки уровней (проходимы ли и за сколько ходов).
## Позже можно использовать для подсказок.


## Лучший ход среди фигур в лотке: {i, x, y} или пусто, если некуда ставить.
static func best_move(board: Board, tray: Array, goals: Array) -> Dictionary:
	var best := {}
	var best_v := -INF
	for i in tray.size():
		var p = tray[i]
		if p == null:
			continue
		var cells: Array = p.cells
		var sz := Shapes.size_of(cells)
		for oy in range(0, board.h - sz.y + 1):
			for ox in range(0, board.w - sz.x + 1):
				if not board.can_place(cells, ox, oy):
					continue
				var v := _eval(board, tray, i, ox, oy, goals)
				if v > best_v:
					best_v = v
					best = {"i": i, "x": ox, "y": oy}
	return best


static func _eval(board: Board, tray: Array, i: int, ox: int, oy: int, goals: Array) -> float:
	var b := board.clone()
	var cells: Array = tray[i].cells
	var r := b.place(cells, ox, oy, 0)
	var v := 0.0
	v += float(r.lines) * 120.0 + float(r.lines * r.lines) * 30.0
	for g in goals:
		match g.t:
			"ice": v += float(r.ice.size()) * 90.0
			"boxes": v += float(r.boxes.size()) * 90.0
	# Для целей «лёд/ящики»: заполнять линии, где есть цели.
	var targets := false
	for g in goals:
		if g.t == "ice" or g.t == "boxes":
			targets = true
	if targets:
		for y in b.h:
			v += _line_value(b, y, true)
		for x in b.w:
			v += _line_value(b, x, false)
	# Прижимать фигуры к краям и другим блокам.
	for c in cells:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = Vector2i(ox + c.x, oy + c.y) + d
			if not b.inside(q.x, q.y) or b.kind[b.idx(q.x, q.y)] != Board.EMPTY:
				v += 3.0
	# Штраф за одиночные пустые клетки (их трудно заполнить).
	for y in b.h:
		for x in b.w:
			if b.kind[b.idx(x, y)] != Board.EMPTY:
				continue
			var free := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if b.is_free(x + d.x, y + d.y):
					free += 1
			if free == 0:
				v -= 25.0
	# Остальные фигуры должны помещаться.
	for j in tray.size():
		if j != i and tray[j] != null and not b.fits_anywhere(tray[j].cells):
			v -= 400.0
	return v


static func _line_value(b: Board, k: int, row: bool) -> float:
	var t := 0
	var filled := 0
	var total := 0
	var n := b.w if row else b.h
	for j in n:
		var x := j if row else k
		var y := k if row else j
		var i := b.idx(x, y)
		if b.kind[i] == Board.HOLE:
			continue
		total += 1
		if b.kind[i] != Board.EMPTY:
			filled += 1
		if b.ice[i] > 0:
			t += 1
		if b.kind[i] == Board.BOX:
			t += b.floors[i]
	if t == 0 or total == 0:
		return 0.0
	var f := float(filled) / total
	return f * f * 25.0 * t


## Играет уровень до победы/поражения. Возвращает {win, moves, score}.
static func play_level(level: Dictionary, seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var b := Board.new()
	b.load_layout(level.layout, rng)
	var goals := Levels.resolve_goals(level, b)
	var limit: int = level.moves
	var tray: Array = []
	while true:
		if tray.is_empty() or tray.all(func(t): return t == null):
			tray = Shapes.deal(b, rng, level.small)
		var mv := best_move(b, tray, goals)
		if mv.is_empty():
			return {"win": false, "moves": b.moves, "score": b.score, "why": "stuck", "b": b, "goals": goals}
		b.place(tray[mv.i].cells, mv.x, mv.y, tray[mv.i].color)
		tray[mv.i] = null
		if Levels.done(goals, b):
			return {"win": true, "moves": b.moves, "score": b.score}
		if limit > 0 and b.moves >= limit:
			return {"win": false, "moves": b.moves, "score": b.score, "why": "moves", "b": b, "goals": goals}
		if b.moves > 400:
			return {"win": false, "moves": b.moves, "score": b.score}
	return {}
