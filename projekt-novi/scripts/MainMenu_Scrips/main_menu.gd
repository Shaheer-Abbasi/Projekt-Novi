extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options_panel: Panel = $"Options Panel"

# Called when the node enters the scene tree for the first time.
func _ready():
	main_buttons.visible = true
	options_panel.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_option_button_pressed() -> void:
	main_buttons.visible = false
	options_panel.visible = true


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_back_button_pressed() -> void:
	_ready()
