# res://scenes/LoadingScreen/LoadingScreen.gd
extends Control

# Путь к вашей главной сцене
const MAIN_SCENE_PATH = "res://scenes/main/main.tscn"

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label

func _ready() -> void:
	start_loading()

func start_loading() -> void:
	ResourceLoader.load_threaded_request(MAIN_SCENE_PATH)
	
	var timer = Timer.new()
	# --- ИСПРАВЛЕНИЕ ЗДЕСЬ ---
	# Даём таймеру конкретное имя, чтобы мы могли найти его позже.
	timer.name = "LoadingTimer"
	
	add_child(timer)
	timer.timeout.connect(_check_load_progress)
	timer.start(0.1)

func _check_load_progress() -> void:
	var progress_array = []
	var status = ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH, progress_array)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.value = progress_array[0] * 100
			label.text = "Загрузка ресурсов... %d%%" % progress_bar.value
		
		ResourceLoader.THREAD_LOAD_LOADED:
			# Как только загрузка завершена, останавливаем таймер
			var timer_node = get_node_or_null("LoadingTimer")
			if is_instance_valid(timer_node):
				timer_node.stop()

			label.text = "Ресурсы загружены. Строится мир..."
			await get_tree().process_frame
			_on_load_finished()
		
		ResourceLoader.THREAD_LOAD_FAILED:
			label.text = "ОШИБКА: Не удалось загрузить сцену!"

func _on_load_finished() -> void:
	# Находим и окончательно удаляем таймер
	var timer_node = get_node_or_null("LoadingTimer")
	if is_instance_valid(timer_node):
		timer_node.queue_free()

	var main_scene_res = ResourceLoader.load_threaded_get(MAIN_SCENE_PATH)
	var main_instance = main_scene_res.instantiate()
	
	get_tree().root.add_child(main_instance)
	main_instance.hide()
	
	await main_instance.build_world_and_spawn_player()
	
	main_instance.show()
	queue_free()
