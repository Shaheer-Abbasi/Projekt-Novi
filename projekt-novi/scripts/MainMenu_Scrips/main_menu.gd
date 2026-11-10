extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options_panel: Panel = $"Options Panel"
@onready var controls_menu = $Controls/InputSettings

# Called when the node enters the scene tree for the first time.
func _ready():
	main_buttons.visible = true
	options_panel.visible = false
	controls_menu.visible = false
	controls_menu.back_requested.connect(_on_controls_back)


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/1.tscn")

func _on_level_select_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenuScenes/level_select.tscn")

func _on_survival_select_button_2_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenuScenes/character_select.tscn")
func _on_premium_shop_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenuScenes/premium_shop.tscn")

func _on_option_button_pressed() -> void:
	main_buttons.visible = false
	options_panel.visible = true


## F9 (debug builds only): showcase reset. Coins, gacha pulls and unlocked characters go back to a new save.
func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		SaveData.reset_gacha()
		CharacterSelectScreen.selected_character = null
		CharacterSelectScreen.selected_name = ""
		var note := Label.new()
		note.text = "SAVE RESET"
		note.add_theme_font_size_override("font_size", 36)
		note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		note.position.y += 40.0
		add_child(note)
		var tw := note.create_tween()
		tw.tween_interval(1.0)
		tw.tween_property(note, "modulate:a", 0.0, 0.6)
		tw.tween_callback(note.queue_free)


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_back_button_pressed() -> void:
	main_buttons.visible = true
	options_panel.visible = false
	controls_menu.visible = false


func _on_controls_pressed() -> void:
	options_panel.visible = false
	controls_menu.visible = true
	
func _on_controls_back() -> void:
	controls_menu.visible = false
	options_panel.visible = true
