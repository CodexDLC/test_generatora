# autoload/services/MapLoader.gd
class_name MapLoader
extends Node

# --- ПАРСИНГ И ЗАГРУЗКА ---

# Функция для загрузки и парсинга JSON-файла карты.
# Возвращает словарь с данными или null в случае ошибки.
func load_map_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		printerr("Map file not found at path: ", path)

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("Failed to open map file: ", path)

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		printerr("Failed to parse map JSON: ", json.get_error_message(), " at line ", json.get_error_line())


	return json.get_data()


# --- ПОСТРОЕНИЕ КАРТЫ ---

# Главная функция-диспетчер. Она смотрит на формат данных и выбирает нужный метод.
func build_grid(map_data: Dictionary, gridmap_node: GridMap) -> void:
	if not "chunks" in map_data or map_data["chunks"].is_empty():
		printerr("Map data is missing 'chunks' or chunks are empty.")
		return
	
	gridmap_node.clear()
	
	# Пока что работаем только с первым чанком
	var chunk = map_data["chunks"][0]
	var encoding = chunk.get("encoding", "tiles_v0") # get() с default на случай, если ключа нет
	
	print("Building grid from chunk with encoding: ", encoding)
	
	if encoding == "rle_rows_v1":
		_build_from_rle_rows(chunk, gridmap_node)
	elif encoding == "tiles_v0":
		_build_from_flat_list(chunk, gridmap_node)
	else:
		printerr("Unknown chunk encoding type: ", encoding)

# --- ДЕКОДЕРЫ И СТРОИТЕЛИ ---

# Строитель для НОВОГО формата RLE
func _build_from_rle_rows(chunk: Dictionary, gridmap_node: GridMap) -> void:
	var rows = chunk.get("rows", [])
	var w = int(chunk.get("w", 0))
	var h = int(chunk.get("h", 0))

	if w == 0 or h == 0 or rows.is_empty():
		printerr("RLE chunk data is invalid (w, h, or rows are missing/empty).")
		return
		
	var grid_data = _decode_rle_rows(rows, w, h)
	
	# --- ВОТ ПРАВИЛЬНОЕ МЕСТО ДЛЯ НОВОЙ СТРОКИ ---
	# Передаем расшифрованные данные в Pathfinder, чтобы он подготовился к поиску пути.
	PathfinderService.build_nav_data(chunk, grid_data)
	# --- КОНЕЦ ИЗМЕНЕНИЯ ---
	
	for z in range(h):
		for x in range(w):
			var tile_id = grid_data[z][x]
			gridmap_node.set_cell_item(Vector3i(x, 0, z), tile_id)

# Строитель для СТАРОГО формата (плоский список)
func _build_from_flat_list(chunk: Dictionary, gridmap_node: GridMap) -> void:
	var tiles = chunk.get("tiles", [])
	if tiles.is_empty():
		printerr("Flat list 'tiles' data is missing or empty.")
		return
		
	for tile_object in tiles:
		var x = int(tile_object["x"])
		var z = int(tile_object["z"])
		var tile_id = int(tile_object["tile"])
		gridmap_node.set_cell_item(Vector3i(x, 0, z), tile_id)

# Декодер для RLE, как вы и предоставили.
# Я сделал его статическим, так как он не зависит от состояния объекта.
static func _decode_rle_rows(rows: Array, w: int, h: int) -> Array:
	var grid := []
	grid.resize(h)
	for z in range(h):
		var line := PackedInt32Array()
		var x := 0
		for pair in rows[z]:
			var tile: int = int(pair[0])
			var run: int  = int(pair[1])
			for i in range(run):
				line.append(tile)
			x += run # Оптимизация: вместо инкремента в цикле, просто прибавляем run
		
		if x != w:
			push_error("RLE row %d sum=%d != w=%d" % [z, x, w])
		
		grid[z] = line
		
	return grid
