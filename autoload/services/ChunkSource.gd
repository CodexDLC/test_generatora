# autoload/services/ChunkSource.gd
class_name ChunkSource
extends Node
## Контракт: вернуть список доступных чанков и загрузить конкретный чанк.

func list_coords() -> Array:        # [Vector2i(cx,cz), ...]
	return []

func load_chunk(cx: int, cz: int) -> Dictionary: # возвращает словарь чанка
	return {}
