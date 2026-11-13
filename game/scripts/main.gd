extends Node
## Главный узел: фон, переключение экранов (меню, уровни, игра), кнопка «Назад».

const VERSION := "0.1"

var ui_root: Control
var screen: Control
var game: GameScreen
var where := "menu"
var deco: Control


func _ready() -> void:
	UI.setup_fonts()
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui_root)
	var bg := TextureRect.new()
	var g := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, UI.BG2)
	gr.set_color(1, UI.BG)
	g.gradient = gr
	g.fill_from = Vector2(0.5, 0.0)
	g.fill_to = Vector2(0.5, 1.0)
	g.width = 4
	g.height = 256
	bg.texture = g
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(bg)
	deco = Decor.new()
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(deco)
	show_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match where:
			"game": game.back()
			"levels": show_menu()
			_: get_tree().quit()


func _set_screen(c: Control, name: String) -> void:
	if screen:
		screen.queue_free()
	screen = c
	where = name
	if deco:
		deco.visible = name != "game"
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(c)
	c.modulate.a = 0.0
	create_tween().tween_property(c, "modulate:a", 1.0, 0.18)


# ---------------------------------------------------------------- меню

func show_menu() -> void:
	var root := Control.new()
	_set_screen(root, "menu")
	game = null

	# Верхняя полоса: монеты, замены, настройки.
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28; top.offset_right = -28; top.offset_top = 44
	top.add_theme_constant_override("separation", 14)
	root.add_child(top)
	top.add_child(_pill("●  %d" % Save.coins(), UI.GOLD))
	top.add_child(_pill("Замены  %d" % Save.boosters("swap"), UI.TEXT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var set_b := UI.button("⚙", UI.PANEL.lightened(0.1), 44, 80)
	set_b.custom_minimum_size.x = 80
	set_b.pressed.connect(_settings)
	top.add_child(set_b)

	var logo := Logo.new()
	logo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	logo.offset_top = 150
	logo.offset_bottom = 520
	root.add_child(logo)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	v.offset_left = 70; v.offset_right = -70
	v.offset_top = -640; v.offset_bottom = -110
	v.add_theme_constant_override("separation", 26)
	v.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(v)

	var has_save: bool = Save.data.get("endless") is Dictionary
	var play := UI.button("Продолжить" if has_save else "Играть", UI.ACCENT, 46, 130)
	play.pressed.connect(func(): start_endless(true))
	v.add_child(play)
	var sub := UI.label("Бесконечный режим · рекорд %d" % int(Save.data.best), 24, UI.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	if has_save:
		var nb := UI.button("Новая партия", UI.PANEL.lightened(0.12), 28, 76)
		nb.pressed.connect(func(): start_endless(false))
		v.add_child(nb)
	var camp := UI.button("Кампания", UI.BLUE, 42, 120)
	camp.pressed.connect(show_levels)
	v.add_child(camp)
	var done := 0
	for n in range(1, Levels.count() + 1):
		if Save.level_medal(n) > 0:
			done += 1
	var sub2 := UI.label("Пройдено уровней: %d из %d" % [done, Levels.count()], 24, UI.DIM)
	sub2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	var city := UI.button("Город", Color("#9b59d0"), 34, 100)
	city.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city.pressed.connect(func(): _info("Город", "Свой город из блоков появится в версии 0.3.\nМонеты, которые ты копишь сейчас, пригодятся там!"))
	row.add_child(city)
	var shop := UI.button("Магазин", UI.GOLD.darkened(0.15), 34, 100)
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.pressed.connect(_shop)
	row.add_child(shop)

	var ver := UI.label("версия %s" % VERSION, 20, Color(1, 1, 1, 0.3))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ver.offset_top = -60
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(ver)


func _pill(text: String, col: Color) -> PanelContainer:
	var p := UI.panel(Color(0, 0, 0, 0.3), 30, 18)
	p.add_child(UI.label(text, 28, col, true))
	return p


# ---------------------------------------------------------------- уровни

func show_levels() -> void:
	var root := Control.new()
	_set_screen(root, "levels")
	game = null
	var back_b := UI.button("‹", UI.PANEL.lightened(0.1), 52, 84)
	back_b.position = Vector2(24, 40)
	back_b.size = Vector2(84, 84)
	back_b.pressed.connect(show_menu)
	root.add_child(back_b)
	var t := UI.label("Глава 1", 48, UI.TEXT, true)
	t.set_anchors_preset(Control.PRESET_TOP_WIDE)
	t.offset_top = 46
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(t)
	var st := UI.label("Медали: золото — меньше всего ходов", 24, UI.DIM)
	st.set_anchors_preset(Control.PRESET_TOP_WIDE)
	st.offset_top = 112
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(st)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 170
	center.offset_bottom = -40
	root.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	center.add_child(grid)
	var open := Save.unlocked()
	var news := {1: "", 6: "ходы", 9: "камни", 12: "ямы", 15: "лёд", 18: "ящики", 19: "этажи"}
	for n in range(1, Levels.count() + 1):
		grid.add_child(_level_tile(n, n <= open, news.get(n, "")))


func _level_tile(n: int, open: bool, tag: String) -> Control:
	var medal := Save.level_medal(n)
	var col := UI.BLUE if open else UI.PANEL
	if medal > 0:
		col = UI.PANEL.lightened(0.12)
	var b := UI.button(str(n), col, 44, 136)
	b.custom_minimum_size = Vector2(136, 150)
	b.disabled = not open
	b.pressed.connect(func(): start_level(n))
	var dot := Control.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	dot.draw.connect(func():
		var c := Vector2(dot.size.x * 0.5, dot.size.y - 28)
		if medal > 0:
			dot.draw_circle(c, 13, UI.medal_color(medal).darkened(0.3))
			dot.draw_circle(c + Vector2(0, -2), 12, UI.medal_color(medal))
		if tag != "" and open:
			dot.draw_string(UI.font_bold, Vector2(0, 30), tag, HORIZONTAL_ALIGNMENT_CENTER, dot.size.x, 20, UI.GOLD))
	b.add_child(dot)
	return b


# ---------------------------------------------------------------- игра

func _new_game() -> GameScreen:
	var g := GameScreen.new()
	g.main = self
	_set_screen(g, "game")
	game = g
	g.go_menu.connect(show_menu)
	g.go_levels.connect(show_levels)
	g.play_level.connect(start_level)
	return g


func start_endless(resume: bool) -> void:
	_new_game().start_endless(resume)


func start_level(n: int) -> void:
	_new_game().start_level(n)


# ---------------------------------------------------------------- окна

func _popup(title: String, nodes: Array, buttons: Array) -> void:
	var ov := ColorRect.new()
	ov.color = Color(0.02, 0.03, 0.1, 0.72)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(ov)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)
	var p := UI.panel(UI.BG2, 40, 40)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	v.custom_minimum_size.x = 560
	p.add_child(v)
	var t := UI.label(title, 46, UI.TEXT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for n in nodes:
		v.add_child(n)
	for b in buttons:
		var btn := UI.button(b[0], b[1], 32, 90)
		var cb: Callable = b[2]
		btn.pressed.connect(func(): ov.queue_free(); cb.call())
		v.add_child(btn)


func _txt(s: String, col := UI.DIM) -> Label:
	var l := UI.label(s, 28, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 520
	return l


func _info(title: String, text: String) -> void:
	_popup(title, [_txt(text)], [["Хорошо", UI.ACCENT, func(): pass]])


func _settings() -> void:
	var snd := Save.setting("sound")
	var vib := Save.setting("vibro")
	_popup("Настройки", [], [
		["Звук: " + ("вкл" if snd else "выкл"), UI.ACCENT if snd else UI.PANEL.lightened(0.1), func(): Save.set_setting("sound", not snd); _settings()],
		["Вибрация: " + ("вкл" if vib else "выкл"), UI.ACCENT if vib else UI.PANEL.lightened(0.1), func(): Save.set_setting("vibro", not vib); _settings()],
		["Готово", UI.BLUE, func(): show_menu()],
	])


func _shop() -> void:
	var c := Save.coins()
	var items := [
		["1 замена — 40 ●", 1, 40],
		["5 замен — 180 ●", 5, 180],
	]
	var btns := []
	for it in items:
		var ok: bool = c >= it[2]
		var n: int = it[1]
		var price: int = it[2]
		btns.append([it[0], UI.GOLD.darkened(0.15) if ok else UI.PANEL.lightened(0.05), func():
			if Save.coins() >= price:
				Save.add_coins(-price); Save.add_booster("swap", n); Sfx.play("coin")
			_shop()])
	btns.append(["Закрыть", UI.BLUE, func(): show_menu()])
	_popup("Магазин", [_txt("У тебя %d монет и %d замен.\nМонеты дают за уровни (больше за золото) и за очки в бесконечном режиме." % [c, Save.boosters("swap")])], btns)


## Логотип: «город» из блоков и название.
class Logo extends Control:
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var cs := 46.0
		var heights := [2, 4, 3, 6, 5, 3, 4, 2]
		var cols := [4, 5, 1, 6, 0, 3, 2, 5]
		var w := cs * heights.size()
		var x0 := (size.x - w) * 0.5
		var base := 210.0
		for i in heights.size():
			var hh: int = heights[i]
			for k in hh:
				var bob := sin(_t * 2.0 + i * 0.7) * 3.0 if k == hh - 1 else 0.0
				var r := Rect2(Vector2(x0 + i * cs, base - (k + 1) * cs + bob), Vector2(cs, cs)).grow(-2)
				UI.draw_block(self, r, UI.BLOCKS[cols[i]].lerp(UI.BG2, 0.15 * (hh - k - 1) / hh))
		var f := UI.font_bold
		draw_string_outline(f, Vector2(0, base + 104), "БЛОК СИТИ", HORIZONTAL_ALIGNMENT_CENTER, size.x, 92, 18, Color(0.04, 0.05, 0.14))
		draw_string(f, Vector2(0, base + 104), "БЛОК СИТИ", HORIZONTAL_ALIGNMENT_CENTER, size.x, 92, UI.TEXT)
		draw_string(UI.font, Vector2(0, base + 150), "головоломка · кампания · город", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, UI.DIM)


## Медленно падающие полупрозрачные блоки на фоне.
class Decor extends Control:
	var items: Array = []

	func _ready() -> void:
		for i in 14:
			items.append(_new(true))

	func _new(any_y: bool) -> Dictionary:
		var sz := 720.0 if size.x < 10 else size.x
		var hh := 1280.0 if size.y < 10 else size.y
		return {"p": Vector2(randf() * sz, randf() * hh if any_y else -80.0), "s": randf_range(28, 70),
			"v": randf_range(18, 45), "c": randi() % UI.BLOCKS.size(), "r": randf() * TAU, "w": randf_range(-0.3, 0.3)}

	func _process(d: float) -> void:
		for i in items.size():
			var it = items[i]
			it.p.y += it.v * d
			it.r += it.w * d
			if it.p.y > size.y + 80:
				items[i] = _new(false)
		queue_redraw()

	func _draw() -> void:
		for it in items:
			draw_set_transform(it.p, it.r)
			var s: float = it.s
			UI.draw_block(self, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), UI.BLOCKS[it.c], 0.07)
		draw_set_transform(Vector2.ZERO)
