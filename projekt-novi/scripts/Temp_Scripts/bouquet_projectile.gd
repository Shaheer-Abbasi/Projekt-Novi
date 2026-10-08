class_name BouquetProjectile
extends Node2D
## A thrown bouquet. It is LOBBED in an arc from the thrower to a target spot, lands,
## bursts into rose petals, and damages every enemy inside the burst radius.
## Drawn entirely in code (no art needed). To use your own bouquet art, assign a
## texture on the Player (see AbilityBouquet).

const FLIGHT_TIME := 0.55
const BURST_TIME := 0.6

var from_pos: Vector2
var to_pos: Vector2
var damage: float = 55.0
var burst_radius: float = 130.0
var arc_height: float = 80.0
var texture: Texture2D

var _t: float = 0.0
var _landed: bool = false
var _burst_t: float = 0.0
var _petals: Array = []

const ROSE_RED := Color(0.86, 0.10, 0.22)
const ROSE_PINK := Color(1.0, 0.55, 0.68)
const ROSE_WHITE := Color(0.98, 0.93, 0.93)
const LEAF_DARK := Color(0.10, 0.42, 0.20)
const LEAF_LIGHT := Color(0.22, 0.62, 0.30)


static func spawn(parent: Node, from: Vector2, to: Vector2, dmg: float, radius: float, tex: Texture2D = null) -> BouquetProjectile:
	var b := BouquetProjectile.new()
	b.from_pos = from
	b.to_pos = to
	b.damage = dmg
	b.burst_radius = radius
	b.texture = tex
	b.z_index = 20
	parent.add_child(b)
	b.global_position = from
	return b


func _process(delta: float) -> void:
	if not _landed:
		_t += delta
		var k := clampf(_t / FLIGHT_TIME, 0.0, 1.0)
		global_position = from_pos.lerp(to_pos, k)
		if k >= 1.0:
			_land()
	else:
		_burst_t += delta
		if _burst_t >= BURST_TIME:
			queue_free()
			return
	queue_redraw()


func _land() -> void:
	_landed = true
	global_position = to_pos
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(to_pos) <= burst_radius:
			e.take_damage(damage)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("shake"):
		player.shake(5.0, 0.12)
	var colors := [ROSE_RED, ROSE_PINK, ROSE_WHITE, ROSE_RED]
	for i in range(34):
		_petals.append({
			"dir": Vector2.RIGHT.rotated(randf() * TAU),
			"dist": randf_range(0.30, 1.0) * burst_radius,
			"size": randf_range(4.5, 8.5),
			"spin": randf_range(-7.0, 7.0),
			"col": colors[randi() % colors.size()],
		})


func _draw() -> void:
	if _landed:
		_draw_burst()
	else:
		_draw_flight()


# --- in the air -----------------------------------------------------------

func _draw_flight() -> void:
	var k := clampf(_t / FLIGHT_TIME, 0.0, 1.0)
	var height := sin(k * PI) * arc_height
	# where it will land: a soft ring showing the burst size
	var target := to_pos - global_position
	draw_arc(target, burst_radius, 0.0, TAU, 56, Color(1.0, 0.55, 0.68, 0.30), 2.0)
	draw_circle(target, burst_radius, Color(1.0, 0.55, 0.68, 0.06))
	# shadow on the ground
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 15.0 - height * 0.05, Color(0.0, 0.0, 0.0, 0.30))
	# the bouquet itself, up in the air, spinning and swelling toward the top of the arc
	var s := 1.0 + 0.35 * sin(k * PI)
	draw_set_transform(Vector2(0.0, -height - 10.0), k * TAU * 1.5, Vector2(s, s))
	if texture != null:
		var w := 56.0
		var size := Vector2(w, w * float(texture.get_height()) / maxf(float(texture.get_width()), 1.0))
		draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
	else:
		_draw_bouquet()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bouquet() -> void:
	# leaves
	for i in range(6):
		_draw_leaf(TAU * float(i) / 6.0 + 0.3, 27.0, LEAF_DARK if i % 2 == 0 else LEAF_LIGHT)
	# wrapping paper cone
	draw_colored_polygon(PackedVector2Array([Vector2(-11, 4), Vector2(11, 4), Vector2(0, 30)]), Color(0.97, 0.94, 0.89))
	draw_polyline(PackedVector2Array([Vector2(-11, 4), Vector2(0, 30), Vector2(11, 4)]), Color(0.78, 0.72, 0.66), 1.5)
	# roses
	_draw_rose(Vector2(-11, -3), 9.5, ROSE_RED)
	_draw_rose(Vector2(11, -3), 9.5, ROSE_PINK)
	_draw_rose(Vector2(0, -13), 10.0, ROSE_RED)
	_draw_rose(Vector2(-5, 6), 8.5, ROSE_WHITE)
	_draw_rose(Vector2(8, 7), 8.5, ROSE_RED)
	# baby's breath
	for p in [Vector2(-19, -12), Vector2(18, -13), Vector2(-3, -25), Vector2(21, 2), Vector2(-21, 3), Vector2(8, -23)]:
		draw_circle(p, 2.4, Color(1.0, 1.0, 1.0))
	# ribbon bow
	draw_colored_polygon(PackedVector2Array([Vector2(0, 11), Vector2(-9, 5), Vector2(-9, 17)]), ROSE_PINK)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 11), Vector2(9, 5), Vector2(9, 17)]), ROSE_PINK)
	draw_circle(Vector2(0, 11), 3.0, ROSE_RED)


func _draw_rose(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col.darkened(0.40))
	draw_circle(c, r * 0.88, col)
	draw_circle(c + Vector2(-r * 0.15, -r * 0.15), r * 0.55, col.lightened(0.14))
	draw_arc(c, r * 0.55, 0.4, 4.6, 12, col.darkened(0.30), 1.5)
	draw_arc(c, r * 0.28, 3.0, 7.0, 8, col.darkened(0.30), 1.2)


func _draw_leaf(angle: float, length: float, col: Color) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var side := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, dir * length * 0.5 + side * length * 0.24, dir * length, dir * length * 0.5 - side * length * 0.24]), col)


# --- the burst ------------------------------------------------------------

func _draw_burst() -> void:
	var k := clampf(_burst_t / BURST_TIME, 0.0, 1.0)
	var grow := 1.0 - pow(1.0 - k, 3.0)
	var alpha := 1.0 - smoothstep(0.5, 1.0, k)
	draw_circle(Vector2.ZERO, burst_radius * grow, Color(1.0, 0.55, 0.68, 0.18 * (1.0 - k)))
	draw_arc(Vector2.ZERO, burst_radius * grow, 0.0, TAU, 56, Color(1.0, 0.62, 0.74, 0.85 * (1.0 - k)), 3.0)
	# a big bloom at the centre that opens and fades
	var bloom := (1.0 - k) * 0.9 + 0.1
	draw_circle(Vector2.ZERO, 34.0 * (0.6 + grow * 0.6), Color(ROSE_RED.r, ROSE_RED.g, ROSE_RED.b, 0.55 * bloom))
	draw_circle(Vector2.ZERO, 22.0 * (0.6 + grow * 0.6), Color(ROSE_PINK.r, ROSE_PINK.g, ROSE_PINK.b, 0.6 * bloom))
	draw_circle(Vector2.ZERO, 10.0 * (0.6 + grow * 0.6), Color(1.0, 0.95, 0.95, 0.7 * bloom))
	# petals flying outward and drifting down
	for p in _petals:
		var pos: Vector2 = p["dir"] * p["dist"] * grow + Vector2(0.0, 30.0 * k * k)
		var c: Color = p["col"]
		draw_set_transform(pos, float(p["spin"]) * k, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, float(p["size"]), Color(c.r, c.g, c.b, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
