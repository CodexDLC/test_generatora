# res://scenes/main/main.gd
extends Node3D

# Убедитесь, что пути к вашим сценам здесь правильные
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const MAP_SCENE: PackedScene = preload("res://scenes/map/MapRoot.tscn")
const UI_SCENE: PackedScene = preload("res://scenes/debug_ui/UI.tscn")

signal world_build_complete

@export var center_chunk_pos: Vector2i = Vector2i(0, 0)
@export var region_size_hint: int = 256
@export var vertex_spacing: float = 1.0
@export var spawn_clearance: float = 0.1
@export var fallback_y: float = 45.0

var _terrain: Terrain3D
var _player: Node3D
var _rs: int
var _vs: float
var _origin_world: Vector3
var _boot_cam: Camera3D

var _initial_render_queue: Array[MapLoader.ChunkData] = []
var _initial_data_loaded_count := 0
var _total_initial_chunks := 9

func _ready() -> void:
	pass

# Эту функцию вызывает экран загрузки.
func build_world_and_spawn_player() -> void:
	# --- ЭТАП 1: ПОДГОТОВКА СЦЕНЫ И УЗЛОВ ---
	var map: Node3D = MAP_SCENE.instantiate()
	add_child(map)
	await get_tree().process_frame
	
	_terrain = map.get_node_or_null("Terrain3D")
	if _terrain == null:
		push_error("КРИТИЧЕСКАЯ ОШИБКА: Узел Terrain3D не найден!"); return
		
	_player = PLAYER_SCENE.instantiate()
	
	_set_region_size(_terrain, region_size_hint)
	_terrain.vertex_spacing = vertex_spacing
	_rs = int(_terrain.region_size)
	_vs = _terrain.vertex_spacing
	ChunkRendererService.terrain = _terrain
	_origin_world = Vector3(float(center_chunk_pos.x * _rs) * _vs, 0.0, float(center_chunk_pos.y * _rs) * _vs)

	# --- ЭТАП 2: БУТСТРАП-КАМЕРА ДЛЯ ГЕНЕРАЦИИ КОЛЛИЗИИ ---
	var half := float(_rs) * _vs * 0.5
	var center_world := _origin_world + Vector3(half, 0.0, half)

	_boot_cam = Camera3D.new()
	add_child(_boot_cam)
	_boot_cam.current = true
	_boot_cam.global_position = center_world + Vector3(0, 200.0, 0)
	_boot_cam.look_at(center_world, Vector3.UP)

	_terrain.set_camera(_boot_cam)
	_terrain.collision.mode = Terrain3DCollision.DYNAMIC_GAME
	print("[Main] BootCam установлен, коллизия включена.")
	
	# --- ЭТАП 3: ЗАГРУЗКА И ПОСЛЕДОВАТЕЛЬНАЯ ОТРИСОВКА ---
	MapLoaderService.chunk_loaded.connect(_on_initial_chunk_loaded)
	
	var offsets := [Vector2i(0,0), Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1), Vector2i(-1,0), Vector2i(1,0), Vector2i(-1,1), Vector2i(0,1), Vector2i(1,1)]
	for offset in offsets:
		var cp: Vector2i = center_chunk_pos + offset
		MapLoaderService.load_chunk_in_thread(cp)
	
	while _initial_data_loaded_count < _total_initial_chunks:
		await get_tree().process_frame
	
	MapLoaderService.chunk_loaded.disconnect(_on_initial_chunk_loaded)
	
	for chunk_data in _initial_render_queue:
		await ChunkRendererService.render_chunk(chunk_data)
	
	print("[Main] Стартовая зона полностью отрисована.")
	await get_tree().physics_frame
	await get_tree().physics_frame

	# --- ЭТАП 4: ФИНАЛЬНЫЙ СПАВН И ЗАПУСК ---
	await _place_player_and_start()
	emit_signal("world_build_complete")

func _on_initial_chunk_loaded(chunk_data: MapLoader.ChunkData):
	if chunk_data:
		_initial_render_queue.append(chunk_data)
	_initial_data_loaded_count += 1

func _place_player_and_start() -> void:
	print("[Main] Ищу точку для спавна...")
	var half: float = float(_rs) * _vs * 0.5
	var center_world: Vector3 = _origin_world + Vector3(half, 0.0, half)
	
	var space_state = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(center_world + Vector3.UP * 5000, center_world + Vector3.DOWN * 5000)
	query.collision_mask = 0x000FFFFF
	query.hit_from_inside = true
	
	var result: Dictionary = space_state.intersect_ray(query)
	
	var ground_y := fallback_y
	if result:
		ground_y = result.position.y
		print("[Main] Высота земли найдена: ", ground_y)
	else:
		printerr("[Main] НЕ УДАЛОСЬ найти высоту земли!")
	
	# Используем данные из сцены demoplayer
	var capsule_height: float = 1.5
	var shape_offset_y: float = 1.25
	var half_h: float = capsule_height / 2.0
	var foot_offset: float = shape_offset_y - half_h
	var spawn_pos := Vector3(center_world.x, ground_y - foot_offset + spawn_clearance, center_world.z)
	
	add_child(_player)
	await get_tree().process_frame
	_player.global_position = spawn_pos
	
	var cam: Camera3D = _player.get_node_or_null("%Camera3D")
	if cam:
		cam.current = true
		_terrain.set_camera(cam)
		if is_instance_valid(_boot_cam):
			_boot_cam.queue_free()

	print("[Main] Игрок заспавнен в позиции: ", spawn_pos)
	
	var ui_instance = UI_SCENE.instantiate()
	add_child(ui_instance)
	ui_instance.player_node = _player
	
	var preloaded_chunks: Array[Vector2i]
	var offsets := [Vector2i(0,0), Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1), Vector2i(-1,0), Vector2i(1,0), Vector2i(-1,1), Vector2i(0,1), Vector2i(1,1)]
	for offset in offsets:
		preloaded_chunks.append(center_chunk_pos + offset)
	ChunkStreamerService.start_streaming(_player, center_chunk_pos, preloaded_chunks)

func _set_region_size(t: Terrain3D, desired: int) -> void:
	if t == null: return
	if desired == 128: t.change_region_size(Terrain3D.RegionSize.SIZE_128)
	elif desired == 256: t.change_region_size(Terrain3D.RegionSize.SIZE_256)
	elif desired == 512: t.change_region_size(Terrain3D.RegionSize.SIZE_512)
	else: t.change_region_size(Terrain3D.RegionSize.SIZE_256)
