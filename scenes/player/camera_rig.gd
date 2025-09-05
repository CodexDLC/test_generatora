# scenes/player/CameraRig.gd
extends Node3D

@export var mouse_sensitivity := 0.003
@export var zoom_sensitivity := 0.1
@export var min_zoom := 6.0
@export var max_zoom := 35.0

# Нам больше не нужна ссылка на CameraPivot для наклона,
# но ссылка на саму камеру для зума все еще полезна.
@onready var camera: Camera3D = $CameraPivot/Camera3D

func _unhandled_input(event: InputEvent) -> void:
	# Вращение камеры по горизонтали (вокруг персонажа)
	# при зажатой правой кнопке мыши.
	if event is InputEventMouseMotion and Input.is_action_pressed("ui_mouse_pan"):
		rotation.y -= event.relative.x * mouse_sensitivity

	# Зум колесиком мыши
	if event is InputEventMouseButton:
		var zoom_amount = 0.0
		if event.is_action_pressed("ui_zoom_in"):
			zoom_amount = -zoom_sensitivity
		elif event.is_action_pressed("ui_zoom_out"):
			zoom_amount = zoom_sensitivity
		
		# Рассчитываем новую дистанцию и ограничиваем ее.
		var new_pos_z = camera.position.z + zoom_amount * camera.position.z
		camera.position.z = clamp(new_pos_z, min_zoom, max_zoom)
