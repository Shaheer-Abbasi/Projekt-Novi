class_name PlaytestHUD
extends CanvasLayer
## HUD logic. The LOOK lives in playtest_hud.tscn, so restyle it in the editor.
## This script only fills in numbers and shows/hides things. It finds nodes by
## their unique names (the % marker), so you can move, restyle or re-nest them
## freely. If you delete a node the HUD just skips it. Just don't rename them.

const MENU_PATH := "res://scenes/MainMenuScenes/main_menu.tscn"
@export var slot_label_format: String = "{name}"

@onready var timer_label := get_node_or_null("%TimerLabel") as Label
@onready var kills_label := get_node_or_null("%KillsLabel") as Label
@onready var name_label := get_node_or_null("%NameLabel") as Label
@onready var hp_bar := get_node_or_null("%HPBar") as ProgressBar
@onready var hp_label := get_node_or_null("%HPLabel") as Label
@onready var ability_bar := get_node_or_null("%AbilityBar") as Control
@onready var boss_panel := get_node_or_null("%BossPanel") as Control
@onready var boss_name := get_node_or_null("%BossName") as Label
@onready var boss_bar := get_node_or_null("%BossBar") as ProgressBar
@onready var boss_phase := get_node_or_null("%BossPhase") as Label
@onready var end_panel := get_node_or_null("%EndPanel") as Control
@onready var end_title := get_node_or_null("%EndTitle") as Label

var _player: PlaytestPlayer
var _slots: Array[Control] = []
var _slot_names: Array[Label] = []
var _slot_status: Array[Label] = []
var _slot_enabled: Array[bool] = []  # false = you hid this box in the editor, so it stays hidden


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working while the game is paused
	if is_instance_valid(boss_panel):
		boss_panel.visible = false
	if is_instance_valid(end_panel):
		end_panel.visible = false
	if is_instance_valid(ability_bar):
		# Match each box to its ability by the NUMBER in its name (Ability1..Ability4), not by position.
		# So you can hide or delete any box without the others getting mixed up.
		var found := {}
		var order := 0
		for box in ability_bar.get_children():
			if box is Control:
				found[_slot_number(box, order)] = box
				order += 1
		var count := 0
		for k in found:
			count = maxi(count, int(k) + 1)
		for i in range(count):
			var box = found.get(i, null)
			_slots.append(box)
			_slot_enabled.append(box != null and box.visible)   # hidden in the editor = stays hidden
			_slot_names.append(box.find_child("Name", true, false) as Label if box != null else null)
			_slot_status.append(box.find_child("Status", true, false) as Label if box != null else null)


## "Ability3" -> 2 (ability index). If the name has no number, use its order in the bar instead.
func _slot_number(box: Node, fallback: int) -> int:
	var digits := ""
	var nm := String(box.name)
	for i in range(nm.length() - 1, -1, -1):
		if nm[i] >= "0" and nm[i] <= "9":
			digits = nm[i] + digits
		else:
			break
	return digits.to_int() - 1 if digits != "" else fallback


# --- small null-safe helpers (so deleting a node never crashes the HUD) ---
func _set_text(l, t: String) -> void:
	if is_instance_valid(l):
		l.text = t


func _set_bar(b, cur: float, mx: float) -> void:
	if is_instance_valid(b):
		b.max_value = mx
		b.value = cur


func bind_player(p: PlaytestPlayer) -> void:
	_player = p
	p.health_changed.connect(_on_player_hp)
	_on_player_hp(p.current_hp, p.max_hp)
	_set_text(name_label, p.character_name.to_upper())
	for i in range(_slots.size()):
		if not is_instance_valid(_slots[i]):
			continue
		var has_ability := i < p.abilities.size() and p.abilities[i] != null and _slot_enabled[i]
		_slots[i].visible = has_ability
		if has_ability:
			_set_text(_slot_names[i], slot_label_format.replace("{key}", _key_text(i)).replace("{name}", p.abilities[i].ability_name))


## The key bound to ability slot i, read from the input map (so it is always correct).
func _key_text(i: int) -> String:
	var events := InputMap.action_get_events("ability_%d" % (i + 1))
	if events.size() > 0 and events[0] is InputEventKey:
		return (events[0] as InputEventKey).as_text_physical_keycode()
	return str(i + 1)


func _on_player_hp(cur: float, mx: float) -> void:
	_set_bar(hp_bar, cur, mx)
	_set_text(hp_label, "HP %d / %d" % [ceili(cur), ceili(mx)])


func _process(_delta: float) -> void:
	if _player == null:
		return
	for i in range(mini(_slots.size(), _player.abilities.size())):
		if not is_instance_valid(_slots[i]):
			continue
		var a: Ability = _player.abilities[i]
		if a == null:
			continue
		_set_text(_slot_status[i], "READY" if a.is_ready() else "%.1fs" % a.cooldown_left())
		_slots[i].modulate = Color.WHITE if a.is_ready() else Color(0.6, 0.6, 0.6)


func set_timer(seconds_left: float) -> void:
	_set_text(timer_label, "%02d:%02d" % [floori(seconds_left / 60.0), int(seconds_left) % 60])


func set_timer_text(t: String) -> void:
	_set_text(timer_label, t)


func set_kills(n: int) -> void:
	_set_text(kills_label, "Kills: %d" % n)


func show_boss(boss: BossNPC) -> void:
	var bs := boss.stats as BossStats
	_set_text(boss_name, bs.boss_display_name if bs != null else "Boss")
	_set_bar(boss_bar, boss.current_hp, boss.stats.max_hp)
	_set_text(boss_phase, "Phase 1")
	if is_instance_valid(boss_panel):
		boss_panel.visible = true
	boss.health_changed.connect(_on_boss_hp)
	boss.phase_changed.connect(_on_boss_phase)
	boss.died.connect(_on_boss_gone)


func _on_boss_hp(cur: float, mx: float) -> void:
	_set_bar(boss_bar, cur, mx)


func _on_boss_phase(p: int) -> void:
	_set_text(boss_phase, "Phase %d" % p)


func _on_boss_gone(_b: EnemyNPC) -> void:
	if is_instance_valid(boss_panel):
		boss_panel.visible = false


func show_end(title: String) -> void:
	_set_text(end_title, title)
	if is_instance_valid(end_panel):
		end_panel.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(end_panel) or not end_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE:
			get_tree().paused = false
			if ResourceLoader.exists(MENU_PATH):
				get_tree().change_scene_to_file(MENU_PATH)
