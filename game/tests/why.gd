extends SceneTree
func _init() -> void:
	var n := int(OS.get_cmdline_user_args()[0])
	var lv := Levels.get_level(n)
	var c := {}
	for s in 20:
		var r := Bot.play_level(lv, 1000 + s * 7919)
		if not r.win:
			c[r.why] = c.get(r.why, 0) + 1
			var pr := []
			for g in r.goals: pr.append("%s %d/%d" % [g.t, Levels.progress(g, r.b), g.n])
			print(r.why, " ", r.moves, " ", pr)
	print(c)
	quit()
