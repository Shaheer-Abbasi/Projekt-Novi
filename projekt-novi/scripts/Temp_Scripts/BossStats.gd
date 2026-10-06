class_name BossStats
extends EnemyStats
## Boss tuning on top of the normal enemy stats.

@export_group("Boss")
@export var boss_display_name: String = "Corporate Enforcer"
@export var phase_2_speed_multiplier: float = 1.3
@export var phase_2_damage_multiplier: float = 1.4
## Seconds of rest between attacks.
@export var attack_interval_phase_1: float = 3.0
@export var attack_interval_phase_2: float = 1.8


func _init() -> void:
	# Boss-sized defaults, so a bare BossStats.new() is already a real boss.
	# Values saved in a .tres file override these.
	enemy_name = "Boss"
	max_hp = 1200.0
	damage = 18.0
	speed = 70.0
	durability = 2.0
	contact_cooldown = 0.6
	body_scale = 2.4
	tint = Color(0.75, 0.5, 1.0)
