extends Node
## Drop this into any menu scene as a child Node (main menu, level select, ...).
## It gives the menu controller support:
##  - selects the first button when a controller is used
##  - runs your existing hover animation when a button is selected (it reuses whatever
##    your mouse_entered / mouse_exited handlers do)
##  - "interact" (Cross / E) presses the selected button
##  - "back" (Circle) presses the Back button, or changes to a fallback scene
##
## The menu is the PARENT of this node.

## Leave empty if the menu has its own Back button (a button whose name or text
## contains "back" or "return" is found automatically).
@export_file("*.tscn") var back_scene: String = ""
## Optional: drag the Back button here to be explicit.
@export var back_button: BaseButton

var _menu: Node
var _wired: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu = get_parent()
	_wire_buttons()
	# Buttons created later (e.g. level cards) get wired too.
	get_tree().node_added.connect(_on_node_added)
	# Only pre-select a button if a controller is actually connected,
	# so mouse players don't see a button highlighted for no reason.
	if Input.get_connected_joypads().size() > 0:
		call_deferred("focus_first")


func _on_node_added(node: Node) -> void:
	if node is BaseButton and _menu != null and _menu.is_ancestor_of(node):
		call_deferred("_wire_buttons")


## Connects every button under the menu so selecting it plays the hover animation.
func _wire_buttons() -> void:
	for n in _menu.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if _wired.has(b):
			continue
		_wired[b] = true
		if b.focus_mode == Control.FOCUS_NONE:
			b.focus_mode = Control.FOCUS_ALL
		# Any handler you connected to hover also runs on controller selection.
		b.focus_entered.connect(func(): b.mouse_entered.emit())
		b.focus_exited.connect(func(): b.mouse_exited.emit())
		# TextureButton: use the Hover picture for the Focused state.
		if b is TextureButton:
			var tb := b as TextureButton
			if tb.texture_focused == null:
				tb.texture_focused = tb.texture_hover
		# Normal Button: use the theme's hover style for focus.
		elif b is Button:
			var hover := b.get_theme_stylebox("hover")
			if hover != null:
				b.add_theme_stylebox_override("focus", hover)


func _mirror(b: BaseButton, from_signal: String, to_signal: String) -> void:
	for c in b.get_signal_connection_list(from_signal):
		var cb: Callable = c["callable"]
		if not b.is_connected(to_signal, cb):
			b.connect(to_signal, cb)


func focus_first() -> void:
	_wire_buttons()
	for n in _menu.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b.is_visible_in_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus()
			return


func _input(event: InputEvent) -> void:
	if get_tree().get_node_count_in_group("remapping") > 0:
		return
	
	var focused := get_viewport().gui_get_focus_owner()

	# Mouse moved: drop controller selection so two buttons aren't highlighted.
	if event is InputEventMouseMotion:
		if focused != null:
			focused.release_focus()
		return

	# Back (Circle). Checked first so it works even with nothing selected.
	if event.is_action_pressed("return"):
		get_viewport().set_input_as_handled()
		_go_back()
		_refocus_next_frame()
		return

	# Controller used but nothing selected: select the first button.
	var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if is_pad and focused == null:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.5:
			return   # ignore stick drift
		focus_first()
		return

	# Interact (Cross / E) presses the selected button.
	if event.is_action_pressed("interact") and focused is BaseButton \
			and not (focused as BaseButton).disabled:
		get_viewport().set_input_as_handled()
		_press(focused as BaseButton)
		_refocus_next_frame()

func _press(b: BaseButton) -> void:
	# Send a genuine "accept" press and release so the button behaves exactly
	# as if clicked: pressed, button_down, button_up, toggled, everything.
	var down := InputEventAction.new()
	down.action = &"ui_accept"
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = &"ui_accept"
	up.pressed = false
	Input.parse_input_event(up)

func _refocus_next_frame() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return   # the press changed scene, so there's nothing to refocus
	if get_viewport().gui_get_focus_owner() == null:
		focus_first()


func _go_back() -> void:
	if back_button != null and back_button.is_visible_in_tree() and not back_button.disabled:
		back_button.pressed.emit()
		return
	for n in _menu.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		var btn_text: String = ""
		if b is Button:
			btn_text = (b as Button).text
		var label: String = (String(b.name) + " " + btn_text).to_lower()
		if b.is_visible_in_tree() and not b.disabled \
				and (label.contains("back") or label.contains("return")):
			b.pressed.emit()
			return
	if back_scene != "" and ResourceLoader.exists(back_scene):
		get_tree().change_scene_to_file(back_scene)
