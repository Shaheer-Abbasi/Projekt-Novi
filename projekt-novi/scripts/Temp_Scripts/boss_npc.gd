class_name BossNPC
extends EnemyNPC
## Boss with two phases.
##   Phase 1: HP 51% - 100%  -> attacks in `phase_1_attacks`
##   Phase 2: HP 50% and under -> attacks in `phase_2_attacks` (+ speed/damage buff)
## Attacks are plain names. To give an attack its own animation, add an
## animation with the SAME NAME to this scene's AnimationPlayer. It plays
## automatically whenever that attack starts. `attack_started` is also
## emitted if you'd rather hook it from code.
##
## Built-in attacks: "slam" (telegraphed circle on the player),
## "charge" (windup then dash), "nova" (ring of projectiles).

signal phase_changed(phase: int)
signal attack_started(attack_name: String, phase: int)

enum State { CHASE, WINDUP, CHARGING, RECOVER }

@export var phase_1_attacks: Array[String] = ["slam", "charge"]
@export var phase_2_attacks: Array[String] = ["slam", "charge", "nova"]
@export var charge_speed: float = 650.0

var phase: int = 1
var boss_stats: BossStats

var _state: State = State.CHASE
var _state_left: float = 0.0
var _attack_timer: float = 2.0
var _current_attack: String = ""
var _charge_dir: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()

@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")


func _ready() -> void:
	if stats == null or not (stats is BossStats):
		stats = BossStats.new()
	super._ready()
	boss_stats = stats as BossStats
	_rng.randomize()
	add_to_group("boss")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _dead or not is_instance_valid(player):
		return
	match _state:
		State.CHASE:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_begin_attack()
		State.WINDUP:
			_state_left -= delta
			if _state_left <= 0.0:
				_execute_attack()
		State.CHARGING:
			_state_left -= delta
			if _state_left <= 0.0:
				_enter_recover(0.5)
		State.RECOVER:
			_state_left -= delta
			if _state_left <= 0.0:
				_state = State.CHASE


func _compute_velocity(to_player: Vector2) -> Vector2:
	match _state:
		State.CHARGING:
			return _charge_dir * charge_speed
		State.WINDUP, State.RECOVER:
			return Vector2.ZERO
	return super._compute_velocity(to_player)


# --- Attacks --------------------------------------------------------------

func _attack_interval() -> float:
	return boss_stats.attack_interval_phase_1 if phase == 1 else boss_stats.attack_interval_phase_2


func _begin_attack() -> void:
	var pool: Array[String] = phase_1_attacks if phase == 1 else phase_2_attacks
	if pool.is_empty():
		_attack_timer = _attack_interval()
		return
	_current_attack = pool[_rng.randi_range(0, pool.size() - 1)]
	attack_started.emit(_current_attack, phase)
	if anim_player != null and anim_player.has_animation(_current_attack):
		anim_player.play(_current_attack)
	_state = State.WINDUP
	match _current_attack:
		"slam":
			_state_left = 0.9 if phase == 1 else 0.65
			var r := 150.0 if phase == 1 else 190.0
			AoETelegraph.spawn(get_parent(), player.global_position, r, _state_left, stats.damage * 1.5)
			_set_tint(Color(1.0, 0.55, 0.3))
		"charge":
			_state_left = 0.7 if phase == 1 else 0.5
			_set_tint(Color(1.0, 0.9, 0.25))
		"nova":
			_state_left = 0.6
			_set_tint(Color(0.85, 0.4, 1.0))
		_:
			_state_left = 0.3


func _execute_attack() -> void:
	match _current_attack:
		"charge":
			_charge_dir = (player.global_position - global_position).normalized()
			_state = State.CHARGING
			_state_left = 0.65
		"nova":
			_fire_nova(16, 0.0)
			if phase == 2:
				get_tree().create_timer(0.35).timeout.connect(_fire_nova.bind(16, PI / 16.0))
			_enter_recover(0.8)
		_:
			_enter_recover(0.5)


func _fire_nova(count: int, angle_offset: float) -> void:
	if _dead:
		return
	for i in range(count):
		var dir := Vector2.RIGHT.rotated(angle_offset + TAU * float(i) / float(count))
		EnemyProjectile.spawn(get_parent(), global_position, dir, 270.0, stats.damage * 0.6)
	RingFX.spawn(get_parent(), global_position, 120.0 * scale.x * 0.5, Color(0.85, 0.4, 1.0), 0.35)


func _enter_recover(seconds: float) -> void:
	_state = State.RECOVER
	_state_left = seconds
	_attack_timer = _attack_interval()
	_set_tint(stats.tint)


func _set_tint(c: Color) -> void:
	_base_tint = c
	sprite.modulate = c


# --- Phases ---------------------------------------------------------------

func take_damage(amount: float) -> void:
	super.take_damage(amount)
	if not _dead and phase == 1 and current_hp <= stats.max_hp * 0.5:
		_enter_phase_2()


func _enter_phase_2() -> void:
	phase = 2
	stats.speed *= boss_stats.phase_2_speed_multiplier
	stats.damage *= boss_stats.phase_2_damage_multiplier
	stats.tint = Color(1.0, 0.45, 0.45)
	_enter_recover(1.0)  # brief stagger while the transition plays
	if anim_player != null and anim_player.has_animation("phase_transition"):
		anim_player.play("phase_transition")
	var base := scale
	var tw := create_tween()
	tw.tween_property(self, "scale", base * 1.2, 0.2)
	tw.tween_property(self, "scale", base, 0.3)
	RingFX.spawn(get_parent(), global_position, 260.0, Color(1.0, 0.3, 0.3), 0.6)
	if is_instance_valid(player):
		player.shake(10.0, 0.4)
	phase_changed.emit(phase)
