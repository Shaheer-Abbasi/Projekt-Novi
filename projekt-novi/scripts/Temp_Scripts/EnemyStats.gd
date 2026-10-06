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
