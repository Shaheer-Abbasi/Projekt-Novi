class_name AbilityBouquet
extends Ability
## Ability 3 (key 3): throw a bouquet toward the aim cursor. It lands on the aim ring
## and bursts into rose petals, damaging everything in the burst radius.
## (This is also a good template for your own abilities.)

## Size of the petal burst, in pixels.
var burst_radius: float = 130.0
## How far it is thrown. 0 = it lands right on the aim ring (your attack range).
var throw_distance: float = 0.0


func _init() -> void:
	ability_name = "Bouquet Toss"
	cooldown_time = 5.0
	damage = 55.0


func activate() -> void:
	var dir: Vector2 = caster.get_aim_direction()
	var dist: float = throw_distance if throw_distance > 0.0 else caster.aim_radius
	var from: Vector2 = caster.global_position + dir * 20.0
	var to: Vector2 = caster.global_position + dir * dist
	# Optional: your own bouquet art, set on the Player node (Bouquet Texture). Empty = built-in art.
	var tex = caster.get("bouquet_texture")
	BouquetProjectile.spawn(caster.get_tree().current_scene, from, to, damage, burst_radius, tex)
