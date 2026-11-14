extends SceneTree
## Создаёт файлы звуков: godot --headless --path game -s res://tests/make_sounds.gd
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://sounds"))
	var s := SoundGen.build_all()
	for n in s:
		s[n].save_to_wav(ProjectSettings.globalize_path("res://sounds/%s.wav" % n))
		print("saved ", n)
	quit()
