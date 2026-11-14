class_name GameView
extends Control
## Рисует поле, лоток с тремя фигурами, перетаскивание и все эффекты.
## Правила здесь не решаются — только показ и ввод. Решает game_screen.gd.

signal dropped(i: int, gx: int, gy: int)
signal tapped(i: int)

var board: Board
var tray: Array = [null, null, null]
var top_margin := 220.0
var bottom_margin := 150.0

var board_rect := Rect2()
var cell := 80.0
var slots: Array[Rect2] = [Rect2(), Rect2(), Rect2()]

var locked := false
var swap_mode := false

var _drag := -1
var _finger := Vector2.ZERO
var _grid := Vector2i(-99, -99)
var _ok := false
var _preview := {"rows": [], "cols": []}

var _effects: Array = []
var _particles: Array = []
var _texts: Array = []
var _pops := {}             # Vector2i -> время
var _shake := 0.0
var _flash := 0.0
var _tray_t: Array[float] = [1.0, 1.0, 1.0]
var _return := {}           # {i, from, t}
var _time := 0.0
var _hint_cells: Array = [] # подсказка (мигающие клетки)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var avail_h := size.y - top_margin - bottom_margin
	var bw: float = min(size.x - 36.0, avail_h * 0.7)
	bw = max(bw, 200.0)
	var bw_cells: int = board.w if board else 8
	var bh_cells: int = board.h if board else 8
	cell = floor(bw / max(bw_cells, bh_cells))
	var bsize := Vector2(cell * bw_cells, cell * bh_cells)
	var tray_h: float = max(cell * 2.6, 170.0)
	var free := avail_h - bsize.y - tray_h
	var y0 := top_margin + maxf(0.0, free * 0.35)
	board_rect = Rect2(Vector2((size.x - bsize.x) * 0.5, y0), bsize)
	var ty := board_rect.end.y + maxf(24.0, free * 0.3)
	var sw := size.x / 3.0
	for i in 3:
		slots[i] = Rect2(Vector2(sw * i, ty), Vector2(sw, tray_h))
	queue_redraw()


func set_board(b: Board) -> void:
	board = b
	_effects.clear(); _particles.clear(); _texts.clear(); _pops.clear()
	_layout()


func set_tray(t: Array, animate := true) -> void:
	tray = t
	for i in 3:
		_tray_t[i] = -0.12 * i if animate else 1.0
	queue_redraw()


func show_hint(cells: Array) -> void:
	_hint_cells = cells


# ---------------------------------------------------------------- ввод

func _gui_input(e: InputEvent) -> void:
	if locked or board == null:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			var i := _slot_at(e.position)
			if i < 0 or tray[i] == null:
				return
			if swap_mode:
				tapped.emit(i)
				return
			_drag = i
			_finger = e.position
			_return = {}
			_hint_cells = []
			_update_drag()
			Sfx.play("pick")
			Sfx.vibro(15, 0.4)
			accept_event()
		elif _drag >= 0:
			var i := _drag
			_drag = -1
			if _ok:
				dropped.emit(i, _grid.x, _grid.y)
			else:
				_return = {"i": i, "from": _piece_tl(i), "t": 0.0}
				if board_rect.grow(cell).has_point(e.position):
					Sfx.play("bad")
			_preview = {"rows": [], "cols": []}
			queue_redraw()
	elif e is InputEventMouseMotion and _drag >= 0:
		_finger = e.position
		_update_drag()


func _slot_at(p: Vector2) -> int:
	for i in 3:
		if slots[i].grow(10).has_point(p):
			return i
	return -1


## Левый верхний угол перетаскиваемой фигуры (фигура над пальцем, чтобы её было видно).
func _piece_tl(i: int) -> Vector2:
	var sz := Shapes.size_of(tray[i].cells)
	var px := Vector2(sz) * cell
	return _finger - Vector2(px.x * 0.5, px.y) - Vector2(0, cell * 1.1)


func _update_drag() -> void:
	var cells: Array = tray[_drag].cells
	var tl := _piece_tl(_drag)
	var g := Vector2i(roundi((tl.x - board_rect.position.x) / cell), roundi((tl.y - board_rect.position.y) / cell))
	_ok = board.can_place(cells, g.x, g.y)
	if not _ok:
		# Небольшой «магнит»: соседняя позиция, если палец почти попал.
		var fx := (tl.x - board_rect.position.x) / cell - g.x
		var fy := (tl.y - board_rect.position.y) / cell - g.y
		for d in [Vector2i(signi(roundi(fx * 10)), 0), Vector2i(0, signi(roundi(fy * 10)))]:
			if d != Vector2i.ZERO and board.can_place(cells, g.x + d.x, g.y + d.y):
				g += d
				_ok = true
				break
	if g != _grid:
		_grid = g
		_preview = board.preview_lines(cells, g.x, g.y) if _ok else {"rows": [], "cols": []}
	queue_redraw()


# ---------------------------------------------------------------- анимации

## Показать результат хода (после board.place).
func play_place(r: Dictionary, col_i: int) -> void:
	var center := Vector2.ZERO
	for p in r.placed:
		_pops[p] = 0.0
		center += Vector2(p)
	center /= max(1, r.placed.size())
	var col: Color = UI.BLOCKS[col_i]
	for c in r.cleared:
		var d := Vector2(c.pos).distance_to(center)
		var cc: Color = UI.BLOCKS[c.color] if c.kind == Board.BLOCK else Color("#c98a4b")
		var idx: int = c.color if c.kind == Board.BLOCK else -1
		_effects.append({"type": "clear", "pos": c.pos, "col": cc, "idx": idx, "t": -d * 0.035, "dur": 0.32, "burst": false})
	for b in r.boxes:
		if b.left > 0:
			_effects.append({"type": "wobble", "pos": b.pos, "t": 0.0, "dur": 0.35})
		_burst(b.pos, Color("#d9a066"), 6, 1.0)
	for p in r.ice:
		_burst(p, Color("#bff3ff"), 7, 1.2)
	for y in r.rows:
		_effects.append({"type": "flash", "row": true, "k": y, "t": 0.0, "dur": 0.35, "col": col})
	for x in r.cols:
		_effects.append({"type": "flash", "row": false, "k": x, "t": 0.0, "dur": 0.35, "col": col})
	var cp := _cell_rect(Vector2i(roundi(center.x), roundi(center.y))).get_center()
	if r.lines > 0:
		Sfx.place()
		Sfx.clear(r.combo, r.lines)
		if r.lines >= 3 or r.combo >= 4:
			Sfx.vibro_pattern([[70, 1.0], [110, 1.0]])
		elif r.lines >= 2 or r.combo >= 2:
			Sfx.vibro_pattern([[55, 1.0], [45, 0.7]])
		else:
			Sfx.vibro(60, 1.0)
		_flash = 0.35 + 0.12 * min(r.lines, 4)
		_texts.append({"s": "+%d" % r.gained, "pos": cp, "t": 0.0, "dur": 1.0, "col": UI.TEXT, "size": 52})
		var word := ""
		if r.lines >= 4:
			word = "Невероятно!"
		elif r.lines == 3:
			word = "Отлично!"
		elif r.lines == 2:
			word = "Хорошо!"
		if r.combo >= 2:
			word = ("Комбо ×%d" % r.combo) if word == "" else word + "  Комбо ×%d" % r.combo
		if word != "":
			var mid := board_rect.get_center()
			_texts = _texts.filter(func(t): return not t.get("word", false))
			_texts.append({"s": word, "pos": mid, "t": -0.1, "dur": 1.2, "col": UI.GOLD, "size": 64 + 4 * min(r.combo, 6), "word": true})
		_shake = clampf(0.35 + 0.25 * (r.lines - 1) + 0.1 * r.combo, 0.35, 1.3)
		# Звёздочки-искры из центра
		for k in 6 + 4 * r.lines:
			var a := randf() * TAU
			_particles.append({"p": cp, "v": Vector2(cos(a), sin(a)) * randf_range(300.0, 800.0), "life": 0.0,
				"max": randf_range(0.5, 0.9), "col": UI.GOLD.lightened(randf() * 0.4), "s": cell * randf_range(0.1, 0.18),
				"rot": randf() * TAU, "w": randf_range(-10.0, 10.0), "star": true})
	else:
		Sfx.place()
		Sfx.vibro(35, 0.65)
		_shake = maxf(_shake, 0.12)
	queue_redraw()


func float_text(s: String, pos: Vector2, col := UI.GOLD, sz := 52) -> void:
	_texts.append({"s": s, "pos": pos, "t": 0.0, "dur": 1.3, "col": col, "size": sz})


func _burst(p: Vector2i, col: Color, n: int, power: float) -> void:
	var c := _cell_rect(p).get_center()
	for k in n:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(180.0, 520.0) * power
		_particles.append({"p": c, "v": v + Vector2(0, -150), "life": 0.0, "max": randf_range(0.4, 0.75),
			"col": col, "s": randf_range(0.12, 0.24) * cell, "rot": randf() * TAU, "w": randf_range(-8.0, 8.0)})


func busy() -> bool:
	return not _effects.is_empty()


func _process(delta: float) -> void:
	_time += delta
	var active := _drag >= 0 or swap_mode or not _hint_cells.is_empty()
	for i in 3:
		if _tray_t[i] < 1.0:
			_tray_t[i] = min(1.0, _tray_t[i] + delta * 4.0)
			active = true
	for k in _pops.keys():
		_pops[k] += delta
		if _pops[k] > 0.25:
			_pops.erase(k)
	if not _pops.is_empty():
		active = true
	var keep: Array = []
	for e in _effects:
		var before: float = e.t
		e.t += delta
		if e.type == "clear" and before < 0.0 and e.t >= 0.0 and not e.burst:
			e.burst = true
			_burst(e.pos, e.col, 5, 1.0)
		if e.t < e.dur:
			keep.append(e)
	_effects = keep
	var kp: Array = []
	for p in _particles:
		p.life += delta
		p.v.y += 1400.0 * delta
		p.p += p.v * delta
		p.rot += p.w * delta
		if p.life < p.max:
			kp.append(p)
	_particles = kp
	var kt: Array = []
	for t in _texts:
		t.t += delta
		if t.t < t.dur:
			kt.append(t)
	_texts = kt
	if not _return.is_empty():
		_return.t += delta * 5.0
		if _return.t >= 1.0:
			_return = {}
		active = true
	_shake = max(0.0, _shake - delta * 2.5)
	_flash = maxf(0.0, _flash - delta * 2.2)
	if active or not (_effects.is_empty() and _particles.is_empty() and _texts.is_empty()) or _shake > 0.0 or _flash > 0.0:
		queue_redraw()


# ---------------------------------------------------------------- рисование

func _cell_rect(p: Vector2i) -> Rect2:
	return Rect2(board_rect.position + Vector2(p) * cell, Vector2(cell, cell))


func _draw() -> void:
	if board == null:
		return
	var sh := Vector2.ZERO
	if _shake > 0.0:
		sh = Vector2(sin(_time * 70.0), cos(_time * 53.0)) * _shake * cell * 0.08
	draw_set_transform(sh)
	_draw_board()
	draw_set_transform(Vector2.ZERO)
	_draw_tray()
	_draw_particles()
	if _drag >= 0:
		var tl := _piece_tl(_drag)
		var p = tray[_drag]
		_draw_piece(p.cells, p.color, tl, cell * 0.96, 1.0, cell * 0.02)
	_draw_texts()
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _flash * 0.35))


func _draw_board() -> void:
	var pad := cell * 0.16
	# Участок: бордюр (тротуар) и газон. Каждая клетка (кроме ям) рисует фон с запасом —
	# вместе получается сплошной участок с вырезами под ямы.
	for y in board.h:
		for x in board.w:
			if board.kind[board.idx(x, y)] != Board.HOLE:
				var rr := _cell_rect(Vector2i(x, y)).grow(pad)
				UI.rrect(self, Rect2(rr.position + Vector2(0, cell * 0.08), rr.size), UI.CURB_DARK, pad * 1.4)
	for y in board.h:
		for x in board.w:
			if board.kind[board.idx(x, y)] != Board.HOLE:
				UI.rrect(self, _cell_rect(Vector2i(x, y)).grow(pad), UI.CURB, pad * 1.4)
	for y in board.h:
		for x in board.w:
			if board.kind[board.idx(x, y)] != Board.HOLE:
				UI.rrect(self, _cell_rect(Vector2i(x, y)).grow(cell * 0.03), UI.GRASS2.darkened(0.12), cell * 0.1)
	var hl_rows: Array = _preview.rows
	var hl_cols: Array = _preview.cols
	var drag_i: int = tray[_drag].color if _drag >= 0 else 0
	var drag_col: Color = UI.BLOCKS[drag_i] if _drag >= 0 else Color.WHITE
	for y in board.h:
		for x in board.w:
			var i := board.idx(x, y)
			var k := board.kind[i]
			var r := _cell_rect(Vector2i(x, y))
			var inner := r.grow(-cell * 0.04)
			if k == Board.HOLE:
				if x > 0 and y > 0 and x < board.w - 1 and y < board.h - 1:
					_draw_pit(r)
				continue
			UI.rrect(self, inner, UI.GRASS if (x + y) % 2 == 0 else UI.GRASS2, cell * 0.14)
			var lit := hl_rows.has(y) or hl_cols.has(x)
			match k:
				Board.BLOCK:
					var ci: int = drag_i if lit else board.color[i]
					var rr := inner
					var p := Vector2i(x, y)
					if _pops.has(p):
						var t: float = _pops[p] / 0.25
						rr = inner.grow(cell * 0.08 * sin(t * PI))
					UI.draw_tile(self, rr, ci)
				Board.STONE:
					_draw_stone(inner)
				Board.BOX:
					_draw_box(inner, board.floors[i], Vector2i(x, y))
			if board.ice[i] > 0:
				_draw_ice(inner, k == Board.EMPTY)
			if lit and k == Board.EMPTY:
				UI.rrect(self, inner, Color(1, 1, 1, 0.38), cell * 0.14)
	# Подсказка
	if not _hint_cells.is_empty():
		var a := 0.25 + 0.2 * sin(_time * 6.0)
		for p in _hint_cells:
			UI.rrect(self, _cell_rect(p).grow(-cell * 0.04), Color(1, 1, 1, a), cell * 0.14)
	# Тень-призрак фигуры
	if _drag >= 0 and _ok:
		var p = tray[_drag]
		for c in p.cells:
			var rr := _cell_rect(_grid + c).grow(-cell * 0.04)
			UI.draw_tile(self, rr, p.color, 0.45)
	# Эффекты линий и исчезающих клеток
	for e in _effects:
		if e.t < 0.0:
			continue
		var k: float = e.t / e.dur
		match e.type:
			"clear":
				var rr := _cell_rect(e.pos).grow(-cell * 0.04)
				var s: float = 1.0 - ease(k, 2.2)
				var rc := Rect2(rr.get_center() - rr.size * s * 0.5, rr.size * s)
				if e.get("idx", -1) >= 0:
					UI.draw_tile(self, rc, e.idx, 1.0 - k * 0.5)
				else:
					UI.draw_block(self, rc, e.col, 1.0 - k * 0.5)
			"flash":
				var a: float = (1.0 - k) * 0.55
				var rr: Rect2
				if e.row:
					rr = Rect2(board_rect.position + Vector2(0, e.k * cell), Vector2(board_rect.size.x, cell))
				else:
					rr = Rect2(board_rect.position + Vector2(e.k * cell, 0), Vector2(cell, board_rect.size.y))
				var g: float = cell * 0.3 * k
				UI.rrect(self, rr.grow(g), Color(1, 1, 1, a * 0.6), cell * 0.3)
			"wobble":
				pass


func _draw_pit(r: Rect2) -> void:
	var rr := r.grow(-cell * 0.02)
	UI.rrect(self, rr, UI.DIRT.darkened(0.15), cell * 0.18)
	UI.rrect(self, Rect2(rr.position + Vector2(0, cell * 0.14), rr.size - Vector2(0, cell * 0.14)), UI.DIRT, cell * 0.18)
	var d := UI.DIRT.darkened(0.25)
	draw_circle(rr.position + rr.size * Vector2(0.3, 0.6), cell * 0.06, d)
	draw_circle(rr.position + rr.size * Vector2(0.65, 0.75), cell * 0.05, d)


func _draw_stone(r: Rect2) -> void:
	var c := Color("#7d879c")
	UI.rrect(self, r, c.darkened(0.35), cell * 0.16)
	UI.rrect(self, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.9)), c, cell * 0.16)
	var d := Color("#5d667a")
	draw_circle(r.position + r.size * Vector2(0.3, 0.35), cell * 0.09, d)
	draw_circle(r.position + r.size * Vector2(0.68, 0.55), cell * 0.12, d)
	draw_circle(r.position + r.size * Vector2(0.4, 0.7), cell * 0.06, d)
	draw_circle(r.position + r.size * Vector2(0.25, 0.22), cell * 0.04, Color(1, 1, 1, 0.35))


func _draw_box(r: Rect2, fl: int, p: Vector2i) -> void:
	var off := 0.0
	for e in _effects:
		if e.type == "wobble" and e.pos == p:
			off = sin(e.t * 40.0) * cell * 0.06 * (1.0 - e.t / e.dur)
	r.position.x += off
	var wood := Color("#c98a4b")
	# Этажи — уступы сзади
	for k in range(fl - 1, 0, -1):
		var rr := Rect2(r.position + Vector2(0, -k * cell * 0.07), r.size)
		UI.rrect(self, rr, wood.darkened(0.25 + 0.1 * k), cell * 0.12)
	UI.rrect(self, r, wood.darkened(0.4), cell * 0.12)
	var top := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.9))
	UI.rrect(self, top, wood, cell * 0.12)
	var line := wood.darkened(0.3)
	var w := cell * 0.05
	draw_line(top.position + top.size * Vector2(0.12, 0.12), top.position + top.size * Vector2(0.88, 0.88), line, w)
	draw_line(top.position + top.size * Vector2(0.88, 0.12), top.position + top.size * Vector2(0.12, 0.88), line, w)
	draw_rect(top.grow(-cell * 0.06), line, false, w)
	if fl > 1:
		var c := top.get_center()
		draw_circle(c, cell * 0.2, Color(0, 0, 0, 0.55))
		var fs := int(cell * 0.3)
		draw_string(UI.font_bold, c + Vector2(-cell * 0.2, fs * 0.36), str(fl), HORIZONTAL_ALIGNMENT_CENTER, cell * 0.4, fs, UI.TEXT)


func _draw_ice(r: Rect2, empty: bool) -> void:
	var a := 0.55 if empty else 0.35
	UI.rrect(self, r, Color(0.72, 0.93, 1.0, a), cell * 0.14)
	var w := cell * 0.05
	var s := Color(1, 1, 1, 0.75)
	draw_line(r.position + r.size * Vector2(0.18, 0.5), r.position + r.size * Vector2(0.5, 0.18), s, w)
	draw_line(r.position + r.size * Vector2(0.32, 0.72), r.position + r.size * Vector2(0.72, 0.32), Color(1, 1, 1, 0.45), w)
	draw_rect(r.grow(-w * 0.5), Color(1, 1, 1, 0.5), false, w * 0.6)


func _tray_scale(i: int) -> float:
	var sz := Shapes.size_of(tray[i].cells)
	var by_w := (slots[i].size.x * 0.8) / (sz.x * cell)
	var by_h := (slots[i].size.y * 0.8) / (sz.y * cell)
	return min(0.62, by_w, by_h)


func _slot_tl(i: int, sc: float) -> Vector2:
	var sz := Vector2(Shapes.size_of(tray[i].cells)) * cell * sc
	return slots[i].get_center() - sz * 0.5


func _draw_tray() -> void:
	for i in 3:
		if tray[i] == null or i == _drag:
			continue
		var p = tray[i]
		var t: float = clamp(_tray_t[i], 0.0, 1.0)
		if t <= 0.0:
			continue
		var sc := _tray_scale(i) * ease(t, -2.4)
		var tl := _slot_tl(i, sc)
		var cs := cell * sc
		if not _return.is_empty() and _return.i == i:
			var k: float = ease(_return.t, -2.0)
			var from: Vector2 = _return.from
			tl = from.lerp(tl, k)
			cs = lerp(cell * 0.96, cs, k)
		var fits := board.fits_anywhere(p.cells)
		if swap_mode:
			var a := 0.35 + 0.25 * sin(_time * 6.0)
			UI.rrect(self, slots[i].grow(-14), Color(UI.GOLD, a * 0.35), 28)
			draw_style_box(UI.box(Color.TRANSPARENT, 28, 4, Color(UI.GOLD, a + 0.3)), slots[i].grow(-14))
		_draw_piece(p.cells, p.color, tl, cs, 1.0 if fits else 0.32, cs * 0.04)


func _draw_piece(cells: Array, col_i: int, tl: Vector2, cs: float, alpha: float, gap: float) -> void:
	for c in cells:
		var r := Rect2(tl + Vector2(c) * cs, Vector2(cs, cs)).grow(-gap)
		UI.draw_tile(self, r, col_i, alpha)


func _draw_particles() -> void:
	for p in _particles:
		var k: float = p.life / p.max
		var col: Color = p.col
		col.a = 1.0 - k
		var s: float = p.s * (1.0 - k * 0.5)
		draw_set_transform(p.p, p.rot)
		if p.get("star", false):
			var pts := PackedVector2Array()
			for j in 10:
				var rad: float = s * (0.75 if j % 2 == 0 else 0.32)
				var ang := j * TAU / 10.0 - PI / 2.0
				pts.append(Vector2(cos(ang), sin(ang)) * rad)
			draw_colored_polygon(pts, col)
		else:
			draw_rect(Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), col)
	draw_set_transform(Vector2.ZERO)


func _draw_texts() -> void:
	for t in _texts:
		if t.t < 0.0:
			continue
		var k: float = t.t / t.dur
		var a: float = 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
		var pop: float = min(1.0, t.t * 8.0)
		var fs := int(t.size * (0.6 + 0.4 * ease(pop, -2.0)))
		var pos: Vector2 = t.pos + Vector2(-size.x * 0.5, -k * cell * 1.2)
		var col: Color = t.col
		col.a = a
		draw_string_outline(UI.font_bold, pos, t.s, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, int(fs * 0.22), Color(0.05, 0.07, 0.18, a))
		draw_string(UI.font_bold, pos, t.s, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, col)
