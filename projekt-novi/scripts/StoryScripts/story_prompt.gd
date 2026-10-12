class_name StoryPrompt
extends CanvasLayer
## The freeze pop-up for story levels: the game stops, a box says "FAN BURST ... PRESS [ 1 ]",
## and everything waits until the player presses that key. StoryEncounter uses it
## (Key Prompt settings). Restyle it with a UISkin ("Freeze prompt" group).

signal key_pressed

const INFO := {
	"ability_1": "A fan of slashes fired toward your cursor.",
	"ability_2": "A shockwave that hurts everything around you.",
	"ability_3": "Throws a bouquet toward your cursor. It bursts into petals where it lands!",
	"ability_4": "Your ultimate. A cinematic power move that hits everything nearby.",
	"ability_5": "A quick dash. You cannot be hit while you dash.",
}

## Set before adding to the scene to restyle it.
var skin: UISkin

var is_open: bool = false

var _eff: UISkin
var _action: String = ""
var _was_paused: bool = false
var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _body: RichTextLabel
var _key: Label


static func default_body(action: String) -> String:
	return INFO.get(action, "")


func _ready() -> void:
	layer = 66
	process_mode = Node.PROCESS_MODE_ALWAYS       # must keep working while the game is frozen
	add_to_group("story_prompt")
	_eff = skin if skin != null else UISkin.new()

	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	root.add_child(_dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _eff.box_or_default(_eff.prompt_box, 22))
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -320.0
	_panel.offset_right = 320.0
	_panel.offset_top = -150.0
	_panel.offset_bottom = 150.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	root.add_child(_panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	_title = _label(50, _eff.prompt_title_color)
	col.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_active = false
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.custom_minimum_size = Vector2(580, 90)
	_body.add_theme_font_size_override("normal_font_size", _eff.prompt_text_size)
	_body.add_theme_color_override("default_color", _eff.text_color)
	_body.add_theme_color_override("font_outline_color", Color.BLACK)
	_body.add_theme_constant_override("outline_size", 6)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _eff.font != null:
		_body.add_theme_font_override("normal_font", _eff.font)
	col.add_child(_body)
	_key = _label(_eff.prompt_key_size, Color.WHITE)
	_key.custom_minimum_size = Vector2(580, 70)
	col.add_child(_key)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	if _eff.font != null:
		l.add_theme_font_override("font", _eff.font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _exit_tree() -> void:
	if is_open and get_tree() != null:
		get_tree().paused = _was_paused


## Freezes the game and waits for the key bound to `action` (for example "ability_1").
func ask(action: String, title: String, body: String) -> void:
	if not InputMap.has_action(action):
		push_warning("StoryPrompt: there is no input action called '%s'." % action)
		return
	_action = action
	_title.text = title
	_body.text = body
	_key.text = "%s  [ %s ]" % [_eff.press_text, TutorialUI.key_text(action)]
	_dim.visible = true
	_panel.visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	is_open = true
	await key_pressed
	is_open = false
	_dim.visible = false
	_panel.visible = false
	get_tree().paused = _was_paused


func _process(_delta: float) -> void:
	if is_open:
		_key.pivot_offset = _key.size * 0.5
		_key.scale = Vector2.ONE * (1.0 + 0.06 * sin(Time.get_ticks_msec() / 1000.0 * 6.0))


func _input(event: InputEvent) -> void:
	if is_open and not event.is_echo() and event.is_action_pressed(_action):
		get_viewport().set_input_as_handled()
		key_pressed.emit()
