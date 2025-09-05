# scenes/player/Player.gd
extends CharacterBody3D

# --- Экспортируемые переменные (можно настроить в Инспекторе) ---
@export var base_speed := 5.0 # Базовая скорость персонажа в метрах/сек

# --- Переменные для пути и движения ---
var _path: Array[Vector2i] = [] # Массив для хранения пути в клетках
var _current_path_index := 0   # Индекс текущей целевой точки в массиве _path

# --- Встроенные функции Godot ---

# _physics_process вызывается каждый физический кадр (стабильно, обычно 60 раз/сек).
# Идеальное место для кода, связанного с движением и физикой.
func _physics_process(delta: float) -> void:
	# Если пути нет или мы уже дошли до конца, ничего не делаем.
	if _path.is_empty():
		velocity = Vector3.ZERO # Останавливаем персонажа
		move_and_slide()
		return

	# 1. Получаем 3D-координаты следующей точки назначения.
	# Берем 2D-координату из нашего пути и превращаем ее в 3D.
	var target_cell: Vector2i = _path[_current_path_index]
	# Ставим цель в центр клетки.
	var target_position := Vector3(target_cell.x + 0.5, global_position.y, target_cell.y + 0.5)

	# 2. Проверяем, достаточно ли мы близко к цели.
	var distance_to_target = global_position.distance_to(target_position)
	
	if distance_to_target < 0.1: # Если дистанция меньше 10 см
		_current_path_index += 1 # Переключаемся на следующую точку в пути
		
		# Если это была последняя точка, очищаем путь и останавливаемся.
		if _current_path_index >= _path.size():
			_path.clear()
			return
	
	# 3. Рассчитываем направление и скорость.
	# Вычисляем вектор направления от текущей позиции к цели.
	var direction = (target_position - global_position).normalized()
	# Устанавливаем скорость. velocity - это встроенное свойство CharacterBody3D.
	velocity = direction * base_speed
	
	# 4. Двигаемся!
	# move_and_slide() - это "волшебная" функция Godot, которая двигает персонажа,
	# учитывая скорость (velocity) и столкновения с другими объектами.
	move_and_slide()


# --- Публичные функции ---

# Эту функцию будет вызывать main.gd, чтобы дать персонажу новый путь.
func set_path(new_path: Array[Vector2i]) -> void:
	if new_path.is_empty():
		_path.clear()
		return
		
	# Принимаем новый путь и сбрасываем счетчик на начало.
	# Мы удаляем первую точку, т.к. персонаж уже стоит на ней.
	new_path.pop_front() 
	_path = new_path
	_current_path_index = 0
