class_name CityBack
extends Control
## Город на заднем плане. В бесконечном режиме растёт: каждые 1000 очков — новое здание.

const STEP := 1000
const START := 4

var built := START
var _grow := 1.0   # анимация последнего здания 0..1


func reset(n: int) -> void:
	built = n
	_grow = 1.0
	queue_redraw()


## Возвращает true, если появилось новое здание.
func set_score(score: int) -> bool:
	var n: int = min(START + score / STEP, 60)
	if n > built:
		built = n
		_grow = 0.0
		return true
	return false


func _process(delta: float) -> void:
	if _grow < 1.0:
		_grow = minf(1.0, _grow + delta * 1.5)
		queue_redraw()


func _draw() -> void:
	var ground := size.y - 110.0
	UI.draw_skyline(self, ground, size.x, Color("#a9d3f2"), 7, 30.0)
	# Ближний ряд: построенные здания + «растущее» новое.
	var unit := 44.0
	var near := Color("#6d9fd3")
	UI.draw_skyline(self, ground, size.x, near, 21, unit, built, true, ease(_grow, -2.0))
	draw_rect(Rect2(0, ground, size.x, size.y - ground), UI.GRASS2)
	draw_rect(Rect2(0, ground, size.x, 10), UI.GRASS.lightened(0.15))
	draw_rect(Rect2(0, ground + 40, size.x, 26), Color("#8d97a8"))
	for x in range(0, int(size.x), 60):
		draw_rect(Rect2(x + 10, ground + 51, 30, 4), Color(1, 1, 1, 0.8))
