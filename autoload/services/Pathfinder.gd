# autoload/services/Pathfinder.gd
class_name Pathfinder
extends Node

var _size := Vector2i.ZERO
var _blocked_cells := {}
var _cost_map := {}



func build_nav_data(chunk_data: Dictionary, grid_data: Array) -> void:
	_size = Vector2i(chunk_data["w"], chunk_data["h"])
	_blocked_cells.clear()
	_cost_map.clear()

	var passable_rules = {
		0: 1, # floor
		4: 1, # road
		5: 2, # grass
		6: 3, # forest
		7: 4  # mountain
	}

	for z in range(_size.y):
		for x in range(_size.x):
			var tile_id = grid_data[z][x]
			var cell = Vector2i(x, z)
			if not tile_id in passable_rules:
				_blocked_cells[cell] = true
			else:
				_cost_map[cell] = passable_rules[tile_id]

	print("Pathfinder: Навигационные данные построены. Размер: ", _size)

func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	print("Pathfinder: Запрошен реальный поиск пути от ", start, " до ", goal)

	if not _is_walkable(goal):
		print("Pathfinder: Целевая клетка непроходима.")
		return []

	var open_list: Dictionary = {}
	var closed_list: Dictionary = {}
	var came_from: Dictionary = {}

	var start_node_g = 0
	var start_node_h = _heuristic(start, goal)
	open_list[start] = {"g": start_node_g, "h": start_node_h, "f": start_node_g + start_node_h}

	while not open_list.is_empty():
		var current_cell: Vector2i = open_list.keys()[0]
		for cell: Vector2i in open_list.keys():
			if open_list[cell]["f"] < open_list[current_cell]["f"]:
				current_cell = cell

		var current_node: Dictionary = open_list[current_cell]
		open_list.erase(current_cell)
		closed_list[current_cell] = current_node

		if current_cell == goal:
			return _reconstruct_path(came_from, current_cell)

		for neighbor_cell in _get_neighbors(current_cell):
			if closed_list.has(neighbor_cell):
				continue

			# --- ИЗМЕНЕНИЕ ЗДЕСЬ ---
			var distance = 10 # Стоимость прямого шага
			if abs(neighbor_cell.x - current_cell.x) == 1 and abs(neighbor_cell.y - current_cell.y) == 1:
				distance = 14 # Стоимость диагонального шага (примерно 10 * sqrt(2))
			
			var tile_cost = _cost_map.get(neighbor_cell, 1)
			var move_cost = tile_cost * distance
			# --- КОНЕЦ ИЗМЕНЕНИЯ ---

			var tentative_g_score = current_node.g + move_cost

			if not open_list.has(neighbor_cell):
				var h_score = _heuristic(neighbor_cell, goal)
				open_list[neighbor_cell] = {"g": tentative_g_score, "h": h_score, "f": tentative_g_score + h_score}
				came_from[neighbor_cell] = current_cell
			elif tentative_g_score < open_list[neighbor_cell]["g"]:
				open_list[neighbor_cell]["g"] = tentative_g_score
				open_list[neighbor_cell]["f"] = tentative_g_score + open_list[neighbor_cell]["h"]
				came_from[neighbor_cell] = current_cell

	print("Pathfinder: Путь не найден.")
	return []

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path

func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

func _get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for z in range(-1, 2):
		for x in range(-1, 2):
			if x == 0 and z == 0:
				continue
			var neighbor = cell + Vector2i(x, z)
			if neighbor.x >= 0 and neighbor.x < _size.x and \
			   neighbor.y >= 0 and neighbor.y < _size.y and \
			   _is_walkable(neighbor):
				if abs(x) == 1 and abs(z) == 1:
					var adjacent1 = cell + Vector2i(x, 0)
					var adjacent2 = cell + Vector2i(0, z)
					if _is_walkable(adjacent1) and _is_walkable(adjacent2):
						neighbors.append(neighbor)
				else:
					neighbors.append(neighbor)
	return neighbors

func _is_walkable(cell: Vector2i) -> bool:
	return not _blocked_cells.has(cell)
