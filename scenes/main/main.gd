# scenes/main/main.gd
extends Node3D

# --- Сцены (проверь свои пути) ---
const MAP_ROOT_SCENE: PackedScene = preload("res://scenes/map/MapRoot.tscn")
const PLAYER_SCENE:   PackedScene = preload("res://scenes/player/player.tscn")

# --- Папка с чанками ---
const WORLD_DIR := "res://data/world_location/demo"

# --- Рабочие поля ---
var _CS: Node = null      # chunksource (автолоад)
var _CR: Node = null      # chunkrenderer (автолоад)
var _ST: Node = null      # chunkstreamer (автолоад)

var _id2kind: Dictionary = {}
var _cell_y: float = 0.5

var _chunk_w: int = 96
var _chunk_h: int = 96
var _last_cx: int = 0
var _last_cz: int = 0

var player_instance: Node3D

func _ready() -> void:
	print("[Main] старт")

	# 0) Создаём MapRoot и берём грид-карты
	var map_instance: Node = MAP_ROOT_SCENE.instantiate()
	add_child(map_instance)
	var grid_terrain: GridMap = map_instance.get_node_or_null("GridMapTerrain") as GridMap
	var grid_props:   GridMap = map_instance.get_node_or_null("GridMapProps")   as GridMap
	if grid_terrain == null:
		push_error("[Main] В MapRoot нет GridMapTerrain"); return

	# 1) Автолоады безопасно (без прямых символов)
	_CS = get_node_or_null("/root/сhunksource")
	_CR = get_node_or_null("/root/chunkrenderer")
	_ST = get_node_or_null("/root/chunkstreamer")

	if _CR == null or _CS == null or _ST == null:
		push_error("[Main] Не найдены автолоады: нужны chunkrenderer, chunksource, chunkstreamer")
		print("--- /root children ---")
		for c in get_tree().root.get_children():
			print("* ", c.name)
		return

	# 2) Привязываем рендерер к грид-картам. Шаг по Y берём из размера клетки
	_CR.set("grid_terrain", grid_terrain)
	_CR.set("grid_props",   grid_props)
	_cell_y = grid_terrain.cell_size.y
	_CR.set("cell_y_m", _cell_y)

	# словарь id->kind и индексация слотов
	if _CR.has_method("_index_libs"):
		_CR.call("_index_libs")
	if _CR and "ID_TO_KIND" in _CR:
		_id2kind = _CR.ID_TO_KIND
	else:
		_id2kind = {}
		print_debug("[Main] Мета-данные 'ID_TO_KIND' не найдены в chunkrenderer.")

	# 3) Источник/стример
	_CS.set("world_dir", WORLD_DIR)
	_ST.set("source_path",   get_path_to(_CS))
	_ST.set("renderer_path", get_path_to(_CR))
	_ST.set("radius", 1)

	# 4) Узнаём размер тайлов из чанка (0,0)
	var ch00: Dictionary = _CS.call("load_chunk", 0, 0)
	if ch00.is_empty():
		push_error("[Main] Нет чанка 0,0 по пути: %s" % WORLD_DIR); return
	var kd: Dictionary = _decode_rle_rows(ch00.get("layers", {}).get("kind", {}).get("rows", []))
	_chunk_w = int(kd.get("w", 0))
	_chunk_h = int(kd.get("h", 0))
	print("[Main] chunk %dx%d" % [_chunk_w, _chunk_h])

	# 5) Рисуем 3×3 вокруг (0,0)
	_ST.call("ensure_radius", 0, 0)

	# 6) Спавним игрока
	_spawn_player(ch00)

	print("[Main] готово. Чанк %dx%d start (%d,%d)" % [_chunk_w, _chunk_h, _last_cx, _last_cz])

# ------------------ СПАВН И УТИЛИТЫ ------------------

# Спавн: всегда в центре чанка (0,0)
func _spawn_player(ch00: Dictionary) -> void:
	print("[Main] spawning player…")

	var kd: Dictionary = _decode_rle_rows(ch00.get("layers", {}).get("kind", {}).get("rows", []))
	var w: int = int(kd.get("w", 0))
	var h: int = int(kd.get("h", 0))

	var cx0: int = w / 2
	var cz0: int = h / 2

	# Вычисляем высоту в центре
	var gy: int = 0
	var h_layer: Dictionary = ch00.get("layers", {}).get("height_q", {})
	if String(h_layer.get("encoding", "")) == "rle_rows_v1":
		var hd: Dictionary = _decode_rle_rows(h_layer.get("rows", []))
		var hh: Array = hd.get("grid", [])
		if cz0 < hh.size():
			var hz: Array = hh[cz0] as Array
			if cx0 < hz.size():
				gy = int(round(float(hz[cx0]) / max(0.001, _cell_y)))
	
	var spawn: Dictionary = {"cx":0, "cz":0, "x":cx0, "z":cz0, "gy":gy}

	# Перевод в мировые координаты
	var sx: int  = int(spawn["x"])
	var sz: int  = int(spawn["z"])
	var scx: int = int(spawn["cx"])
	var scz: int = int(spawn["cz"])
	var sgy: int = int(spawn["gy"])

	var wx: float = float(scx * _chunk_w + sx) + 0.5
	var wz: float = float(scz * _chunk_h + sz) + 0.5
	var wy: float = float(sgy) + 1.0  # на метр над поверхностью

	player_instance = PLAYER_SCENE.instantiate()
	add_child(player_instance)
	player_instance.global_position = Vector3(wx, wy, wz)

	var cam: Camera3D = player_instance.get_node_or_null("Camera3D") as Camera3D
	if cam: cam.current = true

	_last_cx = scx
	_last_cz = scz

	print("[Main] player at chunk(%d,%d) cell(%d,%d) gy=%d → world(%.2f, %.2f, %.2f)" %
		[scx, scz, sx, sz, sgy, wx, wy, wz])

# RLE → (w,h,grid)
func _decode_rle_rows(rows: Array) -> Dictionary:
	var h: int = rows.size()
	if h == 0: return {"w":0, "h":0, "grid":[]}
	var w: int = 0
	for p in rows[0]:
		w += int(p[1])
	var grid: Array = []; grid.resize(h)
	for z in range(h):
		var line: Array = []
		for p in rows[z]:
			var run: int = int(p[1])
			var val = p[0]
			for _i in range(run):
				line.append(val)
		grid[z] = line
	return {"w":w, "h":h, "grid":grid}

# Variant → строковый kind (умеет INT и STRING)
func _resolve_kind(raw: Variant) -> String:
	match typeof(raw):
		TYPE_INT:
			return String(_id2kind.get(int(raw), "ground"))
		TYPE_STRING:
			var s: String = raw
			return String(_id2kind.get(int(s), "ground")) if s.is_valid_int() else s
		_:
			return "ground"



# Ближайшая проходимая клетка в 3×3 чанках вокруг (0,0)
func _pick_spawn_3x3(cs: Node, passable := {"ground":true,"road":true,"bridge":true,"sand":true}) -> Dictionary:
	var best := {"cx":0,"cz":0,"x":0,"z":0,"gy":0,"dist2":1_000_000}
	for cz in range(-1, 2):
		for cx in range(-1, 2):
			var ch: Dictionary = cs.call("load_chunk", cx, cz)
			if ch.is_empty(): continue

			var kd: Dictionary = _decode_rle_rows(ch.get("layers", {}).get("kind", {}).get("rows", []))
			var w: int = int(kd.get("w", 0))
			var h: int = int(kd.get("h", 0))
			var kinds: Array = kd.get("grid", [])

			var heights: Array = []
			var h_layer: Dictionary = ch.get("layers", {}).get("height_q", {})
			if String(h_layer.get("encoding", "")) == "rle_rows_v1":
				heights = _decode_rle_rows(h_layer.get("rows", [])).get("grid", [])

			var cx0: int = w / 2
			var cz0: int = h / 2

			var max_r: int = int(max(w, h))
			for r in range(max_r):
				for dz in range(-r, r + 1):
					for dx in range(-r, r + 1):
						var x: int = cx0 + dx
						var z: int = cz0 + dz
						if x < 0 or z < 0 or x >= w or z >= h: continue

						var kind: String = _resolve_kind(kinds[z][x])
						if not passable.has(kind): continue

						var gy: int = 0
						if z < heights.size():
							var hz: Array = heights[z] as Array
							if x < hz.size():
								gy = int(round(float(hz[x]) / max(0.001, _cell_y)))

						var d2: int = dx*dx + dz*dz
						if d2 < best["dist2"]:
							best = {"cx":cx,"cz":cz,"x":x,"z":z,"gy":gy,"dist2":d2}
	return best
	
func _unhandled_input(event: InputEvent) -> void:
	# 1. Проверяем, был ли это клик левой кнопкой мыши.
	# Если это не клик левой кнопкой мыши, выходим из функции.
	if not (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT):
		return

	# 2. Если игрок не существует, мы ничего не делаем.
	if player_instance == null:
		return

	# 3. Делаем RayCast от камеры.
	var camera = get_viewport().get_camera_3d()
	var from = camera.project_ray_origin(event.position)
	var to = from + camera.project_ray_normal(event.position) * 1000

	# 4. Создаем параметры для RayCast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to, 1) # Layer 1 - ваша карта
	var result = space_state.intersect_ray(query)

	# 5. Если RayCast попал в объект, получаем его координаты.
	if result:
		var hit_pos = result.position
		# Превращаем мировые координаты в координаты клетки.
		var target_cell = Vector2i(floor(hit_pos.x), floor(hit_pos.z))

		print("Нажали на клетку: ", target_cell)

		# 6. Находим путь и отдаём его игроку.
		var start_cell = Vector2i(floor(player_instance.global_position.x), floor(player_instance.global_position.z))
		
		var pathfinder_service = get_node_or_null("/root/PathfinderService")
		if pathfinder_service:
			var new_path = pathfinder_service.find_path(start_cell, target_cell)
			player_instance.set_path(new_path)
		else:
			push_error("PathfinderService не найден!")
