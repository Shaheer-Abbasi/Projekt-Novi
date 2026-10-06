class_name CharacterData
extends Resource
## One playable character: stats, basic attack, and its 4 abilities.
## Make a new .tres from this to add another character.

@export var character_name: String = "Vow"
@export var max_health: float = 120.0
@export var move_speed: float = 220.0

@export_group("Basic Attack (Left Click)")
@export var basic_damage: float = 12.0
## Seconds between shots while the mouse button is held.
@export var fire_cooldown: float = 0.4
## Radius of the aim ring in pixels. Basic bullets stop at this distance.
@export var attack_range: float = 170.0
@export var bullet_speed: float = 750.0

@export_group("Abilities")
## Key 1
@export var ability_1_script: GDScript
## Key 2
@export var ability_2_script: GDScript
## Key 3
@export var ability_3_script: GDScript
## Key 4 - the Ultimate (plays a short scene first)
@export var ability_4_script: GDScript
