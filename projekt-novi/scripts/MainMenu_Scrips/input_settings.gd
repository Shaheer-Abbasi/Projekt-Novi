extends Control
signal back_requested

@onready var input_button_scene = preload("res://scenes/MainMenuScenes/input_button.tscn")
@onready var action_list = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ActionList

var is_remapping := false
var action_to_remap = null
var remapping_button = null

var input_actions = {
	"up": "Move Up",
	"down": "Move Down",
	"left": "Move Left",
	"right": "Move Right",
	"interact": "Interact",
	"pause_menu": "Options",
	"basic attack": "Basic Attack",
	"ability_3": "Dash",
	"ability_1": "Ability 1",
	"ability_2": "Ability 2",
	"ability_4": "Ultimate"
}


func _ready() -> void:
	_create_action_list()


func _create_action_list() -> void:
	_cancel_remap()
	InputMap.load_from_project_settings()
	for item in action_list.get_children():
		item.queue_free()

	for action in input_actions:
		var button = input_button_scene.instantiate()
		button.find_child("LabelAction").text = input_actions[action]
		action_list.add_child(button)
		_fill_row(button, action)
		button.pressed.connect(_on_input_button_pressed.bind(button, action))


## Writes the keyboard/mouse name and the controller name into a row.
func _fill_row(button, action: String) -> void:
	var key_text := ""
	var pad_text := ""
	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				if pad_text == "":
					pad_text = _pad_name(e)
			elif key_text == "":
				key_text = _key_name(e)
	if action == "ability_4":
		pad_text = "L3 + R3"          # the Ultimate combo is checked in code, so it is fixed
	button.find_child("LabelInput").text = key_text
	button.find_child("LabelInput2").text = pad_text


# ---------- remapping ----------

func _on_input_button_pressed(button, action) -> void:
	if is_remapping:
		return
	is_remapping = true
	action_to_remap = action
	remapping_button = button
	add_to_group("remapping")         # tells MenuController to stay out of the way
	button.find_child("LabelInput").text = "Press a key"
	if action != "ability_4":
		button.find_child("LabelInput2").text = "or a button"


func _input(event: InputEvent) -> void:
	if not is_remapping or event.is_echo():
		return

	var is_key: bool = event is InputEventKey and event.is_pressed()
	var is_mouse: bool = event is InputEventMouseButton and event.is_pressed() \
			and not (event as InputEventMouseButton).button_index in [
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
				MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
	var is_pad_button: bool = event is InputEventJoypadButton and event.is_pressed()
	var is_pad_axis: bool = event is InputEventJoypadMotion \
			and absf((event as InputEventJoypadMotion).axis_value) > 0.6
	var is_pad: bool = is_pad_button or is_pad_axis

	if not (is_key or is_mouse or is_pad):
		return
	if is_pad and action_to_remap == "ability_4":
		return                         # the Ultimate's L3 + R3 combo is fixed

	get_viewport().set_input_as_handled()
	_replace_binding(action_to_remap, event, is_pad)
	_finish_remap()


## Replaces ONLY the keyboard/mouse binding, or ONLY the controller binding.
func _replace_binding(action: String, new_event: InputEvent, is_pad: bool) -> void:
	var keep: Array[InputEvent] = []
	for e in InputMap.action_get_events(action):
		var e_is_pad: bool = e is InputEventJoypadButton or e is InputEventJoypadMotion
		if e_is_pad != is_pad:
			keep.append(e)             # the other kind of binding stays

	InputMap.action_erase_events(action)
	for e in keep:
		InputMap.action_add_event(action, e)

	var ev := new_event.duplicate() as InputEvent
	if ev is InputEventMouseButton:
		(ev as InputEventMouseButton).double_click = false
	if is_pad:
		ev.device = -1                 # any controller
		if ev is InputEventJoypadMotion:
			var m := ev as InputEventJoypadMotion
			m.axis_value = signf(m.axis_value)   # remember the direction, not how far it was pushed
	InputMap.action_add_event(action, ev)


func _finish_remap() -> void:
	_fill_row(remapping_button, action_to_remap)
	is_remapping = false
	action_to_remap = null
	remapping_button = null
	call_deferred("_leave_remap_group")


func _leave_remap_group() -> void:
	if not is_remapping and is_in_group("remapping"):
		remove_from_group("remapping")


func _cancel_remap() -> void:
	is_remapping = false
	action_to_remap = null
	remapping_button = null
	if is_in_group("remapping"):
		remove_from_group("remapping")


# ---------- readable names ----------

func _key_name(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		var text := k.as_text_physical_keycode() if k.physical_keycode != 0 else k.as_text_keycode()
		return text.replace("Escape", "Esc")
	if e is InputEventMouseButton:
		match (e as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Left Click"
			MOUSE_BUTTON_RIGHT: return "Right Click"
			MOUSE_BUTTON_MIDDLE: return "Middle Click"
	return e.as_text()


func _pad_name(e: InputEvent) -> String:
	if e is InputEventJoypadButton:
		match (e as InputEventJoypadButton).button_index:
			JOY_BUTTON_A: return "Cross"
			JOY_BUTTON_B: return "Circle"
			JOY_BUTTON_X: return "Square"
			JOY_BUTTON_Y: return "Triangle"
			JOY_BUTTON_BACK: return "Select"
			JOY_BUTTON_START: return "Options"
			JOY_BUTTON_LEFT_STICK: return "L3"
			JOY_BUTTON_RIGHT_STICK: return "R3"
			JOY_BUTTON_LEFT_SHOULDER: return "L1"
			JOY_BUTTON_RIGHT_SHOULDER: return "R1"
			JOY_BUTTON_DPAD_UP: return "D-Pad Up"
			JOY_BUTTON_DPAD_DOWN: return "D-Pad Down"
			JOY_BUTTON_DPAD_LEFT: return "D-Pad Left"
			JOY_BUTTON_DPAD_RIGHT: return "D-Pad Right"
	elif e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		var pos := m.axis_value > 0.0
		match m.axis:
			JOY_AXIS_LEFT_X: return "Left Stick " + ("Right" if pos else "Left")
			JOY_AXIS_LEFT_Y: return "Left Stick " + ("Down" if pos else "Up")
			JOY_AXIS_RIGHT_X: return "Right Stick " + ("Right" if pos else "Left")
			JOY_AXIS_RIGHT_Y: return "Right Stick " + ("Down" if pos else "Up")
			JOY_AXIS_TRIGGER_LEFT: return "L2"
			JOY_AXIS_TRIGGER_RIGHT: return "R2"
	return e.as_text()


func _on_reset_button_pressed() -> void:
	_create_action_list()



func _on_back_button_pressed() -> void:
	_cancel_remap()
	back_requested.emit()
