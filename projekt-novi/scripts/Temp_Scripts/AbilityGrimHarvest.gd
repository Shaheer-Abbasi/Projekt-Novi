class_name AbilityGrimHarvest
extends AbilityUltimate
## Reaper's Ultimate: after the cutscene, a huge scythe spin around her.
## Hits everything in range, and instantly finishes any enemy (not bosses) left under 25% HP.

## Enemies at or below this share of their HP are finished off.
@export var execute_below: float = 0.25


func _init() -> void:
	ability_name = "Grim Harvest"
	cooldown_time = 40.0
	damage = 180.0
	radius = 480.0


func activate() -> void:
	var origin: Vector2 = caster.global_position
	for e in caster.get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(origin) > radius:
			continue
		e.take_damage(damage)
		if is_instance_valid(e) and not e.is_in_group("boss") and "current_hp" in e and "stats" in e \
				and e.current_hp > 0.0 and e.current_hp <= e.stats.max_hp * execute_below:
			e.take_damage(e.current_hp + e.stats.durability + 1.0)      # executed
	var root: Node = caster.get_tree().current_scene
	for i in range(3):
		ReaperFX.arc(root, origin, Vector2.RIGHT.rotated(TAU * i / 3.0), radius * (0.5 + 0.2 * i), TAU / 3.0, 0.5)
	RingFX.spawn(root, origin, radius, ReaperFX.PURPLE, 0.6)
	caster.shake(14.0, 0.5)
