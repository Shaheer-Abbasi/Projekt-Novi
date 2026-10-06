extends Node2D
## Playtest arena: runs the round.
##   - 10-minute timer (round_duration)
##   - spawns chaser enemies that get tougher over the round
##   - at 0:00 every normal enemy despawns and the boss appears
##   - boss HP bar shows bottom-center (HUD)
##
## Debug keys:  F1 = jump to the boss now     Esc = back to main menu

enum RoundState { PLAYING, BOSS, ENDED }

const ENEMY_SCENE := preload("res://scenes/TempScenes/enemy_npc.tscn")
const BOSS_SCENE := preload("res://scenes/TempScenes/boss_npc.tscn")
const GRUNT_PATH := "res://tempresources/grunt_stats.tres"
const FAST_PATH := "res://tempresources/fast_stats.tres"
const TANK_PATH := "res://tempresources/tank_stats.tres"
const BOSS_PATH := "res://tempresources/boss_stats.tres"

## Round length in seconds (600 = 10 minutes). Lower it while testing.
@export var round_duration: float = 600.0
@export var arena_size: Vector2 = Vector2(3200.0, 2200.0)
@export var max_enemies: int = 70
## Optional: your own stats for the ranged Shooter enemy. Leave empty to use the built-in one.
## (If you make your own, remember to turn "Ranged" ON in it.)
@export var shooter_stats: EnemyStats
## How far from the player enemies appear (keep above half the screen size).
@export var spawn_distance: float = 700.0

var time_left: float = 600.0
var state: RoundState = RoundState.PLAYING
var arena_rect: Rect2

var _spawn_cd: float = 1.0
var _grunt: EnemyStats
var _fast: EnemyStats
var _tank: EnemyStats
var _shooter: EnemyStats

@onready var player: PlaytestPlayer = $Player
@onready var hud: PlaytestHUD = $HUD


func _ready() -> void:
	arena_rect = Rect2(-arena_size * 0.5, arena_size)
	_grunt = _try_load(GRUNT_PATH) as EnemyStats
	if _grunt == null:
		_grunt = EnemyStats.new()
	_fast = _try_load(FAST_PATH) as EnemyStats
	_tank = _try_load(TANK_PATH) as EnemyStats
	_shooter = shooter_stats if shooter_stats != null else _default_shooter()
	time_left = round_duration
	RoundStats.reset()  # new round: currency, kills, survival time back to 0
	player.set_arena(arena_rect)
	player.global_position = arena_rect.get_center()
	player.died.connect(_on_player_died)
	hud.bind_player(player)
	hud.set_timer(time_left)
	queue_redraw()


func _try_load(path: String) -> Resource:
	if ResourceLoader.exists("res://scripts/Temp_Scripts/EnemyStats.gd"):
		return load("res://scripts/Temp_Scripts/EnemyStats.gd")
	return null


func _draw() -> void:
	draw_rect(arena_rect, Color(0.12, 0.2, 0.13))
	var step := 128.0
	var x := arena_rect.position.x
	while x <= arena_rect.end.x:
		draw_line(Vector2(x, arena_rect.position.y), Vector2(x, arena_rect.end.y), Color(1, 1, 1, 0.05), 2.0)
		x += step
	var y := arena_rect.position.y
	while y <= arena_rect.end.y:
		draw_line(Vector2(arena_rect.position.x, y), Vector2(arena_rect.end.x, y), Color(1, 1, 1, 0.05), 2.0)
		y += step
	draw_rect(arena_rect, Color(0.85, 0.2, 0.2, 0.8), false, 6.0)


func _process(delta: float) -> void:
	if state == RoundState.BOSS:
		# Countdown is stuck at 0 during the boss, but the player is still surviving.
		RoundStats.set_survival_time(RoundStats.survival_time + delta)
		return
	if state != RoundState.PLAYING:
		return
	time_left = maxf(time_left - delta, 0.0)
	hud.set_timer(time_left)
	RoundStats.set_survival_time(round_duration - time_left)  # elapsed = from the round timer
	_update_spawning(delta)
	if time_left <= 0.0:
		_start_boss_phase()


# --- Spawning -------------------------------------------------------------

func _progress() -> float:
	return clampf(1.0 - time_left / maxf(round_duration, 0.001), 0.0, 1.0)


func _update_spawning(delta: float) -> void:
	_spawn_cd -= delta
	if _spawn_cd > 0.0:
		return
	var p := _progress()
	_spawn_cd = lerpf(1.2, 0.35, p)
	if get_tree().get_nodes_in_group("enemies").size() >= max_enemies:
		return
	_spawn_enemy(p)

## The ranged Shooter, built in code so it needs no extra file.
func _default_shooter() -> EnemyStats:
	var s := EnemyStats.new()
	s.enemy_name = "Shooter"
	s.max_hp = 16.0                       # takes about two slashes
	s.damage = 4.0                        # contact damage
	s.speed = 85.0                        # same as your Robot
	s.contact_cooldown = 1.0
	s.body_scale = 0.7
	s.tint = Color(1.0, 0.6, 0.6)         # reddish, so you can tell them apart
	s.ranged = true
	s.preferred_distance = 300.0
	s.too_close_distance = 150.0
	s.attack_range = 520.0
	s.attack_cooldown = 2.2
	s.projectile_speed = 400.0
	s.projectile_damage = 8.0
	return s

func _pick_stats(p: float) -> EnemyStats:
	if _shooter != null and p > 0.05 and randf() < 0.15:   # about 1 in 7 spawns, after the first 30 seconds
		return _shooter
	var r := randf()
	if _tank != null and p > 0.25 and r < 0.15:
		return _tank
	if _fast != null and p > 0.10 and r < 0.40:
		return _fast
	return _grunt


func _spawn_enemy(p: float) -> void:
	var enemy := ENEMY_SCENE.instantiate() as EnemyNPC
	enemy.stats = _pick_stats(p)
	var angle := randf() * TAU
	var pos := player.global_position + Vector2.RIGHT.rotated(angle) * spawn_distance
	enemy.global_position = pos.clamp(arena_rect.position + Vector2(50, 50), arena_rect.end - Vector2(50, 50))
	add_child(enemy)
	enemy.scale_stats(1.0 + p * 2.0, 1.0 + p * 0.5)


# --- Boss -----------------------------------------------------------------

func _start_boss_phase() -> void:
	state = RoundState.BOSS
	hud.set_timer_text("BOSS")
	# Everything except the boss goes away.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var boss := BOSS_SCENE.instantiate() as BossNPC
	var bs := _try_load(BOSS_PATH) as BossStats
	if bs != null:
		boss.stats = bs
	add_child(boss)
	boss.global_position = (player.global_position + Vector2(0, -450.0)).clamp(
		arena_rect.position + Vector2(100, 100), arena_rect.end - Vector2(100, 100))
	boss.died.connect(_on_boss_died)
	hud.show_boss(boss)


func _on_boss_died(_b: EnemyNPC) -> void:
	state = RoundState.ENDED
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	hud.show_end("VICTORY")
	get_tree().paused = true


func _on_player_died() -> void:
	if state == RoundState.ENDED:
		return
	state = RoundState.ENDED
	hud.show_end("GAME OVER")
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 and state == RoundState.PLAYING:
			time_left = 0.0
		elif event.keycode == KEY_ESCAPE and ResourceLoader.exists("res://scenes/MainMenuScenes/main_menu.tscn"):
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/MainMenuScenes/main_menu.tscn")
