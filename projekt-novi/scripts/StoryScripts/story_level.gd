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
## ON: pressing Esc leaves the level for the menu. OFF: Esc does nothing in this level.
@export var escape_to_menu: bool = true

@export_group("Fade in")
## The level starts on a plain color and fades up to the picture, instead of snapping on. 0 = no fade.
@export var fade_in_seconds: float = 1.2
## The color it fades in from (black by default; try white for a bright flash).
@export var fade_color: Color = Color.BLACK

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
## The player starts with NO abilities, whatever her character file says. Tick this for a tutorial that teaches them one at a time
## (each room's key prompt gives her its ability). Off = she starts with the abilities in her character file.
@export var start_with_no_abilities: bool = false

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

@export_group("Clear cinematic (slow-mo, zoom, pan to the door)")
## When the LAST enemy of a room falls: slow motion and a zoom on it, the player is held still, the camera pans to the door that opens, then back to her.
## Bosses get a longer slow motion with a screen shake. Turn it off for the whole level here, or for one room on its encounter node.
@export var clear_cinematics: bool = true
## How slow time gets (0.25 = quarter speed).
@export_range(0.05, 1.0, 0.01) var slow_mo_scale: float = 0.25
## How long the slow motion lasts, in REAL seconds, for a normal room.
@export var slow_mo_seconds: float = 1.3
## The same for a boss.
@export var boss_slow_mo_seconds: float = 3.0
## How far the camera zooms in on the last enemy (1.5 = 50% closer).
@export var cinematic_zoom: float = 1.5
## Seconds for each camera move (to the door, then back to the player).
@export var pan_seconds: float = 1.0
## Seconds the camera stays on the door once it opens.
@export var door_hold_seconds: float = 0.9
## Screen shake strength for a boss, in pixels. 0 = none.
@export var boss_shake: float = 8.0
## Slow the sound down during the slow motion (it also drops in pitch). Turn off to keep the sound at normal speed.
@export var slow_mo_audio: bool = true
## How slow the sound gets: 1.0 = no change, 0.25 = as slow as the picture. Higher = gentler. (It eases in and out.)
@export_range(0.25, 1.0, 0.01) var slow_mo_audio_speed: float = 0.6

@export_group("Enemy death effect (blink, disintegrate, fade)")
## Enemies blink a different color when they die, then break into pixels that drift away and fade (instead of vanishing at once).
## The level adds a DeathEffects node for this. To change the colors / timing, add your own DeathEffects node to the level: the level then uses yours.
@export var enemy_death_effect: bool = true

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
## Copy the Inspector settings of the Player AND of the Ultimate cinematic in your playtest scene (slash sound, slash pictures,
## the Ultimate's voice line, portrait and text...) onto the ones this level builds. Those settings live in that scene, not in the
## player / cutscene scripts, so without this they are lost. (Her character data and abilities are never copied.)
@export var copy_player_settings: bool = true
## The scene whose Player to copy. Empty = the level looks for playtest.tscn by name.
@export var copy_player_settings_from: PackedScene
@export var player_scene: PackedScene
@export var hud_scene: PackedScene
@export var character_data: CharacterData

var player: PlaytestPlayer
var hud: PlaytestHUD
var arena_rect: Rect2 = Rect2(-100000.0, -100000.0, 200000.0, 200000.0)
var kills: int = 0
var is_complete: bool = false
var intro_running: bool = false
var is_cinematic: bool = false

var _settings_root: Node             # your playtest scene, opened once to copy settings from (freed at the end of _ready)
var _settings_name: String = ""
var _audio_tween: Tween
var _skin_cache: UISkin             # the skin everything uses: your Ui Skin (if any) + the characters above
var _player_source: String = ""     # where the Player came from (for the startup message)
var _hud_source: String = ""
var _round_stats: Node          # your RoundStats autoload, if the project has one
var _xp: Node                   # your XpManager autoload, if the project has one

static var _file_cache: Dictionary = {}


func _ready() -> void:
	_start_fade_in()                              # first, so the very first frame is already covered
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
	if start_with_no_abilities and player != null:
		_clear_abilities()
	hud = get_node_or_null("HUD") as PlaytestHUD
	if hud != null:
		_hud_source = "a node called HUD in the scene"
	if hud == null:
		hud = _spawn_hud()
	if get_tree().get_first_node_in_group("ultimate_cutscene") == null:
		add_child(_make_cutscene())                # put your own UltimateCutscene node in the scene to use yours instead
	if world_bounds.size != Vector2.ZERO:
		arena_rect = world_bounds
	if player != null:
		player.set_arena(arena_rect)
		player.died.connect(_on_player_died)
		if cant_lose:
			player.health_changed.connect(_keep_alive)
	if hud != null and player != null:
		hud.bind_player(player)
		if start_with_no_abilities:
			_refresh_hud_abilities()
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
	if enemy_death_effect and _find_death_effects() == null:
		add_child(DeathEffects.new())
	if allow_tab_skip:
		get_tree().root.window_input.connect(_on_window_input)
	if intro_run_to != null and player != null:
		intro_running = true
		_run_intro.call_deferred()
	_free_settings_source()
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
	if is_cinematic:
		_set_time_scale(1.0)                      # never leave the game in slow motion after a scene change
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


## Covers the screen with Fade Color and fades it away over Fade In Seconds (see FadeCover below).
func _start_fade_in() -> void:
	if fade_in_seconds <= 0.0:
		return
	var cover := FadeCover.new()
	cover.name = "FadeIn"
	cover.setup(fade_color, fade_in_seconds)
	add_child(cover)


## The cover used by Fade In. It never blocks the mouse or keys, sits above everything (HUD, dialogue), keeps going while the game
## is paused, and removes itself when done. It stays fully covered through the first frames and then counts time in SMALL steps,
## so a long first frame (a level that is slow to build) can not use up the fade before you ever see it.
class FadeCover extends CanvasLayer:
	var seconds: float = 1.0
	var _rect: ColorRect
	var _elapsed: float = 0.0
	var _frames: int = 0

	func setup(color: Color, secs: float) -> void:
		layer = 120
		process_mode = Node.PROCESS_MODE_ALWAYS
		seconds = maxf(secs, 0.01)
		_rect = ColorRect.new()
		_rect.color = color
		_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_rect)

	func _process(delta: float) -> void:
		_frames += 1
		if _frames <= 2:
			return                                                        # the long first frames: stay fully covered
		_elapsed += minf(delta / maxf(Engine.time_scale, 0.001), 1.0 / 30.0)      # real time (not slow motion), at most 1/30 s per frame
		_rect.modulate.a = 1.0 - clampf(_elapsed / seconds, 0.0, 1.0)
		if _elapsed >= seconds:
			queue_free()


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
	_copy_player_settings(p)
	if p.character_data == null:
		p.character_data = character_data
	add_child(p)
	var start := get_node_or_null("PlayerStart") as Node2D
	if start != null:
		p.global_position = start.global_position
	return p


## Your playtest scene (the slot, else playtest.tscn by name), opened ONCE so settings can be copied from it. null = nothing to copy from.
func _settings_source() -> Node:
	if not copy_player_settings:
		return null
	if _settings_root != null:
		return _settings_root
	var src_scene := copy_player_settings_from
	if src_scene == null:
		src_scene = _load_found("playtest.tscn") as PackedScene
	if src_scene == null:
		return null
	_settings_name = src_scene.resource_path if src_scene.resource_path != "" else "the scene in Copy Player Settings From"
	_settings_root = src_scene.instantiate()
	return _settings_root


func _free_settings_source() -> void:
	if _settings_root != null:
		_settings_root.free()
		_settings_root = null


## Copies the Inspector settings of `src` onto `dst` (both use the same script), except the names in `skip`. Returns the names copied.
static func _copy_settings(src: Node, dst: Node, skip: Array) -> PackedStringArray:
	var copied: PackedStringArray = []
	for prop in src.get_property_list():
		var usage := int(prop["usage"])
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue                                   # only the settings you see in the Inspector
		var nm := String(prop["name"])
		if nm in skip:
			continue
		var v = src.get(nm)
		if v == null or (typeof(v) == typeof(dst.get(nm)) and v == dst.get(nm)):
			continue                                   # nothing set, or the same as the new one
		dst.set(nm, v)
		copied.append(nm)
	return copied


## Copies the Inspector settings of the Player in your playtest scene onto the Player this level builds.
func _copy_player_settings(p: Node) -> void:
	var scene_root := _settings_source()
	if scene_root == null:
		return
	var src: Node = scene_root.get_node_or_null("Player")
	if src == null or src.get_script() != p.get_script():
		push_warning("StoryLevel: could not copy Player settings: %s has no node called 'Player' using the same player script." % _settings_name)
		return
	var copied := _copy_settings(src, p, ["character_data"])      # character_data NEVER: it decides her stats and abilities, and the tutorial has its own
	print("StoryLevel: copied %d Player settings from %s: %s" % [copied.size(), _settings_name, ", ".join(copied) if not copied.is_empty() else "(nothing differed)"])


## The Ultimate cinematic this level uses: a new one, with the settings (voice line, portrait, text...) of the UltimateCutscene in your playtest scene.
func _make_cutscene() -> UltimateCutscene:
	var cs := UltimateCutscene.new()
	var scene_root := _settings_source()
	if scene_root != null:
		for n in scene_root.find_children("*", "Node", true, false):
			if n is UltimateCutscene:
				var copied := _copy_settings(n, cs, [])
				print("StoryLevel: copied %d Ultimate cinematic settings from %s: %s" % [copied.size(), _settings_name, ", ".join(copied) if not copied.is_empty() else "(nothing differed)"])
				break
	return cs


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
		push_warning("StoryLevel: no ability script called '%s' was found, so it could not be given to the player. The ability scripts in this project are: %s.  On the room's node, type the exact one in 'Prompt Ability Name'." % [kind, _known_ability_names()])
		return null
	for a in player.abilities:
		if a != null and a.get_script() == script:
			return a
	if not grant:
		print("StoryLevel: the player does not have %s and 'Grant Ability If Missing' is off, so it was not given." % kind)
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
	var action := action_for_ability(ab)
	if InputMap.has_action(action):
		print("StoryLevel: gave the player %s (%s) on key %s." % [kind, script.resource_path.get_file(), TutorialUI.key_text(action)])
	else:
		push_warning("StoryLevel: gave the player %s, but it is the player's ability number %d and the player has no key for that (%s does not exist), so it cannot be pressed." % [kind, player.abilities.size(), action])
	return ab


## The input action that fires this ability: ability_<its position in the player's list>, like the player's own input uses.
func action_for_ability(ab: Ability) -> String:
	if player == null or ab == null:
		return ""
	var i := player.abilities.find(ab)
	return "" if i < 0 else "ability_%d" % (i + 1)


## Finds the script for an ability kind. Tries, in order: the exact class name, the exact file name, then any ability script
## whose name CONTAINS the keyword (so "AbilityBouquet" also finds "AbilityBouquetThrow" or "AbilityBouquetToss").
func _ability_script(kind: String) -> Script:
	var sc := _script_of_class(kind)
	if sc != null:
		return sc
	var path := find_project_file(kind + ".gd")
	if path != "":
		return load(path) as Script
	var key := kind.trim_prefix("Ability").to_lower()
	if key != "":
		for c in ProjectSettings.get_global_class_list():
			if String(c["class"]).to_lower().contains(key) and _is_ability_script(load(c["path"]) as Script):
				print("StoryLevel: no ability called '%s'; using '%s' (its name contains '%s')." % [kind, c["class"], key])
				return load(c["path"]) as Script
		var files: Array = []
		_scan_prefix("res://", "ability", files)
		for f in files:
			if String(f).get_file().to_lower().contains(key):
				var cand := load(f) as Script
				if _is_ability_script(cand):
					print("StoryLevel: no ability called '%s'; using '%s' (its name contains '%s')." % [kind, String(f).get_file(), key])
					return cand
	return null


static func _is_ability_script(sc: Script) -> bool:
	if sc == null or not sc.can_instantiate():
		return false
	var b := sc.get_base_script()
	while b != null:
		if b.resource_path.get_file() == "Ability.gd" or String(b.get_global_name()) == "Ability":
			return true
		b = b.get_base_script()
	return false


## Every .gd file whose name starts with the prefix (case-insensitive), anywhere in res://.
static func _scan_prefix(dir_path: String, prefix: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for f in d.get_files():
		if f.to_lower().begins_with(prefix) and f.to_lower().ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_scan_prefix(dir_path.path_join(sub), prefix, out)


## The names of the ability scripts this project has (to show you the real names when one is not found).
func _known_ability_names() -> String:
	var names: PackedStringArray = []
	for c in ProjectSettings.get_global_class_list():
		if String(c["base"]) == "Ability":
			names.append(String(c["class"]))
	if names.is_empty():
		var files: Array = []
		_scan_prefix("res://", "ability", files)
		for f in files:
			names.append(String(f).get_file().get_basename())
	return ", ".join(names) if not names.is_empty() else "(none found)"


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
#  clear cinematic: slow-mo + zoom on the last enemy, pan to the door, pan back
# =====================================================================

## Plays the cinematic. focus = where the last enemy fell; doors = world positions to pan to; open_doors = called when the camera arrives at the first door;
## boss = longer slow motion and a screen shake. Returns when the player has control again.
func play_clear_cinematic(focus: Vector2, doors: Array, open_doors: Callable, boss: bool) -> void:
	if is_cinematic or player == null or player.camera == null:
		open_doors.call()
		return
	is_cinematic = true
	await get_tree().process_frame
	await get_tree().process_frame
	while get_tree().paused and is_inside_tree():          # a level-up screen (or a conversation) first: the cinematic waits for it
		await get_tree().process_frame
	if not is_inside_tree():
		return
	var pcam: Camera2D = player.camera
	var cam := Camera2D.new()                               # a separate camera, so the player's own camera is never touched
	cam.name = "ClearCinematicCamera"
	cam.limit_left = -10000000
	cam.limit_top = -10000000
	cam.limit_right = 10000000
	cam.limit_bottom = 10000000
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.global_position = pcam.get_screen_center_position()
	cam.zoom = pcam.zoom
	cam.make_current()
	# hold the player still and safe, and freeze anything still alive
	var was_locked: bool = player._input_locked
	var invuln_before: float = player._invuln_left
	player.set_input_locked(true)
	player.velocity = Vector2.ZERO
	player._invuln_left = 100000.0
	var frozen: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			frozen.append([e, e.process_mode])
			e.process_mode = Node.PROCESS_MODE_DISABLED
	# 1) slow motion, zooming in on the last enemy
	var dur := boss_slow_mo_seconds if boss else slow_mo_seconds
	var fx := _find_death_effects()
	if fx != null and fx.enabled:
		dur = maxf(dur, fx.total_seconds(boss))                # hold on the dying enemy until its effect is (mostly) done
	_set_time_scale(slow_mo_scale, 0.2)
	_move_camera(cam, focus, pcam.zoom * cinematic_zoom, dur * 0.7)
	await _shake_for(cam, dur, boss_shake if boss else 0.0)
	_set_time_scale(1.0, 0.4)
	# 2) pan to the door; it opens when the camera gets there
	var opened := false
	for pt in doors:
		await _move_camera_wait(cam, pt, pcam.zoom * 1.15, pan_seconds)
		if not opened:
			opened = true
			open_doors.call()
		await _real_wait(door_hold_seconds)
	if not opened:
		open_doors.call()
	# 3) back to the player
	await _move_camera_wait(cam, player.global_position, pcam.zoom, pan_seconds)
	pcam.make_current()
	cam.queue_free()
	player.set_input_locked(was_locked)
	player._invuln_left = invuln_before
	for pair in frozen:
		if is_instance_valid(pair[0]):
			pair[0].process_mode = pair[1]
	is_cinematic = false


func _find_death_effects() -> DeathEffects:
	return get_tree().get_first_node_in_group("death_effects") as DeathEffects


## Sets the game speed. The sound follows more gently (slow_mo_audio_speed) and eases over `ease_seconds` instead of jumping.
func _set_time_scale(scale: float, ease_seconds: float = 0.0) -> void:
	Engine.time_scale = scale
	if not slow_mo_audio:
		return
	var target := 1.0 if scale >= 1.0 else clampf(slow_mo_audio_speed, 0.05, 1.0)
	if _audio_tween != null and _audio_tween.is_valid():
		_audio_tween.kill()
	if ease_seconds <= 0.0 or not is_inside_tree():
		AudioServer.playback_speed_scale = target
		return
	_audio_tween = create_tween()
	_audio_tween.set_ignore_time_scale(true)
	_audio_tween.tween_property(AudioServer, "playback_speed_scale", target, ease_seconds)


## A wait that is not slowed by the slow motion (and pauses with the game).
func _real_wait(seconds: float) -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(maxf(seconds, 0.01))
	await tw.finished


func _move_camera(cam: Camera2D, pos: Vector2, zoom: Vector2, seconds: float) -> Tween:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(cam, "global_position", pos, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "zoom", zoom, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


func _move_camera_wait(cam: Camera2D, pos: Vector2, zoom: Vector2, seconds: float) -> void:
	var tw := _move_camera(cam, pos, zoom, seconds)
	await tw.finished


## Waits `seconds` of real time, shaking the camera (strength fades out) if strength > 0.
func _shake_for(cam: Camera2D, seconds: float, strength: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and is_inside_tree():
		await get_tree().process_frame
		if get_tree().paused:
			continue
		elapsed += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
		if strength > 0.0 and is_instance_valid(cam):
			cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * clampf(1.0 - elapsed / seconds, 0.0, 1.0)
	if is_instance_valid(cam):
		cam.offset = Vector2.ZERO


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

## Removes every ability the player was built with (Start With No Abilities). Her stats are untouched.
func _clear_abilities() -> void:
	var removed := 0
	for a in player.abilities:
		if a != null and is_instance_valid(a):
			a.queue_free()
			removed += 1
	player.abilities.clear()
	print("StoryLevel: Start With No Abilities removed %d abilities from the player." % removed)


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
		if not escape_to_menu:
			return
		get_tree().paused = false
		if menu_scene != null:
			get_tree().change_scene_to_packed(menu_scene)
		elif ResourceLoader.exists(MENU_PATH):
			get_tree().change_scene_to_file(MENU_PATH)
	elif event.keycode == KEY_F1 and debug_keys:
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				e.take_damage(99999.0)
