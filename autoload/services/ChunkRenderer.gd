extends Node3D

@export var grid_terrain: GridMap
@export var grid_props: GridMap
@export var terrain_lib: MeshLibrary
@export var props_lib: MeshLibrary
@export var cell_y_m: float = 0.5
@export var rand_seed: int = 0   # вместо seed

# Логические типы из генератора
const ID_TO_KIND := {
	0:"ground", 1:"obstacle", 2:"water", 3:"road", 4:"void",
	5:"slope", 6:"wall", 7:"bridge", 8:"sand", 9:"tree", 10:"rock",
}
const TERRAIN_KINDS := {"ground":true,"road":true,"water":true,"sand":true,"slope":true,"bridge":true,"wall":true,"void":true}
const PROPS_KINDS   := {"tree":true,"rock":true}

# Как искать слоты в MeshLibrary по префиксам (регистр не важен)
@export var terrain_prefixes := {
	"ground": ["ground","floor","grass","FOREST"], # FOREST временно считаем проходимой землёй
	"road":   ["road","ROAD"],
	"water":  ["water","water_deep","WATER_DEEP"],
	"sand":   ["sand"],
	"slope":  ["slope"],
	"wall":   ["wall","Wall","mountain","MOUNTAIN"],
	"void":   ["void","border","BORDER"],
	"bridge": ["bridge"],
}
@export var props_prefixes := {
	"tree": ["tree"],
	"rock": ["rock"],
}

# Корзины ID слотов по типам
var _terrain_buckets := {
	"ground":PackedInt32Array(), "road":PackedInt32Array(), "water":PackedInt32Array(),
	"sand":PackedInt32Array(), "slope":PackedInt32Array(), "bridge":PackedInt32Array(),
	"wall":PackedInt32Array(), "void":PackedInt32Array(),
}
var _props_buckets := { "tree":PackedInt32Array(), "rock":PackedInt32Array() }

# Куб с цветом (оставь как есть)
func _make_box_mesh(col: Color, size := Vector3.ONE) -> Mesh:
	var m := BoxMesh.new()
	m.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	m.material = mat
	return m



# ДОБАВЬ: создаём минимальную MeshLibrary для террейна
# ===== terrain fallback =====
func _ensure_minimal_terrain_lib(force := false) -> void:
	if terrain_lib != null and not force:
		return
	var lib := MeshLibrary.new()
	var id := 0

	lib.create_item(id); lib.set_item_name(id, "ground_flat"); lib.set_item_mesh(id, _make_box_mesh(Color8(122,158,122))); id += 1
	lib.create_item(id); lib.set_item_name(id, "road");        lib.set_item_mesh(id, _make_box_mesh(Color8(210,180,140))); id += 1
	lib.create_item(id); lib.set_item_name(id, "water_deep");  lib.set_item_mesh(id, _make_box_mesh(Color8( 53,115,184))); id += 1
	lib.create_item(id); lib.set_item_name(id, "sand");        lib.set_item_mesh(id, _make_box_mesh(Color8(224,205,168))); id += 1
	lib.create_item(id); lib.set_item_name(id, "wall");        lib.set_item_mesh(id, _make_box_mesh(Color8( 90, 90, 90))); id += 1
	lib.create_item(id); lib.set_item_name(id, "void");        lib.set_item_mesh(id, _make_box_mesh(Color8(  0,  0,  0, 0))); id += 1
	lib.create_item(id); lib.set_item_name(id, "slope"); lib.set_item_mesh(id, _make_box_mesh(Color8(128, 128, 128))); id += 1
	lib.create_item(id); lib.set_item_name(id, "bridge"); lib.set_item_mesh(id, _make_box_mesh(Color8(139, 69, 19))); id += 1

	terrain_lib = lib
	if grid_terrain:
		grid_terrain.mesh_library = terrain_lib
	print("[Renderer] Bootstrapped minimal terrain MeshLibrary OK")


# ДОБАВЬ: минимальная библиотека пропсов (дерево/камень — тоже кубы)
# ===== props fallback =====
# 2) Минимальная библиотека ПРОПСОВ — БЕЗ лямбд
func _ensure_minimal_props_lib(force := false) -> void:
	if props_lib != null and not force:
		return
	var lib := MeshLibrary.new()
	var id := 0

	lib.create_item(id); lib.set_item_name(id, "tree"); lib.set_item_mesh(id, _make_box_mesh(Color8( 34,139, 34))); id += 1
	lib.create_item(id); lib.set_item_name(id, "rock"); lib.set_item_mesh(id, _make_box_mesh(Color8(128,128,128))); id += 1

	props_lib = lib
	if grid_props:
		grid_props.mesh_library = props_lib
	print("[Renderer] Bootstrapped minimal props MeshLibrary OK")


func _ready() -> void:
	if grid_terrain and grid_terrain.mesh_library:
		terrain_lib = grid_terrain.mesh_library
	if grid_props and grid_props.mesh_library:
		props_lib = grid_props.mesh_library

	# <<< Новое: берём шаг по Y из размера клетки GridMap, чтобы высоты совпадали
	if grid_terrain:
		cell_y_m = grid_terrain.cell_size.y

	# если библиотек нет — создадим кубики
	if terrain_lib == null:
		_ensure_minimal_terrain_lib()
	if props_lib == null:
		_ensure_minimal_props_lib()

	_index_libs()
	#if _terrain_buckets["ground"].is_empty():
		#push_warning("[Renderer] Не нашли ground/floor/grass — включаю минимальную библиотеку.")
		#_ensure_minimal_terrain_lib(true)
		#_index_libs()

func _index_libs() -> void:
	# чистим корзины
	for k in _terrain_buckets.keys(): _terrain_buckets[k].clear()
	for k in _props_buckets.keys():   _props_buckets[k].clear()

	# индексируем террейн
	if terrain_lib:
		for id in terrain_lib.get_item_list():
			var n := terrain_lib.get_item_name(id).to_lower()
			var placed := false
			for kind in terrain_prefixes.keys():
				for pref in terrain_prefixes[kind]:
					if n.begins_with(pref.to_lower()):
						_terrain_buckets[kind].append(id)
						placed = true
						break
				if placed: break

	# индексируем пропсы
	if props_lib:
		for id in props_lib.get_item_list():
			var n := props_lib.get_item_name(id).to_lower()
			var placed := false
			for kind in props_prefixes.keys():
				for pref in props_prefixes[kind]:
					if n.begins_with(pref.to_lower()):
						_props_buckets[kind].append(id)
						placed = true
						break
				if placed: break

	# логи
	for k in _terrain_buckets.keys():
		print("[Renderer] terrain '", k, "' -> ", _terrain_buckets[k].size())
	for k in _props_buckets.keys():
		print("[Renderer]  props   '", k, "' -> ", _props_buckets[k].size())

	if _terrain_buckets["ground"].is_empty():
		push_warning("[Renderer] Нет слотов ground/floor/grass в MeshLibrary террейна — земля не отрисуется.")

# Декодер RLE-строк (encoding = rle_rows_v1)
static func _decode_rle_rows(rows:Array) -> Dictionary:
	var h := rows.size()
	if h == 0:
		return {"w":0,"h":0,"grid":[]}
	var w := 0
	for pair in rows[0]:
		w += int(pair[1])
	var grid := []
	grid.resize(h)
	for z in h:
		var line := []
		var sum := 0
		for pair in rows[z]:
			var value = pair[0]
			var run := int(pair[1])
			for i in run:
				line.append(value)
			sum += run
		if sum != w:
			push_error("RLE: строка %d имеет %d, ожидали %d" % [z, sum, w])
		grid[z] = line
	return {"w":w,"h":h,"grid":grid}

# Выбор ID слота из корзины (стабильный рандом по координатам)
func _pick(bucket: PackedInt32Array, kind: String, cx: int, cz: int, x: int, z: int) -> int:
	if bucket.is_empty():
		return -1
	var h: int = int(hash("%s|%d,%d|%d,%d|%d" % [kind, cx, cz, x, z, rand_seed]))
	return bucket[abs(h) % bucket.size()]

func clear_all() -> void:
	if grid_terrain: grid_terrain.clear()
	if grid_props:   grid_props.clear()

# Рендер одного чанка в GridMap’ы
func build_from_chunk(cx:int, cz:int, chunk:Dictionary, origin:Vector3i=Vector3i.ZERO) -> void:
	if chunk.is_empty():
		return

	# ----- ЧИТАЕМ СЛОИ С ЯВНЫМИ ТИПАМИ -----
	var layers: Dictionary = chunk.get("layers", {})
	var kind_layer: Dictionary = layers.get("kind", {})
	var h_layer: Dictionary    = layers.get("height_q", {})

	var enc_kind: String = String(kind_layer.get("encoding", ""))
	if enc_kind != "rle_rows_v1":
		push_error("Слой 'kind' в неожиданном формате: %s" % enc_kind)
		return

	var kd: Dictionary = _decode_rle_rows(kind_layer.get("rows", []))
	var w: int = int(kd.get("w", 0))
	var h: int = int(kd.get("h", 0))
	var kinds: Array = kd.get("grid", [])

	# высоты могут отсутствовать → рисуем плоско
	var heights: Array = []
	var enc_h: String = String(h_layer.get("encoding", ""))
	if enc_h == "rle_rows_v1":
		var hd: Dictionary = _decode_rle_rows(h_layer.get("rows", []))
		heights = hd.get("grid", [])

		# ----- РИСУЕМ -----
	for z in range(h):
		for x in range(w):
			# --- 1) читаем raw-значение из слоя kind
			var raw = kinds[z][x]
			var kind: String = "ground"
			match typeof(raw):
				TYPE_INT:
					kind = String(ID_TO_KIND.get(int(raw), "ground"))
				TYPE_STRING:
					var s: String = raw
					kind = String(ID_TO_KIND.get(int(s), "ground")) if s.is_valid_int() else s
				_:
					kind = "ground"

			# --- 2) void не рисуем вообще (экономия и меньше «псевдопола»)
			if kind == "void":
				continue

			# --- 3) высота в ячейках по Y
			var gy: int = 0
			if z < heights.size():
				var hz: Array = heights[z] as Array
				if x < hz.size():
					var height_m: float = float(hz[x])
					gy = int(round(height_m / max(0.001, cell_y_m)))

			var pos: Vector3i = origin + Vector3i(x, gy, z)

			# --- НОВЫЙ КОД для заполнения пустоты
			var ground_slot: int = _pick(_terrain_buckets.get("ground", PackedInt32Array()), "ground", cx, cz, x, z)

			if grid_terrain:
				# Заполняем пространство под поверхностью
				for y in range(gy):
					grid_terrain.set_cell_item(origin + Vector3i(x, y, z), ground_slot, 0)
				
			# --- 4) раскладка по гридмапам (ваш существующий код)
			if TERRAIN_KINDS.has(kind) and grid_terrain:
				var slot: int = _pick(_terrain_buckets.get(kind, PackedInt32Array()), kind, cx, cz, x, z)
				if slot >= 0:
					grid_terrain.set_cell_item(pos, slot, 0)
			elif PROPS_KINDS.has(kind) and grid_props:
				var slot2: int = _pick(_props_buckets.get(kind, PackedInt32Array()), kind, cx, cz, x, z)
				if slot2 >= 0:
					grid_props.set_cell_item(pos, slot2, 0)
