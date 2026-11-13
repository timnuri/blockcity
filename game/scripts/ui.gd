class_name UI
extends RefCounted
## Общие цвета и готовые элементы интерфейса.

const BG := Color("#0f1530")
const BG2 := Color("#1a2350")
const PANEL := Color("#18204a")
const CELL := Color("#222c5c")
const TEXT := Color("#f4f6ff")
const DIM := Color("#9aa5d6")
const GOLD := Color("#ffc93c")
const SILVER := Color("#cfd8e8")
const BRONZE := Color("#d9895b")
const ACCENT := Color("#4cd97b")
const BLUE := Color("#4f7dff")
const RED := Color("#ff5a6a")

const BLOCKS := [
	Color("#ff5a5f"), Color("#ffa62b"), Color("#ffd93d"), Color("#4cd97b"),
	Color("#3dc6f2"), Color("#5b7cfa"), Color("#b45cf0"),
]

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


static func label(text: String, size := 32, col := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
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
static func draw_block(ci: CanvasItem, r: Rect2, col: Color, alpha := 1.0) -> void:
	var rad := r.size.x * 0.18
	var dark := col.darkened(0.32)
	dark.a = alpha
	var main := col
	main.a = alpha
	_rrect(ci, r, dark, rad)
	var top := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.88))
	_rrect(ci, top, main, rad)
	var gl := col.lightened(0.45)
	gl.a = 0.55 * alpha
	var shine := Rect2(r.position + r.size * Vector2(0.14, 0.1), r.size * Vector2(0.72, 0.26))
	_rrect(ci, shine, gl, r.size.x * 0.1)
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
