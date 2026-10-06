class_name EnemyNPC
extends CharacterBody2D
## Enemy. EVERY combat number comes from its EnemyStats:
## HP, Damage, Speed, Durability. Change them in the .tres, or at
## runtime through `stats` / scale_stats(). This node works on its own copy.
## By default it CHASES you. If stats.ranged is on, it keeps its distance,
## strafes, and shoots lasers at you instead (like your Robot in Level 1).

signal died(enemy: EnemyNPC)
signal health_changed(current_hp: float, max_hp: float)

@export var stats: EnemyStats

var current_hp: float = 1.0
var player: PlaytestPlayer
var _contact_left: float = 0.0
var _base_tint: Color = Color.WHITE
var _dead: bool = false
var _flash_tween: Tween
var _attack_left: float = 1.0
var _strafe_sign: float = 1.0
var _strafe_left: float = 2.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var contact_area: Area2D = $ContactArea


func _ready() -> void:
	add_to_group("enemies")
	if stats == null:
		stats = EnemyStats.new()
	else:
		stats = stats.duplicate()  # private copy: safe to modify at runtime
	current_hp = stats.max_hp
	scale = Vector2.ONE * stats.body_scale
	_base_tint = stats.tint
	sprite.modulate = _base_tint
	_attack_left = randf_range(0.8, 1.6)               # first shot after about a second
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	_strafe_left = randf_range(1.5, 3.0)
	_find_player()


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as PlaytestPlayer


## Difficulty scaling hook (the spawner calls this).
func scale_stats(hp_multiplier: float, damage_multiplier: float) -> void:
	stats.max_hp *= hp_multiplier
	current_hp = stats.max_hp
	stats.damage *= damage_multiplier
	stats.projectile_damage *= damage_multiplier


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_instance_valid(player):
		_find_player()
		return
	var to_player := player.global_position - global_position
	velocity = _compute_velocity(to_player)
	move_and_slide()
	if stats.ranged:
		_clamp_to_arena()   # shooters back away from you, so keep them from leaving the stage
	if absf(to_player.x) > 2.0:
		sprite.flip_h = to_player.x < 0.0

	_contact_left -= delta
	if _contact_left <= 0.0:
		for body in contact_area.get_overlapping_bodies():
			if body.is_in_group("player"):
				body.take_damage(stats.damage)
				_contact_left = stats.contact_cooldown
				break

	if stats.ranged:
		_update_ranged(delta, to_player.length())


## Movement rule. Bosses override this.
func _compute_velocity(to_player: Vector2) -> Vector2:
	if stats.ranged:
		return _ranged_velocity(to_player)
	if to_player.length() < 1.0:
		return Vector2.ZERO
	return to_player.normalized() * stats.speed


## Ranged movement (same idea as your Robot): too far = approach, too close = back away,
## in between = strafe sideways.
func _ranged_velocity(to_player: Vector2) -> Vector2:
	var d := to_player.length()
	if d < 1.0:
		return Vector2.ZERO
	var dir := to_player / d
	var desired: Vector2
	if d > stats.preferred_distance:
		desired = dir
	elif d < stats.too_close_distance:
		desired = -dir
	else:
		desired = dir.orthogonal() * _strafe_sign
	return desired.normalized() * stats.speed


func _update_ranged(delta: float, distance: float) -> void:
	_strafe_left -= delta
	if _strafe_left <= 0.0:
		_strafe_sign = -_strafe_sign
		_strafe_left = randf_range(1.5, 3.0)
	_attack_left -= delta
	if _attack_left <= 0.0 and distance <= stats.attack_range:
		_attack_left = stats.attack_cooldown
		_shoot()


## Fires a laser at where the player is right now (you can dodge it).
func _shoot() -> void:
	if not is_instance_valid(player):
		return
	var dir := (player.global_position - global_position).normalized()
	EnemyProjectile.spawn(get_parent(), global_position + dir * 20.0, dir, stats.projectile_speed, stats.projectile_damage, true)


func _clamp_to_arena() -> void:
	var stage := get_parent()
	if stage != null and "arena_rect" in stage:
		var r: Rect2 = stage.arena_rect
		global_position = global_position.clamp(r.position + Vector2(40, 40), r.end - Vector2(40, 40))


func take_damage(amount: float) -> void:
	if _dead:
		return
	var dealt := maxf(amount - stats.durability, 1.0)
	current_hp -= dealt
	health_changed.emit(current_hp, stats.max_hp)
	_hit_flash()
	queue_redraw()
	if current_hp <= 0.0:
		_die()


func _hit_flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	sprite.modulate = Color(1.0, 0.45, 0.45)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", _base_tint, 0.12)


func _die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	RingFX.spawn(get_parent(), global_position, 36.0 * scale.x, Color(1.0, 0.8, 0.5), 0.25)
	queue_free()


func _draw() -> void:
	if current_hp >= stats.max_hp:
		return
	var width := 70.0
	var ratio := clampf(current_hp / stats.max_hp, 0.0, 1.0)
	draw_rect(Rect2(-width * 0.5, -82.0, width, 7.0), Color(0.12, 0.02, 0.02, 0.9), true)
	draw_rect(Rect2(-width * 0.5, -82.0, width * ratio, 7.0), Color(1.0, 0.08, 0.12), true)
