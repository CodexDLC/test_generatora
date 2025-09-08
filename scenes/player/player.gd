# res://scenes/player/player.gd
extends CharacterBody3D

@export var MOVE_SPEED: float = 10.0
@export var JUMP_SPEED: float = 15.0

# --- Переменные для переключения вида ---
@export var first_person: bool = false:
	set(p_value):
		first_person = p_value
		var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		var body_model = $Pivot/Superhero_Female2
		
		if first_person:
			tween.tween_property($CameraRig/CameraPivot/Camera3D, "position:z", 0.5, 0.33)
			tween.tween_callback(body_model.set_visible.bind(false))
		else:
			body_model.visible = true
			tween.tween_property($CameraRig/CameraPivot/Camera3D, "position:z", 12.0, 0.33)

# --- Переменные для отладки ---
@export var gravity_enabled: bool = true:
	set(p_value):
		gravity_enabled = p_value
		if not gravity_enabled:
			velocity.y = 0
			
@export var collision_enabled: bool = true:
	set(p_value):
		collision_enabled = p_value
		$CollisionShape3D.disabled = not collision_enabled

@onready var camera: Camera3D = $CameraRig/CameraPivot/Camera3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	collision_layer = 1
	collision_mask  = 0x000FFFFF
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_snap_length = 1.0

func _physics_process(delta: float) -> void:
	# 1. Применяем гравитацию
	if not is_on_floor() and gravity_enabled:
		velocity.y -= gravity * delta

	# 2. Обрабатываем прыжок (теперь здесь, т.к. это связано с физикой)
	if Input.is_action_just_pressed("jump") and is_on_floor() and gravity_enabled:
		velocity.y = JUMP_SPEED
		
	# 3. Получаем направление движения
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_speed = MOVE_SPEED
	if Input.is_action_pressed("move_sprint"):
		current_speed *= 2.0
		
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	# 4. Двигаем персонажа
	move_and_slide()

# Обработка одиночных нажатий, не связанных с физикой
func _unhandled_input(event: InputEvent) -> void:
	# Обработка изменения скорости колесиком мыши
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			MOVE_SPEED = clamp(MOVE_SPEED + 1, 1, 100)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			MOVE_SPEED = clamp(MOVE_SPEED - 1, 1, 100)
	
	# Обработка переключателей
	if event.is_action_just_pressed("toggle_view"):
		first_person = !first_person
	elif event.is_action_just_pressed("toggle_gravity"):
		gravity_enabled = !gravity_enabled
	elif event.is_action_just_pressed("toggle_collision"):
		collision_enabled = !collision_enabled
