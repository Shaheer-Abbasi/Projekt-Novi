class_name AbilityShockwave
extends Ability
## Ability 2: damage pulse around the caster.

@export var radius: float = 240.0


func _init() -> void:
	ability_name = "Shockwave"
	cooldown_time = 4.0
	damage = 40.0


func activate() -> void:
	var origin: Vector2 = caster.global_position
	for e in caster.get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(origin) <= radius:
			e.take_damage(damage)
	RingFX.spawn(caster.get_tree().current_scene, origin, radius, Color(0.3, 0.9, 1.0), 0.4)
	caster.shake(5.0, 0.15)
