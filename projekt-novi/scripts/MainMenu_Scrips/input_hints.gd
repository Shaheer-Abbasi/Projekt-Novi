extends Node
## Autoload "InputHints". Knows whether the player last used keyboard/mouse or a controller,
## and turns an input action into the matching button name ("E" or "Cross").
##
##   InputHints.text("interact")                      -> "E"  or  "Cross"
##   InputHints.format("Press {interact} to talk")    -> "Press E to talk"  or  "Press Cross to talk"
##   InputHints.format("Use {move} to move")          -> "Use WASD to move"  or  "Use Left Stick to move"
##   InputHints.bind(label, "Press {interact}")       -> keeps the label updated when the device changes

signal device_changed(using_pad: bool)

var using_pad: bool = false

var _pad_device: int = 0
var _bound: Array = []
var _regex := RegEx.new()

## Actions whose controller input is a combo, which the Input Map can't store.
const PAD_OVERRIDES := {"ability_4": "L3 + R3"}

const PS_BUTTONS := {
	JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
	JOY_BUTTON_BACK: "Select", JOY_BUTTON_START: "Options",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_DPAD_UP: "D-Pad Up", JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left", JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
}

const XBOX_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-Pad Up", JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left", JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
}


## true = show the PlayStation face buttons as symbols; false = show the names (Cross, Circle...).
var use_symbols: bool = true

const PS_SYMBOLS := {
	JOY_BUTTON_A: "✕", JOY_BUTTON_B: "○", JOY_BUTTON_X: "□", JOY_BUTTON_Y: "△",
}

## For rich text (RichTextLabel): button pictures. Put files named ps_<name>.png in ICON_DIR.
const ICON_DIR := "res://ui/prompts/"
const ICON_HEIGHT := 28
const PS_ICON_NAMES := {
	JOY_BUTTON_A: "cross", JOY_BUTTON_B: "circle", JOY_BUTTON_X: "square", JOY_BUTTON_Y: "triangle",
	JOY_BUTTON_BACK: "share", JOY_BUTTON_START: "options",
	JOY_BUTTON_LEFT_STICK: "l3", JOY_BUTTON_RIGHT_STICK: "r3",
	JOY_BUTTON_LEFT_SHOULDER: "l1", JOY_BUTTON_RIGHT_SHOULDER: "r1",
	JOY_BUTTON_DPAD_UP: "dpad_up", JOY_BUTTON_DPAD_DOWN: "dpad_down",
	JOY_BUTTON_DPAD_LEFT: "dpad_left", JOY_BUTTON_DPAD_RIGHT: "dpad_right",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_regex.compile("\\{(\\w+)\\}")


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_pad_device = event.device
		_set_pad(true)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_pad_device = event.device
		_set_pad(true)
	elif event is InputEventKey and event.pressed:
		_set_pad(false)
	elif event is InputEventMouseButton and event.pressed:
		_set_pad(false)
	elif event is InputEventMouseMotion and event.relative.length() > 3.0:
		_set_pad(false)


func _set_pad(value: bool) -> void:
	if value == using_pad:
		return
	using_pad = value
	_refresh()
	device_changed.emit(value)


# ---------- the main functions ----------

## The button name for an action, for whichever device the player is using right now.
func text(action: String) -> String:
	if not InputMap.has_action(action):
		return action
	var events := InputMap.action_get_events(action)
	if using_pad:
		if PAD_OVERRIDES.has(action):
			return PAD_OVERRIDES[action]
		for e in events:
			if _is_pad(e):
				return pad_name(e)
	for e in events:
		if not _is_pad(e):
			return key_name(e)
	if not events.is_empty():
		return pad_name(events[0])           # the action only has a controller binding
	return action


## Replaces {action_name} in a piece of text. {move} becomes WASD or Left Stick.
func format(template: String, rich: bool = false) -> String:
	var out := template
	for m in _regex.search_all(template):
		var token := m.get_string(1)
		var replacement := move_text() if token == "move" else (rich_text(token) if rich else text(token))
		out = out.replace(m.get_string(0), replacement)
	return out


## Keeps a label (or any node's text property) updated when the player switches device.
func bind(node: Object, template: String, property: String = "text", rich: bool = false) -> void:
	_bound.append([node, template, property, rich])
	node.set(property, format(template, rich))


func move_text() -> String:
	if using_pad:
		return "Left Stick"
	var keys: PackedStringArray = []
	for a in ["up", "left", "down", "right"]:
		keys.append(_key_only(a))
	for k in keys:
		if k.length() != 1:
			return "/".join(keys)
	return "".join(keys)


func _refresh() -> void:
	for i in range(_bound.size() - 1, -1, -1):
		var b: Array = _bound[i]
		if not is_instance_valid(b[0]):
			_bound.remove_at(i)
			continue
		b[0].set(b[2], format(b[1], b[3]))


## Like text(), but on a controller it returns a button PICTURE (BBCode) when the file exists
## in ICON_DIR. Use it with a RichTextLabel that has BBCode enabled. Otherwise falls back to text().
func rich_text(action: String) -> String:
	var plain := text(action)
	if not using_pad or _is_xbox() or PAD_OVERRIDES.has(action) or not InputMap.has_action(action):
		return plain
	for e in InputMap.action_get_events(action):
		if _is_pad(e):
			var path := _icon_path(e)
			if path != "" and ResourceLoader.exists(path):
				return "[img=%d]%s[/img]" % [ICON_HEIGHT, path]
			break
	return plain


func _icon_path(e: InputEvent) -> String:
	var n := ""
	if e is InputEventJoypadButton:
		n = PS_ICON_NAMES.get((e as InputEventJoypadButton).button_index, "")
	elif e is InputEventJoypadMotion:
		match (e as InputEventJoypadMotion).axis:
			JOY_AXIS_TRIGGER_LEFT: n = "l2"
			JOY_AXIS_TRIGGER_RIGHT: n = "r2"
	return "" if n == "" else "%sps_%s.png" % [ICON_DIR, n]


# ---------- names ----------

func _is_pad(e: InputEvent) -> bool:
	return e is InputEventJoypadButton or e is InputEventJoypadMotion


func _key_only(action: String) -> String:
	if not InputMap.has_action(action):
		return action
	for e in InputMap.action_get_events(action):
		if not _is_pad(e):
			return key_name(e)
	return action


func _is_xbox() -> bool:
	var n := Input.get_joy_name(_pad_device).to_lower()
	return n.contains("xbox") or n.contains("xinput")


func key_name(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		var t := k.as_text_physical_keycode() if k.physical_keycode != 0 else k.as_text_keycode()
		return t.replace("Escape", "Esc")
	if e is InputEventMouseButton:
		match (e as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Left Click"
			MOUSE_BUTTON_RIGHT: return "Right Click"
			MOUSE_BUTTON_MIDDLE: return "Middle Click"
	return e.as_text()


func pad_name(e: InputEvent) -> String:
	var xbox := _is_xbox()
	if e is InputEventJoypadButton:
		var idx: int = (e as InputEventJoypadButton).button_index
		if not xbox and use_symbols and PS_SYMBOLS.has(idx):
			return PS_SYMBOLS[idx]
		var table: Dictionary = XBOX_BUTTONS if xbox else PS_BUTTONS
		return table.get(idx, e.as_text())
	if e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		var pos := m.axis_value > 0.0
		match m.axis:
			JOY_AXIS_LEFT_X: return "Left Stick " + ("Right" if pos else "Left")
			JOY_AXIS_LEFT_Y: return "Left Stick " + ("Down" if pos else "Up")
			JOY_AXIS_RIGHT_X: return "Right Stick " + ("Right" if pos else "Left")
			JOY_AXIS_RIGHT_Y: return "Right Stick " + ("Down" if pos else "Up")
			JOY_AXIS_TRIGGER_LEFT: return "LT" if xbox else "L2"
			JOY_AXIS_TRIGGER_RIGHT: return "RT" if xbox else "R2"
	return e.as_text()
