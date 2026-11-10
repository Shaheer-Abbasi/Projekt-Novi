class_name AbilityReapingWave
extends Ability
## Reaper's second ability: an expanding slash that heals per enemy hit.

@export_range(1.0, 2000.0, 1.0) var wave_speed: float = 400.0
@export_range(1.0, 2000.0, 1.0) var wave_range: float = 320.0
@export_range(0.0, 5.0, 0.1) var heal_percent_per_hit: float = 1.0


func _init() -> void:
	ability_name = "Reaping Wave"
	cooldown_time = 7.0
	damage = 16.0


func activate() -> void:
	var player := caster as PlaytestPlayer
	var wave := Wave.new()
	wave.player = player
	wave.speed = wave_speed
	wave.max_radius = wave_range
	wave.damage = damage
	wave.heal_fraction = heal_percent_per_hit / 100.0
	wave.slash_frames = player.slash_frames
	wave.sprite_rotation_offset = deg_to_rad(player.slash_rotation_offset_degrees)
	wave.z_index = 3
	wave.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_tree().current_scene.add_child(wave)
	wave.global_position = player.global_position
	var sprite := player.get_node("CharacterSprite/AnimatedSprite2D") as AnimatedSprite2D
	sprite.play(&"attack")


class Wave extends Node2D:
	const HIT_MARGIN := 24.0
	const SPRITE_COUNT := 16

	var player: PlaytestPlayer
	var speed: float
	var max_radius: float
	var damage: float
	var heal_fraction: float
	var slash_frames: Array[Texture2D]
	var sprite_rotation_offset: float
	var _radius: float = 0.0
	var _hit_enemies: Dictionary = {}

	func _physics_process(delta: float) -> void:
		var inner := maxf(_radius - HIT_MARGIN, 0.0)
		_radius = minf(_radius + speed * delta, max_radius)
		var outer := minf(_radius + HIT_MARGIN, max_radius)
		_hit_enemies_in_band(inner * inner, outer * outer)
		queue_redraw()
		if _radius >= max_radius:
			queue_free()

	func _hit_enemies_in_band(inner_squared: float, outer_squared: float) -> void:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not enemy is Node2D or enemy.is_queued_for_deletion() or not enemy.has_method("take_damage"):
				continue
			if enemy is EnemyNPC and enemy._dead:
				continue
			var id := enemy.get_instance_id()
			if _hit_enemies.has(id):
				continue
			var distance_squared := global_position.distance_squared_to(enemy.global_position)
			if distance_squared < inner_squared or distance_squared > outer_squared:
				continue
			_hit_enemies[id] = true
			enemy.call("take_damage", damage)
			if is_instance_valid(player):
				player.heal(player.max_hp * heal_fraction)

	func _draw() -> void:
		if _radius <= 0.0:
			return
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 96, Color(0.78, 0.3, 1.0, 0.7), 3.0, true)
		if slash_frames.is_empty():
			return
		var frame := mini(int(_radius / max_radius * slash_frames.size()), slash_frames.size() - 1)
		var texture := slash_frames[frame]
		if texture == null:
			return
		var width := minf(150.0, TAU * _radius / SPRITE_COUNT * 1.4)
		var size := texture.get_size() * (width / texture.get_width())
		for index in range(SPRITE_COUNT):
			var angle := TAU * index / SPRITE_COUNT
			var position_on_ring := Vector2.RIGHT.rotated(angle) * _radius
			draw_set_transform(position_on_ring, angle + sprite_rotation_offset)
			draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
