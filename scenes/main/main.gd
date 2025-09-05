extends Node3D

# --- 1. Предзагружаем сцены, которые будем создавать ---
# Убедись, что пути к твоим сценам верные.
const PlayerScene = preload("res://scenes/player/player.tscn")
const MapRootScene = preload("res://scenes/map/MapRoot.tscn")

# --- 2. Переменные для хранения ссылок на созданные узлы ---
var player_node: CharacterBody3D
var terrain_node: Terrain3D
var grid_map_node: GridMap


func _ready():
	"""
	Эта функция вызывается один раз. Здесь мы собираем мир:
	- Создаем экземпляры сцен (инстанцируем).
	- Добавляем их в главное дерево.
	- "Знакомим" глобальные сервисы с нужными узлами.
	"""
	print("--- Main.gd: Старт сборки мира ---")

	# --- 3. Создаем и добавляем сцену с картой ---
	var map_instance = MapRootScene.instantiate()
	map_instance.name = "MapRoot" # Даем ей имя, чтобы можно было найти
	add_child(map_instance)
	
	# ТЕПЕРЬ, когда узел в сцене, мы можем безопасно получить ссылки на его части
	terrain_node = map_instance.get_node("Terrain3D")
	grid_map_node = map_instance.get_node("GridMap_Props") # Убедись, что GridMap так называется в MapRoot.tscn
	
	# --- 4. Создаем и добавляем сцену игрока ---
	player_node = PlayerScene.instantiate()
	player_node.name = "Player" # Даем имя
	add_child(player_node)
	
	# --- 5. ИНИЦИАЛИЗАЦИЯ СЕРВИСОВ (Ключевой момент "склейки") ---
	# Теперь, когда все узлы существуют, передаем ссылки в наши autoload-сервисы.
	# Используем имена сервисов из настроек Autoload (например, ChunkStreamerService).
	
	# Говорим Стримеру, за кем следить
	ChunkStreamerService.player = player_node
	
	# Говорим Рендереру, где строить мир
	ChunkRendererService.terrain = terrain_node
	ChunkRendererService.grid_map = grid_map_node
	
	print("--- Main.gd: Сборка завершена. Сервисы инициализированы. ---")
