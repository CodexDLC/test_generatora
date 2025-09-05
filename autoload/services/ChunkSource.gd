# Этот сервис хранит глобальные константы мира.
# Он должен быть первым в списке Autoload.
extends Node

# Путь к папке с данными ОДНОГО сгенерированного мира.
const WORLD_DATA_PATH = "res://data/world_location/25/" # <- Убедись, что сид верный

# Размер чанка в метрах/юнитах. Должен быть равен "size" в generator/presets/base_default.json
const CHUNK_SIZE = 128

# Максимальная высота ландшафта в метрах. Из "max_height_m" в том же JSON.
const MAX_TERRAIN_HEIGHT = 45.0
