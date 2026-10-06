class_name PlayerBullet
extends Area2D
## The player's projectile.
##  - With slash frames assigned (Player node > Slash Frames) it flies as an
##    animated SLASH. The animation is timed to finish as it reaches the ring.
##  - With no frames assigned it falls back to the old round bullet.
## Either way it flies a fixed distance and stops there. For slashes, the
## FRONT EDGE of the slash (not its centre) ends at the aim ring.
## Physics layers: mask 4 = enemy bodies (layer 3).

var direction: Vector2 = Vector2.RIGHT
var speed: float = 750.0
var damage: float = 10.0
var max_range: float = 170.0
var pierce: bool = false
var is_slash: bool = false
var _travelled: float = 0.0
var _hit: Dictionary = {}  # enemies this slash already damaged (so it hits each only once)
var _spent: bool = false   # a non-piercing slash is "used up" after its first hit


## `look` is filled in by the Player: {frames, width, speed, rotation, pierce}
static func spawn(parent: Node, pos: Vector2, dir: Vector2, dmg: float, rng: float, spd: float, look: Dictionary = {}) -> PlayerBullet:
	var b := PlayerBullet.new()
	b.collision_layer = 0
	b.collision_mask = 4
	b.monitorable = false
	b.direction = dir.normalized()
	b.damage = dmg
	b.max_range = rng
	b.speed = spd

	var shape := CircleShape2D.new()
	var cs := CollisionShape2D.new()
	cs.shape = shape
	b.add_child(cs)

	var textures: Array[Texture2D] = []
	for t in look.get("frames", []):
		if t is Texture2D:
			textures.append(t)

	if textures.is_empty():
		# ----- fallback: the old round bullet -----
		shape.radius = 7.0
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/bullet.png") as Texture2D
		b.add_child(sprite)
		b.rotation = b.direction.angle()
	else:
		# ----- slash -----
		b.is_slash = true
		var width: float = look.get("width", 120.0)
		b.pierce = look.get("pierce", true)
		b.speed = look.get("speed", 450.0)
		b.max_range = maxf(rng - width * 0.5, 10.0)   # front edge ends at the ring
		shape.radius = width * 0.4                       # hit area

		var flight := b.max_range / maxf(b.speed, 1.0)
		var sf := SpriteFrames.new()
		if sf.has_animation("default"):
			sf.remove_animation("default")
		sf.add_animation("slash")
		sf.set_animation_loop("slash", false)
		sf.set_animation_speed("slash", maxf(float(textures.size()) / maxf(flight, 0.05), 1.0))
		for t in textures:
			sf.add_frame("slash", t)

		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = sf
		anim.animation = &"slash"
		anim.scale = Vector2.ONE * (width / maxf(float(textures[0].get_width()), 1.0))
		b.add_child(anim)
		anim.play("slash")
		b.rotation = b.direction.angle() + deg_to_rad(look.get("rotation", 0.0))

	parent.add_child(b)
	b.global_position = pos
	return b


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var step := minf(speed * delta, max_range - _travelled)
	global_position += direction * step
	_travelled += step
	if _travelled >= max_range - 0.01:
		if not is_slash:
			RingFX.spawn(get_parent(), global_position, 12.0, Color(0.6, 1.0, 1.0), 0.18)
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _spent or not body.is_in_group("enemies") or not body.has_method("take_damage"):
		return
	var id := body.get_instance_id()
	if _hit.has(id):
		return
	_hit[id] = true
	body.take_damage(damage)
	if not pierce:
		_spent = true
		queue_free()
