class_name UI
extends RefCounted
## Общие цвета и готовые элементы интерфейса.

# Светлая «дневная» тема: небо, газон, здания.
const SKY_TOP := Color("#3f9fea")
const SKY_BOT := Color("#bfe8ff")
const BG := SKY_TOP
const BG2 := Color("#ffffff")          # карточки и окна
const CARD := Color("#ffffff")
const PANEL := Color("#7c8db4")        # нейтральные кнопки
const INK := Color("#26334f")          # тёмный текст
const TEXT := Color("#ffffff")         # светлый текст (с обводкой)
const DIM := Color("#62708f")
const GOLD := Color("#ffb81c")
const SILVER := Color("#b9c6da")
const BRONZE := Color("#d98a52")
const ACCENT := Color("#3fc25a")
const BLUE := Color("#3d7cf5")
const RED := Color("#f2545b")
const GRASS := Color("#74c94f")
const GRASS2 := Color("#67bd43")
const CURB := Color("#efe8d8")
const CURB_DARK := Color("#cbbf9f")
const DIRT := Color("#9a7451")

# Цвета «зданий»: кирпич, деревянный дом, магазин, стеклянная башня, стекло, офис, кафе.
const BLOCKS := [
	Color("#e8553f"), Color("#f59a2c"), Color("#f9c832"), Color("#22b3a1"),
	Color("#45bdf0"), Color("#4e6ef0"), Color("#a65ae3"),
]
const BLOCK_NAMES := ["кирпич", "дом", "магазин", "башня", "стекло", "офис", "кафе"]

static var font_bold: Font = preload("res://fonts/Inter-ExtraBold.otf")
static var font: Font = preload("res://fonts/Inter-SemiBold.otf")
static var symbols: Font = preload("res://fonts/DejaVuSans-Bold.ttf")


## Символы (★ ● ‹ ×), которых нет в шрифте Inter, берутся из DejaVu.
static func setup_fonts() -> void:
	for f in [font_bold, font]:
		if f is FontFile and f.fallbacks.is_empty():
			f.fallbacks = [symbols]


static func medal_color(m: int) -> Color:
	match m:
		3: return GOLD
		2: return SILVER
		1: return BRONZE
	return Color(1, 1, 1, 0.12)


static func box(col: Color, radius := 24, border := 0, border_col := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	s.anti_aliasing_size = 1.0
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_col
	return s


## Объёмная кнопка: нижний «бортик» темнее основного цвета.
static func button(text: String, col: Color, font_size := 34, min_h := 96) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", font_size)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, TEXT)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	var n := box(col, 26)
	n.border_width_bottom = 8
	b.add_theme_color_override("font_outline_color", col.darkened(0.45))
	b.add_theme_constant_override("outline_size", 6)
	n.border_color = col.darkened(0.35)
	n.shadow_color = Color(0, 0, 0, 0.25)
	n.shadow_size = 6
	n.shadow_offset = Vector2(0, 4)
	var h := n.duplicate()
	h.bg_color = col.lightened(0.08)
	var p := n.duplicate()
	p.bg_color = col.darkened(0.08)
	p.border_width_bottom = 2
	p.content_margin_top = 6
	var d := n.duplicate()
	d.bg_color = col.darkened(0.45)
	d.border_color = col.darkened(0.6)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): Sfx.play("button"))
	return b


## Светлый текст автоматически получает тёмную обводку (чтобы читался на небе).
static func label(text: String, size := 32, col := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if col.get_luminance() > 0.6:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", max(6, size / 5))
	if bold:
		l.add_theme_font_override("font", font_bold)
	return l


static func panel(col := PANEL, radius := 32, pad := 28) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(col, radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", s)
	return p


## Рисует объёмный «желейный» блок.
static func draw_block(ci: CanvasItem, r: Rect2, col: Color, alpha := 1.0, dot_on := true) -> void:
	var rad := r.size.x * 0.18
	var dark := col.darkened(0.32)
	dark.a = alpha
	var main := col
	main.a = alpha
	_rrect(ci, r, dark, rad)
	var top := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.88))
	_rrect(ci, top, main, rad)
	var gl := col.lightened(0.45)
	if dot_on:
		gl.a = 0.55 * alpha
		var shine := Rect2(r.position + r.size * Vector2(0.14, 0.1), r.size * Vector2(0.72, 0.26))
		_rrect(ci, shine, gl, r.size.x * 0.1)
	else:
		gl.a = 0.7 * alpha
		_rrect(ci, Rect2(r.position + Vector2(r.size.x * 0.1, r.size.y * 0.05), Vector2(r.size.x * 0.8, r.size.y * 0.07)), gl, r.size.x * 0.035)
	if dot_on:
		var dot := Color(1, 1, 1, 0.65 * alpha)
		ci.draw_circle(r.position + r.size * Vector2(0.24, 0.2), r.size.x * 0.055, dot)


static var _sb_cache := {}


static func _rrect(ci: CanvasItem, r: Rect2, col: Color, rad: float) -> void:
	var key := "%s_%d" % [col.to_html(), int(rad)]
	var s: StyleBoxFlat = _sb_cache.get(key)
	if s == null:
		if _sb_cache.size() > 800:
			_sb_cache.clear()
		s = StyleBoxFlat.new()
		s.bg_color = col
		s.set_corner_radius_all(int(rad))
		s.anti_aliasing = true
		s.anti_aliasing_size = 0.8
		_sb_cache[key] = s
	ci.draw_style_box(s, r)


static func rrect(ci: CanvasItem, r: Rect2, col: Color, rad: float) -> void:
	_rrect(ci, r, col, rad)


## Блок-«здание»: объёмная плитка + рисунок материала (кирпич, окна, витрина…).
static func draw_tile(ci: CanvasItem, r: Rect2, idx: int, alpha := 1.0) -> void:
	var col: Color = BLOCKS[idx]
	draw_block(ci, r, col, alpha, false)
	var s := r.size.x
	var top := Rect2(r.position, Vector2(s, r.size.y * 0.88))
	var dk := col.darkened(0.28)
	dk.a = 0.75 * alpha
	var win := Color("#fff4c2")
	win.a = 0.95 * alpha
	var glass := Color("#e8f7ff")
	glass.a = 0.8 * alpha
	var w := maxf(1.5, s * 0.045)
	var p := top.position
	match idx:
		0: # кирпич
			for k in 3:
				var y := p.y + top.size.y * (0.3 + 0.22 * k)
				ci.draw_line(Vector2(p.x + s * 0.12, y), Vector2(p.x + s * 0.88, y), dk, w)
				var off := 0.33 if k % 2 == 0 else 0.55
				ci.draw_line(Vector2(p.x + s * off, y), Vector2(p.x + s * off, y + top.size.y * 0.22), dk, w)
		1: # деревянный дом с окном
			var wr := Rect2(p + top.size * Vector2(0.32, 0.36), top.size * Vector2(0.36, 0.36))
			_rrect(ci, wr, win, s * 0.05)
			ci.draw_line(Vector2(wr.get_center().x, wr.position.y), Vector2(wr.get_center().x, wr.end.y), dk, w)
			ci.draw_line(Vector2(wr.position.x, wr.get_center().y), Vector2(wr.end.x, wr.get_center().y), dk, w)
		2: # магазин с полосатым навесом
			var aw := Rect2(p + top.size * Vector2(0.1, 0.12), top.size * Vector2(0.8, 0.28))
			for k in 4:
				var c := Color(1, 1, 1, 0.85 * alpha) if k % 2 == 0 else Color("#e8553f", 0.9 * alpha)
				ci.draw_rect(Rect2(aw.position + Vector2(aw.size.x * k / 4.0, 0), Vector2(aw.size.x / 4.0, aw.size.y)), c)
			_rrect(ci, Rect2(p + top.size * Vector2(0.22, 0.5), top.size * Vector2(0.56, 0.32)), glass, s * 0.04)
		3: # стеклянная башня — сетка окон
			for yy in 3:
				for xx in 2:
					var wr := Rect2(p + top.size * Vector2(0.2 + xx * 0.34, 0.16 + yy * 0.25), top.size * Vector2(0.26, 0.17))
					_rrect(ci, wr, glass if (xx + yy) % 2 == 0 else win, s * 0.03)
		4: # стекло — блики
			var g2 := Color(1, 1, 1, 0.55 * alpha)
			ci.draw_line(p + top.size * Vector2(0.25, 0.85), p + top.size * Vector2(0.75, 0.35), g2, w * 2.2)
			ci.draw_line(p + top.size * Vector2(0.5, 0.88), p + top.size * Vector2(0.85, 0.53), g2, w * 1.2)
		5: # офис — окна 3×3, часть светится
			for yy in 3:
				for xx in 3:
					var on := (xx * 7 + yy * 3) % 4 != 0
					var wr := Rect2(p + top.size * Vector2(0.15 + xx * 0.25, 0.18 + yy * 0.24), top.size * Vector2(0.18, 0.15))
					ci.draw_rect(wr, win if on else dk)
		6: # кафе — арка-окно и дверь
			var arch := Rect2(p + top.size * Vector2(0.24, 0.28), top.size * Vector2(0.52, 0.5))
			_rrect(ci, arch, win, s * 0.2)
			ci.draw_line(Vector2(arch.get_center().x, arch.position.y + s * 0.05), Vector2(arch.get_center().x, arch.end.y), dk, w)
	var dot := Color(1, 1, 1, 0.7 * alpha)
	ci.draw_circle(r.position + r.size * Vector2(0.16, 0.13), s * 0.045, dot)


## Белое облако из кругов.
static func draw_cloud(ci: CanvasItem, c: Vector2, s: float, a := 0.9) -> void:
	var col := Color(1, 1, 1, a)
	var sh := Color(0.75, 0.86, 0.96, a)
	for e in [[-0.55, 0.12, 0.42], [0.0, 0.0, 0.58], [0.55, 0.1, 0.45], [0.22, -0.28, 0.42], [-0.25, -0.2, 0.36]]:
		ci.draw_circle(c + Vector2(e[0], e[1] + 0.08) * s, e[2] * s, sh)
	for e in [[-0.55, 0.12, 0.42], [0.0, 0.0, 0.58], [0.55, 0.1, 0.45], [0.22, -0.28, 0.42], [-0.25, -0.2, 0.36]]:
		ci.draw_circle(c + Vector2(e[0], e[1]) * s, e[2] * s, col)


## Силуэты домов. seed задаёт форму, count — сколько домов показать (для «растущего» города).
static func draw_skyline(ci: CanvasItem, base_y: float, width: float, col: Color, seed_v: int, unit: float, count := 999, windows := false, grow_k := 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var x := -unit * 0.5
	var i := 0
	while x < width + unit:
		var bw := unit * rng.randf_range(1.0, 2.2)
		var bh := unit * rng.randf_range(1.6, 5.5)
		var kind := rng.randi_range(0, 3)
		if i < count:
			if i == count - 1:
				bh *= grow_k
			var r := Rect2(Vector2(x, base_y - bh), Vector2(bw - unit * 0.12, bh))
			ci.draw_rect(r, col)
			match kind:
				1: # крыша-треугольник
					ci.draw_colored_polygon(PackedVector2Array([r.position, Vector2(r.get_center().x, r.position.y - unit * 0.7), Vector2(r.end.x, r.position.y)]), col)
				2: # антенна
					ci.draw_rect(Rect2(Vector2(r.get_center().x - unit * 0.06, r.position.y - unit * 0.9), Vector2(unit * 0.12, unit * 0.9)), col)
				3: # ступенька
					ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.2, -unit * 0.5), Vector2(r.size.x * 0.6, unit * 0.5)), col)
			if windows and grow_k > 0.6:
				var wr := RandomNumberGenerator.new()
				wr.seed = seed_v * 1000 + i
				var wc := col.lightened(0.35)
				var rows := int(bh / (unit * 0.55))
				var cols := int(r.size.x / (unit * 0.45))
				for yy in range(1, rows):
					for xx in cols:
						if wr.randf() < 0.55:
							ci.draw_rect(Rect2(r.position + Vector2(unit * 0.15 + xx * unit * 0.45, yy * unit * 0.55), Vector2(unit * 0.2, unit * 0.25)), wc)
		x += bw
		i += 1
