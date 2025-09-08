# res://autoload/services/ChunkRenderer.gd
extends Node
class_name ChunkRenderer

var terrain: Terrain3D
# Эта константа HMAX больше не будет использоваться, мы будем брать значение из ChunkSource
# const HMAX: float = 90.0

# --- ИЗМЕНЕНИЕ: Функция теперь асинхронная, чтобы ждать физику ---
func render_chunk(chunk_data: MapLoader.ChunkData) -> void:
	if terrain == null or chunk_data == null:
		printerr("[Renderer] terrain=null или chunk_data=null")
		return

	var rs: int = int(terrain.region_size)
	var vs: float = terrain.vertex_spacing

	if chunk_data.height == null or chunk_data.control == null:
		printerr("[Renderer] нет height/control"); return
	if chunk_data.height.get_width() != rs or chunk_data.control.get_width() != rs:
		printerr("[Renderer] размеры карт не совпадают с region_size"); return

	# Мировой сдвиг региона (в МЕТРАХ)
	var origin_x: float = chunk_data.chunk_pos.x * rs * vs
	var origin_z: float = chunk_data.chunk_pos.y * rs * vs
	var world_origin := Vector3(origin_x, 0.0, origin_z)

	# --- ИСПРАВЛЕНИЕ ЗДЕСЬ ---
	# Мы берем высоту из сервиса (Autoload), а не из класса
	var hmax = ChunkSourceService.MAX_TERRAIN_HEIGHT
	
	var images: Array[Image] = [chunk_data.height, chunk_data.control, null]

	# Импортируем геометрию и текстуры
	terrain.data.import_images(images, world_origin, 0.0, hmax)

	# Ждем один кадр физики, чтобы коллизия успела построиться
	await get_tree().physics_frame
	
	# Логи для отладки
	var half_size = rs * vs * 0.5
	var center_pos = world_origin + Vector3(half_size, 0, half_size)
	print("[Renderer] Чанк (%d, %d) отрисован. Центр в мире: %s" % [chunk_data.chunk_pos.x, chunk_data.chunk_pos.y, center_pos])
