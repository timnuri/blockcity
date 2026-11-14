class_name LevelMap
extends Control
## Карта главы: дорога-змейка через район, на ней 20 участков-уровней.
## Пройденные — с медалью, текущий — пульсирует, закрытые — с замком.

signal picked(n: int)
signal locked_tap

const COLS := 4
const ROWS := 5
const R := 54.0

var _t := 0.0
var _pts: Array[Vector2] = []
var _area := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	_area = Rect2(Vector2(28, 170), Vector2(size.x - 56, size.y - 210))
	_pts.clear()
	var n := Levels.count()
	for i in n:
		var row := i / COLS
		var k := i % COLS
		var col := k if row % 2 == 0 else COLS - 1 - k
		var x := _area.position.x + _area.size.x * (0.14 + 0.24 * col)
		var y := _area.end.y - 90.0 - (_area.size.y - 180.0) * (float(row) / (ROWS - 1))
		_pts.append(Vector2(x, y))
	queue_redraw()


func _process(d: float) -> void:
	_t += d
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var open := Save.unlocked()
		for i in _pts.size():
			if _pts[i].distance_to(e.position) < R * 1.15:
				if i + 1 <= open:
					Sfx.play("button")
					picked.emit(i + 1)
				else:
					Sfx.play("bad")
					locked_tap.emit()
				accept_event()
				return


func _draw() -> void:
	if _pts.is_empty():
		return
	# Район: газон с бордюром.
	UI.rrect(self, _area.grow(14).grow_side(SIDE_BOTTOM, 6), UI.CURB_DARK, 46)
	UI.rrect(self, _area.grow(14), UI.CURB, 46)
	UI.rrect(self, _area, UI.GRASS, 36)
	# Деревья и домики между дорогами.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 26:
		var p := Vector2(rng.randf_range(_area.position.x + 30, _area.end.x - 30), rng.randf_range(_area.position.y + 30, _area.end.y - 30))
		if _near_road(p, 62.0):
			continue
		if rng.randf() < 0.6:
			_tree(p, rng.randf_range(16, 26))
		else:
			UI.draw_tile(self, Rect2(p - Vector2(22, 22), Vector2(44, 44)), rng.randi_range(0, 6))
	# Дорога.
	var road := PackedVector2Array(_pts)
	draw_polyline(road, Color("#6d7585"), 46.0, true)
	for p in _pts:
		draw_circle(p, 23.0, Color("#6d7585"))
	draw_polyline(road, Color("#848d9e"), 38.0, true)
	for p in _pts:
		draw_circle(p, 19.0, Color("#848d9e"))
	for i in _pts.size() - 1:
		var a := _pts[i]
		var b := _pts[i + 1]
		var L := a.distance_to(b)
		var dir := (b - a) / L
		var s := 30.0
		while s < L - 30.0:
			draw_line(a + dir * s, a + dir * minf(s + 16.0, L - 30.0), Color(1, 1, 1, 0.85), 5.0)
			s += 30.0
	# Участки-уровни.
	var open := Save.unlocked()
	var tags := {6: "ходы", 9: "камни", 12: "ямы", 15: "лёд", 18: "ящики", 19: "этажи", 20: "финал"}
	for i in _pts.size():
		var n := i + 1
		var p := _pts[i]
		var medal := Save.level_medal(n)
		if n > open:
			_node(p, Color("#c5ccd8"), Color("#9aa3b4"), "", 1.0)
			_lock(p)
		elif medal > 0:
			_node(p, UI.medal_color(medal), UI.medal_color(medal).darkened(0.3), str(n), 1.0)
		else:
			var pulse := 1.0 + 0.06 * sin(_t * 5.0)
			draw_circle(p, R * 1.35 * pulse, Color(1, 1, 1, 0.25 + 0.15 * sin(_t * 5.0)))
			_node(p, Color.WHITE, UI.BLUE, str(n), pulse)
			# Флажок «ты здесь»
			var fy := p.y - R - 30.0 + sin(_t * 4.0) * 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(p.x - 16, fy - 18), Vector2(p.x + 16, fy - 18), Vector2(p.x, fy + 6)]), UI.RED)
			draw_circle(Vector2(p.x, fy - 24), 16, UI.RED)
			draw_circle(Vector2(p.x, fy - 24), 7, Color.WHITE)
		if tags.has(n) and n <= open:
			var ty := p.y + R + 30.0
			draw_string_outline(UI.font_bold, Vector2(p.x - 80, ty), tags[n], HORIZONTAL_ALIGNMENT_CENTER, 160, 24, 7, UI.INK)
			draw_string(UI.font_bold, Vector2(p.x - 80, ty), tags[n], HORIZONTAL_ALIGNMENT_CENTER, 160, 24, UI.GOLD)


func _node(p: Vector2, fill: Color, ring: Color, text: String, sc: float) -> void:
	var r := R * sc
	draw_circle(p + Vector2(0, 7), r, ring.darkened(0.25))
	draw_circle(p, r, ring)
	draw_circle(p, r - 8, fill)
	draw_circle(p + Vector2(-r * 0.35, -r * 0.4), r * 0.16, Color(1, 1, 1, 0.6))
	if text != "":
		var fs := int(40 * sc)
		var dark := fill.get_luminance() > 0.75
		var col := UI.INK if dark else UI.TEXT
		if not dark:
			draw_string_outline(UI.font_bold, p + Vector2(-r, fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, 8, fill.darkened(0.45))
		draw_string(UI.font_bold, p + Vector2(-r, fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, col)


func _lock(p: Vector2) -> void:
	var c := Color("#6f7889")
	draw_arc(p + Vector2(0, -8), 13, PI, TAU, 16, c, 6.0, true)
	draw_line(p + Vector2(-13, -8), p + Vector2(-13, 2), c, 6.0)
	draw_line(p + Vector2(13, -8), p + Vector2(13, 2), c, 6.0)
	UI.rrect(self, Rect2(p + Vector2(-20, 0), Vector2(40, 30)), c, 6)
	draw_circle(p + Vector2(0, 13), 4.5, Color("#c5ccd8"))


func _tree(p: Vector2, s: float) -> void:
	draw_rect(Rect2(p + Vector2(-s * 0.12, 0), Vector2(s * 0.24, s * 0.7)), Color("#8a5a35"))
	draw_circle(p + Vector2(0, -s * 0.15), s * 0.75, Color("#3f9e3a"))
	draw_circle(p + Vector2(-s * 0.25, -s * 0.4), s * 0.3, Color("#5cbd4d"))


func _near_road(p: Vector2, d: float) -> bool:
	for i in _pts.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, _pts[i], _pts[i + 1])
		if q.distance_to(p) < d:
			return true
	return _pts[-1].distance_to(p) < d
