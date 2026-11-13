extends SceneTree
## Снимки экранов для проверки. Запуск:
## xvfb-run godot --rendering-driver opengl3 --path game -s res://tests/shots.gd --resolution 390x844 -- /tmp/shots

var out := "/tmp/shots"
var main: Node

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()

func _shot(name: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	print("shot ", name)

func _bot_moves(g, n: int) -> void:
	for k in n:
		if g.finished:
			return
		var mv := Bot.best_move(g.board, g.tray, g.goals)
		if mv.is_empty():
			return
		g._on_drop(mv.i, mv.x, mv.y)
		for i in 3:
			await process_frame

func _run() -> void:
	var S = root.get_node("Save")
	S.data = S._defaults()
	S.data.coins = 120
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _shot("1_menu")
	main.show_levels()
	await _shot("2_levels")
	main.start_endless(false)
	await _shot("3_endless_start")
	await _bot_moves(main.game, 14)
	await _shot("4_endless_play")
	# Перетаскивание: держим фигуру над полем.
	var g = main.game
	var v = g.view
	var mv := Bot.best_move(g.board, g.tray, [])
	if not mv.is_empty():
		v._drag = mv.i
		v._finger = v.board_rect.position + Vector2(mv.x + 1, mv.y + 2.5) * v.cell
		v._update_drag()
		await _shot("5_drag")
		v._drag = -1
	main.start_level(20)
	await _shot("6_level20_intro")
	main.game._close_popup()
	await _shot("7_level20")
	main.start_level(17)
	main.game._close_popup()
	await _bot_moves(main.game, 3)
	await _shot("8_level17_play")
	main.start_level(1)
	main.game._close_popup()
	main.game._maybe_hint()
	await _shot("9_level1_hint")
	await _bot_moves(main.game, 30)
	for i in 60:
		await process_frame
	await _shot("10_level1_win")
	quit()
