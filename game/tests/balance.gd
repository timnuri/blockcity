extends SceneTree
## Бот проходит каждый уровень много раз: процент побед и сколько ходов нужно.
## Запуск: godot --headless --path game -s res://tests/balance.gd -- [попыток] [уровень]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var tries := int(args[0]) if args.size() > 0 else 40
	var only := int(args[1]) if args.size() > 1 else 0
	var medals := []
	for n in range(1, Levels.count() + 1):
		if only and n != only:
			continue
		var lv := Levels.get_level(n)
		var wins: Array[int] = []
		for s in tries:
			var r := Bot.play_level(lv, 1000 + s * 7919)
			if r.win:
				wins.append(r.moves)
		wins.sort()
		var rate := 100.0 * wins.size() / tries
		var p25 := wins[int(wins.size() * 0.25)] if wins.size() else -1
		var p60 := wins[int(wins.size() * 0.6)] if wins.size() else -1
		var mx := wins[-1] if wins.size() else -1
		medals.append([max(p25, 3), max(p60, p25 + 2)])
		print("Уровень %2d: побед %5.1f%%  ходы: 25%%=%d 60%%=%d макс=%d  медали=%s лимит=%d" % [n, rate, p25, p60, mx, str(lv.medals), lv.moves])
	print("MEDALS ", medals)
	quit()
