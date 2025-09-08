extends Node
class_name ChunkSource  # проверь, что автолод ссылается именно на этот класс/файл

const WORLD_ROOT_USER := "user://data/world_location/"
const WORLD_ID        := 25

const CHUNK_SIZE: int = 128
const MAX_TERRAIN_HEIGHT: float = 150.0

static func world_data_path() -> String:
	return WORLD_ROOT_USER + str(WORLD_ID) + "/"

static func chunk_dir(cx: int, cz: int) -> String:
	return "%s%d_%d/" % [world_data_path(), cx, cz]

static func height_path(cx: int, cz: int) -> String:
	return chunk_dir(cx, cz) + "heightmap.r16"

# <<< ДОБАВЬ ЭТУ ФУНКЦИЮ ЗДЕСЬ >>>
static func control_path(cx: int, cz: int) -> String:
	return chunk_dir(cx, cz) + "control.r32"

func _ready() -> void:
	print("[ChunkSource] WORLD_DATA_PATH = ", world_data_path())
