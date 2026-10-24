extends CanvasLayer

func _ready() -> void:
	visible = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause_menu"):
		if get_tree().paused:
			visible = false
			get_tree().paused = false
		else:
			visible = true
			get_tree().paused = true

func _on_button_pressed() -> void:
	visible = false
	get_tree().paused = false


func _on_options_pressed() -> void:
	pass # Replace with function body.


func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenuScenes/main_menu.tscn")


func _on_exit_game_pressed() -> void:
	get_tree().quit()
