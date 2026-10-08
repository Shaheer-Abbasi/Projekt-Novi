class_name PlaytestPlayer
extends CharacterBody2D
## Playtest player.
##  - WASD move (your existing up/down/left/right actions)
##  - Left click = basic attack toward the AIM CURSOR
##  - Keys 1/2/3/4 = abilities (4 = Ultimate)
##  - AimCursor orbits the player at `aim_radius` and points at the mouse.
##    Basic bullets travel exactly `aim_radius`, so they stop at the ring.

signal health_changed(current_hp: float, max_hp: float)
signal died

const CHARACTER_DATA_PATH := "res://playtest/resources/vow_data.tres"
const MUZZLE_OFFSET := 24.0
const HIT_INVULN_TIME := 0.35

@export var character_data: CharacterData

@export_group("Aim Cursor")
## Draws the red reference ring (the bullets' max range).
@export var show_range_ring: bool = true:
	set(value):
		show_range_ring = value
		queue_redraw()
## If your cursor sprite does NOT point right (+X) in the image file,
## rotate it here. Up-pointing sprite = 90, left = 180, down = -90.
@export var cursor_rotation_offset_degrees: float = 0.0
## Hide the operating-system mouse arrow while playing.
@export var hide_system_cursor: bool = false
@export_group("Sprite")
## Off: the sprite only ever faces left or right (follows your movement).
## On: pure up/down movement switches to your walk_up / walk_down art.
@export var use_up_down_art: bool = false

@export_group("Slash")
## Your slash animation frames IN ORDER. Set Size to 3, then drag your slash PNGs in.
## Leave empty to use the old round bullet.
@export var slash_frames: Array[Texture2D] = []
## How wide the slash looks on screen, in pixels.
@export var slash_width: float = 120.0
## How fast the slash travels (pixels per second). Lower = you see the animation longer.
@export var slash_speed: float = 450.0
## If your slash art doesn't face RIGHT, rotate it here (faces up = 90, left = 180, down = -90).
@export var slash_rotation_offset_degrees: float = 0.0
## On: the slash passes through enemies (hits each once). Off: it vanishes on the first hit.
@export var slash_pierce: bool = true
## Sound played on every slash. Drag a .wav or .ogg here. Empty = silent.
@export var slash_sound: AudioStream
## Volume in dB (0 = normal, -6 = quieter, +3 = louder).
@export var slash_volume_db: float = 0.0
## Random pitch change so repeated slashes don't sound identical (0 = none, 0.1 = +/-10%).
@export_range(0.0, 0.5, 0.01) var slash_pitch_variation: float = 0.08

@export_group("Bouquet")
## Your own bouquet art for the Bouquet Toss. Leave empty to use the built-in drawn bouquet.
@export var bouquet_texture: Texture2D

var character_name: String = "Vow"
var max_hp: float = 120.0
var current_hp: float = 120.0
var speed: float = 220.0
var aim_radius: float = 170.0
var abilities: Array[Ability] = []
var arena_rect: Rect2 = Rect2(-100000, -100000, 200000, 200000)

var _aim_dir: Vector2 = Vector2.RIGHT
var _facing_right: bool = true
var _fire_left: float = 0.0
var _input_locked: bool = false
var _dashing: bool = false
var _dash_vel: Vector2 = Vector2.ZERO
var _dash_left: float = 0.0
var _invuln_left: float = 0.0
var _dead: bool = false
var _flash_tween: Tween

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var aim_cursor: Sprite2D = $AimCursor
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	_ensure_input_actions()
	if character_data == null and ResourceLoader.exists(CHARACTER_DATA_PATH):
		character_data = load(CHARACTER_DATA_PATH) as CharacterData
	if character_data == null:
		character_data = CharacterData.new()
	character_name = character_data.character_name
	max_hp = character_data.max_health
	current_hp = max_hp
	speed = character_data.move_speed
	aim_radius = character_data.attack_range
	_setup_abilities()
	if hide_system_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	queue_redraw()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ensure_input_actions() -> void:
	var keys := {"ability_1": KEY_1, "ability_2": KEY_2, "ability_3": KEY_3, "ability_4": KEY_4, "ability_5": KEY_SHIFT}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)


## Builds the 8-direction walk animations from your Vow art. Same layout as
## your player.tscn: index 0..7 = right, right, down, down, left, left, up, up.
func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var dirs := ["right", "right", "down", "down", "left", "left", "up", "up"]
	for i in range(8):
		var anim := "walk%d" % i
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 5.0)
		frames.set_animation_loop(anim, true)
		for f in range(1, 5):
			var path := "res://player/vow/walk_%s/walk_%s_%02d.png" % [dirs[i], dirs[i], f]
			frames.add_frame(anim, load(path) as Texture2D)
	sprite.sprite_frames = frames
	sprite.animation = &"walk2"


func _setup_abilities() -> void:
	var scripts: Array = [
		character_data.ability_1_script,
		character_data.ability_2_script,
		character_data.ability_3_script,
		character_data.ability_4_script,
		character_data.ability_5_script,
	]
	for s in scripts:
		if s == null:
			abilities.append(null)   # empty slot: keeps every other ability on its own number / key
			continue
		var ability := s.new() as Ability  # Script.new() so each ability's _init() runs
		add_child(ability)
		ability.setup(self)
		abilities.append(ability)


func set_arena(rect: Rect2) -> void:
	arena_rect = rect
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_update_aim()
	_fire_left = maxf(_fire_left - delta, 0.0)
	if _invuln_left > 0.0:
		_invuln_left -= delta

	if _dashing:
		velocity = _dash_vel
		_dash_left -= delta
		if _dash_left <= 0.0:
			_dashing = false
		move_and_slide()
		_clamp_to_arena()
		return

	if _input_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir := get_move_direction()
	velocity = dir * speed
	move_and_slide()
	_clamp_to_arena()
	_update_animation(dir)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _fire_left <= 0.0:
		_fire_left = character_data.fire_cooldown
		fire_bullet(_aim_dir, character_data.basic_damage)


# --- Aim cursor ---------------------------------------------------------

func _update_aim() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		_aim_dir = to_mouse.normalized()
	aim_cursor.position = _aim_dir * aim_radius
	aim_cursor.rotation = _aim_dir.angle() + deg_to_rad(cursor_rotation_offset_degrees)


func get_aim_direction() -> Vector2:
	return _aim_dir


func _draw() -> void:
	if show_range_ring:
		draw_arc(Vector2.ZERO, aim_radius, 0.0, TAU, 96, Color(1.0, 0.2, 0.2, 0.55), 1.5)


# --- Movement helpers ---------------------------------------------------

func get_move_direction() -> Vector2:
	return Input.get_vector("left", "right", "up", "down")


func apply_dash(direction: Vector2, dash_speed: float, duration: float) -> void:
	_dashing = true
	_dash_vel = direction.normalized() * dash_speed
	_dash_left = duration
	_invuln_left = maxf(_invuln_left, duration + 0.05)
	_update_animation(direction)


## Used by the Ultimate to freeze input during its pre-scene.
func set_input_locked(locked: bool) -> void:
	_input_locked = locked


func _clamp_to_arena() -> void:
	global_position = global_position.clamp(arena_rect.position + Vector2(30, 30), arena_rect.end - Vector2(30, 30))


## Animation names inside your AnimatedSprite2D's SpriteFrames.
@export var run_animation: StringName = &"run"
@export var idle_animation: StringName = &"idle"


func _update_animation(dir: Vector2) -> void:
	# Face the way you move. Standing still keeps the last facing.
	if absf(dir.x) > 0.1:
		_set_facing_left(dir.x < 0.0)
	_play_for_movement(dir.length() > 0.0)


## Plays "run" while moving, "idle" when still. If you have no "idle"
## animation, it freezes on the first frame of "run" instead.
func _play_for_movement(moving: bool) -> void:
	for n in find_children("*", "AnimatedSprite2D", true, false):
		var s := n as AnimatedSprite2D
		if s.sprite_frames == null:
			continue
		var frames := s.sprite_frames
		if moving and frames.has_animation(run_animation):
			if s.animation != run_animation or not s.is_playing():
				s.play(run_animation)
		elif frames.has_animation(idle_animation):
			if s.animation != idle_animation or not s.is_playing():
				s.play(idle_animation)
		elif frames.has_animation(run_animation):
			s.animation = run_animation
			s.stop()
			s.frame = 0


## Flips EVERY sprite under the player (any name, any depth), except the aim cursor.
func _set_facing_left(face_left: bool) -> void:
	for n in find_children("*", "", true, false):
		if n == aim_cursor:
			continue
		if "flip_h" in n:  # Sprite2D, AnimatedSprite2D, ...
			n.flip_h = face_left


# --- Combat ---------------------------------------------------------------
var _last_slash_sfx_frame: int = -1000


## One sound per swing: a burst of several slashes (Fan Burst) plays it only once.
func _play_slash_sound() -> void:
	if slash_sound == null:
		return
	var now := Engine.get_physics_frames()
	if now - _last_slash_sfx_frame < 4:   # ~0.07 s: slashes fired together share one sound
		return
	_last_slash_sfx_frame = now
	var sfx := AudioStreamPlayer.new()
	sfx.stream = slash_sound
	sfx.volume_db = slash_volume_db
	sfx.pitch_scale = 1.0 + randf_range(-slash_pitch_variation, slash_pitch_variation)
	sfx.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
	
## Fires one bullet. Default range is the aim ring, so it stops at the circle.
func fire_bullet(dir: Vector2, damage: float, bullet_range: float = -1.0) -> void:
	_play_slash_sound()
	var rng := aim_radius if bullet_range < 0.0 else bullet_range
	var start := global_position + dir * MUZZLE_OFFSET
	var look := {
		"frames": slash_frames,
		"width": slash_width,
		"speed": slash_speed,
		"rotation": slash_rotation_offset_degrees,
		"pierce": slash_pierce,
	}
	PlayerBullet.spawn(get_tree().current_scene, start, dir, damage, maxf(rng - MUZZLE_OFFSET, 10.0), character_data.bullet_speed, look)


func _unhandled_input(event: InputEvent) -> void:
	if _dead or _input_locked:
		return
	for i in range(abilities.size()):
		if event.is_action_pressed("ability_%d" % (i + 1)):
			abilities[i].try_activate()
			return


func take_damage(amount: float) -> void:
	if _dead or _invuln_left > 0.0:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	health_changed.emit(current_hp, max_hp)
	_invuln_left = HIT_INVULN_TIME
	if _flash_tween != null:
		_flash_tween.kill()
	sprite.modulate = Color(1.0, 0.4, 0.4)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if current_hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	aim_cursor.visible = false
	died.emit()


func shake(strength: float = 8.0, duration: float = 0.25) -> void:
	var tw := create_tween()
	tw.tween_method(_shake_step.bind(strength), 0.0, 1.0, duration)
	tw.tween_callback(_shake_end)


func _shake_step(t: float, strength: float) -> void:
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * (1.0 - t)


func _shake_end() -> void:
	camera.offset = Vector2.ZERO
