class_name StoryLevel
extends Node2D
## The root script of a STORY MODE level or a MISSION-style tutorial. (Roguelike mode keeps using
## playtest.gd, untouched.) It holds the settings every encounter in the level shares, and handles
## the basics: Player, HUD, game over, level complete -> next scene, Esc to menu.
##
## It can build the Player and HUD for you: if the scene has no node called "Player" / "HUD", it finds
## your playtest_player.tscn / playtest_hud.tscn by file name and adds them (the Player appears at a
## Marker2D called "PlayerStart"). It also finds your enemy and boss scenes the same way.
##
## Build a level: make a Node2D scene, give the root this script, then add StoryEncounter nodes
## (with StorySpawnPoint children). See README_StoryMode.md.

signal level_completed
signal intro_finished
signal ability_granted(kind: String)

const MENU_PATH := "res://scenes/MainMenuScenes/main_menu.tscn"
const LEVEL_SELECT_PATH := "res://scenes/MainMenuScenes/level_select.tscn"

@export_group("This level")
## Shown at the top of the HUD (where the roguelike timer was).
@export var level_title: String = ""
## Which level this is (1, 2, 3...). Used to unlock the next level when this one is completed. 0 = don't touch level unlocks.
@export var level_number: int = 0
## Opened after the level is completed (next level, a video cutscene, the level select). Empty = the level select.
@export var next_scene: PackedScene
## Seconds between the last fight and the ending (LEVEL COMPLETE, or the logo card).
@export var complete_delay: float = 4.0
## Also unlock level_number + 1 in the LevelManager when this level is completed.
@export var unlock_next_level: bool = true
## Where Esc goes. Empty = the main menu at its usual path.
@export var menu_scene: PackedScene

@export_group("Opening run-in")
## Optional: a Marker2D. At the start the player runs from where she begins (PlayerStart) to this spot,
## then the first encounter begins. Leave empty for no run-in.
@export var intro_run_to: Node2D
@export var intro_run_seconds: float = 2.5

@export_group("Ending")
## Big text when the level is completed. Empty = none.
@export var level_complete_text: String = "LEVEL COMPLETE"
## After the last fight: fade to black and show the logo card ("PRESS ANY KEY") before the next scene.
@export var show_logo_at_end: bool = false
@export var ending_logo: Texture2D
## Shown instead of the logo picture when there is none.
@export var ending_logo_text: String = "PROJEKT NOVI"
## Saves "the tutorial is done" (SaveData), so the menu's Start button skips it from now on.
@export var mark_tutorial_done: bool = false

@export_group("Tutorial helpers")
## Nobody can lose: health refills when it gets very low.
@export var cant_lose: bool = false
## TAB skips straight to the next scene (and counts as completed).
@export var allow_tab_skip: bool = false

@export_group("HUD counters: credits, kills, survived")
## Start this level with Credits, Kills and Survived at 0 (like a new roguelike round).
## Turn OFF in a story level where credits should carry over from the last one.
@export var reset_round_stats: bool = true
## Show the Credits and Survived counters. Turn OFF for a tutorial that only teaches the basics.
@export var show_credits_and_survival: bool = true
## Make the HUD's "Survived" clock run while you play this level.
@export var track_survival_time: bool = true

@export_group("XP and leveling")
## Start this level at XP level 1 with an empty bar. (Off = keep the XP you already have.)
@export var reset_xp_at_start: bool = false
## When the level is left (finished, skipped, or Esc), put XP back to level 1, so nothing earned here carries into the real game.
@export var reset_xp_at_end: bool = false
## Show "LEVEL UP!" in the middle of the screen when the player levels up.
## (Not shown when your level-up screen opens, because that screen already says it.)
@export var announce_level_up: bool = true
## Add your level-up screen ("choose an upgrade", level_up_ui.tscn, found by file name) to this level.
## Skipped if the level already has one. Needs a node called Player in the level.
@export var include_level_up_screen: bool = false

@export_group("World")
## The walkable area. The player can't leave it and the camera stops at its edges.
## Leave the size at 0 for no limit (use walls and doors to block the way instead).
@export var world_bounds: Rect2 = Rect2()

@export_group("Enemies used by every encounter")
## Drag your enemy scene here (the same one the roguelike mode uses). Empty = found automatically (enemy_npc.tscn).
@export var enemy_scene: PackedScene
@export var boss_scene: PackedScene
## Optional: your own stats for each kind. Empty = a built-in version.
## Drag the same .tres files the roguelike mode uses to share your tuning.
@export var grunt_stats: EnemyStats
@export var runner_stats: EnemyStats
@export var tank_stats: EnemyStats
@export var shooter_stats: EnemyStats
@export var boss_stats: BossStats

@export_group("Dialogue characters (easy: a name, a picture, a side)")
## Names are written in the dialogue like  VOW: Hello.  (capitals do not matter). A character with NO picture still talks: the name just shows as text.
@export var hero_name: String = "VOW"
## Drag the picture straight in (a PNG). Empty = no portrait for this character.
@export var hero_portrait: Texture2D
@export var hero_side: DialogueSpeaker.PortraitSide = DialogueSpeaker.PortraitSide.LEFT
@export var guide_name: String = "OPERATOR"
@export var guide_portrait: Texture2D
@export var guide_side: DialogueSpeaker.PortraitSide = DialogueSpeaker.PortraitSide.RIGHT
## A third character, if you need one (a boss, a scientist). Leave the name empty to skip.
@export var other_name: String = ""
@export var other_portrait: Texture2D
@export var other_side: DialogueSpeaker.PortraitSide = DialogueSpeaker.PortraitSide.RIGHT
## ON: portraits stand big at the side of the screen, behind the box (like your mockup). OFF: a small portrait inside the box.
@export var big_portraits: bool = true

@export_group("Look and testing")
## OPTIONAL. Only if you want a custom look (your own box / name tab / key pictures). Empty = the plain built-in look:
## name and text are drawn as text, no pictures needed. The characters above work with or without it.
@export var ui_skin: UISkin
## F1 defeats every enemy on screen (handy for testing doors and messages).
@export var debug_keys: bool = true

@export_group("Found automatically (only fill these if the level can't find them)")
@export var player_scene: PackedScene
@export var hud_scene: PackedScene
@export var character_data: CharacterData

var player: PlaytestPlayer
var hud: PlaytestHUD
var arena_rect: Rect2 = Rect2(-100000.0, -100000.0, 200000.0, 200000.0)
var kills: int = 0
var is_complete: bool = false
var intro_running: bool = false

var _skin_cache: UISkin             # the skin everything uses: your Ui Skin (if any) + the characters above
var _player_source: String = ""     # where the Player came from (for the startup message)
var _hud_source: String = ""
var _round_stats: Node          # your RoundStats autoload, if the project has one
var _xp: Node                   # your XpManager autoload, if the project has one

static var _file_cache: Dictionary = {}


func _ready() -> void:
	_round_stats = get_node_or_null("/root/RoundStats")
	_xp = get_node_or_null("/root/XpManager")
	if _round_stats != null and reset_round_stats and _round_stats.has_method("reset"):
		_round_stats.reset()                      # before the HUD is built, so it starts at zero
	if _xp != null and reset_xp_at_start and _xp.has_method("reset"):
		_xp.reset()
	if _xp != null and announce_level_up and _xp.has_signal("leveled_up"):
		_xp.leveled_up.connect(_on_leveled_up)
	_resolve_assets()
	_build_skin()
	player = get_node_or_null("Player") as PlaytestPlayer
	if player != null and _player_source == "":
		_player_source = "a node called Player in the scene"
	if player == null:
		player = get_tree().get_first_node_in_group("player") as PlaytestPlayer
		if player != null:
			_player_source = "a node in the 'player' group"
	if player == null:
		player = _spawn_player()
	hud = get_node_or_null("HUD") as PlaytestHUD
	if hud != null:
		_hud_source = "a node called HUD in the scene"
	if hud == null:
		hud = _spawn_hud()
	if get_tree().get_first_node_in_group("ultimate_cutscene") == null:
		add_child(UltimateCutscene.new())          # a plain one; put your own UltimateCutscene node in the scene to use yours
	if world_bounds.size != Vector2.ZERO:
		arena_rect = world_bounds
	if player != null:
		player.set_arena(arena_rect)
		player.died.connect(_on_player_died)
		if cant_lose:
			player.health_changed.connect(_keep_alive)
	if hud != null and player != null:
		hud.bind_player(player)
		hud.set_timer_text(level_title)
		if _round_stats == null:
			hud.set_kills(0)                      # (with RoundStats the HUD follows it by itself)
	if hud != null and not show_credits_and_survival:
		for counter in ["currency_label", "survival_label"]:
			var n = hud.get(counter)
			if n is CanvasItem:
				n.visible = false
	if include_level_up_screen and not _has_level_up_screen():
		_add_level_up_screen()
	if allow_tab_skip:
		get_tree().root.window_input.connect(_on_window_input)
	if intro_run_to != null and player != null:
		intro_running = true
		_run_intro.call_deferred()
	var encounter_count := 0
	for n in find_children("*", "Area2D", true, false):
		if n is StoryEncounter:
			encounter_count += 1
	var chars: PackedStringArray = []
	for sp in _skin().speakers:
		chars.append("%s (%s, %s)" % [sp.speaker_name, "portrait" if sp.portrait != null else "no portrait", "left" if sp.side == DialogueSpeaker.PortraitSide.LEFT else "right"])
	var data_src := "none"
	if player != null and player.character_data != null:
		data_src = player.character_data.resource_path if player.character_data.resource_path != "" else "set on the Player"
	print("StoryLevel '%s' is running: %d encounters." % [name, encounter_count])
	print("   Player: %s | character data: %s | abilities now: %d" % [_player_source if player != null else "MISSING", data_src, player.abilities.size() if player != null else 0])
	print("   HUD: %s" % (_hud_source if hud != null else "MISSING"))
	print("   Look: %s | portraits: %s | characters with a portrait: %s" % ["your Ui Skin" if ui_skin != null else "plain built-in", "big (behind the box)" if big_portraits else "small (in the box)", ", ".join(chars) if not chars.is_empty() else "none (names show as text)"])


func _exit_tree() -> void:
	var root := get_tree().root if get_tree() != null else null
	if root != null and root.window_input.is_connected(_on_window_input):
		root.window_input.disconnect(_on_window_input)
	if _xp != null and is_instance_valid(_xp):
		if _xp.has_signal("leveled_up") and _xp.leveled_up.is_connected(_on_leveled_up):
			_xp.leveled_up.disconnect(_on_leveled_up)
		if reset_xp_at_end and _xp.has_method("reset"):
			_xp.reset()                           # whatever way the level is left, XP earned here stays here


func _on_leveled_up(new_level: int) -> void:
	if not announce_level_up or is_complete:
		return
	await get_tree().process_frame               # a level-up screen, if there is one, opens at the end of this frame
	if not is_inside_tree() or get_tree().paused:
		return                                   # it is showing "LEVEL N - CHOOSE AN UPGRADE" already
	get_notice().show_big("LEVEL UP!   Level %d" % new_level, 2.5, Color(1.0, 0.85, 0.2))


## True if the scene already contains your level-up screen (any node running level_up_ui.gd).
func _has_level_up_screen() -> bool:
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var sc: Script = n.get_script()
		if sc != null and sc.resource_path.get_file() == "level_up_ui.gd":
			return true
	return false


func _add_level_up_screen() -> void:
	if player == null:
		push_warning("StoryLevel: Include Level Up Screen needs a Player node in the level.")
		return
	var ps := _load_found("level_up_ui.tscn") as PackedScene
	if ps == null:
		push_warning("StoryLevel: Include Level Up Screen is on, but level_up_ui.tscn was not found anywhere in the project.")
		return
	add_child(ps.instantiate())


# =====================================================================
#  finding things (so a moved folder doesn't break the level)
# =====================================================================

## Finds a file anywhere in the project by its name. Returns "" if there is none.
static func find_project_file(file_name: String) -> String:
	if _file_cache.has(file_name):
		return _file_cache[file_name]
	var found := _scan("res://", file_name)
	_file_cache[file_name] = found
	return found


## Every file with this name anywhere in the project (res://), in folder order.
static func find_project_files(file_name: String) -> Array:
	var out: Array = []
	_scan_all("res://", file_name, out)
	return out


static func _scan_all(dir_path: String, file_name: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for f in d.get_files():
		if f.trim_suffix(".remap") == file_name:
			out.append(dir_path.path_join(file_name))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_scan_all(dir_path.path_join(sub), file_name, out)


## "" if every file this resource points at exists, otherwise the first one that is missing.
static func missing_dependency(path: String) -> String:
	for dep in ResourceLoader.get_dependencies(path):
		var dep_path := ""
		var uid_text := ""
		for part in String(dep).split("::"):
			if part.begins_with("res://"):
				dep_path = part
			elif part.begins_with("uid://"):
				uid_text = part
		if uid_text != "":
			var id := ResourceUID.text_to_id(uid_text)
			if id != ResourceUID.INVALID_ID and ResourceUID.has_id(id):
				continue
		if dep_path != "" and (ResourceLoader.exists(dep_path) or FileAccess.file_exists(dep_path)):
			continue
		return dep_path if dep_path != "" else uid_text
	return ""


static func _scan(dir_path: String, file_name: String) -> String:
	var d := DirAccess.open(dir_path)
	if d == null:
		return ""
	for f in d.get_files():
		if f.trim_suffix(".remap") == file_name:       # (a built game lists scenes as .remap files)
			return dir_path.path_join(file_name)
	for sub in d.get_directories():
		if sub.begins_with("."):
			continue
		var r := _scan(dir_path.path_join(sub), file_name)
		if r != "":
			return r
	return ""


static func _script_of_class(cls: String) -> Script:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == cls:
			return load(c["path"]) as Script
	return null


func _resolve_assets() -> void:
	if enemy_scene == null:
		enemy_scene = _load_found("enemy_npc.tscn") as PackedScene
	if boss_scene == null:
		boss_scene = _load_found("boss_npc.tscn") as PackedScene
	if character_data == null:
		character_data = _load_found("vow_data.tres") as CharacterData


## Loads the first HEALTHY file with this name. A copy that points at files which no longer exist (after folders were
## moved, say) is skipped, and the Output panel says exactly what it is missing.
func _load_found(file_name: String) -> Resource:
	var skipped: PackedStringArray = []
	for path in find_project_files(file_name):
		var missing := missing_dependency(path)
		if missing != "":
			skipped.append("%s  ->  needs %s, which does not exist" % [path, missing])
			continue
		var r := load(path)
		if r != null:
			for line in skipped:
				push_warning("StoryLevel: skipped a broken copy of %s:  %s.  Open it in Godot and use 'Fix Dependencies', or delete it." % [file_name, line])
			return r
	for line in skipped:
		push_warning("StoryLevel: could not use %s:  %s.  Open it in Godot and use 'Fix Dependencies'." % [file_name, line])
	return null


func _spawn_player() -> PlaytestPlayer:
	var ps := player_scene
	if ps == null:
		ps = _load_found("playtest_player.tscn") as PackedScene
	if ps == null:
		push_error("StoryLevel: no 'Player' node and no playtest_player.tscn found. Add your player scene as a child called Player.")
		return null
	var p := ps.instantiate() as PlaytestPlayer
	if p == null:
		push_error("StoryLevel: the player scene's root must be a PlaytestPlayer.")
		return null
	p.name = "Player"
	_player_source = "built from %s" % (ps.resource_path if ps.resource_path != "" else "the Player Scene slot")
	if p.character_data == null:
		p.character_data = character_data
	add_child(p)
	var start := get_node_or_null("PlayerStart") as Node2D
	if start != null:
		p.global_position = start.global_position
	return p


func _spawn_hud() -> PlaytestHUD:
	var hs := hud_scene
	if hs == null:
		hs = _load_found("playtest_hud.tscn") as PackedScene
	if hs == null:
		push_warning("StoryLevel: no 'HUD' node and no playtest_hud.tscn found, so there will be no HUD.")
		return null
	var h := hs.instantiate()
	if h.get_script() == null:
		h.set_script(_script_of_class("PlaytestHUD"))
	h.name = "HUD"
	_hud_source = "built from %s" % (hs.resource_path if hs.resource_path != "" else "the Hud Scene slot")
	add_child(h)
	return h as PlaytestHUD


# =====================================================================
#  giving the player an ability for this level (the tutorial teaches them one section at a time)
# =====================================================================

## Returns the player's ability of this kind ("AbilityFanBurst", "AbilityDash"...). If the player does not have it
## yet (for example the character data has no abilities until they are unlocked at the CyberDoc) and `grant` is true,
## it is created the same way the player creates its own abilities, added, and the HUD is refreshed.
## This only lasts for this level: the Player is rebuilt for every scene, and the character data is not touched.
func get_or_grant_ability(kind: String, grant: bool = true) -> Ability:
	if player == null:
		return null
	var script := _ability_script(kind)
	if script == null:
		push_warning("StoryLevel: no ability script called '%s' was found in the project." % kind)
		return null
	for a in player.abilities:
		if a != null and a.get_script() == script:
			return a
	if not grant:
		return null
	var ab := script.new() as Ability
	if ab == null:
		push_warning("StoryLevel: '%s' is not an Ability." % kind)
		return null
	player.add_child(ab)
	ab.setup(player)
	player.abilities.append(ab)
	_refresh_hud_abilities()
	ability_granted.emit(kind)
	return ab


## The input action that fires this ability: ability_<its position in the player's list>, like the player's own input uses.
func action_for_ability(ab: Ability) -> String:
	if player == null or ab == null:
		return ""
	var i := player.abilities.find(ab)
	return "" if i < 0 else "ability_%d" % (i + 1)


func _ability_script(kind: String) -> Script:
	var sc := _script_of_class(kind)
	if sc != null:
		return sc
	var path := find_project_file(kind + ".gd")
	return load(path) as Script if path != "" else null


## Makes the HUD show the abilities the player has now (its own setup only runs once, when it is bound).
func _refresh_hud_abilities() -> void:
	if hud == null or player == null:
		return
	if not ("_slots" in hud and "_slot_names" in hud and "_slot_enabled" in hud and hud.has_method("_key_text") and hud.has_method("_set_text")):
		return
	for i in range(hud._slots.size()):
		if not is_instance_valid(hud._slots[i]):
			continue
		var has: bool = i < player.abilities.size() and player.abilities[i] != null and hud._slot_enabled[i]
		hud._slots[i].visible = has
		if has:
			hud._set_text(hud._slot_names[i], hud.slot_label_format.replace("{key}", hud._key_text(i)).replace("{name}", player.abilities[i].ability_name))


# =====================================================================
#  enemy stats
# =====================================================================

## Stats for an enemy kind (StorySpawnPoint.Kind): your slot if filled, else a built-in version.
func get_stats(kind: int) -> EnemyStats:
	match kind:
		StorySpawnPoint.Kind.GRUNT:
			return grunt_stats if grunt_stats != null else _make(12.0, 6.0, 90.0, 0.0, 0.7, Color.WHITE)
		StorySpawnPoint.Kind.RUNNER:
			return runner_stats if runner_stats != null else _make(6.0, 4.0, 170.0, 0.0, 0.5, Color(1, 0.9, 0.4))
		StorySpawnPoint.Kind.TANK:
			return tank_stats if tank_stats != null else _make(60.0, 10.0, 55.0, 3.0, 1.0, Color(0.5, 0.7, 1.0))
		StorySpawnPoint.Kind.SHOOTER:
			if shooter_stats != null:
				return shooter_stats
			var s := _make(16.0, 4.0, 85.0, 0.0, 0.7, Color(1.0, 0.6, 0.6))
			s.ranged = true
			return s
		StorySpawnPoint.Kind.BOSS:
			return boss_stats if boss_stats != null else BossStats.new()
	return _make(12.0, 6.0, 90.0, 0.0, 0.7, Color.WHITE)


func _make(hp: float, dmg: float, spd: float, dur: float, body: float, tint: Color) -> EnemyStats:
	var s := EnemyStats.new()
	s.max_hp = hp
	s.damage = dmg
	s.speed = spd
	s.durability = dur
	s.body_scale = body
	s.tint = tint
	return s


func register_kill() -> void:
	kills += 1
	# With RoundStats the HUD's kill counter follows it by itself; without it, write our own count.
	if hud != null and _round_stats == null:
		hud.set_kills(kills)


func _process(delta: float) -> void:
	if track_survival_time and _round_stats != null and not is_complete and _round_stats.has_method("set_survival_time"):
		var t = _round_stats.get("survival_time")
		if t != null:
			_round_stats.set_survival_time(float(t) + delta)


# =====================================================================
#  opening run-in
# =====================================================================

func _run_intro() -> void:
	player.set_input_locked(true)
	var target := intro_run_to.global_position
	player._update_animation((target - player.global_position).normalized())     # run animation while she runs in
	var tw := create_tween()
	tw.tween_property(player, "global_position", target, maxf(intro_run_seconds, 0.05))
	await tw.finished
	player._update_animation(Vector2.ZERO)
	player.set_input_locked(false)
	intro_running = false
	intro_finished.emit()


# =====================================================================
#  ending
# =====================================================================

## Called by the encounter marked "Completes Level".
func complete_level() -> void:
	if is_complete:
		return
	is_complete = true
	level_completed.emit()
	if level_complete_text.strip_edges() != "":
		get_notice().show_big(level_complete_text, complete_delay, Color(0.78, 0.95, 0.10))
	_unlock_next()
	await _wait(complete_delay)
	if show_logo_at_end:
		await _play_ending_logo()
	_go_next()


func _play_ending_logo() -> void:
	var ui := TutorialUI.new()
	ui.name = "EndingCard"
	ui.skin = _skin()
	add_child(ui)
	var tw := ui.fade_to(1.0, 1.4)
	await tw.finished
	ui.set_skip_hint_visible(false)
	ui.show_logo(ending_logo, ending_logo_text)
	await ui.logo_dismissed


func _unlock_next() -> void:
	var lm := get_node_or_null("/root/LevelManager")
	if lm != null and unlock_next_level and level_number > 0 and lm.has_method("_unlock_level"):
		lm._unlock_level(level_number + 1)


func _go_next() -> void:
	if mark_tutorial_done:
		SaveData.mark_tutorial_done()
	get_tree().paused = false
	if next_scene != null:
		get_tree().change_scene_to_packed(next_scene)
	elif ResourceLoader.exists(LEVEL_SELECT_PATH):
		get_tree().change_scene_to_file(LEVEL_SELECT_PATH)
	else:
		push_warning("StoryLevel: level completed but no Next Scene is set. Assign one in the Inspector.")


func _wait(seconds: float) -> void:
	var t := Timer.new()
	t.one_shot = true
	add_child(t)
	t.start(maxf(seconds, 0.05))
	await t.timeout
	t.queue_free()


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		skip_to_next_scene()


## What TAB does: skip everything and go on (counts as completed).
func skip_to_next_scene() -> void:
	if is_complete:
		return
	is_complete = true
	_unlock_next()
	_go_next()


func _keep_alive(cur: float, mx: float) -> void:
	if cur < mx * 0.35:
		player.current_hp = mx
		player.health_changed.emit(mx, mx)


# =====================================================================
#  shared UI pieces
# =====================================================================

## The skin everything uses: your Ui Skin (if you gave one), plus the characters from the easy fields above.
func _skin() -> UISkin:
	if _skin_cache == null:
		_build_skin()
	return _skin_cache


func _build_skin() -> void:
	var s: UISkin = ui_skin.duplicate() as UISkin if ui_skin != null else UISkin.new()
	var list: Array[DialogueSpeaker] = []
	for sp in s.speakers:
		if sp != null:
			list.append(sp)
	for entry in [[hero_name, hero_portrait, hero_side], [guide_name, guide_portrait, guide_side], [other_name, other_portrait, other_side]]:
		var nm: String = String(entry[0]).strip_edges()
		if nm == "" or entry[1] == null:
			continue                                   # no picture: the character just talks, name as text
		for i in range(list.size() - 1, -1, -1):       # the easy fields win over a same-named character in the skin
			if list[i].speaker_name.to_lower() == nm.to_lower():
				list.remove_at(i)
		var sp := DialogueSpeaker.new()
		sp.speaker_name = nm
		sp.portrait = entry[1]
		sp.side = entry[2]
		list.append(sp)
	s.speakers = list
	s.portrait_style = UISkin.PortraitStyle.STAGE if big_portraits else UISkin.PortraitStyle.IN_BOX
	_skin_cache = s


## The shared message banner (created on first use).
func get_notice() -> StoryNotice:
	var n := get_tree().get_first_node_in_group("story_notice") as StoryNotice
	if n == null:
		n = StoryNotice.new()
		n.skin = _skin()
		add_child(n)
	return n


## The shared conversation box (created on first use).
func get_dialogue() -> DialogueBox:
	var d := get_tree().get_first_node_in_group("story_dialogue") as DialogueBox
	if d == null:
		d = DialogueBox.new()
		d.skin = _skin()
		add_child(d)
		d.add_to_group("story_dialogue")
	return d


## The shared key prompt (created on first use).
func get_prompt() -> StoryPrompt:
	var p := get_tree().get_first_node_in_group("story_prompt") as StoryPrompt
	if p == null:
		p = StoryPrompt.new()
		p.skin = _skin()
		add_child(p)
	return p


func _on_player_died() -> void:
	if is_complete:
		return
	if hud != null:
		hud.show_end("GAME OVER")
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		get_tree().paused = false
		if menu_scene != null:
			get_tree().change_scene_to_packed(menu_scene)
		elif ResourceLoader.exists(MENU_PATH):
			get_tree().change_scene_to_file(MENU_PATH)
	elif event.keycode == KEY_F1 and debug_keys:
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				e.take_damage(99999.0)
