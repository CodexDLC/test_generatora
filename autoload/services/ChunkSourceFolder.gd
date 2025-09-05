extends Node
@export var world_dir := "res://data/world_location/demo"

# Собираем список координат чанков из подпапок: и "0,0", и "0_0"
func list_coords() -> Array:
	var out: Array = []
	var d := DirAccess.open(world_dir)
	if d == null:
		push_error("Нет папки мира: %s" % world_dir); return out
	d.list_dir_begin()
	while true:
		var entry_name := d.get_next()
		if entry_name == "": break
		if not d.current_is_dir(): continue
		# принимаем и запятую, и подчёркивание
		var p := entry_name.replace("_", ",").split(",")
		if p.size() == 2 and p[0].is_valid_int() and p[1].is_valid_int():
			out.append(Vector2i(int(p[0]), int(p[1])))
	d.list_dir_end()
	out.sort_custom(func(a, b):
		if a.x == b.x: return a.y < b.y
		return a.x < b.x
	)
	print("[ChunkSource] found coords: ", out.size())
	return out

# Загружаем chunk.rle.json; пробуем путь с запятой и с подчёркиванием
func load_chunk(cx:int, cz:int) -> Dictionary:
	var path1 := "%s/%d,%d/chunk.rle.json" % [world_dir, cx, cz]
	var path2 := "%s/%d_%d/chunk.rle.json" % [world_dir, cx, cz]
	var path := path1
	if not FileAccess.file_exists(path1) and FileAccess.file_exists(path2):
		path = path2
	if not FileAccess.file_exists(path):
		push_warning("Нет файла чанка: %s И %s" % [path1, path2]); return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Не могу открыть файл: %s" % path); return {}
	var jp := JSON.new()
	var err := jp.parse(f.get_as_text())
	if err != OK:
		push_error("JSON-ошибка в %s: %s (строка %d, колонка %d)"
			% [path, jp.get_error_message(), jp.get_error_line(), jp.get_error_position()])
		return {}
	if typeof(jp.data) != TYPE_DICTIONARY:
		push_error("Неверный формат JSON: %s" % path); return {}
	var parsed: Dictionary = jp.data
	return parsed
