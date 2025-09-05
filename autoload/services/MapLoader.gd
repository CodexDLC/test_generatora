# Этот сервис отвечает за загрузку и декодирование данных чанков с диска.
extends Node

# Внутренний класс для удобной передачи данных между сервисами.
class ChunkData:
	var chunk_pos: Vector2i
	var heightmap_image: Image
	# var kind_grid: Array # <-- Раскомментируем, когда понадобится для GridMap
	# var height_grid: Array # <-- Раскомментируем, когда понадобится для GridMap

# Главная функция: загружает данные для одного чанка.
func load_chunk_data(chunk_pos: Vector2i) -> ChunkData:
	# Формируем путь к файлу карты высот, используя константы из ChunkSourceService
	var heightmap_path = "%s%d_%d/heightmap.r16" % [ChunkSourceService.WORLD_DATA_PATH, chunk_pos.x, chunk_pos.y]
	
	if not FileAccess.file_exists(heightmap_path):
		printerr("MapLoaderService: Файл высот не найден для чанка %s" % chunk_pos)
		return null

	# Читаем бинарные данные из файла .r16
	var file = FileAccess.open(heightmap_path, FileAccess.READ)
	var raw_data = file.get_buffer(file.get_length())
	
	# Создаем Image в 16-битном формате (это критически важный шаг)
	var image = Image.create_from_data(
		ChunkSourceService.CHUNK_SIZE,
		ChunkSourceService.CHUNK_SIZE,
		false,
		Image.FORMAT_RH,
		raw_data
	)

	# TODO: Здесь будет загрузка и парсинг chunk.rle.json
	
	# Собираем все данные в один объект
	var data_container = ChunkData.new()
	data_container.chunk_pos = chunk_pos
	data_container.heightmap_image = image
	
	print("MapLoaderService: Данные для чанка %s успешно загружены." % chunk_pos)
	return data_container
