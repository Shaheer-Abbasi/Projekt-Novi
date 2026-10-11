extends CanvasLayer
## Counter scene. Pauses the level while open and resumes on close.

signal closed

@export var spin_cost: int = 50
@export var spin_duration: float = 4.0
@onready var doc: Control = $Stage/Cyberdoc

# Wedges clockwise from the top. Pointer is at the top.
# add the stats in the middle
var wedges: Array[Dictionary] = [
	{"name": "Fan Burst +1", "weight": 30},
	{"name": "Shockwave +1", "weight": 30},
	{"name": "Ability 3 +1", "weight": 30},
	{"name": "Ultimate +1", "weight": 10},
]

@onready var stage: Control = $Stage
@onready var wheel: Control = $Stage/Wheel
@onready var dialogue: Label = $Stage/DialogueLabel
@onready var spin_button: Button = $Stage/Buttons/SpinButton
@onready var leave_button: Button = $Stage/Buttons/LeaveButton
@onready var popup: Panel = $RewardPopup
@onready var popup_label: Label = $RewardPopup/VBox/RewardLabel
@onready var popup_ok: Button = $RewardPopup/VBox/OkButton

var busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep running while the level is paused
	get_tree().paused = true

	if "wedge_count" in wheel:                 # placeholder wheel matches the table
		wheel.wedge_count = wedges.size()
		wheel.queue_redraw()

	popup.hide()
	spin_button.text = "Spin (%d)" % spin_cost
	spin_button.pressed.connect(_on_spin_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	spin_button.grab_focus()

	await _say("Welcome to my clinic. Feeling lucky?")


func _on_spin_pressed() -> void:
	if busy:
		return
	if not RoundStats.spend_currency(spin_cost):
		_say("Come back when you've got the credits.")
		return

	busy = true
	_set_buttons_disabled(true)

	# Pay, roll, grant and save BEFORE the animation.
	var index := _roll_wedge()
	var reward := wedges[index]
	GameState.add_item(reward)
	GameState.save_game()

	await _focus_wheel(true)
	await _spin_to(index)
	await _show_reward(reward)
	await _focus_wheel(false)
	
	await _say("Another spin?")
	busy = false
	_set_buttons_disabled(false)
	spin_button.grab_focus()
	


func _on_leave_pressed() -> void:
	if busy:
		return
	busy = true
	_set_buttons_disabled(true)
	await _say("Come again!")
	await get_tree().create_timer(0.6).timeout
	_close()


# ---------- helpers ----------

func _roll_wedge() -> int:
	var total := 0
	for w in wedges:
		total += w.weight
	var r := randi_range(1, total)
	for i in wedges.size():
		r -= wedges[i].weight
		if r <= 0:
			return i
	return 0


func _spin_to(index: int) -> void:
	var step := TAU / wedges.size()
	var center := (index + 0.5) * step
	var jitter := randf_range(-0.4, 0.4) * step
	wheel.pivot_offset = wheel.size / 2.0
	wheel.rotation = fposmod(wheel.rotation, TAU)
	var target := TAU * 5.0 - center + jitter
	var tween := create_tween()
	tween.tween_property(wheel, "rotation", target, spin_duration) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(0.4).timeout


func _focus_wheel(zoom_in: bool) -> void:
	var wheel_center := wheel.position + wheel.size / 2.0
	var view_center := get_viewport().get_visible_rect().size / 2.0
	stage.pivot_offset = wheel_center
	var tween := create_tween().set_parallel(true)
	tween.tween_property(doc, "modulate:a", 0.0 if zoom_in else 1.0, 0.4)
	tween.tween_property(stage, "scale", Vector2.ONE * (1.5 if zoom_in else 1.0), 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(stage, "position", (view_center - wheel_center) if zoom_in else Vector2.ZERO, 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _show_reward(reward: Dictionary) -> void:
	popup_label.text = "%s\n[%s]" % [reward.name, reward.weight] # added weight as placeholder for stats
	popup.show()
	popup.scale = Vector2.ZERO
	popup.pivot_offset = popup.size / 2.0
	var tween := create_tween()
	tween.tween_property(popup, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	popup_ok.grab_focus()
	await popup_ok.pressed
	popup.hide()


func _say(line: String) -> void:
	dialogue.text = line
	dialogue.visible_ratio = 0.0
	var tween := create_tween()
	tween.tween_property(dialogue, "visible_ratio", 1.0, maxf(0.3, line.length() * 0.03))
	await tween.finished


func _set_buttons_disabled(value: bool) -> void:
	spin_button.disabled = value
	leave_button.disabled = value


func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
