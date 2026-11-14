extends Node
## Главный узел: фон, переключение экранов (меню, уровни, игра), кнопка «Назад».

const VERSION := "0.2"

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
	gr.set_color(0, UI.SKY_TOP)
	gr.set_color(1, UI.SKY_BOT)
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
	deco = SkyBack.new()
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
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(c)
	c.modulate.a = 0.0
	create_tween().tween_property(c, "modulate:a", 1.0, 0.18)


# ---------------------------------------------------------------- меню

func show_menu() -> void:
	var root := Control.new()
	_set_screen(root, "menu")
	game = null
	var cb := CityBack.new()
	cb.set_anchors_preset(Control.PRESET_FULL_RECT)
	cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cb)
	cb.reset(14)

	# Верхняя полоса: монеты, замены, настройки.
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28; top.offset_right = -28; top.offset_top = 44
	top.add_theme_constant_override("separation", 14)
	root.add_child(top)
	top.add_child(_pill("Монеты  %d" % Save.coins(), UI.GOLD.darkened(0.25)))
	top.add_child(_pill("Замены  %d" % Save.boosters("swap"), UI.INK))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var set_b := UI.button("⚙", UI.PANEL.lightened(0.1), 44, 80)
	set_b.custom_minimum_size.x = 80
	set_b.pressed.connect(_settings)
	top.add_child(set_b)

	var logo := Logo.new()
	logo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	logo.offset_top = 230
	logo.offset_bottom = 600
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
	var sub := UI.label("Бесконечный режим · рекорд %d" % int(Save.data.best), 26, UI.TEXT, true)
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
	var sub2 := UI.label("Пройдено уровней: %d из %d" % [done, Levels.count()], 26, UI.TEXT, true)
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

	var ver := UI.label("версия %s" % VERSION, 22, UI.TEXT)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ver.offset_top = -60
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(ver)


func _pill(text: String, col: Color) -> PanelContainer:
	var p := UI.panel(Color(1, 1, 1, 0.92), 30, 18)
	p.add_child(UI.label(text, 28, col, true))
	return p


# ---------------------------------------------------------------- уровни

func show_levels() -> void:
	var root := Control.new()
	_set_screen(root, "levels")
	game = null
	var map := LevelMap.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.picked.connect(start_level)
	map.locked_tap.connect(func(): _info("Уровень закрыт", "Сначала пройди предыдущий уровень.\nЛюбая медаль открывает следующий — золото не обязательно."))
	root.add_child(map)
	var back_b := UI.button("‹", UI.PANEL, 52, 84)
	back_b.position = Vector2(24, 40)
	back_b.size = Vector2(84, 84)
	back_b.pressed.connect(show_menu)
	root.add_child(back_b)
	var t := UI.label("Глава 1 · Окраина", 44, UI.TEXT, true)
	t.set_anchors_preset(Control.PRESET_TOP_WIDE)
	t.offset_top = 46
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(t)
	var gold := 0
	for n in range(1, Levels.count() + 1):
		if Save.level_medal(n) == 3:
			gold += 1
	var st := UI.label("Золотых медалей: %d из %d" % [gold, Levels.count()], 26, UI.TEXT, true)
	st.set_anchors_preset(Control.PRESET_TOP_WIDE)
	st.offset_top = 106
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(st)


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
	ov.color = Color(0.08, 0.14, 0.3, 0.55)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(ov)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)
	var p := UI.panel(UI.CARD, 40, 40)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	v.custom_minimum_size.x = 560
	p.add_child(v)
	var t := UI.label(title, 46, UI.INK, true)
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
		var cs := 52.0
		var heights := [2, 3, 3, 4, 4, 3, 3, 2]
		var cols := [4, 5, 1, 6, 0, 3, 2, 5]
		var w := cs * heights.size()
		var x0 := (size.x - w) * 0.5
		var base := 210.0
		for i in heights.size():
			var hh: int = heights[i]
			for k in hh:
				var bob := sin(_t * 2.0 + i * 0.7) * 3.0 if k == hh - 1 else 0.0
				var r := Rect2(Vector2(x0 + i * cs, base - (k + 1) * cs + bob), Vector2(cs, cs)).grow(-2)
				UI.draw_tile(self, r, cols[i])
		var f := UI.font_bold
		draw_string_outline(f, Vector2(0, base + 104), "БЛОК СИТИ", HORIZONTAL_ALIGNMENT_CENTER, size.x, 92, 22, UI.INK)
		draw_string(f, Vector2(0, base + 104), "БЛОК СИТИ", HORIZONTAL_ALIGNMENT_CENTER, size.x, 92, UI.TEXT)
		draw_string_outline(UI.font_bold, Vector2(0, base + 150), "головоломка · кампания · город", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, 8, UI.INK)
		draw_string(UI.font_bold, Vector2(0, base + 150), "головоломка · кампания · город", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, UI.TEXT)


## Небо: солнце и плывущие облака.
class SkyBack extends Control:
	var clouds: Array = []
	var _t := 0.0

	func _ready() -> void:
		for i in 6:
			clouds.append({"p": Vector2(randf() * 760.0, randf_range(60.0, 700.0)), "s": randf_range(40.0, 90.0), "v": randf_range(8.0, 22.0)})

	func _process(d: float) -> void:
		_t += d
		for c in clouds:
			c.p.x += c.v * d
			if c.p.x > size.x + 150:
				c.p.x = -150
				c.p.y = randf_range(60.0, size.y * 0.55)
		queue_redraw()

	func _draw() -> void:
		var sun := Vector2(size.x - 110, 170)
		for k in 3:
			draw_circle(sun, 70 + k * 26 + sin(_t * 1.5) * 4, Color(1, 0.95, 0.6, 0.12))
		draw_circle(sun, 62, Color("#ffe27a"))
		for c in clouds:
			UI.draw_cloud(self, c.p, c.s, 0.85)
