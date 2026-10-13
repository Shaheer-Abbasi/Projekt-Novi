class_name StoryInteractable
extends Area2D
## Something the player can walk up to and press E on: an NPC icon, a terminal, a locked door.
## When she is close, a small "[E] Talk" tag appears. Pressing E plays a conversation (plain text, like every
## other dialogue) and then shows a message banner, like the "Use WASD to move" one.
## Put your picture in as a child Sprite2D (the placeholder one is called "Icon"), and give this node a
## CollisionShape2D to say how close she must be (a circle is added for you if you forget).

signal interacted

@export_group("What happens")
## TYPE THE CONVERSATION RIGHT HERE. One line per line:   VOW: What do they say?   Empty = no conversation.
@export_multiline var dialogue_text: String = ""
## (Advanced) A DialogueSequence file to reuse. If the text above is filled in, the text wins.
@export var dialogue: DialogueSequence
## Shown at the top of the screen AFTER the conversation (like the "Use WASD" message). Empty = nothing.
@export_multiline var message_after: String = ""
## How long that message stays.
@export var message_seconds: float = 8.0
## ON: after the first talk, pressing E does nothing more. OFF: she can talk to it again.
@export var only_once: bool = false

@export_group("The E tag")
## Words after the key, e.g. "Talk to CyberDoc" -> [E] Talk to CyberDoc
@export var prompt_text: String = "Talk"
## Where the tag floats, relative to this node (negative y = above).
@export var prompt_offset: Vector2 = Vector2(0.0, -64.0)
## The input action. If the project has none with this name, it is created and bound to the key below.
@export var interact_action: String = "interact"
@export var interact_key: Key = KEY_E

var _in_range: bool = false
var _busy: bool = false
var _done: bool = false
var _prompt: Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2                 # the player's physics layer
	monitorable = false
	var has_shape := false
	for c in get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			has_shape = true
	if not has_shape:
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 90.0
		cs.shape = circle
		add_child(cs)
	if not InputMap.has_action(interact_action):
		InputMap.add_action(interact_action)
		var e := InputEventKey.new()
		e.physical_keycode = interact_key
		InputMap.action_add_event(interact_action, e)
	_prompt = Label.new()
	_prompt.text = "[%s] %s" % [TutorialUI.key_text(interact_action), prompt_text]
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color.WHITE)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.09, 0.85)
	bg.border_color = UISkin.LIME
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(6)
	_prompt.add_theme_stylebox_override("normal", bg)
	_prompt.size = Vector2(260.0, 36.0)
	_prompt.position = prompt_offset + Vector2(-130.0, -18.0)
	_prompt.z_index = 20
	_prompt.visible = false
	add_child(_prompt)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_in_range = true
		_refresh_prompt()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_in_range = false
		_refresh_prompt()


func _refresh_prompt() -> void:
	_prompt.visible = _in_range and not _busy and not (only_once and _done)


func _unhandled_input(event: InputEvent) -> void:       # (not called while the game is frozen)
	if _in_range and not _busy and not (only_once and _done) and event.is_action_pressed(interact_action):
		get_viewport().set_input_as_handled()
		_interact()


func _interact() -> void:
	_busy = true
	_refresh_prompt()
	interacted.emit()
	var level := _find_level()
	var seq: DialogueSequence = dialogue
	if dialogue_text.strip_edges() != "":
		seq = DialogueSequence.new()
		seq.text = dialogue_text
	if seq != null and not seq.is_empty():
		var box: DialogueBox
		if level != null:
			box = level.get_dialogue()
		else:
			box = get_tree().get_first_node_in_group("story_dialogue") as DialogueBox
			if box == null:
				box = DialogueBox.new()
				get_tree().current_scene.add_child(box)
				box.add_to_group("story_dialogue")
		box.play_sequence(seq)
		await box.finished
	if message_after.strip_edges() != "":
		var notice: StoryNotice
		if level != null:
			notice = level.get_notice()
		else:
			notice = get_tree().get_first_node_in_group("story_notice") as StoryNotice
			if notice == null:
				notice = StoryNotice.new()
				get_tree().current_scene.add_child(notice)
		notice.show_message(message_after, message_seconds)
	_done = true
	_busy = false
	_refresh_prompt()


func _find_level() -> StoryLevel:
	var n := get_parent()
	while n != null:
		if n is StoryLevel:
			return n
		n = n.get_parent()
	return null
