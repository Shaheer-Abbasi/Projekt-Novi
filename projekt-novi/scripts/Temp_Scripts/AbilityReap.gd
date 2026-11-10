class_name AbilityReap
extends Ability
## Reaper, ability 1: a wide scythe sweep toward the aim cursor.
## Every enemy caught in it heals her a little.

## How far the sweep reaches, in pixels.
@export var radius: float = 260.0
## How wide the sweep is, in degrees.
@export var spread_degrees: float = 180.0
## HP healed per enemy hit, and the most one sweep can heal.
@export var heal_per_hit: float = 3.0
@export var max_heal: float = 18.0


func _init() -> void:
	ability_name = "Reap"
	cooldown_time = 4.0
	damage = 28.0


func activate() -> void:
	var origin: Vector2 = caster.global_position
	var aim: Vector2 = caster.get_aim_direction()
	var half := deg_to_rad(spread_degrees) / 2.0
	var hits := 0
	for e in caster.get_tree().get_nodes_in_group("enemies"):
		var to: Vector2 = e.global_position - origin
		if to.length() <= radius and absf(aim.angle_to(to)) <= half:
			e.take_damage(damage)
			hits += 1
	if hits > 0:
		caster.heal(minf(hits * heal_per_hit, max_heal))
	ReaperFX.arc(caster.get_tree().current_scene, origin, aim, radius * 0.75, deg_to_rad(spread_degrees))
	caster.shake(4.0, 0.12)
