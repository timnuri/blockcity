class_name GameScreen
extends Control
## Экран партии: бесконечный режим или уровень кампании.
## Здесь правила игры: раздача фигур, ходы, победа/поражение, усилитель «Замена».

signal go_menu
signal go_levels
signal play_level(n: int)

const SWAP_PRICE := 40

var main: Node
var mode := "endless"   # или "level"
var level := {}
var goals: Array = []
var board := Board.new()
var tray: Array = [null, null, null]
var rng := RandomNumberGenerator.new()
var finished := false

var view: GameView
var city: CityBack
var _shown_score := 0.0
var _title: Label
var _score: Label
var _best: Label
var _goal_box: HBoxContainer
var _moves: Label
var _medals: HBoxContainer
var _swap_btn: Button
var _overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	rng.randomize()
	city = CityBack.new()
	city.set_anchors_preset(Control.PRESET_FULL_RECT)
	city.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(city)
	view = GameView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.top_margin = 262.0
	view.bottom_margin = 150.0
	add_child(view)
	view.dropped.connect(_on_drop)
	view.tapped.connect(_on_tap)
	_build_hud()
	_build_bottom()


# ---------------------------------------------------------------- запуск

func start_endless(resume := true) -> void:
	mode = "endless"
	finished = false
	var saved = Save.data.get("endless")
	if resume and saved is Dictionary:
		board.from_dict(saved.board)
		tray = []
		for t in saved.tray:
			if t == null:
				tray.append(null)
			else:
				var cells: Array[Vector2i] = []
				for c in t.cells:
					cells.append(Vector2i(int(c[0]), int(c[1])))
				tray.append({"cells": cells, "color": int(t.color)})
		view.set_board(board)
		view.set_tray(tray, true)
	else:
		board.setup(8, 8)
		view.set_board(board)
		_deal()
	_title.text = "Бесконечный"
	_shown_score = board.score
	_score.text = str(board.score)
	city.reset(CityBack.START + board.score / CityBack.STEP)
	_refresh()
	_check_stuck()


func start_level(n: int) -> void:
	mode = "level"
	finished = false
	level = Levels.get_level(n)
	board.load_layout(level.layout, rng)
	goals = Levels.resolve_goals(level, board)
	view.set_board(board)
	city.reset(5 + n)
	_title.text = "Уровень %d" % n
	_deal()
	_refresh()
	if level.intro != "" and not Save.intro_seen(n):
		Save.mark_intro(n)
		_popup("Уровень %d" % n, [_text(level.intro)], [["Понятно", UI.ACCENT, func(): _close_popup(); _maybe_hint()]])
	else:
		_maybe_hint()


func _maybe_hint() -> void:
	if mode == "level" and level.num == 1 and board.moves == 0:
		var mv := Bot.best_move(board, tray, goals)
		if not mv.is_empty():
			var cells: Array = []
			for c in tray[mv.i].cells:
				cells.append(Vector2i(mv.x, mv.y) + c)
			view.show_hint(cells)


func _deal() -> void:
	if mode == "level":
		tray = Shapes.deal(board, rng, level.small, 1.0)
	else:
		var mercy: float = clamp(1.0 - board.score / 25000.0, 0.4, 0.97)
		tray = Shapes.deal(board, rng, 0.15, mercy)
	view.set_tray(tray, true)


# ---------------------------------------------------------------- ходы

func _on_drop(i: int, gx: int, gy: int) -> void:
	if finished:
		return
	var p = tray[i]
	var r := board.place(p.cells, gx, gy, p.color)
	tray[i] = null
	view.play_place(r, p.color)
	if r.lines > 0:
		Save.data.stats.lines = int(Save.data.stats.lines) + r.lines
	if tray.all(func(t): return t == null):
		_deal()
	else:
		view.set_tray(tray, false)
	_refresh()
	if mode == "level":
		if Levels.done(goals, board):
			_finish(true)
			return
		if level.moves > 0 and board.moves >= level.moves:
			_finish(false, "Закончились ходы")
			return
	else:
		_save_endless()
	_check_stuck()


func _check_stuck() -> void:
	if finished:
		return
	for t in tray:
		if t != null and board.fits_anywhere(t.cells):
			return
	# Ни одна фигура не помещается.
	view.locked = true
	await get_tree().create_timer(0.7).timeout
	if Save.boosters("swap") > 0:
		_popup("Некуда ставить!", [_text("Можно заменить фигуру на случайную — вдруг повезёт.")], [
			["Заменить фигуру (%d)" % Save.boosters("swap"), UI.GOLD, func(): _close_popup(); view.locked = false; _start_swap()],
			["Сдаться", UI.RED, func(): _close_popup(); _finish(false, "Некуда ставить фигуры")],
		])
	else:
		_finish(false, "Некуда ставить фигуры")


func _start_swap() -> void:
	if Save.boosters("swap") <= 0:
		_offer_buy()
		return
	view.swap_mode = not view.swap_mode
	_refresh()


func _on_tap(i: int) -> void:
	if not view.swap_mode or tray[i] == null:
		return
	Save.add_booster("swap", -1)
	view.swap_mode = false
	var old: Array = tray[i].cells
	var s := Shapes.random_shape(rng, level.get("small", 0.15) if mode == "level" else 0.15)
	var tries := 0
	while s == old and tries < 10:
		s = Shapes.random_shape(rng)
		tries += 1
	tray[i] = {"cells": s, "color": rng.randi_range(0, Shapes.COLORS - 1)}
	view.set_tray(tray, false)
	view._tray_t[i] = 0.0
	Sfx.play("swap")
	_refresh()
	if mode == "endless":
		_save_endless()
	_check_stuck()


func _offer_buy() -> void:
	var can := Save.coins() >= SWAP_PRICE
	var body := [_text("Замен не осталось.\nКупить 1 замену за %d монет? У тебя %d." % [SWAP_PRICE, Save.coins()])]
	var btns := []
	if can:
		btns.append(["Купить", UI.GOLD, func():
			Save.add_coins(-SWAP_PRICE); Save.add_booster("swap", 1); Sfx.play("coin")
			_close_popup(); _refresh()])
	btns.append(["Закрыть", UI.BLUE, _close_popup])
	_popup("Замена фигуры", body, btns)


func _finish(win: bool, why := "") -> void:
	finished = true
	view.locked = true
	view.swap_mode = false
	await get_tree().create_timer(0.75).timeout
	if mode == "endless":
		var best := int(Save.data.best)
		var record := board.score > best
		if record:
			Save.data.best = board.score
		var coins := board.score / 250
		Save.data.coins = Save.coins() + coins
		Save.data.stats.games = int(Save.data.stats.games) + 1
		Save.data.endless = null
		Save.save()
		Sfx.play("win" if record else "lose")
		var body := [_big("%d" % board.score, 96, UI.INK)]
		body.append(_text("Новый рекорд!" if record else "Рекорд: %d" % max(best, board.score), UI.GOLD if record else UI.DIM))
		if coins > 0:
			body.append(_text("+%d монет" % coins, UI.GOLD))
		_popup("Игра окончена", body, [
			["Ещё раз", UI.ACCENT, func(): _close_popup(); view.locked = false; start_endless(false)],
			["Меню", UI.BLUE, func(): go_menu.emit()],
		])
		return
	var n: int = level.num
	if win:
		var medal := Levels.medal_for(level, board.moves)
		var reward := Save.record_level(n, medal, board.moves)
		Sfx.play("win")
		Sfx.vibro(60)
		var names := ["", "Бронза", "Серебро", "Золото"]
		var body := [_medal_node(medal), _big(names[medal], 44, UI.medal_color(medal))]
		var m: Array = level.medals
		body.append(_text("Ходов: %d   (золото ≤ %d, серебро ≤ %d)" % [board.moves, m[0], m[1]], UI.DIM, 26))
		if reward > 0:
			body.append(_text("+%d монет" % reward, UI.GOLD))
		if medal == 3 and reward > 0:
			body.append(_text("+1 замена фигуры за золото", UI.GOLD, 26))
		var btns := []
		if n < Levels.count():
			btns.append(["Дальше", UI.ACCENT, func(): play_level.emit(n + 1)])
		else:
			btns.append(["Глава пройдена!", UI.ACCENT, func(): go_levels.emit()])
		btns.append(["Ещё раз", UI.BLUE, func(): play_level.emit(n)])
		btns.append(["К уровням", UI.PANEL.lightened(0.15), func(): go_levels.emit()])
		_popup("Уровень пройден!", body, btns)
	else:
		Sfx.play("lose")
		_popup("Не получилось", [_text(why, UI.DIM)], [
			["Заново", UI.ACCENT, func(): play_level.emit(n)],
			["К уровням", UI.BLUE, func(): go_levels.emit()],
		])


func _save_endless() -> void:
	var t := []
	for p in tray:
		if p == null:
			t.append(null)
		else:
			var cells := []
			for c in p.cells:
				cells.append([c.x, c.y])
			t.append({"cells": cells, "color": p.color})
	Save.data.endless = {"board": board.to_dict(), "tray": t}
	if board.score > int(Save.data.best):
		Save.data.best = board.score
	Save.save()


func back() -> void:
	if _overlay:
		return
	if mode == "endless" or finished or board.moves == 0:
		if mode == "endless" and not finished:
			_save_endless()
		if mode == "endless":
			go_menu.emit()
		else:
			go_levels.emit()
		return
	_popup("Выйти из уровня?", [_text("Прогресс этого уровня пропадёт.", UI.DIM)], [
		["Остаться", UI.ACCENT, _close_popup],
		["Выйти", UI.RED, func(): go_levels.emit()],
	])


# ---------------------------------------------------------------- интерфейс

func _build_hud() -> void:
	var top := Control.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 230
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var back_b := UI.button("‹", UI.PANEL.lightened(0.1), 52, 84)
	back_b.position = Vector2(24, 40)
	back_b.size = Vector2(84, 84)
	back_b.pressed.connect(back)
	top.add_child(back_b)
	_title = UI.label("", 30, UI.TEXT, true)
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.offset_top = 40
	top.add_child(_title)
	_score = UI.label("0", 76, UI.TEXT, true)
	_score.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.offset_top = 76
	top.add_child(_score)
	_best = UI.label("", 26, UI.GOLD, true)
	_best.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_best.offset_left = -220
	_best.offset_right = -28
	_best.offset_top = 56
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_best)
	# Цели уровня
	_goal_box = HBoxContainer.new()
	_goal_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_goal_box.offset_top = 138
	_goal_box.offset_left = 24
	_goal_box.offset_right = -24
	_goal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_goal_box.add_theme_constant_override("separation", 14)
	_goal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_goal_box)
	_medals = HBoxContainer.new()
	_medals.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_medals.offset_top = 214
	_medals.alignment = BoxContainer.ALIGNMENT_CENTER
	_medals.add_theme_constant_override("separation", 22)
	_medals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_medals)


func _build_bottom() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -130
	bar.offset_bottom = -30
	bar.offset_left = 40
	bar.offset_right = -40
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bar)
	_swap_btn = UI.button("", UI.GOLD.darkened(0.15), 30, 96)
	_swap_btn.custom_minimum_size.x = 440
	_swap_btn.pressed.connect(_start_swap)
	bar.add_child(_swap_btn)


func _refresh() -> void:
	var lv := mode == "level"
	_score.visible = not lv
	_best.visible = not lv
	_goal_box.visible = lv
	_medals.visible = lv
	if lv:
		_title.text = "Уровень %d" % level.num
		for c in _goal_box.get_children():
			c.queue_free()
		for g in goals:
			var cur: int = min(Levels.progress(g, board), g.n)
			_goal_box.add_child(_chip("%s  %d/%d" % [Levels.goal_name(g.t), cur, g.n], cur >= g.n))
		var mv := "Ходы  %d" % board.moves
		if level.moves > 0:
			mv = "Осталось  %d" % (level.moves - board.moves)
		_goal_box.add_child(_chip(mv, false, level.moves > 0 and level.moves - board.moves <= 3))
		for c in _medals.get_children():
			c.queue_free()
		var m: Array = level.medals
		var cur_medal := Levels.medal_for(level, board.moves)
		for k in [3, 2]:
			var on: bool = cur_medal >= k
			var nm := "золото" if k == 3 else "серебро"
			var l := UI.label("● %s ≤ %d" % [nm, m[3 - k]], 24, UI.medal_color(k) if on else Color(1, 1, 1, 0.25), true)
			_medals.add_child(l)
	else:
		if board.score != int(_shown_score):
			var tw := create_tween()
			tw.tween_method(func(v: float): _shown_score = v; _score.text = str(int(v)), _shown_score, float(board.score), 0.35)
			_score.pivot_offset = _score.size * 0.5
			_score.scale = Vector2(1.18, 1.18)
			create_tween().tween_property(_score, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if city.set_score(board.score):
			view.float_text("Новое здание в городе!", Vector2(size.x * 0.5, view.board_rect.position.y - 20), UI.GOLD, 40)
			Sfx.play("build")
		_best.text = "Рекорд\n%d" % max(int(Save.data.best), board.score)
	var n := Save.boosters("swap")
	_swap_btn.text = ("Нажми на фигуру…  (отмена)" if view.swap_mode else "Заменить фигуру  ×%d" % n)


func _chip(text: String, done: bool, warn := false) -> PanelContainer:
	var p := UI.panel(UI.ACCENT if done else (UI.RED if warn else Color(1, 1, 1, 0.92)), 22, 14)
	p.add_child(UI.label(text, 28, UI.TEXT if (done or warn) else UI.INK, true))
	return p


func _text(s: String, col := UI.INK, size := 30) -> Label:
	var l := UI.label(s, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 520
	return l


func _big(s: String, size: int, col: Color) -> Label:
	var l := UI.label(s, size, col, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _medal_node(m: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(160, 160)
	c.draw.connect(func():
		var ctr := c.size * 0.5
		var col := UI.medal_color(m)
		c.draw_circle(ctr + Vector2(0, 6), 66, col.darkened(0.4))
		c.draw_circle(ctr, 66, col)
		c.draw_circle(ctr, 48, col.lightened(0.25))
		c.draw_circle(ctr + Vector2(-18, -20), 10, Color(1, 1, 1, 0.7))
		c.draw_string(UI.font_bold, ctr + Vector2(-80, 22), "★", HORIZONTAL_ALIGNMENT_CENTER, 160, 60, col.darkened(0.3)))
	return c


func _popup(title: String, body: Array, buttons: Array) -> void:
	_close_popup()
	var ov := ColorRect.new()
	ov.color = Color(0.08, 0.14, 0.3, 0.55)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ov)
	_overlay = ov
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)
	var p := UI.panel(UI.CARD, 40, 40)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	v.custom_minimum_size.x = 560
	p.add_child(v)
	v.add_child(_big(title, 48, UI.INK))
	for b in body:
		v.add_child(b)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	v.add_child(gap)
	for b in buttons:
		var btn := UI.button(b[0], b[1], 34, 92)
		btn.pressed.connect(b[2])
		v.add_child(btn)
	p.pivot_offset = Vector2(300, 250)
	p.scale = Vector2(0.85, 0.85)
	p.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.15)


func _close_popup() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
