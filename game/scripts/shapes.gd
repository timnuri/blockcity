class_name Shapes
extends RefCounted
## Фигуры и раздача «трёх фигур».

const COLORS := 7

# Каждая фигура — список клеток. Вес: чем больше, тем чаще выпадает.
const LIST := [
	# [вес, клетки]
	[4, [[0, 0]]],
	[6, [[0, 0], [1, 0]]],
	[6, [[0, 0], [0, 1]]],
	[6, [[0, 0], [1, 0], [2, 0]]],
	[6, [[0, 0], [0, 1], [0, 2]]],
	[4, [[0, 0], [1, 0], [2, 0], [3, 0]]],
	[4, [[0, 0], [0, 1], [0, 2], [0, 3]]],
	[2, [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]]],
	[2, [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]]],
	[7, [[0, 0], [1, 0], [0, 1], [1, 1]]],
	[2, [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1], [0, 2], [1, 2], [2, 2]]],
	[3, [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1]]],
	[3, [[0, 0], [1, 0], [0, 1], [1, 1], [0, 2], [1, 2]]],
	# маленькие уголки
	[3, [[0, 0], [1, 0], [0, 1]]],
	[3, [[0, 0], [1, 0], [1, 1]]],
	[3, [[0, 0], [0, 1], [1, 1]]],
	[3, [[1, 0], [0, 1], [1, 1]]],
	# L из 4 клеток
	[2, [[0, 0], [0, 1], [0, 2], [1, 2]]],
	[2, [[1, 0], [1, 1], [1, 2], [0, 2]]],
	[2, [[0, 0], [1, 0], [0, 1], [0, 2]]],
	[2, [[0, 0], [1, 0], [1, 1], [1, 2]]],
	[2, [[0, 0], [1, 0], [2, 0], [0, 1]]],
	[2, [[0, 0], [1, 0], [2, 0], [2, 1]]],
	[2, [[0, 0], [0, 1], [1, 1], [2, 1]]],
	[2, [[2, 0], [0, 1], [1, 1], [2, 1]]],
	# T
	[2, [[0, 0], [1, 0], [2, 0], [1, 1]]],
	[2, [[1, 0], [0, 1], [1, 1], [2, 1]]],
	[2, [[0, 0], [0, 1], [0, 2], [1, 1]]],
	[2, [[1, 0], [1, 1], [1, 2], [0, 1]]],
	# S / Z
	[2, [[1, 0], [2, 0], [0, 1], [1, 1]]],
	[2, [[0, 0], [1, 0], [1, 1], [2, 1]]],
	[2, [[0, 0], [0, 1], [1, 1], [1, 2]]],
	[2, [[1, 0], [1, 1], [0, 1], [0, 2]]],
	# большие уголки 3×3
	[2, [[0, 0], [1, 0], [2, 0], [0, 1], [0, 2]]],
	[2, [[0, 0], [1, 0], [2, 0], [2, 1], [2, 2]]],
	[2, [[0, 0], [0, 1], [0, 2], [1, 2], [2, 2]]],
	[2, [[2, 0], [2, 1], [2, 2], [1, 2], [0, 2]]],
]

static var _cache: Array = []


static func all() -> Array:
	if _cache.is_empty():
		for e in LIST:
			var cells: Array[Vector2i] = []
			for c in e[1]:
				cells.append(Vector2i(c[0], c[1]))
			_cache.append({"w": e[0], "cells": cells})
	return _cache


static func size_of(shape: Array) -> Vector2i:
	var s := Vector2i.ZERO
	for c in shape:
		s.x = max(s.x, c.x + 1)
		s.y = max(s.y, c.y + 1)
	return s


## Случайная фигура. small > 0 — чаще мелкие (для первых уровней).
static func random_shape(rng: RandomNumberGenerator, small := 0.0) -> Array:
	var items := all()
	var total := 0.0
	var ws: Array[float] = []
	for it in items:
		var wv := float(it.w)
		var n: int = it.cells.size()
		if small > 0.0 and n >= 5:
			wv *= max(0.05, 1.0 - small)
		ws.append(wv)
		total += wv
	var r := rng.randf() * total
	for i in items.size():
		r -= ws[i]
		if r <= 0.0:
			return items[i].cells
	return items[0].cells


## Раздаёт 3 фигуры. mercy (0..1) — насколько стараться дать набор,
## который можно поставить целиком. В уровнях 1.0, в бесконечном режиме падает с очками.
static func deal(board: Board, rng: RandomNumberGenerator, small := 0.0, mercy := 1.0) -> Array:
	var insist := rng.randf() < mercy
	var best: Array = []
	var best_fit := -1
	for attempt in 40:
		var set: Array = []
		var fit := 0
		for k in 3:
			var s := random_shape(rng, small)
			set.append({"cells": s, "color": rng.randi_range(0, COLORS - 1)})
			if board.fits_anywhere(s):
				fit += 1
		if fit == 3 and insist and _playable(board, set):
			return set
		if fit > best_fit:
			best_fit = fit
			best = set
		if not insist and fit >= 1:
			return set
	return best


## Можно ли поставить все 3 фигуры подряд (в каком-нибудь порядке)?
static func _playable(board: Board, set: Array) -> bool:
	for order in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		var b := board.clone()
		var ok := true
		for k in order:
			var cells: Array = set[k].cells
			var pos := _first_fit(b, cells)
			if pos.x < 0:
				ok = false
				break
			b.place(cells, pos.x, pos.y, 0)
		if ok:
			return true
	return false


static func _first_fit(b: Board, cells: Array) -> Vector2i:
	var sz := size_of(cells)
	for oy in range(0, b.h - sz.y + 1):
		for ox in range(0, b.w - sz.x + 1):
			if b.can_place(cells, ox, oy):
				return Vector2i(ox, oy)
	return Vector2i(-1, -1)
