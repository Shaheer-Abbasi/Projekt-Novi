class_name AbilityUltimate
extends Ability
## Ability 4: the Ultimate. Plays the UltimateCutscene (game pauses),
## THEN fires the actual effect. If the scene has no cutscene node it
## just fires immediately.

@export var radius: float = 520.0

var _active: bool = false


func _init() -> void:
	ability_name = "Ultimate"
	cooldown_time = 40.0
	damage = 250.0


func try_activate() -> void:
	if not is_ready() or _active:
		return
	_active = true
	_cooldown_left = cooldown_time
	activated.emit()
	_run()


func _run() -> void:
	var cs := caster.get_tree().get_first_node_in_group("ultimate_cutscene") as UltimateCutscene
	if cs != null:
		caster.set_input_locked(true)
		cs.play(ability_name, caster.character_name)
		await cs.finished
		caster.set_input_locked(false)
	activate()
	_active = false


func activate() -> void:
	var origin: Vector2 = caster.global_position
	for e in caster.get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(origin) <= radius:
			e.take_damage(damage)
	var root: Node = caster.get_tree().current_scene
	RingFX.spawn(root, origin, radius, Color(1.0, 0.9, 0.3), 0.6)
	RingFX.spawn(root, origin, radius * 0.6, Color(0.3, 1.0, 1.0), 0.45)
	caster.shake(14.0, 0.5)
