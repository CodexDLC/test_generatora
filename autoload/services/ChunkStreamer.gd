extends Node
## Держит квадрат чанков вокруг центра. Сам находит автолоады по /root/...

@export var radius:int = 1
@export var source_path: NodePath = NodePath("/root/chunksource")
@export var renderer_path: NodePath = NodePath("/root/chunkrenderer")

func _get_source() -> Node:
	return get_node_or_null(source_path)

func _get_renderer() -> Node:
	return get_node_or_null(renderer_path)

static func _origin_for(cx:int, cz:int, chunk:Dictionary) -> Vector3i:
	var rows:Array = chunk["layers"]["kind"]["rows"]
	var w := 0; for p in rows[0]: w += int(p[1])
	var h := rows.size()
	return Vector3i(cx*w, 0, cz*h)

func ensure_radius(center_cx:int, center_cz:int) -> void:
	var source := _get_source()
	var renderer := _get_renderer()
	if source == null or renderer == null:
		push_error("ChunkStreamer: не присвоен source/renderer (проверь автолоады).")
		return

	# Учебно просто: очищаем и рисуем заново.
	if renderer.has_method("clear_all"):
		renderer.call("clear_all")

	for dz in range(-radius, radius+1):
		for dx in range(-radius, radius+1):
			var cx := center_cx + dx
			var cz := center_cz + dz

			var ch: Dictionary = {}
			if source.has_method("load_chunk"):
				ch = source.call("load_chunk", cx, cz)
			else:
				push_error("source не умеет load_chunk()"); continue

			if ch.is_empty():
				continue

			var org := _origin_for(cx, cz, ch)
			if renderer.has_method("build_from_chunk"):
				renderer.call("build_from_chunk", cx, cz, ch, org)
			else:
				push_error("renderer не умеет build_from_chunk()")
