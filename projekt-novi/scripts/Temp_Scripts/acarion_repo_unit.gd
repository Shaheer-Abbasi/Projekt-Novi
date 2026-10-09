class_name AcarionRepoUnit
extends BossNPC
## Tutorial / Level 2 boss.
## Stage 1: holds the center, fires lasers at range, uses a short cone in melee.
## Staying close for 5 seconds forces a heavily telegraphed spin AoE.
## Stage 2: at 25% HP the unit enters kamikaze mode and detonates, killing the player.

enum RepoState { COMBAT, CONE_WINDUP, SPIN_WINDUP, KAMIKAZE }

@export_group("Ranged")
@export var laser_interval: float = 1.35
@export var laser_speed: float = 520.0
@export var laser_damage: float = 9.0
@export var laser_count: int = 3
@export var laser_spread_degrees: float = 9.0

@export_group("Melee")
@export var melee_range: float = 185.0
@export var cone_radius: float = 175.0
@export var cone_half_angle_degrees: float = 38.0
@export var cone_damage: float = 14.0
@export var cone_cooldown: float = 1.25
@export var cone_windup: float = 0.42

@export_group("Anti-Camp Spin")
@export var close_time_before_spin: float = 5.0
@export var spin_radius: float = 285.0
@export var spin_damage: float = 24.0
@export var spin_windup: float = 1.35
@export var spin_recovery: float = 1.0

@export_group("Kamikaze")
@export_range(0.05, 0.9, 0.01) var kamikaze_health_ratio: float = 0.25
@export var kamikaze_windup: float = 2.35
@export var explosion_radius: float = 900.0

var _repo_state: RepoState = RepoState.COMBAT
var _home_position: Vector2
var _laser_left: float = 0.8
var _melee_left: float = 0.0
var _close_time: float = 0.0
var _repo_state_left: float = 0.0
var _facing_dir: Vector2 = Vector2.RIGHT
var _spin_recovery_left: float = 0.0
var _message_layer: CanvasLayer
var _message_label: Label
var _message_tween: Tween


func _ready() -> void:
	super._ready()
	_home_position = global_position
	phase = 1
	stats.ranged = false
	stats.speed = 0.0
	_setup_message_ui()
	call_deferred("_announce", "CORPORATE PROPERTY DETECTED.\nBEGINNING REPOSSESSION OF CORPORATE ASSETS.", 3.8)


func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(player):
		return

	# This boss is a sentry/retrieval unit: it anchors itself to the center.
	global_position = _home_position
	velocity = Vector2.ZERO

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance > 1.0:
		_facing_dir = to_player.normalized()
		sprite.flip_h = _facing_dir.x < 0.0

	_melee_left = maxf(_melee_left - delta, 0.0)
	_spin_recovery_left = maxf(_spin_recovery_left - delta, 0.0)

	match _repo_state:
		RepoState.KAMIKAZE:
			_update_kamikaze(delta)
		RepoState.CONE_WINDUP:
			_repo_state_left -= delta
			queue_redraw()
			if _repo_state_left <= 0.0:
				_execute_cone()
		RepoState.SPIN_WINDUP:
			_repo_state_left -= delta
			queue_redraw()
			if _repo_state_left <= 0.0:
				_execute_spin()
		RepoState.COMBAT:
			_update_combat(delta, distance)

	queue_redraw()


func _update_combat(delta: float, distance: float) -> void:
	if distance <= melee_range:
		_close_time += delta
		if _close_time >= close_time_before_spin and _spin_recovery_left <= 0.0:
			_begin_spin()
			return
		if _melee_left <= 0.0:
			_begin_cone()
			return
	else:
		_close_time = maxf(_close_time - delta * 2.0, 0.0)

	_laser_left -= delta
	if distance > melee_range * 0.9 and _laser_left <= 0.0:
		_fire_laser_burst()
		_laser_left = laser_interval


func _fire_laser_burst() -> void:
	if not is_instance_valid(player):
		return
	var base_dir := (player.global_position - global_position).normalized()
	var spread := deg_to_rad(laser_spread_degrees)
	for i in range(laser_count):
		var t := 0.5 if laser_count <= 1 else float(i) / float(laser_count - 1)
		var angle := lerpf(-spread, spread, t)
		var dir := base_dir.rotated(angle)
		EnemyProjectile.spawn(get_parent(), global_position + dir * 72.0, dir, laser_speed, laser_damage, true)
	RingFX.spawn(get_parent(), global_position, 72.0, Color(1.0, 0.08, 0.12), 0.22)


func _begin_cone() -> void:
	_repo_state = RepoState.CONE_WINDUP
	_repo_state_left = cone_windup
	_facing_dir = (player.global_position - global_position).normalized()
	_set_tint(Color(1.0, 0.52, 0.18))
	queue_redraw()


func _execute_cone() -> void:
	if is_instance_valid(player):
		var offset := player.global_position - global_position
		var distance := offset.length()
		if distance <= cone_radius and distance > 0.1:
			var angle := absf(_facing_dir.angle_to(offset.normalized()))
			if angle <= deg_to_rad(cone_half_angle_degrees):
				player.take_damage(cone_damage)
				player.shake(5.0, 0.18)
	_repo_state = RepoState.COMBAT
	_melee_left = cone_cooldown
	_set_tint(stats.tint)


func _begin_spin() -> void:
	_repo_state = RepoState.SPIN_WINDUP
	_repo_state_left = spin_windup
	_close_time = 0.0
	_set_tint(Color(1.0, 0.12, 0.08))
	_announce("PROXIMITY VIOLATION.\nCLEAR THE RETRIEVAL ZONE.", spin_windup)
	RingFX.spawn(get_parent(), global_position, spin_radius, Color(1.0, 0.2, 0.1), spin_windup)
	queue_redraw()


func _execute_spin() -> void:
	if is_instance_valid(player) and player.global_position.distance_to(global_position) <= spin_radius:
		player.take_damage(spin_damage)
		player.shake(11.0, 0.4)
	for i in range(18):
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 18.0)
		EnemyProjectile.spawn(get_parent(), global_position + dir * 82.0, dir, 360.0, spin_damage * 0.35, false)
	RingFX.spawn(get_parent(), global_position, spin_radius, Color(1.0, 0.06, 0.08), 0.4)
	_repo_state = RepoState.COMBAT
	_spin_recovery_left = spin_recovery
	_melee_left = 0.7
	_set_tint(stats.tint)


func take_damage(amount: float) -> void:
	if _dead or _repo_state == RepoState.KAMIKAZE:
		return
	var dealt := maxf(amount - stats.durability, 1.0)
	current_hp = maxf(current_hp - dealt, 0.0)
	health_changed.emit(current_hp, stats.max_hp)
	_hit_flash()
	queue_redraw()

	if current_hp <= stats.max_hp * kamikaze_health_ratio:
		_begin_kamikaze()


func _begin_kamikaze() -> void:
	if _repo_state == RepoState.KAMIKAZE:
		return
	phase = 2
	phase_changed.emit(phase)
	_repo_state = RepoState.KAMIKAZE
	_repo_state_left = kamikaze_windup
	velocity = Vector2.ZERO
	_set_tint(Color(1.0, 0.02, 0.02))
	_announce("INITIATING KAMIKAZE MODE", kamikaze_windup)
	if is_instance_valid(player):
		player.shake(7.0, kamikaze_windup)
	RingFX.spawn(get_parent(), global_position, 180.0, Color(1.0, 0.0, 0.0), kamikaze_windup)
	queue_redraw()


func _update_kamikaze(delta: float) -> void:
	_repo_state_left -= delta
	# Faster pulse as the timer approaches zero.
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.02)
	sprite.modulate = Color(1.0, 0.05 + pulse * 0.28, 0.05 + pulse * 0.08)
	queue_redraw()
	if _repo_state_left <= 0.0:
		_detonate()


func _detonate() -> void:
	if _dead:
		return
	_dead = true
	for radius in [180.0, 360.0, 620.0, explosion_radius]:
		RingFX.spawn(get_parent(), global_position, radius, Color(1.0, 0.12, 0.04), 0.55)
	if is_instance_valid(player):
		player.shake(28.0, 0.8)
		player.force_kill()
	sprite.visible = false
	await get_tree().create_timer(0.65).timeout
	if is_inside_tree():
		queue_free()


func _setup_message_ui() -> void:
	_message_layer = CanvasLayer.new()
	_message_layer.layer = 20
	add_child(_message_layer)

	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message_label.position = Vector2(-440.0, 92.0)
	_message_label.size = Vector2(880.0, 110.0)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 27)
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.22, 0.20))
	_message_label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01))
	_message_label.add_theme_constant_override("outline_size", 8)
	_message_label.visible = false
	_message_layer.add_child(_message_label)


func _announce(message: String, duration: float = 2.0) -> void:
	if not is_instance_valid(_message_label):
		return
	if _message_tween != null:
		_message_tween.kill()
	_message_label.text = message
	_message_label.modulate.a = 1.0
	_message_label.visible = true
	_message_tween = create_tween()
	_message_tween.tween_interval(maxf(duration - 0.35, 0.1))
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.35)
	_message_tween.tween_callback(_message_label.hide)


func _draw() -> void:
	# EnemyNPC's small HP bar.
	super._draw()

	if _repo_state == RepoState.CONE_WINDUP:
		var half := deg_to_rad(cone_half_angle_degrees)
		var points := PackedVector2Array([Vector2.ZERO])
		var segments := 18
		for i in range(segments + 1):
			var angle := lerpf(-half, half, float(i) / float(segments))
			points.append(_facing_dir.rotated(angle) * cone_radius)
		draw_colored_polygon(points, Color(1.0, 0.28, 0.05, 0.22))
		draw_line(Vector2.ZERO, _facing_dir.rotated(-half) * cone_radius, Color(1.0, 0.55, 0.15, 0.9), 4.0)
		draw_line(Vector2.ZERO, _facing_dir.rotated(half) * cone_radius, Color(1.0, 0.55, 0.15, 0.9), 4.0)

	if _repo_state == RepoState.SPIN_WINDUP:
		var progress := 1.0 - clampf(_repo_state_left / maxf(spin_windup, 0.01), 0.0, 1.0)
		draw_circle(Vector2.ZERO, spin_radius, Color(1.0, 0.05, 0.02, 0.08), false, 10.0)
		draw_arc(Vector2.ZERO, spin_radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 96, Color(1.0, 0.2, 0.08), 12.0)

	if _repo_state == RepoState.KAMIKAZE:
		var progress := 1.0 - clampf(_repo_state_left / maxf(kamikaze_windup, 0.01), 0.0, 1.0)
		var radius := lerpf(120.0, explosion_radius, progress)
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.0, 0.0, 0.05), false, 8.0)
