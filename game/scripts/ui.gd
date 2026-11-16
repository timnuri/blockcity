class_name UI
extends RefCounted
## Общие цвета и готовые элементы интерфейса.

# Тема «Солнечный городок» (макет design/mockups/Sunny.dc.html).
const SKY := Color("#CFEFFF")          # фон (просто голубой, без облаков — выбор Тима)
const SKY_TOP := SKY
const SKY_BOT := SKY
const BG := SKY
const BG2 := Color("#ffffff")          # карточки и окна
const CARD := Color("#ffffff")
const PANEL := Color("#ffffff")        # второстепенные кнопки — белые с тёмным текстом
const INK := Color("#1F3A2E")          # тёмно-зелёный текст
const TEXT := Color("#ffffff")         # светлый текст (на цветных плашках)
const DIM := Color("#2E5A44")
const GOLD := Color("#ffb81c")
const SILVER := Color("#b9c6da")
const BRONZE := Color("#d98a52")
const PRIMARY := Color("#E8604C")      # главная кнопка (красная)
const PRIMARY_DARK := Color("#B83A2B")
const ACCENT := Color("#4FA83F")       # «готово», включено
const BLUE := Color("#4A90D9")
const RED := Color("#E8604C")
const FIELD := Color("#5FAE4E")        # газон-подложка поля
const GRASS := Color("#76C064")        # пустая клетка
const GRASS2 := Color("#70BA5E")
const CURB := Color("#efe8d8")
const CURB_DARK := Color("#cbbf9f")
const DIRT := Color("#9a7451")
const LIGHT := Color("#FFF9D6")        # подсветка линии, которая соберётся

# Цвета блоков (тело / тёмная середина). 5 цветов — выбор Тима.
const BLOCKS := [
	Color("#E8604C"), Color("#F5C243"), Color("#4A90D9"), Color("#F28C38"), Color("#9B6BDF"),
]
const BLOCKS_DARK := [
	Color("#B83A2B"), Color("#C9862A"), Color("#2F5F9E"), Color("#B85A1A"), Color("#6A3FB0"),
]

static var font_bold: Font = preload("res://fonts/MPLUSRounded1c-ExtraBold-sub.ttf")
static var font: Font = preload("res://fonts/MPLUSRounded1c-Bold-sub.ttf")
static var symbols: Font = preload("res://fonts/DejaVuSans-Bold.ttf")


## Символы (★ ● ‹ ×), которых нет в основном шрифте, берутся из DejaVu.
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
	var light := col.get_luminance() > 0.7
	var fc := INK if light else TEXT
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.4))
	var n := box(col, 26)
	n.border_width_bottom = 8
	n.border_color = Color(0, 0, 0, 0.12) if light else col.darkened(0.25)
	n.shadow_color = Color(0, 0, 0, 0.0)
	var h := n.duplicate()
	h.bg_color = col.lightened(0.08)
	var p := n.duplicate()
	p.bg_color = col.darkened(0.08)
	p.border_width_bottom = 2
	p.content_margin_top = 6
	var d := n.duplicate()
	d.bg_color = col.darkened(0.15)
	d.border_color = col.darkened(0.3)
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


## Блок со скошенными краями (выбор Тима 16.11.2026, вариант «В»): сплошной, без пустой середины.
## Тёмная основа, светлая фаска сверху-слева, середина цвета блока.
static func draw_tile(ci: CanvasItem, r: Rect2, idx: int, alpha := 1.0) -> void:
	var k := posmod(idx, BLOCKS.size())
	var col: Color = BLOCKS[k]
	var dk: Color = BLOCKS_DARK[k]
	var lt: Color = col.lightened(0.38)
	col.a = alpha
	dk.a = alpha
	lt.a = alpha
	var s := r.size.x
	var b := s * 0.2   # ширина фаски
	var rad := s * 0.13
	_rrect(ci, r, dk, rad)
	var p := r.position
	var e := r.end
	var light := PackedVector2Array([
		p + Vector2(0, rad), p + Vector2(rad, 0), Vector2(e.x - rad * 0.6, p.y), Vector2(e.x - b, p.y + b),
		p + Vector2(b, b), Vector2(p.x + b, e.y - b), Vector2(p.x, e.y - rad * 0.6),
	])
	ci.draw_colored_polygon(light, lt)
	ci.draw_rect(Rect2(p + Vector2(b, b), r.size - Vector2(b, b) * 2.0), col)


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


## Цвет блока по номеру (номер может быть из старого сохранения, где цветов было 7).
static func block_color(i: int) -> Color:
	return BLOCKS[posmod(i, BLOCKS.size())]
