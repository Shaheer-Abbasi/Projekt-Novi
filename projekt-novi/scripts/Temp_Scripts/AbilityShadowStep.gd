class_name AbilityShadowStep
extends Ability
## Reaper, ability 2: blink to the aim cursor, cutting every enemy along the way.
## She cannot be hit while she moves (it is a very fast dash, so walls still stop her).

## How long the blink takes, in seconds.
@export var travel_time: float = 0.12
## How close to her path an enemy must be to get cut.
@export var path_width: float = 70.0


func _init() -> void:
	ability_name = "Shadow Step"
	cooldown_time = 5.0
	damage = 30.0


func activate() -> void:
	var start: Vector2 = caster.global_position
	var aim: Vector2 = caster.get_aim_direction()
	var distance: float = caster.aim_radius
	caster.apply_dash(aim, distance / travel_time, travel_time)
	await caster.get_tree().create_timer(travel_time + 0.02).timeout
	if not is_instance_valid(caster):
		return
	var end: Vector2 = caster.global_position
	for e in caster.get_tree().get_nodes_in_group("enemies"):
		var p: Vector2 = Geometry2D.get_closest_point_to_segment(e.global_position, start, end)
		if p.distance_to(e.global_position) <= path_width:
			e.take_damage(damage)
	ReaperFX.trail(caster.get_tree().current_scene, start, end)
