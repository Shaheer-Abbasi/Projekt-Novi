extends CanvasLayer
## Instanced into every arena; listens to the existing XpManager singleton.
## Pauses the game until a choice is made. Queues simultaneous level-ups.

@onready var overlay: ColorRect = $Overlay
@onready var level_title: Label = $Overlay/Center/Panel/Margin/Content/LevelTitle
@onready var options_row: HBoxContainer = $Overlay/Center/Panel/Margin/Content/Options
@onready var player: PlaytestPlayer = get_parent().get_node("Player") as PlaytestPlayer

var _pending_levels: Array[int] = []
var _offered: Array[String] = []
var _show_scheduled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.hide()
	for i in range(options_row.get_child_count()):
		var button := options_row.get_child(i) as Button
		button.pressed.connect(_choose.bind(i))
		button.focus_mode = Control.FOCUS_ALL
	XpManager.leveled_up.connect(_on_leveled_up)



func _on_leveled_up(new_level: int) -> void:
	_pending_levels.append(new_level)
	if not overlay.visible and not _show_scheduled:
		# A level-up can happen inside enemy physics/damage callbacks.
		# Show and pause AFTER the current event finishes.
		_show_scheduled = true
		call_deferred("_show_next")

func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	var focused := get_viewport().gui_get_focus_owner()
	if is_pad and (focused == null or not overlay.is_ancestor_of(focused)):
		(options_row.get_child(0) as Button).grab_focus()
		return
	if event.is_action_pressed("interact") and focused is Button and not (focused as Button).disabled:
		get_viewport().set_input_as_handled()
		(focused as Button).pressed.emit()

func _show_next() -> void:
	_show_scheduled = false
	if _pending_levels.is_empty():
		overlay.hide()
		get_tree().paused = false
		return

	_offered = LevelUpUpgrades.roll_choices()
	level_title.text = "LEVEL %d  -  CHOOSE AN UPGRADE" % _pending_levels.front()
	for i in range(options_row.get_child_count()):
		var id: String = _offered[i]
		var data: Dictionary = LevelUpUpgrades.OPTIONS[id]
		var button := options_row.get_child(i) as Button
		button.text = "%s\n\n%s" % [data["name"], data["description"]]
		button.disabled = false

	overlay.show()
	get_tree().paused = true
	(options_row.get_child(0) as Button).grab_focus.call_deferred()


func _choose(index: int) -> void:
	if not overlay.visible or index < 0 or index >= _offered.size():
		return
	# Prevent accidental double-clicks / double reward grants.
	for child in options_row.get_children():
		(child as Button).disabled = true
	if not LevelUpUpgrades.apply(player, _offered[index]):
		push_error("Could not apply the selected level-up upgrade")
		for child in options_row.get_children():
			(child as Button).disabled = false
		return

	_offered.clear()
	_pending_levels.pop_front()
	if _pending_levels.is_empty():
		overlay.hide()
		get_tree().paused = false
	else:
		# If a large XP pickup gave multiple levels, make a NEW set of 3.
		_show_next()


func _exit_tree() -> void:
	# Don't leave the game paused if this scene is unloaded with the menu open.
	if overlay != null and overlay.visible:
		get_tree().paused = false
