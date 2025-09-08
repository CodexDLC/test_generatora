# res://autoload/services/MapLoader.gd
extends Node
class_name MapLoader

# Сигнал, который будет отправлен, когда чанк будет готов в фоновом потоке
signal chunk_loaded(chunk_data)

# Класс для хранения данных чанка
class ChunkData:
	var chunk_pos: Vector2i
	var height: Image
	var control: Image
	var color: Image

# --- ОСНОВНАЯ ФУНКЦИЯ, КОТОРУЮ ВЫЗЫВАЕТ СТРИМЕР ---
# Она просто запускает долгую операцию в отдельном потоке
func load_chunk_in_thread(chunk_pos: Vector2i) -> void:
	var thread := Thread.new()
	# Запускаем нашу "потоковую" функцию. Когда она завершится, поток будет уничтожен.
	thread.start(Callable(self, "_load_chunk_data_threaded").bind(chunk_pos))

# --- ЭТА ФУНКЦИЯ ВЫПОЛНЯЕТСЯ В ОТДЕЛЬНОМ ПОТОКЕ ---
# Она делает всю "грязную" работу: чтение файлов, создание Image
func _load_chunk_data_threaded(chunk_pos: Vector2i) -> void:
	var heightmap_path := ChunkSource.height_path(chunk_pos.x, chunk_pos.y)

	if not FileAccess.file_exists(heightmap_path):
		printerr("[MapLoader-Thread] Файл высот не найден: ", heightmap_path)
		# Отправляем сигнал с null, чтобы стример знал о неудаче
		call_deferred("emit_signal", "chunk_loaded", null)
		return

	var height: Image = _load_height_auto(heightmap_path)
	if height == null:
		printerr("[MapLoader-Thread] Не удалось загрузить файл высот: ", heightmap_path)
		call_deferred("emit_signal", "chunk_loaded", null)
		return

	var w: int = height.get_width()
	var h: int = height.get_height()

	var control: Image
	var control_path := ChunkSource.control_path(chunk_pos.x, chunk_pos.y)
	if FileAccess.file_exists(control_path):
		control = _load_control_r32(control_path, w)
	else:
		print("[MapLoader-Thread] Файл control.r32 не найден, создаю плоскую карту.")
		control = _make_flat_control_rf(w, h)

	var color: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	color.fill(Color(0.5, 0.5, 0.5))

	var cd := ChunkData.new()
	cd.chunk_pos = chunk_pos
	cd.height = height
	cd.control = control
	cd.color = color

	# Вместо return мы отправляем сигнал с готовыми данными в основной поток
	call_deferred("emit_signal", "chunk_loaded", cd)

# --- ВСПОМОГАТЕЛЬНЫЕ СТАТИЧЕСКИЕ ФУНКЦИИ ---
# (Они не изменились, но здесь они в правильном и полном виде)

static func _load_height_auto(path: String, flip_y := false) -> Image:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("[MapLoader] file open failed: ", path)
		return null
	var raw: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var n: int = raw.size()
	var ext: String = path.get_extension().to_lower()
	var bpp: int = 0
	if ext == "r16": bpp = 2
	elif ext == "r32" or ext == "rf" or ext == "f32": bpp = 4
	if bpp == 0:
		for candidate in [2, 4]:
			if n % candidate == 0:
				var test_count: int = n / candidate
				var side_test: int = int(round(sqrt(float(test_count))))
				if side_test * side_test * candidate == n:
					bpp = candidate
					break
	if bpp == 0: return null
	var pixel_count: int = n / bpp
	var side: int = int(round(sqrt(float(pixel_count))))
	if side * side * bpp != n: return null
	var img := Image.create(side, side, false, Image.FORMAT_RF)
	if bpp == 4:
		var sp := StreamPeerBuffer.new()
		sp.data_array = raw
		sp.big_endian = false
		for y in range(side):
			var yy := side - 1 - y if flip_y else y
			for x in range(side):
				var v: float = sp.get_float()
				img.set_pixel(x, yy, Color(v, 0, 0, 1))
	else:
		var i: int = 0
		for y in range(side):
			var yy := side - 1 - y if flip_y else y
			for x in range(side):
				var u16: int = raw[i] | (raw[i + 1] << 8)
				i += 2
				var v: float = float(u16) / 65535.0
				img.set_pixel(x, yy, Color(v, 0, 0, 1))
	return img
	
static func _make_flat_control_rf(w: int, h: int) -> Image:
	var px_val: float = 0.0
	if ClassDB.class_exists("Terrain3DUtil"):
		var bits := Terrain3DUtil.enc_base(0) | Terrain3DUtil.enc_nav(true)
		px_val = Terrain3DUtil.as_float(bits)
	var img := Image.create(w, h, false, Image.FORMAT_RF)
	var px := Color(px_val, 0, 0, 1)
	img.fill(px)
	return img

static func _load_control_r32(path: String, side: int) -> Image:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("[MapLoader] control open failed: ", path); return null
	var raw: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	if raw.size() != side * side * 4:
		printerr("[MapLoader] control size mismatch: bytes=", raw.size(), " need=", side * side * 4)
		return null
	var img := Image.create_from_data(side, side, false, Image.FORMAT_RF, raw)
	return img
