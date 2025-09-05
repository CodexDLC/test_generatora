# Этот сервис отвечает за визуальное отображение данных чанка в сцене.
extends Node


# Ссылки на узлы сцены. Их установит main.gd при старте.
var terrain: Terrain3D
var grid_map: GridMap

# Функция для "постройки" одного чанка
func render_chunk(cx: int, cz: int, height_img: Image) -> void:
	# Height должен быть RH (R16F) или RF (R32F). Если не RH — конвертируем.
	if height_img.get_format() != Image.FORMAT_RH:
		height_img.convert(Image.FORMAT_RH)

	# Пока не используем splat и colormap — отдаём заглушки,
	# НО длина массива ОБЯЗАНА быть 3.
	var images: Array = [height_img, null, null]   # [height, control, color]

	var data := ChunkRendererService.terrain.get_data()
	data.import_images(images)  # если у тебя считается регион/индексы — оставь как было, важен именно массив из 3
	print("ChunkRendererService: Визуал для чанка %s построен." % chunk_data.chunk_pos)
