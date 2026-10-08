class_name AbilityBladeStorm
extends Ability
## Ability 3 (key 3): a ring of slashes flying out in every direction at once.
## This is a good template for your own abilities: copy it, change _init() and activate().

## How many slashes in the ring.
@export var slash_count: int = 8


func _init() -> void:
	ability_name = "Blade Storm"
	cooldown_time = 6.0
	damage = 14.0        # per slash


func activate() -> void:
	# Line the ring up with where you are aiming, then spread the slashes evenly around you.
	var start: float = caster.get_aim_direction().angle()
	for i in range(slash_count):
		var angle := start + TAU * float(i) / float(slash_count)
		caster.fire_bullet(Vector2.RIGHT.rotated(angle), damage)
	caster.shake(6.0, 0.15)
