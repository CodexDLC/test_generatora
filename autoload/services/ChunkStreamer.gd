extends Node

var player: Node3D
var load_radius = 1 # Сетка 3x3 чанка
var loaded_chunks: Dictionary = {}
var current_player_chunk_pos := Vector2i.MAX

func _process(delta):
	if not is_instance_valid(player): return

	# Определяем, в каком чанке игрок
	var player_chunk_now = Vector2i(
		floor(player.global_position.x / ChunkSourceService.CHUNK_SIZE),
		floor(player.global_position.z / ChunkSourceService.CHUNK_SIZE)
	)
	
	if player_chunk_now != current_player_chunk_pos:
		current_player_chunk_pos = player_chunk_now
		_update_world()

func _update_world():
	var required_chunks := {}
	# Собираем список чанков, которые должны быть загружены
	for z in range(current_player_chunk_pos.y - load_radius, current_player_chunk_pos.y + load_radius + 1):
		for x in range(current_player_chunk_pos.x - load_radius, current_player_chunk_pos.x + load_radius + 1):
			required_chunks[Vector2i(x,z)] = true
	
	# Загружаем те, которых еще нет
	for pos in required_chunks:
		if not loaded_chunks.has(pos):
			# Используем правильные имена сервисов
			var chunk_data = MapLoaderService.load_chunk_data(pos)
			if chunk_data:
				ChunkRendererService.render_chunk(chunk_data)
				loaded_chunks[pos] = true # Помечаем как загруженный
	
	# TODO: Логика выгрузки чанков, которые больше не в `required_chunks`
