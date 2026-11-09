class_name PerfectDodge
extends Node
## A NieR-style PERFECT DODGE. Dash just as an attack would hit you and:
##   - your Dash is ready again at once,
##   - time slows down and the camera zooms in a little,
##   - the screen dims EXCEPT you, who glow, turn slightly see-through and leave afterimages that fade away.
## Drop this node into a level (a story level, or your regular playtest scene). It finds the player by itself.
##
## It needs ONE small addition in your player script (a "damage_avoided" signal, see perfect_dodge_patch.txt) so it can tell when your
## Dash avoided a hit. Without it, only "dash right after being hit" works (see Late Grace Seconds), and the Output says so.

## Turns the picture's colors toward `tint` by `amount` (keeps its see-through shape). Used for the white afterimages and the player's glow.
const WHITEN_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.8;
void fragment() {
	vec4 base = COLOR;
	COLOR = vec4(mix(base.rgb, tint.rgb, amount), base.a);
}
"""

## Emitted every time a perfect dodge happens (for score, sounds, achievements...).
signal perfect_dodge

@export var enabled: bool = true

@export_group("When it counts")
## Dash right AFTER being hit, within this many seconds, and it still counts: the damage is given back. 0 = off.
@export_range(0.0, 0.5, 0.01) var late_grace_seconds: float = 0.12
## A perfect dodge makes the Dash ready again at once.
@export var reset_dash_cooldown: bool = true
## Seconds before another perfect dodge can happen (so a pile of hits does not count many times).
@export var min_gap_seconds: float = 0.6

@export_group("Slow motion and zoom")
## How slow time gets (0.3 = a bit under a third of normal speed).
@export_range(0.05, 1.0, 0.01) var slow_scale: float = 0.3
## How long the whole effect lasts, in REAL seconds (the slow-down eases in fast and eases out gently).
@export var slow_seconds: float = 1.1
## How far the camera zooms in (1.12 = 12% closer).
@export_range(1.0, 1.6, 0.01) var zoom_amount: float = 1.12
## How slow the SOUND gets during the slow motion: 1.0 = unchanged, lower = deeper and slower.
@export_range(0.25, 1.0, 0.01) var audio_speed: float = 0.8

@export_group("Dim and glow")
## How dark everything except the player gets (0 = not at all, 1 = black).
@export_range(0.0, 1.0, 0.01) var dim_strength: float = 0.5
@export var dim_color: Color = Color(0.02, 0.03, 0.09)
## The color of the glow and of the player's tint (white by default).
@export var glow_color: Color = Color(1.0, 1.0, 1.0)
## How much the player's own colors turn to the glow color during the effect (0 = keep her colors, 1 = a solid silhouette).
@export_range(0.0, 1.0, 0.01) var player_whiten: float = 0.3
## How see-through the player gets (1 = solid).
@export_range(0.1, 1.0, 0.01) var player_alpha: float = 0.6
## A soft glow behind the player.
@export var glow_halo: bool = true

@export_group("Afterimages")
@export var afterimage_color: Color = Color(1.0, 1.0, 1.0, 0.6)
## How much of the picture's own colors turn to the afterimage color (1 = pure white silhouettes).
@export_range(0.0, 1.0, 0.01) var afterimage_whiteness: float = 0.8
## How long NEW afterimages keep appearing, in real seconds.
@export var afterimage_seconds: float = 0.8
## A new afterimage appears each time the player has moved this many pixels (and at least every 0.07 s).
@export var afterimage_distance: float = 16.0
## How long each afterimage takes to fade away.
@export var afterimage_fade_seconds: float = 0.7

@export_group("Sound")
## Played when it happens. Drag a .wav or .ogg here.
@export var sound: AudioStream
@export var sound_volume_db: float = 0.0
## Empty Sound slot plays a simple built-in whoosh and chime. Turn off for silence.
@export var use_built_in_sound: bool = true

@export_group("Testing")
## Press the Preview Key to see the effect without being attacked, so you can tune it. Turn off in the finished game.
@export var preview_key_enabled: bool = true
@export var preview_key: Key = KEY_F3

var is_active: bool = false          # true while the effect is playing

var _player: Node
var _dash: Node
var _hooked: Dictionary = {}
var _warned: bool = false
var _prev_hp: float = -1.0
var _last_hit_ms: int = -100000
var _last_hit_amount: float = 0.0
var _dash_ms: int = -100000
var _last_trigger_ms: int = -100000

var _t: float = 0.0
var _touched_time: bool = false
var _ghost_until: float = 0.0
var _ghost_timer: float = 0.0
var _last_ghost_pos: Vector2 = Vector2.ZERO
var _base_zoom: Vector2 = Vector2.ONE
var _sprites: Array = []                 # every sprite under the player
var _sprite_base: Dictionary = {}        # their own colours, to put back
var _base_z: int = 0
var _dim: DimLayer
var _halo: Sprite2D
var _built_in: AudioStreamWAV
var _shader: Shader
var _player_mat: ShaderMaterial
var _whitened: Array = []               # the sprites that got our material (so only those are put back)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS          # so it can notice when the game gets paused and stop cleanly
	var parent := get_parent()
	if parent != null and "abilities" in parent:
		_bind_player(parent)


func _exit_tree() -> void:
	if is_active:
		_end(true)                                   # never leave the game slowed or dimmed after a scene change


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		var p := get_tree().get_first_node_in_group("player")
		if p == null or not ("abilities" in p):
			return
		_bind_player(p)
	_hook_dash()
	if is_active:
		_tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if preview_key_enabled and event is InputEventKey and event.pressed and not event.echo and event.keycode == preview_key:
		trigger("preview")


## Triggers the effect (the same as a real perfect dodge). Also usable from your own code.
func trigger(_reason: String = "") -> void:
	if not enabled or _player == null or not is_instance_valid(_player) or _player._dead:
		return
	var now := Time.get_ticks_msec()
	if now - _last_trigger_ms < int(min_gap_seconds * 1000.0):
		return
	_last_trigger_ms = now
	if reset_dash_cooldown and _dash != null and is_instance_valid(_dash):
		_dash._cooldown_left = 0.0
	perfect_dodge.emit()
	if _cinematic_running():
		return                                       # the level's own cinematic owns time and the camera right now
	if is_active:
		_t = 0.0                                     # another one while playing: start the effect over
		_ghost_until = afterimage_seconds
		return
	_begin()


# ---------------------------------------------------------------- finding the player and listening

func _bind_player(p: Node) -> void:
	_player = p
	_prev_hp = float(p.current_hp) if "current_hp" in p else -1.0
	if p.has_signal("health_changed") and not p.health_changed.is_connected(_on_health_changed):
		p.health_changed.connect(_on_health_changed)
	if p.has_signal("damage_avoided"):
		if not p.damage_avoided.is_connected(_on_damage_avoided):
			p.damage_avoided.connect(_on_damage_avoided)
	elif not _warned:
		_warned = true
		push_warning("PerfectDodge: the player has no 'damage_avoided' signal, so only 'dash right after being hit' can count. Add the 3 lines from perfect_dodge_patch.txt to your player script.")


## Connects to the player's Dash ability (also one the tutorial gives later).
func _hook_dash() -> void:
	for a in _player.abilities:
		if a == null or _hooked.has(a.get_instance_id()):
			continue
		var sc: Script = a.get_script()
		var nm := String(sc.get_global_name()).to_lower() if sc != null else ""
		if nm.contains("dash") or str(a.get("ability_name")).to_lower() == "dash":
			_hooked[a.get_instance_id()] = true
			_dash = a
			a.activated.connect(_on_dash.bind(a))


func _on_health_changed(current: float, _maximum: float) -> void:
	if _prev_hp >= 0.0 and current < _prev_hp - 0.001:
		_last_hit_ms = Time.get_ticks_msec()
		_last_hit_amount = _prev_hp - current
	_prev_hp = current


func _on_dash(_ability: Node) -> void:
	var now := Time.get_ticks_msec()
	_dash_ms = now
	# Dashed right after being hit: give the damage back and count it.
	if late_grace_seconds > 0.0 and _last_hit_amount > 0.0 and now - _last_hit_ms <= int(late_grace_seconds * 1000.0) and not _player._dead:
		var back := _last_hit_amount
		_last_hit_amount = 0.0
		_player.current_hp = minf(_player.current_hp + back, _player.max_hp)
		_player.health_changed.emit(_player.current_hp, _player.max_hp)
		trigger("late")


## The player says an attack reached it while it was invulnerable. If that is the Dash protecting it, it is a perfect dodge.
func _on_damage_avoided(_amount: float) -> void:
	var dashing: bool = ("_dashing" in _player and _player._dashing) or Time.get_ticks_msec() - _dash_ms <= 280
	if dashing:
		trigger("dash")


func _cinematic_running() -> bool:
	for n in [get_parent(), get_tree().current_scene]:
		if n != null and "is_cinematic" in n and n.is_cinematic:
			return true
	return false


# ---------------------------------------------------------------- the effect

func _begin() -> void:
	is_active = true
	_t = 0.0
	_ghost_until = afterimage_seconds
	_ghost_timer = 0.0
	_touched_time = true
	var cam: Camera2D = _player.camera if "camera" in _player else null
	_base_zoom = cam.zoom if cam != null else Vector2.ONE
	_sprites = _player_sprites()
	_sprite_base.clear()
	for sp in _sprites:
		_sprite_base[sp.get_instance_id()] = sp.self_modulate
	_whitened.clear()
	if player_whiten > 0.0:
		_player_mat = ShaderMaterial.new()
		_player_mat.shader = _get_shader()
		_player_mat.set_shader_parameter("tint", glow_color)
		_player_mat.set_shader_parameter("amount", 0.0)
		for sp in _sprites:
			if sp.material == null:                           # never replace a material the sprite already has
				sp.material = _player_mat
				_whitened.append(sp)
	_base_z = _player.z_index
	_player.z_index = 60                             # above the dimming, so the player stays bright
	_dim = DimLayer.new()
	_dim.color = dim_color
	_player.get_parent().add_child(_dim)
	if glow_halo and not _sprites.is_empty():
		_halo = _make_halo(_sprites[0])
		_player.add_child(_halo)
	_last_ghost_pos = _player.global_position
	_spawn_afterimage()
	_play_sound()


func _tick(delta: float) -> void:
	if get_tree().paused or _cinematic_running() or _player._dead:
		_end(not _cinematic_running())               # something else took over (a menu, a cinematic, death): stop cleanly
		return
	var rdt := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)       # real time, whatever the slow motion does
	_t += rdt
	var in_t := 0.08
	var out_t := 0.45
	var k := 1.0
	if _t < in_t:
		k = _t / in_t
	elif _t > slow_seconds - out_t:
		k = clampf((slow_seconds - _t) / out_t, 0.0, 1.0)
	k = smoothstep(0.0, 1.0, k)
	Engine.time_scale = lerpf(1.0, slow_scale, k)
	if audio_speed < 1.0:
		AudioServer.playback_speed_scale = lerpf(1.0, audio_speed, k)
	var cam: Camera2D = _player.camera if "camera" in _player else null
	if cam != null:
		cam.zoom = _base_zoom * lerpf(1.0, zoom_amount, k)
		if _dim != null:
			_dim.global_position = cam.get_screen_center_position()
	elif _dim != null:
		_dim.global_position = _player.global_position
	if _dim != null:
		_dim.set_alpha(dim_strength * k)
	if _player_mat != null:
		_player_mat.set_shader_parameter("amount", player_whiten * k)
	for sp in _sprites:
		if is_instance_valid(sp):
			var base: Color = _sprite_base.get(sp.get_instance_id(), Color.WHITE)
			var glow := Color(base.r, base.g, base.b, base.a * player_alpha)       # see-through; the colour change is the shader's job
			sp.self_modulate = base.lerp(glow, k)
	if _halo != null:
		_halo.modulate.a = k * 0.5 * (0.85 + 0.15 * sin(_t * 14.0))
	# afterimages: one each time the player has moved a little, and at least every 0.07 s
	if _t < _ghost_until:
		_ghost_timer += rdt
		if _player.global_position.distance_to(_last_ghost_pos) >= afterimage_distance or _ghost_timer >= 0.07:
			_spawn_afterimage()
	if _t >= slow_seconds:
		_end(true)


## Puts everything back. restore_time = false when the level's cinematic is in charge of time (we must not touch it).
func _end(restore_time: bool) -> void:
	is_active = false
	if restore_time and _touched_time:
		Engine.time_scale = 1.0
		AudioServer.playback_speed_scale = 1.0
	if _player != null and is_instance_valid(_player):
		var cam: Camera2D = _player.camera if "camera" in _player else null
		if cam != null:
			cam.zoom = _base_zoom
		_player.z_index = _base_z
	for sp in _whitened:
		if is_instance_valid(sp) and sp.material == _player_mat:
			sp.material = null
	_whitened.clear()
	_player_mat = null
	for sp in _sprites:
		if is_instance_valid(sp):
			sp.self_modulate = _sprite_base.get(sp.get_instance_id(), Color.WHITE)
	_sprites.clear()
	_sprite_base.clear()
	if _dim != null and is_instance_valid(_dim):
		_dim.queue_free()
	_dim = null
	if _halo != null and is_instance_valid(_halo):
		_halo.queue_free()
	_halo = null


func _make_halo(spr: Node2D) -> Sprite2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var h := Sprite2D.new()
	h.texture = tex
	h.position = spr.position
	h.scale = Vector2(1.55, 1.55)
	h.modulate = Color(glow_color.r, glow_color.g, glow_color.b, 0.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD          # adds light instead of covering
	h.material = mat
	h.z_index = -1                                              # behind the player's picture
	return h


func _get_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = WHITEN_SHADER
	return _shader


## Every sprite of the player (any name, any depth), except the aim cursor and our own glow.
func _player_sprites() -> Array:
	var out: Array = []
	var cursor = _player.get("aim_cursor")
	for n in _player.find_children("*", "", true, false):
		if n == _halo or n == cursor:
			continue
		if (n is AnimatedSprite2D or n is Sprite2D) and n.is_visible_in_tree():
			out.append(n)
	return out


## A see-through copy of how the player looks right now, left where it was; it fades away on its own.
func _spawn_afterimage() -> void:
	_last_ghost_pos = _player.global_position
	_ghost_timer = 0.0
	for sp in _sprites:
		if not is_instance_valid(sp) or not sp.is_visible_in_tree():
			continue
		var g := Sprite2D.new()
		if sp is AnimatedSprite2D:
			if sp.sprite_frames == null:
				continue
			var tex: Texture2D = sp.sprite_frames.get_frame_texture(sp.animation, sp.frame)
			if tex == null:
				continue
			g.texture = tex
		else:
			g.texture = sp.texture
			g.hframes = sp.hframes
			g.vframes = sp.vframes
			g.frame = sp.frame
			g.region_enabled = sp.region_enabled
			g.region_rect = sp.region_rect
		g.centered = sp.centered
		g.offset = sp.offset
		g.flip_h = sp.flip_h
		g.flip_v = sp.flip_v
		g.top_level = true
		g.z_as_relative = false
		g.z_index = 55                                          # above the dimming, just below the player
		var base: Color = _sprite_base.get(sp.get_instance_id(), Color.WHITE)
		g.modulate = Color(1.0, 1.0, 1.0, afterimage_color.a * base.a)
		var gm := ShaderMaterial.new()
		gm.shader = _get_shader()
		gm.set_shader_parameter("tint", Color(afterimage_color.r, afterimage_color.g, afterimage_color.b, 1.0))
		gm.set_shader_parameter("amount", afterimage_whiteness)
		g.material = gm
		_player.get_parent().add_child(g)
		g.global_transform = sp.global_transform
		var tw := create_tween()
		tw.set_ignore_time_scale(true)
		tw.set_parallel(true)
		tw.tween_property(g, "modulate:a", 0.0, maxf(afterimage_fade_seconds, 0.05))
		tw.tween_property(g, "scale", g.scale * 1.06, maxf(afterimage_fade_seconds, 0.05))
		tw.chain().tween_callback(g.queue_free)


func _play_sound() -> void:
	var stream: AudioStream = sound
	if stream == null and use_built_in_sound:
		if _built_in == null:
			_built_in = _make_sound()
		stream = _built_in
	if stream == null:
		return
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = sound_volume_db
	sfx.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()


## A simple placeholder: a short whoosh and a two-note chime, made in code.
func _make_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.6)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(rate)
		var whoosh := (randf() * 2.0 - 1.0) * exp(-t * 6.0) * 0.30 * (1.0 - exp(-t * 60.0))
		var chime := sin(TAU * 1175.0 * t) * exp(-t * 7.0) * 0.30 + sin(TAU * 1760.0 * t) * exp(-t * 9.0) * 0.20
		data.encode_s16(i * 2, int(clampf(whoosh + chime, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


## The dimming: a huge dark rectangle that follows the camera, drawn above the world but below the player and the afterimages.
class DimLayer extends Node2D:
	var color: Color = Color(0.02, 0.03, 0.09)
	var alpha: float = 0.0

	func _init() -> void:
		top_level = true
		z_as_relative = false
		z_index = 50

	func set_alpha(a: float) -> void:
		if absf(a - alpha) > 0.001:
			alpha = a
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-8000.0, -8000.0, 16000.0, 16000.0), Color(color.r, color.g, color.b, alpha))
