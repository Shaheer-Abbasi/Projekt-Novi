class_name RunResultScreen
extends Control
## Victory / Defeat screen shown when a roguelike run ends.
## Used by BOTH victory_screen.tscn and defeat_screen.tscn. The only difference
## between them is the look (colors, title) and the "Is Victory" box in the Inspector.
##
## The LOOK lives in the .tscn files, so restyle them in the editor. This script only
## fills in the numbers. It finds nodes by their unique names (the % marker), so you can
## move or restyle them freely. Just don't rename them.
##
## The stats come from RoundStats (credits, kills, survival time, boss) and are saved
## by RoundStats.finish_run() right before this screen opens.

const MENU_PATH := "res://scenes/MainMenuScenes/main_menu.tscn"
const FALLBACK_LEVEL := "res://scenes/Levels/1.tscn"

## ON for the victory screen, OFF for the defeat screen.
@export var is_victory: bool = true
## How long the numbers take to count up from 0, in seconds. 0 = show them instantly.
@export var count_up_seconds: float = 1.0

@onready var time_value := get_node_or_null("%TimeValue") as Label
@onready var kills_value := get_node_or_null("%KillsValue") as Label
@onready var credits_value := get_node_or_null("%CreditsValue") as Label
@onready var level_value := get_node_or_null("%LevelValue") as Label
@onready var boss_value := get_node_or_null("%BossValue") as Label
@onready var retry_button := get_node_or_null("%RetryButton") as Button
@onready var menu_button := get_node_or_null("%MenuButton") as Button
@onready var hint_label := get_node_or_null("%HintLabel") as Label

var _opened_ms: int = 0
var _leaving: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Engine.time_scale = 1.0
	_opened_ms = Time.get_ticks_msec()

	_count_up(time_value, RoundStats.survival_time, _format_time)
	_count_up(kills_value, RoundStats.kills, _format_int)
	_count_up(credits_value, RoundStats.currency, _format_int)
	_set_text(level_value, str(RoundStats.last_run_level))
	_set_text(boss_value, "YES" if RoundStats.boss_defeated else "NO")

	if is_instance_valid(retry_button):
		retry_button.pressed.connect(_retry)
		retry_button.grab_focus()   # so a controller / arrow keys can pick a button right away
	if is_instance_valid(menu_button):
		menu_button.pressed.connect(_to_menu)
	if is_instance_valid(hint_label):
		var retry_word := "Play Again" if is_victory else "Retry"
		InputHints.bind(hint_label, "{Restart} - " + retry_word + "        {pause_menu} - Main Menu")

	# Fade the whole screen in.
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	# Ignore input for a moment, so button-mashing at the end of the fight can't skip this screen.
	if Time.get_ticks_msec() - _opened_ms < 700:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("Restart"):
		get_viewport().set_input_as_handled()
		_retry()
	elif event.is_action_pressed("pause_menu") or event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		_to_menu()


func _retry() -> void:
	if _leaving or Time.get_ticks_msec() - _opened_ms < 700:
		return
	_leaving = true
	var path := RoundStats.last_run_scene
	if path == "" or not ResourceLoader.exists(path):
		path = FALLBACK_LEVEL
	get_tree().change_scene_to_file(path)


func _to_menu() -> void:
	if _leaving or Time.get_ticks_msec() - _opened_ms < 700:
		return
	_leaving = true
	if ResourceLoader.exists(MENU_PATH):
		get_tree().change_scene_to_file(MENU_PATH)


# --- helpers --------------------------------------------------------------

## Animates a number on a label from 0 up to its final value.
func _count_up(label: Label, final_value: float, formatter: Callable) -> void:
	if not is_instance_valid(label):
		return
	if count_up_seconds <= 0.0 or final_value <= 0.0:
		label.text = formatter.call(final_value)
		return
	label.text = formatter.call(0.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: label.text = formatter.call(v),
		0.0, final_value, count_up_seconds).set_delay(0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]


func _format_int(v: float) -> String:
	return str(roundi(v))


func _set_text(l: Label, t: String) -> void:
	if is_instance_valid(l):
		l.text = t
