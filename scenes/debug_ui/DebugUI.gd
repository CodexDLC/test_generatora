# res://scenes/debug_ui/DebugUI.gd
extends Control

# Эта переменная будет хранить ссылку на нашего игрока.
# Имя должно быть player_node, чтобы совпадать с main.gd
var player_node: CharacterBody3D

@onready var label: Label = $Label

func _process(_delta: float) -> void:
	if not is_instance_valid(player_node):
		label.text = "Ожидание игрока..."
		return

	var debug_text := ""
	debug_text += "FPS: %d\n" % Engine.get_frames_per_second()
	
	# Демо-игрок хранит скорость в переменной MOVE_SPEED
	debug_text += "Скорость: %.1f\n" % player_node.MOVE_SPEED 
	debug_text += "Позиция: %.1v\n" % player_node.global_position
	
	debug_text += """
--- УПРАВЛЕНИЕ ---
Движение: WASD
Мышь: Вращение камерой
Скорость: Колесо мыши
Вид от 1/3 лица: V
Гравитация Вкл/Выкл: G
Коллизия Вкл/Выкл: C
Выход: F8
UI Вкл/Выкл: F9
"""
	label.text = debug_text

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F8:
				get_tree().quit()
			KEY_F9:
				visible = not visible
