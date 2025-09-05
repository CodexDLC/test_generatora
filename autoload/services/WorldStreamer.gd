extends Node3D

# --- Ссылки и настройки ---
@onready var terrain: Terrain3D = $Terrain3D
@onready var player: CharacterBody3D = $Player # Предполагаем, что игрок есть в сцене

# Путь к сгенерированным данным (папка с сидом)
const DATA_PATH = "res://data/world_location/25/"

# Настройки, синхронизированные с генератором
const CHUNK_SIZE = 128
const MAX_TERRAIN_HEIGHT = 45.0

# Словарь для отслеживания загруженных чанков
var loaded_chunks: Dictionary = {}
var current_player_chunk_pos: Vector2i = Vector2i(999, 999) # Несуществующая позиция

func _process(delta):
	# 1. Определяем, в каком чанке сейчас игрок
	var player_pos = player.global_position
	var player_chunk_pos = Vector2i(
		floor(player_pos.x / CHUNK_SIZE),
		floor(player_pos.z / CHUNK_SIZE)
	)

	# 2. Если игрок перешел в новый чанк, обновляем мир вокруг него
	if player_chunk_pos != current_player_chunk_pos:
		current_player_chunk_pos = player_chunk_pos
		update_world_around_player()

func update_world_around_player():
	print("Игрок в чанке: ", current_player_chunk_pos, ". Обновляем мир...")
	var load_radius = 1 # Будем грузить сетку 3x3 чанка вокруг игрока
	
	# Проходим по всем чанкам, которые должны быть загружены
	for z in range(current_player_chunk_pos.y - load_radius, current_player_chunk_pos.y + load_radius + 1):
		for x in range(current_player_chunk_pos.x - load_radius, current_player_chunk_pos.x + load_radius + 1):
			var chunk_pos = Vector2i(x, z)
			
			# Если чанк еще не загружен - загружаем
			if not loaded_chunks.has(chunk_pos):
				load_chunk(chunk_pos)
	
	# TODO: В будущем здесь будет логика выгрузки дальних чанков

func load_chunk(chunk_pos: Vector2i):
	var heightmap_path = "%s%d_%d/heightmap.r16" % [DATA_PATH, chunk_pos.x, chunk_pos.y]
	
	print("  Загрузка чанка ", chunk_pos, " из файла: ", heightmap_path)

	if not FileAccess.file_exists(heightmap_path):
		printerr("    ОШИБКА: Файл высот не найден!")
		# Помечаем, что мы пытались его загрузить, чтобы не пробовать снова
		loaded_chunks[chunk_pos] = null 
		return

	# Загружаем данные .r16
	var file = FileAccess.open(heightmap_path, FileAccess.READ)
	var raw_data = file.get_buffer(file.get_length())
	var image = Image.create_from_data(CHUNK_SIZE, CHUNK_SIZE, false, Image.FORMAT_RH, raw_data)

	# --- КЛЮЧЕВОЙ МОМЕНТ "СКЛЕЙКИ" ---
	# Мы говорим Terrain3D, в какое место в мире нужно "вставить" эту карту высот
	var world_origin = Vector3(
		chunk_pos.x * CHUNK_SIZE,
		0,
		chunk_pos.y * CHUNK_SIZE
	)

	# Импортируем карту высот со смещением
	terrain.data.import_images([image], world_origin, 0.0, MAX_TERRAIN_HEIGHT)
	
	# Помечаем чанк как загруженный
	loaded_chunks[chunk_pos] = true # В будущем здесь будет ссылка на ноду чанка
	print("    Чанк успешно загружен и встроен в мир!")
