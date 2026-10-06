class_name EnemyStats
extends Resource
## Modifiable stat block for any enemy. EnemyNPC makes its own copy of
## this at spawn, so changing one enemy's stats at runtime never touches
## the shared .tres file or other enemies.

@export_group("Combat")
@export var enemy_name: String = "Grunt"
@export var max_hp: float = 10.0
## Damage dealt to the player on contact.
@export var damage: float = 5.0
@export var speed: float = 90.0
## Flat damage subtracted from every hit it takes. A hit always does at least 1.
@export var durability: float = 0.0
## Seconds between contact-damage ticks against the player.
@export var contact_cooldown: float = 0.9

@export_group("Look")
## Scales the whole enemy (sprite + collision).
@export var body_scale: float = 1.0
@export var tint: Color = Color.WHITE

@export_group("Ranged attack")
## Turn ON to make this enemy keep its distance and shoot lasers instead of charging you.
@export var ranged: bool = false
## Tries to stay about this far from the player.
@export var preferred_distance: float = 300.0
## Backs away if the player gets closer than this.
@export var too_close_distance: float = 150.0
## Only shoots when the player is within this distance.
@export var attack_range: float = 520.0
## Seconds between shots.
@export var attack_cooldown: float = 2.2
## Laser speed in pixels per second.
@export var projectile_speed: float = 400.0
## Damage of each laser.
@export var projectile_damage: float = 8.0
