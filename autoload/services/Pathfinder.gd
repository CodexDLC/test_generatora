# res://autoload/services/Pathfinder.gd
# Это наш "Следопыт" (Pathfinder), который умеет находить самый короткий путь
# на карте, работая как навигатор в машине. Он использует алгоритм A* (А-звезда).
# Путь ищется по клеткам (Vector2i). Диагонали разрешены, но без «срезания углов».

extends Node
class_name Pathfinder

# --- Настройки и волшебные числа ---
const SQRT2 := 1.41421356237
const INF   := 1.0e30
var allow_diagonals := true

# --- Внутренняя память Следопыта ---
var _size: Vector2i = Vector2i.ZERO
var _blocked: Dictionary = {}
var _cost: Dictionary = {}

# Правила для разных типов клеток
var _rules := {
	0: {"pass": true,  "cost": 1.0},  # 0: Обычная земля
	3: {"pass": true,  "cost": 0.6},  # 3: Дорога (идти по ней выгоднее!)
	7: {"pass": true,  "cost": 0.6},  # 7: Мост (тоже выгодно)
	8: {"pass": true,  "cost": 1.2},  # 8: Песок (идти чуть дороже)
	# --- Непроходимые клетки ---
	1: {"pass": false, "cost": 0.0}, 2: {"pass": false, "cost": 0.0},
	4: {"pass": false, "cost": 0.0}, 5: {"pass": false, "cost": 0.0},
	6: {"pass": false, "cost": 0.0}, 9: {"pass": false, "cost": 0.0},
	10:{"pass": false, "cost": 0.0},
}


# Строит карту для навигации
func build_nav_data(chunk_info: Dictionary, grid: Array) -> void:
	print("[Следопыт] Начинаю строить навигационную карту...")
	_size = Vector2i(int(chunk_info.get("w", 0)), int(chunk_info.get("h", 0)))
	_blocked.clear()
	_cost.clear()

	if _size.x <= 0 or _size.y <= 0:
		printerr("[Следопыт] ОШИБКА: Неправильный размер карты: ", _size); return
	if grid.is_empty() or grid.size() != _size.y:
		printerr("[Следопыт] ОШИБКА: Карта пустая или её высота не совпадает с размером!"); return

	print("[Следопыт] Размер карты для постройки: ", _size)

	for y in range(_size.y):
		var row = grid[y]
		if row.size() != _size.x:
			printerr("[Следопыт] ОШИБКА: Ряд %d имеет неправильную ширину!" % y); continue

		for x in range(_size.x):
			var tile_type = row[x]
			var rule: Dictionary = _rules.get(tile_type, {"pass": false, "cost": 0.0})
			var cell := Vector2i(x, y)
			
			if not rule.pass:
				_blocked[cell] = true
			else:
				_cost[cell] = float(rule.cost)

	print("[Следопыт] Карта построена! Заблокировано клеток: ", _blocked.size(), ", проходимых: ", _cost.size())


# Ищет путь из точки А в точку Б
func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	print("[Следопыт] Ищу путь из ", start, " в ", goal)

	if not _inside(start) or not _inside(goal):
		printerr("[Следопыт] ОШИБКА: Старт или цель находятся за пределами карты!"); return []
	if _is_blocked(start):
		printerr("[Следопыт] ОШИБКА: Стартовая точка заблокирована!"); return []
	if _is_blocked(goal):
		printerr("[Следопыт] ОШИБКА: Цель заблокирована!"); return []

	var open_set: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = { start: 0.0 }
	var f_score: Dictionary = { start: _heuristic(start, goal) }

	while not open_set.is_empty():
		open_set.sort_custom(func(a, b): return f_score.get(a, INF) < f_score.get(b, INF))
		
		# ИСПРАВЛЕНО (строка 94): Явно указываем тип для переменной 'current'
		var current: Vector2i = open_set.pop_front()

		if current == goal:
			print("[Следопыт] Путь найден!")
			return _reconstruct_path(came_from, current)

		for neighbor in _neighbors(current):
			# ИСПРАВЛЕНО (строка ~191): Явно указываем тип для 'step_cost'
			var step_cost: float = _cost.get(neighbor, 1.0)
			var move_cost := SQRT2 if (current.x != neighbor.x and current.y != neighbor.y) else 1.0
			
			# ИСПРАВЛЕНО (строка ~192): Явно указываем тип и приводим значение g_score к float
			var tentative_g_score: float = float(g_score.get(current, INF)) + step_cost * move_cost

			if tentative_g_score < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + _heuristic(neighbor, goal)
				if not open_set.has(neighbor):
					open_set.append(neighbor)

	print("[Следопыт] Не удалось найти путь.")
	return []


# ------------------- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ -------------------

func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < _size.x and c.y >= 0 and c.y < _size.y

func _is_blocked(c: Vector2i) -> bool:
	return _blocked.has(c)

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx: int = abs(a.x - b.x)
	var dy: int = abs(a.y - b.y)
	if allow_diagonals:
		return (dx + dy) + (SQRT2 - 2.0) * float(min(dx, dy))
	return float(dx + dy)

func _neighbors(c: Vector2i) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	var dirs := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
				 Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(-1, 1)] if allow_diagonals else \
			   [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]

	for d in dirs:
		# ИСПРАВЛЕНО (строка 208): Явно указываем тип для переменной 'n'
		var n: Vector2i = c + d
		
		if not _inside(n) or _is_blocked(n):
			continue
		
		if d.x != 0 and d.y != 0:
			if _is_blocked(Vector2i(c.x + d.x, c.y)) or _is_blocked(Vector2i(c.x, c.y + d.y)):
				continue
		
		res.append(n)
	return res

func _reconstruct_path(parent: Dictionary, cur: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [cur]
	while parent.has(cur):
		# ИСПРАВЛЕНО (строка 158): Указываем точный тип 'as Vector2i'
		cur = parent[cur] as Vector2i
		path.push_front(cur)
		
	print("[Следопыт] Путь собран. Длина: ", path.size(), " клеток. Старт: ", path.front(), ", Финиш: ", path.back())
	return path
