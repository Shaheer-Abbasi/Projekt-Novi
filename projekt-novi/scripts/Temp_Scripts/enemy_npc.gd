class_name EnemyNPC
extends CharacterBody2D
## Chaser enemy. EVERY combat number comes from its EnemyStats:
## HP, Damage, Speed, Durability. Change them in the .tres, or at
## runtime through `stats` / scale_stats(). This node works on its own copy.

signal died(enemy: EnemyNPC)
signal health_changed(current_hp: float, max_hp: float)

@export var stats: EnemyStats

var current_hp: float = 1.0
var player: PlaytestPlayer
var _contact_left: float = 0.0
var _base_tint: Color = Color.WHITE
var _dead: bool = false
var _flash_tween: Tween

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
	_find_player()


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as PlaytestPlayer


## Difficulty scaling hook (the spawner calls this).
func scale_stats(hp_multiplier: float, damage_multiplier: float) -> void:
	stats.max_hp *= hp_multiplier
	current_hp = stats.max_hp
	stats.damage *= damage_multiplier


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_instance_valid(player):
		_find_player()
		return
	var to_player := player.global_position - global_position
	velocity = _compute_velocity(to_player)
	move_and_slide()
	if absf(to_player.x) > 2.0:
		sprite.flip_h = to_player.x < 0.0

	_contact_left -= delta
	if _contact_left <= 0.0:
		for body in contact_area.get_overlapping_bodies():
			if body.is_in_group("player"):
				body.take_damage(stats.damage)
				_contact_left = stats.contact_cooldown
				break


## Movement rule. Bosses override this.
func _compute_velocity(to_player: Vector2) -> Vector2:
	if to_player.length() < 1.0:
		return Vector2.ZERO
	return to_player.normalized() * stats.speed


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
