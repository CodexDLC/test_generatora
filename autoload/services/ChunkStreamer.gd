# res/autoload/services/ChunkStreamer.gd
extends Node
class_name ChunkStreamer

signal chunk_physics_ready(chunk_pos: Vector2i)

var target_node: Node3D
@export var load_radius: int = 2

var loaded_chunks: Dictionary = {}
var current_chunk_pos := Vector2i(999999, 999999)

func _ready() -> void:
	set_process(false) 
	MapLoaderService.chunk_loaded.connect(_on_chunk_loaded)

func start_streaming(player_node: Node3D, start_pos: Vector2i, preloaded_chunks: Array[Vector2i]):
	print("[Streamer] Получена команда на запуск. Цель:", player_node.name)
	target_node = player_node
	current_chunk_pos = start_pos
	
	for pos in preloaded_chunks:
		loaded_chunks[pos] = true
	
	set_process(true)
	print("[Streamer] Стриминг активирован.")

func _process(_dt: float) -> void:
	if not is_instance_valid(target_node):
		printerr("[Streamer] КРИТИЧЕСКАЯ ОШИБКА: Цель стала невалидной во время работы!")
		set_process(false)
		return

	var cs := float(ChunkSource.CHUNK_SIZE)
	if cs == 0.0: return

	var now := Vector2i(
		floor(target_node.global_position.x / cs),
		floor(target_node.global_position.z / cs)
	)

	if now == current_chunk_pos: return

	current_chunk_pos = now
	var required_chunks := {}
	for z in range(now.y - load_radius, now.y + load_radius + 1):
		for x in range(now.x - load_radius, now.x + load_radius + 1):
			required_chunks[Vector2i(x, z)] = true

	for pos: Vector2i in required_chunks.keys():
		if not loaded_chunks.has(pos):
			MapLoaderService.load_chunk_in_thread(pos)
			loaded_chunks[pos] = "loading"

func _on_chunk_loaded(chunk_data: MapLoader.ChunkData) -> void:
	if chunk_data == null:
		return

	var pos: Vector2i = chunk_data.chunk_pos
	
	var status = loaded_chunks.get(pos)
	if typeof(status) == TYPE_BOOL and status == true:
		return
		
	await ChunkRendererService.render_chunk(chunk_data)
	
	loaded_chunks[pos] = true
	emit_signal("chunk_physics_ready", pos)
