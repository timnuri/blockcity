class_name Board
extends RefCounted
## Логика игрового поля (без графики): клетки, установка фигур, очистка линий,
## препятствия (камни, ямы, лёд, многоэтажные ящики), очки и комбо.

enum { EMPTY, BLOCK, STONE, HOLE, BOX }

var w := 8
var h := 8
var kind := PackedInt32Array()    # тип клетки
var color := PackedInt32Array()   # цвет блока (для BLOCK)
var ice := PackedInt32Array()     # 1 = под клеткой лёд
var floors := PackedInt32Array()  # этажей у ящика (для BOX)

var score := 0
var combo := 0          # сколько очисток подряд (с запасом в 3 хода)
var since_clear := 99   # ходов с последней очистки
var lines_total := 0
var moves := 0
var ice_broken := 0
var boxes_destroyed := 0


func setup(width: int, height: int) -> void:
	w = width
	h = height
	var n := w * h
	kind.resize(n); kind.fill(EMPTY)
	color.resize(n); color.fill(0)
	ice.resize(n); ice.fill(0)
	floors.resize(n); floors.fill(0)
	score = 0; combo = 0; since_clear = 99
	lines_total = 0; moves = 0; ice_broken = 0; boxes_destroyed = 0


## Раскладка из строк: '.' пусто, '#' камень, 'x' яма, 'i' лёд,
## 'b' готовый блок, 'B' блок на льду, '1'..'3' ящик с этажами.
func load_layout(rows: Array, rng: RandomNumberGenerator) -> void:
	setup(rows[0].length(), rows.size())
	for y in h:
		var row: String = rows[y]
		for x in w:
			var i := idx(x, y)
			var c := row[x]
			match c:
				"#": kind[i] = STONE
				"x": kind[i] = HOLE
				"i": ice[i] = 1
				"b":
					kind[i] = BLOCK; color[i] = rng.randi_range(0, Shapes.COLORS - 1)
				"B":
					kind[i] = BLOCK; ice[i] = 1; color[i] = rng.randi_range(0, Shapes.COLORS - 1)
				"1", "2", "3":
					kind[i] = BOX; floors[i] = int(c)


func idx(x: int, y: int) -> int:
	return y * w + x


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h


func is_free(x: int, y: int) -> bool:
	return inside(x, y) and kind[idx(x, y)] == EMPTY


func can_place(shape: Array, ox: int, oy: int) -> bool:
	for c in shape:
		if not is_free(ox + c.x, oy + c.y):
			return false
	return true


func fits_anywhere(shape: Array) -> bool:
	var sz := Shapes.size_of(shape)
	for oy in range(0, h - sz.y + 1):
		for ox in range(0, w - sz.x + 1):
			if can_place(shape, ox, oy):
				return true
	return false


func count_ice() -> int:
	var n := 0
	for v in ice:
		n += v
	return n


func count_boxes() -> int:
	var n := 0
	for k in kind:
		if k == BOX:
			n += 1
	return n


## Строка/столбец заполнены? Ямы пропускаются, камни и ящики считаются заполненными.
func _row_full(y: int) -> bool:
	var any := false
	for x in w:
		var k := kind[idx(x, y)]
		if k == EMPTY:
			return false
		if k != HOLE:
			any = true
	return any


func _col_full(x: int) -> bool:
	var any := false
	for y in h:
		var k := kind[idx(x, y)]
		if k == EMPTY:
			return false
		if k != HOLE:
			any = true
	return any


## Какие линии очистятся, если поставить фигуру сюда (для подсветки). Поле не меняется.
func preview_lines(shape: Array, ox: int, oy: int) -> Dictionary:
	var rows: Array[int] = []
	var cols: Array[int] = []
	if not can_place(shape, ox, oy):
		return {"rows": rows, "cols": cols}
	for c in shape:
		kind[idx(ox + c.x, oy + c.y)] = BLOCK
	for c in shape:
		var y: int = oy + c.y
		var x: int = ox + c.x
		if not rows.has(y) and _row_full(y):
			rows.append(y)
		if not cols.has(x) and _col_full(x):
			cols.append(x)
	for c in shape:
		kind[idx(ox + c.x, oy + c.y)] = EMPTY
	return {"rows": rows, "cols": cols}


## Ставит фигуру. Возвращает подробности для анимаций и целей уровня.
func place(shape: Array, ox: int, oy: int, col: int) -> Dictionary:
	var placed: Array[Vector2i] = []
	for c in shape:
		var p := Vector2i(ox + c.x, oy + c.y)
		var i := idx(p.x, p.y)
		kind[i] = BLOCK
		color[i] = col
		placed.append(p)
	moves += 1
	var pv := _full_lines(placed)
	var rows: Array[int] = pv.rows
	var cols: Array[int] = pv.cols
	var n_lines := rows.size() + cols.size()

	var cleared: Array = []      # [{pos, kind, color}] — клетки, которые исчезли
	var hit_boxes: Array = []    # [{pos, left}] — ящики, потерявшие этаж
	var broke_ice: Array[Vector2i] = []
	var seen := {}
	var cells: Array[Vector2i] = []
	for y in rows:
		for x in w:
			cells.append(Vector2i(x, y))
	for x in cols:
		for y in h:
			cells.append(Vector2i(x, y))
	for p in cells:
		if seen.has(p):
			continue
		seen[p] = true
		var i := idx(p.x, p.y)
		match kind[i]:
			BLOCK:
				cleared.append({"pos": p, "kind": BLOCK, "color": color[i]})
				kind[i] = EMPTY
			BOX:
				floors[i] -= 1
				if floors[i] <= 0:
					floors[i] = 0
					kind[i] = EMPTY
					boxes_destroyed += 1
					cleared.append({"pos": p, "kind": BOX, "color": 0})
				hit_boxes.append({"pos": p, "left": floors[i]})
		if kind[i] != HOLE and kind[i] != STONE and ice[i] > 0:
			ice[i] -= 1
			ice_broken += 1
			broke_ice.append(p)

	# Очки: клетки фигуры + бонус за линии, умноженный на комбо.
	var gained := shape.size()
	if n_lines > 0:
		if since_clear <= 3:
			combo += 1
		else:
			combo = 1
		since_clear = 0
		var base := [0, 10, 30, 60, 100, 150, 210, 280]
		var b: int = base[min(n_lines, base.size() - 1)] * 10
		gained += b * combo
		lines_total += n_lines
	else:
		since_clear += 1
		if since_clear > 3:
			combo = 0
	score += gained
	return {
		"placed": placed, "rows": rows, "cols": cols, "lines": n_lines,
		"cleared": cleared, "boxes": hit_boxes, "ice": broke_ice,
		"gained": gained, "combo": combo,
	}


func _full_lines(placed: Array[Vector2i]) -> Dictionary:
	var rows: Array[int] = []
	var cols: Array[int] = []
	for p in placed:
		if not rows.has(p.y) and _row_full(p.y):
			rows.append(p.y)
		if not cols.has(p.x) and _col_full(p.x):
			cols.append(p.x)
	return {"rows": rows, "cols": cols}


## Копия поля (для бота и проверок).
func clone() -> Board:
	var b := Board.new()
	b.w = w; b.h = h
	b.kind = kind.duplicate(); b.color = color.duplicate()
	b.ice = ice.duplicate(); b.floors = floors.duplicate()
	b.score = score; b.combo = combo; b.since_clear = since_clear
	b.lines_total = lines_total; b.moves = moves
	b.ice_broken = ice_broken; b.boxes_destroyed = boxes_destroyed
	return b


func to_dict() -> Dictionary:
	return {
		"w": w, "h": h, "kind": Array(kind), "color": Array(color),
		"ice": Array(ice), "floors": Array(floors), "score": score,
		"combo": combo, "since": since_clear, "lines": lines_total, "moves": moves,
		"iceb": ice_broken, "boxd": boxes_destroyed,
	}


func from_dict(d: Dictionary) -> void:
	w = int(d.w); h = int(d.h)
	kind = PackedInt32Array(d.kind); color = PackedInt32Array(d.color)
	ice = PackedInt32Array(d.ice); floors = PackedInt32Array(d.floors)
	score = int(d.score); combo = int(d.combo); since_clear = int(d.since)
	lines_total = int(d.lines); moves = int(d.moves)
	ice_broken = int(d.get("iceb", 0)); boxes_destroyed = int(d.get("boxd", 0))
