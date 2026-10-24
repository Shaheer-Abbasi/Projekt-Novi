extends CanvasLayer

@onready var controls_menu = $Controls/InputSettings
@onready var main_buttons = $BoxContainer
@onready var options_panel = $"Options Panel"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the game is paused
	visible = false
	controls_menu.visible = false
	options_panel.visible = false
	controls_menu.back_requested.connect(_on_controls_back)
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	# Don't interfere while a key or button is being rebound on the controls screen.
	if get_tree().get_node_count_in_group("remapping") > 0:
		return

	# Open / close. "visible" is the menu's own state, so the shop, level-up screen and
	# dialogue (which also pause the game) can never be unpaused by this menu.
	if event.is_action_pressed("pause_menu"):
		get_viewport().set_input_as_handled()
		if visible:
			_close_menu()
		elif not get_tree().paused:
			_open_menu()
		return

	if not visible:
		return

	# Circle / Backspace: back one step, or close the menu.
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		if controls_menu.visible:
			_on_controls_back()
		elif options_panel.visible:
			_on_back_button_pressed()
		else:
			_close_menu()
		return

	# Controller used but nothing selected: select the first control on the current screen.
	var focused := get_viewport().gui_get_focus_owner()
	var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if is_pad and focused == null:
		if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < 0.5:
			return   # ignore stick drift
		_focus_first(_current_screen())
		return

	# Cross / E presses the selected button.
	if event.is_action_pressed("interact") and focused is BaseButton \
			and not (focused as BaseButton).disabled:
		get_viewport().set_input_as_handled()
		(focused as BaseButton).pressed.emit()


## The screen the player is looking at right now.
func _current_screen() -> Node:
	if controls_menu.visible:
		return controls_menu
	if options_panel.visible:
		return options_panel
	return main_buttons


func _open_menu() -> void:
	controls_menu.visible = false
	options_panel.visible = false
	main_buttons.visible = true       # always start on the main pause screen
	visible = true
	get_tree().paused = true
	_focus_first(main_buttons)


func _close_menu() -> void:
	visible = false
	# Short wait so the same press can't also trigger a dodge when the game unpauses.
	await get_tree().create_timer(0.08).timeout
	if not visible:
		get_tree().paused = false


## Selects the first button or slider on a screen (so a controller can use it).
func _focus_first(container: Node) -> void:
	for n in container.find_children("*", "Control", true, false):
		var c := n as Control
		if not (c is BaseButton or c is Range):
			continue
		if c.is_visible_in_tree() and c.focus_mode != Control.FOCUS_NONE:
			if c is BaseButton and (c as BaseButton).disabled:
				continue
			c.call_deferred("grab_focus")
			return


# ---------- your button signals ----------

# Resume
func _on_button_pressed() -> void:
	_close_menu()


# Pause screen -> Options
func _on_options_pressed() -> void:
	options_panel.visible = true
	main_buttons.visible = false
	_focus_first(options_panel)


# Options -> Controls
func _on_controls_pressed() -> void:
	options_panel.visible = false
	controls_menu.visible = true
	main_buttons.visible = false
	print("Controls pressed | InputSettings in tree: ", controls_menu.is_visible_in_tree(),
		" | size: ", controls_menu.size,
		" | parent: ", controls_menu.get_parent().name, " visible: ", controls_menu.get_parent().visible)
	_focus_first(controls_menu)


# Controls -> back to Options (also called by the Back button inside the controls scene)
func _on_controls_back() -> void:
	controls_menu.visible = false
	options_panel.visible = true
	_focus_first(options_panel)


# Options -> back to the pause screen
func _on_back_button_pressed() -> void:
	options_panel.visible = false
	controls_menu.visible = false
	main_buttons.visible = true
	_focus_first(main_buttons)


func _on_quit_pressed() -> void:
	visible = false
	Engine.time_scale = 1.0                       # never carry slow motion into the menu
	AudioServer.playback_speed_scale = 1.0
	get_tree().paused = false                     # the main menu must not load frozen
	get_tree().change_scene_to_file("res://scenes/MainMenuScenes/main_menu.tscn")


func _on_exit_game_pressed() -> void:
	get_tree().quit()
