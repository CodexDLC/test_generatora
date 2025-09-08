# Файл: FreeCamera.gd
extends Camera3D

@export var move_speed: float = 20.0
@export var mouse_sensitivity: float = 0.15

var _velocity := Vector3.ZERO
var _mouse_delta := Vector2.ZERO

# --- НОВОЕ: Функции для включения/выключения ---
func activate() -> void:
	set_physics_process(true)
	set_process_input(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	current = true

func deactivate() -> void:
	set_physics_process(false)
	set_process_input(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	current = false

func _ready() -> void:
	# При запуске камера должна быть выключена
	deactivate()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_delta = event.relative

func _physics_process(delta: float) -> void:
	# ... (остальной код движения и вращения остается без изменений) ...
	if _mouse_delta.length() > 0:
		rotate_y(deg_to_rad(-_mouse_delta.x * mouse_sensitivity))
		rotate_object_local(Vector3.RIGHT, deg_to_rad(-_mouse_delta.y * mouse_sensitivity))
		rotation.x = clamp(rotation.x, deg_to_rad(-89), deg_to_rad(89))
		_mouse_delta = Vector2.ZERO

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if Input.is_action_pressed("move_up"):
		direction.y += 1.0
	if Input.is_action_pressed("move_down"):
		direction.y -= 1.0

	if direction:
		_velocity.x = direction.x * move_speed
		_velocity.y = direction.y * move_speed
		_velocity.z = direction.z * move_speed
	else:
		_velocity = _velocity.move_toward(Vector3.ZERO, move_speed)

	position += _velocity * delta
