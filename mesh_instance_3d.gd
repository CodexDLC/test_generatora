@tool
extends MeshInstance3D

enum Kind { FRUSTUM, RAMP }

@export var kind: Kind = Kind.FRUSTUM : set = _set_and_rebuild
# FRUSTUM: низ 1.0, верх 0.75, высота 0.5 по умолчанию
@export var bottom_size: float = 1.0 : set = _set_and_rebuild
@export var top_size: float = 0.75 : set = _set_and_rebuild
@export var height_y: float = 0.5 : set = _set_and_rebuild
# RAMP: ширина X = bottom_size, глубина Z = bottom_size, подъём = height_y
@export var generate_collision := true : set = _set_and_rebuild
@export var convex_collision := false : set = _set_and_rebuild
@export var double_sided := true : set = _set_and_rebuild  # отключить cull

func _ready() -> void:
	rebuild()

func _set_and_rebuild(_v) -> void:
	if Engine.is_editor_hint():
		call_deferred("rebuild")

func rebuild() -> void:
	if kind == Kind.FRUSTUM:
		mesh = _make_frustum(bottom_size, top_size, height_y)
	else:
		mesh = _make_ramp(bottom_size, bottom_size, height_y)
	if mesh and generate_collision:
		_create_collision(mesh, convex_collision)

func _make_frustum(bottom: float, top: float, h: float) -> ArrayMesh:
	var b := bottom * 0.5
	var t := top * 0.5
	var y0 := 0.0
	var y1 := h
	var V0 = Vector3(-b,y0,-b)
	var V1 = Vector3( b,y0,-b)
	var V2 = Vector3( b,y0, b)
	var V3 = Vector3(-b,y0, b)
	var V4 = Vector3(-t,y1,-t)
	var V5 = Vector3( t,y1,-t)
	var V6 = Vector3( t,y1, t)
	var V7 = Vector3(-t,y1, t)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Низ (нормаль вниз)
	_add_quad(st, V0, V1, V2, V3, true)
	# Верх (нормаль вверх)
	_add_quad(st, V4, V5, V6, V7, false)
	# Бока (внешние нормали)
	_add_quad(st, V0, V4, V5, V1, false) # -Z
	_add_quad(st, V1, V5, V6, V2, false) # +X
	_add_quad(st, V2, V6, V7, V3, false) # +Z
	_add_quad(st, V3, V7, V4, V0, false) # -X

	st.generate_normals()
	var am := st.commit()
	_set_material_flags(am)
	return am

func _make_ramp(size_x: float, size_z: float, rise_y: float) -> ArrayMesh:
	var x := size_x * 0.5
	var z := size_z * 0.5
	# Низ прямоугольник, подъём к +Z
	var A = Vector3(-x, 0, -z)
	var B = Vector3( x, 0, -z)
	var C = Vector3( x, 0,  z)
	var D = Vector3(-x, 0,  z)
	var E = Vector3( x, rise_y, z)   # верхняя кромка
	var F = Vector3(-x, rise_y, z)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Низ
	_add_quad(st, A, B, C, D, true)
	# Задняя вертикаль (+Z)
	_add_quad(st, D, C, E, F, false)
	# Левая боковая
	_add_quad(st, A, D, F, Vector3(-x,0,-z), false) # A,D,F,A (замкнуть)
	# Правая боковая
	_add_quad(st, B, Vector3(x,0,-z), E, C, false)  # B,B,E,C
	# Скат (A-B-E-F)
	_add_quad(st, A, B, E, F, false)

	st.generate_normals()
	var am := st.commit()
	_set_material_flags(am)
	return am

func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, flip: bool) -> void:
	# Простейшие UV на весь квадрат
	var uv0 := Vector2(0,0)
	var uv1 := Vector2(1,0)
	var uv2 := Vector2(1,1)
	var uv3 := Vector2(0,1)
	if flip:
		# инвертировать порядок для нужной стороны
		st.set_uv(uv0); st.add_vertex(a)
		st.set_uv(uv3); st.add_vertex(d)
		st.set_uv(uv2); st.add_vertex(c)
		st.set_uv(uv0); st.add_vertex(a)
		st.set_uv(uv2); st.add_vertex(c)
		st.set_uv(uv1); st.add_vertex(b)
	else:
		st.set_uv(uv0); st.add_vertex(a)
		st.set_uv(uv1); st.add_vertex(b)
		st.set_uv(uv2); st.add_vertex(c)
		st.set_uv(uv2); st.add_vertex(c)
		st.set_uv(uv3); st.add_vertex(d)
		st.set_uv(uv0); st.add_vertex(a)

func _set_material_flags(am: ArrayMesh) -> void:
	if not am: return
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED if double_sided else BaseMaterial3D.CULL_BACK
	am.surface_set_material(0, mat)

func _create_collision(m: ArrayMesh, convex: bool) -> void:
	# Удалить старую коллизию
	for c in get_children():
		if c is StaticBody3D: remove_child(c); c.queue_free()
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = m.create_convex_shape() if convex else m.create_trimesh_shape()
	add_child(body)
	body.add_child(shape)
	# Сделать узлы «сценовыми» (чтоб сохранялись)
	if Engine.is_editor_hint():
		var root := get_tree().edited_scene_root
		if root:
			body.owner = root
			shape.owner = root
