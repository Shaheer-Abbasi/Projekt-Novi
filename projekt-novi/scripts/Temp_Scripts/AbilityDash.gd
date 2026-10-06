class_name AbilityDash
extends Ability
## Ability 3: short dash with brief invulnerability. Goes the way you are
## moving, or toward the aim cursor if you are standing still.

@export var dash_speed: float = 950.0
@export var dash_duration: float = 0.18


func _init() -> void:
	ability_name = "Dash"
	cooldown_time = 2.0
	damage = 0.0


func activate() -> void:
	var dir: Vector2 = caster.get_move_direction()
	if dir == Vector2.ZERO:
		dir = caster.get_aim_direction()
	caster.apply_dash(dir, dash_speed, dash_duration)
