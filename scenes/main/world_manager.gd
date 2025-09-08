# res://world_manager.gd
extends Node

# Убрали @export, так как персонаж будет назначаться из кода
var player_node: CharacterBody3D

var start_chunk_pos: Vector2i
var is_player_spawned := false

# Эту функцию будет вызывать ваш код, который создаёт персонажа
func setup_player(new_player: CharacterBody3D) -> void:
	# Сохраняем ссылку на персонажа
	self.player_node = new_player

	if not is_instance_valid(player_node):
		printerr("[WorldManager] ОШИБКА: Передан неверный узел игрока!")
		return

	# 1. Немедленно "замораживаем" игрока
	player_node.set_physics_process(false)
	player_node.hide()

	# 2. Определяем стартовый чанк
	var chunk_size := float(ChunkSource.CHUNK_SIZE)
	start_chunk_pos = Vector2i(
		floor(player_node.global_position.x / chunk_size),
		floor(player_node.global_position.z / chunk_size)
	)
	
	print("[WorldManager] Игрок зарегистрирован. Ожидание готовности чанка: ", start_chunk_pos)

	# 3. Подключаемся к сигналу от ChunkStreamer
	ChunkStreamerService.chunk_physics_ready.connect(_on_chunk_ready)
	
	# Проверяем, может чанк уже готов
	if ChunkStreamerService.loaded_chunks.get(start_chunk_pos) == true:
		_on_chunk_ready(start_chunk_pos)


func _on_chunk_ready(chunk_pos: Vector2i) -> void:
	if is_player_spawned:
		return

	if chunk_pos == start_chunk_pos:
		print("[WorldManager] Стартовый чанк готов! Включаю игрока.")
		
		ChunkStreamerService.target_node = player_node
		
		player_node.set_physics_process(true)
		player_node.show()
		
		is_player_spawned = true
		
		ChunkStreamerService.chunk_physics_ready.disconnect(_on_chunk_ready)
