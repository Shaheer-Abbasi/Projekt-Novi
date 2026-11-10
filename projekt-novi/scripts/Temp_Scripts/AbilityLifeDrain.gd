class_name AbilityLifeDrain
extends Ability
## Reaper's first ability: drain the nearest enemy and recover that HP over time.

const HEAL_TICKS := 6

@export_range(0.1, 10.0, 0.1) var heal_duration: float = 3.0


func _init() -> void:
	ability_name = "Life Drain"
	cooldown_time = 8.0
	damage = 24.0


func activate() -> void:
	var player := caster as PlaytestPlayer
	var target := _find_closest_enemy(player.global_position)
	if target == null:
		_cooldown_left = 0.0
		return

	var hp_before := _enemy_hp(target)
	target.call("take_damage", damage)
	var drained_hp := hp_before - _enemy_hp(target)
	if drained_hp <= 0.0:
		return

	var heal_per_tick := drained_hp / HEAL_TICKS
	var tick_delay := heal_duration / HEAL_TICKS
	var healing := create_tween()
	for tick in range(HEAL_TICKS):
		healing.tween_callback(player.heal.bind(heal_per_tick)).set_delay(tick_delay)


func _find_closest_enemy(origin: Vector2) -> Node2D:
	var closest: Node2D = null
	var closest_distance_squared := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D or enemy.is_queued_for_deletion() or not enemy.has_method("take_damage"):
			continue
		if _enemy_hp(enemy) <= 0.0 or (enemy is EnemyNPC and enemy._dead):
			continue
		var distance_squared := origin.distance_squared_to(enemy.global_position)
		if distance_squared < closest_distance_squared:
			closest = enemy
			closest_distance_squared = distance_squared
	return closest


func _enemy_hp(enemy: Node2D) -> float:
	if enemy is EnemyNPC:
		return maxf(enemy.current_hp, 0.0)
	# The legacy Robot stores its HP as an integer named health.
	if "health" in enemy:
		return maxf(float(enemy.get("health")), 0.0)
	return 0.0
