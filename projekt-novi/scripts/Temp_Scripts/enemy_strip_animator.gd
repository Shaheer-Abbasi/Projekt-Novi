class_name EnemyStripAnimator
extends Node
## Animates an enemy drawn from a 4-frame strip (the layout of enemies.aseprite):
##   frame 0 = idle, 1 = moving, 2 = attacking, 3 = hurt.
## Add it as a child of an EnemyNPC / BossNPC whose Sprite2D has hframes = 4.

## Frames per second for the idle / moving bob while the enemy walks.
@export var move_fps: float = 5.0
## How long the hurt frame shows after a hit.
@export var hurt_seconds: float = 0.15

var _enemy: EnemyNPC
var _sprite: Sprite2D
var _hurt_left: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	_enemy = get_parent() as EnemyNPC
	_sprite = _enemy.get_node("Sprite2D") as Sprite2D
	_enemy.health_changed.connect(_on_hit)


func _on_hit(_current: float, _max: float) -> void:
	_hurt_left = hurt_seconds


func _process(delta: float) -> void:
	_t += delta
	if _hurt_left > 0.0:
		_hurt_left -= delta
		_sprite.frame = 3
	elif _enemy is BossNPC and (_enemy as BossNPC)._state != BossNPC.State.CHASE:
		_sprite.frame = 2                      # winding up, charging or recovering from an attack
	elif _enemy.velocity.length() > 5.0:
		_sprite.frame = int(_t * move_fps) % 2
	else:
		_sprite.frame = 0
