extends CanvasLayer
## Instanced into every arena; listens to the existing XpManager singleton.
## Pauses the game until a choice is made. Queues simultaneous level-ups.
## The screen waits until the kills stop (an ability has finished hitting everything), then fades in.

## Extra seconds to wait after the level-up, on top of the kill wait below. 0 = none.
@export var show_delay: float = 0.0
## The screen only appears once no enemy has died (no XP gained) for this many seconds.
## Raise it if your ability's hits are spread out and the screen still pops up too early.
@export var settle_seconds: float = 0.6
## Never wait longer than this (seconds), even if enemies keep dying (a big swarm).
@export var max_wait_seconds: float = 4.0
## ON: also wait for the Ultimate's cinematic, a dash, and the clear slow motion to finish.
@export var wait_for_effects: bool = false
## How long the screen takes to fade in. 0 = instant.
@export var fade_seconds: float = 0.7
## Seconds the choices ignore input after appearing, so mashing buttons can't pick one by accident.
@export var input_guard_seconds: float = 0.25

@onready var overlay: ColorRect = $Overlay
@onready var level_title: Label = $Overlay/Center/Panel/Margin/Content/LevelTitle
@onready var options_row: HBoxContainer = $Overlay/Center/Panel/Margin/Content/Options
@onready var player: PlaytestPlayer = get_parent().get_node("Player") as PlaytestPlayer

var _pending_levels: Array[int] = []
var _offered: Array[String] = []
var _show_scheduled: bool = false
var _accepting: bool = false
var _fade_tween: Tween
var _last_xp_ms: int = 0          # when XP last changed = when an enemy last died


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.hide()
	for i in range(options_row.get_child_count()):
		var button := options_row.get_child(i) as Button
		button.pressed.connect(_choose.bind(i))
		button.focus_mode = Control.FOCUS_ALL
	XpManager.xp_changed.connect(_on_xp_changed)
	XpManager.leveled_up.connect(_on_leveled_up)


## Every kill gives XP, so this tells us enemies are still dying.
func _on_xp_changed(_current_xp: int, _xp_to_next: int) -> void:
	_last_xp_ms = Time.get_ticks_msec()


func _on_leveled_up(new_level: int) -> void:
	_last_xp_ms = Time.get_ticks_msec()
	_pending_levels.append(new_level)
	if not overlay.visible and not _show_scheduled:
		_show_scheduled = true
		_show_when_calm()


## Waits until the kills have stopped for a moment, then shows the screen.
func _show_when_calm() -> void:
	if show_delay > 0.0:
		await get_tree().create_timer(show_delay, true, false, true).timeout
	var waited := 0.0
	while true:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		if player != null and player._dead:
			_show_scheduled = false
			return                                   # game over: no level-up screen
		if get_tree().paused:
			continue                                 # a conversation, the pause menu, the shop...: just wait
		waited += get_process_delta_time() / maxf(Engine.time_scale, 0.001)   # real seconds, even in slow motion
		var kills_settling := (Time.get_ticks_msec() - _last_xp_ms) < int(settle_seconds * 1000.0)
		var effects_playing := wait_for_effects and _effects_playing()
		if (not kills_settling and not effects_playing) or waited >= max_wait_seconds:
			break
	_show_next()


## True while the Ultimate's cinematic, a dash or the clear slow motion is still playing.
func _effects_playing() -> bool:
	if Engine.time_scale < 0.99:
		return true
	if player != null and (player._input_locked or player._dashing):
		return true
	var level := get_parent()
	if "is_cinematic" in level and level.is_cinematic:
		return true
	return false


func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	var focused := get_viewport().gui_get_focus_owner()
	if is_pad and (focused == null or not overlay.is_ancestor_of(focused)):
		(options_row.get_child(0) as Button).grab_focus()
		return
	if _accepting and event.is_action_pressed("interact") and focused is Button and not (focused as Button).disabled:
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

	var already_showing := overlay.visible
	overlay.show()
	get_tree().paused = true
	(options_row.get_child(0) as Button).grab_focus.call_deferred()
	_fade_in(already_showing)


## Fades the screen in (only the first time; a second queued level-up just swaps the choices).
func _fade_in(already_showing: bool) -> void:
	_accepting = false
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if already_showing or fade_seconds <= 0.0:
		overlay.modulate.a = 1.0
	else:
		overlay.modulate.a = 0.0
		_fade_tween = create_tween()
		_fade_tween.set_ignore_time_scale(true)
		_fade_tween.tween_property(overlay, "modulate:a", 1.0, fade_seconds)
		await _fade_tween.finished
	await get_tree().create_timer(input_guard_seconds, true, false, true).timeout
	_accepting = true


func _choose(index: int) -> void:
	if not _accepting or not overlay.visible or index < 0 or index >= _offered.size():
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
		_accepting = false
		overlay.hide()
		get_tree().paused = false
	else:
		# If a large XP pickup gave multiple levels, make a NEW set of 3.
		_show_next()


func _exit_tree() -> void:
	# Don't leave the game paused if this scene is unloaded with the menu open.
	if overlay != null and overlay.visible:
		get_tree().paused = false
