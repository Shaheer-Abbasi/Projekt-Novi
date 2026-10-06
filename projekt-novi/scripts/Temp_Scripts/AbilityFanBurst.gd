class_name AbilityFanBurst
extends Ability
## Ability 1: a fan of bullets toward the aim cursor.

@export var shot_count: int = 5
@export var spread_degrees: float = 36.0


func _init() -> void:
	ability_name = "Fan Burst"
	cooldown_time = 3.0
	damage = 12.0


func activate() -> void:
	var base: Vector2 = caster.get_aim_direction()
	var half := deg_to_rad(spread_degrees) * 0.5
	for i in range(shot_count):
		var t := 0.5 if shot_count == 1 else float(i) / float(shot_count - 1)
		caster.fire_bullet(base.rotated(lerpf(-half, half, t)), damage)
