class_name AbilityDeathMark
extends Ability
## Reaper, ability 3: mark the enemy closest to the aim cursor.
## For a few seconds it takes extra damage from every hit. If it dies while marked,
## it bursts and hurts the enemies around it - chain your kills.

## Seconds the mark lasts.
@export var mark_seconds: float = 5.0
## Extra damage the marked enemy takes, as a share of each hit (0.5 = +50%).
@export var bonus_share: float = 0.5
## How far from the aim cursor to look for a target.
@export var search_radius: float = 320.0
## The burst when a marked enemy dies.
@export var burst_radius: float = 180.0
@export var burst_damage: float = 45.0

var _target: Node2D
var _target_hp: float = 0.0
var _until_ms: int = 0
var _fx: ReaperFX
var _applying_bonus: bool = false


func _init() -> void:
	ability_name = "Death Mark"
	cooldown_time = 8.0
	damage = 15.0


func activate() -> void:
	var point: Vector2 = caster.global_position + caster.get_aim_direction() * caster.aim_radius
	var best: Node2D = null
	var best_d := search_radius
	for e in caster.get_tree().get_nodes_in_group("enemies"):
		if not (e.has_signal("health_changed") and e.has_signal("died")):
			continue
		var d: float = e.global_position.distance_to(point)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		_cooldown_left = 0.5          # nothing to mark: don't waste the whole cooldown
		return
	_clear()
	_target = best
	_target_hp = _target.current_hp
	_until_ms = Time.get_ticks_msec() + int(mark_seconds * 1000.0)
	_target.health_changed.connect(_on_target_hurt)
	_target.died.connect(_on_target_died)
	_fx = ReaperFX.mark(_target, mark_seconds)
	_target.take_damage(damage)


func _process(delta: float) -> void:
	super._process(delta)
	if _target != null and (not is_instance_valid(_target) or Time.get_ticks_msec() > _until_ms):
		_clear()


func _on_target_hurt(current: float, _max: float) -> void:
	var lost := _target_hp - current
	_target_hp = current
	if lost <= 0.0 or _applying_bonus or not is_instance_valid(_target):
		return
	_applying_bonus = true            # the bonus hit fires this signal again; don't bonus the bonus
	_target.take_damage(lost * bonus_share)
	_applying_bonus = false


func _on_target_died(_enemy) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var origin := _target.global_position
	var root: Node = caster.get_tree().current_scene
	for e in caster.get_tree().get_nodes_in_group("enemies"):
		if e != _target and e.global_position.distance_to(origin) <= burst_radius:
			e.take_damage(burst_damage)
	RingFX.spawn(root, origin, burst_radius, ReaperFX.PURPLE, 0.4)
	_clear()


func _clear() -> void:
	if _target != null and is_instance_valid(_target):
		if _target.health_changed.is_connected(_on_target_hurt):
			_target.health_changed.disconnect(_on_target_hurt)
		if _target.died.is_connected(_on_target_died):
			_target.died.disconnect(_on_target_died)
	if _fx != null and is_instance_valid(_fx):
		_fx.queue_free()
	_target = null
	_fx = null
