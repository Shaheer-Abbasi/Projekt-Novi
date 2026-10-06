class_name Ability
extends Node
## Base class for every ability. Subclass it and override activate().
## `caster` is the PlaytestPlayer; it exposes get_aim_direction(),
## fire_bullet(), apply_dash(), set_input_locked(), shake().

signal activated

@export var ability_name: String = "Ability"
@export var cooldown_time: float = 1.0
@export var damage: float = 10.0

var caster  # untyped on purpose: lets abilities call the player's methods freely
var _cooldown_left: float = 0.0


func setup(owner_caster) -> void:
	caster = owner_caster


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func is_ready() -> bool:
	return _cooldown_left <= 0.0


func cooldown_left() -> float:
	return _cooldown_left


func try_activate() -> void:
	if not is_ready():
		return
	_cooldown_left = cooldown_time
	activated.emit()
	activate()


## Override in subclasses.
func activate() -> void:
	pass
