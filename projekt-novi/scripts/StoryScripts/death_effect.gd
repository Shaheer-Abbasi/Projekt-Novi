class_name DeathEffect
extends Node2D
## What plays where an enemy died: it BLINKS a different color, then DISINTEGRATES into little pixels that drift away,
## glow like embers and fade. It works from a SNAPSHOT of the enemy's sprite, so the enemy itself can be freed the instant it dies.
## You normally never touch this: the DeathEffects node (or a StoryLevel) creates it. Settings live on the DeathEffects node.
## It runs in REAL time (not slowed by the slow-motion) and stops while the game is paused.

var blink_color: Color = Color(1.0, 0.25, 0.2)
var blink_flashes: int = 3
var blink_seconds: float = 0.45
var disintegrate: bool = true
var disintegrate_seconds: float = 2.0
var ember_color: Color = Color(1.0, 0.55, 0.15)
var spread: float = 70.0
var rise: float = 50.0

var phase: String = "blink"        # "blink" -> "disintegrate" -> "done"
var t: float = 0.0
var flash: float = 1.0             # how much of the blink color is showing right now (0..1)
var released: int = 0              # how many pixels have started to fly
var cell_count: int = 0

const LIFE := 0.35                 # how long (as a share of the disintegration) one pixel takes to fly away and fade

var _layers: Array = []            # {tex, src, xform, color, sil, centered, offset, flip_h, flip_v}
var _c_layer: PackedInt32Array = PackedInt32Array()
var _c_src: Array[Rect2] = []
var _c_pos: PackedVector2Array = PackedVector2Array()
var _c_size: PackedVector2Array = PackedVector2Array()
var _c_th: PackedFloat32Array = PackedFloat32Array()
var _c_vel: PackedVector2Array = PackedVector2Array()
var _c_spin: PackedFloat32Array = PackedFloat32Array()


## Makes the effect for a dying enemy. `cfg` is a DeathEffects node (its settings are copied). Returns null if there is nothing to show.
static func spawn(enemy: Node2D, cfg: Node) -> DeathEffect:
	if enemy == null or not is_instance_valid(enemy) or enemy.get_parent() == null:
		return null
	var layers := _capture(enemy)
	if layers.is_empty():
		return null
	var boss := enemy.is_in_group("boss")
	var longer: float = cfg.boss_longer_by if boss else 1.0
	var fx := DeathEffect.new()
	fx.top_level = true                                  # drawn in world coordinates, whatever the parent's transform
	fx.z_index = 20
	fx.blink_color = cfg.blink_color
	fx.blink_flashes = cfg.blink_flashes
	fx.blink_seconds = cfg.blink_seconds * longer
	fx.disintegrate = cfg.disintegrate
	fx.disintegrate_seconds = cfg.disintegrate_seconds * longer
	fx.ember_color = cfg.ember_color
	fx.spread = cfg.spread * (cfg.boss_bigger_spread if boss else 1.0)
	fx.rise = cfg.rise * (cfg.boss_bigger_spread if boss else 1.0)
	fx._build(layers, cfg.pixel_size)
	enemy.get_parent().add_child.call_deferred(fx)
	return fx


## The sprites of an enemy as they look right now (picture, which part of it, where it is, its tint).
static func _capture(enemy: Node2D) -> Array:
	var out: Array = []
	var base_tint = enemy.get("_base_tint")
	for node in enemy.find_children("*", "Sprite2D", true, false):
		var sp := node as Sprite2D
		if sp == null or sp.texture == null or not sp.is_visible_in_tree():
			continue
		var tex: Texture2D = sp.texture
		var src := Rect2(Vector2.ZERO, tex.get_size())
		if sp.region_enabled:
			src = sp.region_rect
		elif sp.hframes * sp.vframes > 1:
			var fw := tex.get_width() / float(sp.hframes)
			var fh := tex.get_height() / float(sp.vframes)
			src = Rect2(Vector2((sp.frame % sp.hframes) * fw, (sp.frame / sp.hframes) * fh), Vector2(fw, fh))
		var color := sp.modulate * sp.self_modulate
		if base_tint is Color and sp == enemy.get("sprite"):
			color = (base_tint as Color) * sp.self_modulate      # the enemy's own tint, not a hit flash it happens to be in the middle of
		var img: Image = tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		if img != null and img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		out.append({
			"tex": tex, "src": src, "xform": sp.global_transform, "color": color, "img": img,
			"centered": sp.centered, "offset": sp.offset, "flip_h": sp.flip_h, "flip_v": sp.flip_v,
		})
	return out


func _build(layers: Array, cell: int) -> void:
	_layers = layers
	var total_min := Vector2(1e9, 1e9)
	var total_max := Vector2(-1e9, -1e9)
	for li in range(layers.size()):
		var L: Dictionary = layers[li]
		var src: Rect2 = L["src"]
		var img: Image = L["img"]
		L["sil"] = _make_silhouette(img, src, blink_color, L["color"])
		var px := maxi(cell, 1)
		while (src.size.x / px) * (src.size.y / px) > 2500.0:      # a big sprite uses bigger pixels (never thousands of them)
			px += 1
		var scale: Vector2 = (L["xform"] as Transform2D).get_scale()
		for cy in range(0, int(src.size.y), px):
			for cx in range(0, int(src.size.x), px):
				var cw := mini(px, int(src.size.x) - cx)
				var ch := mini(px, int(src.size.y) - cy)
				if img != null:
					var sx := int(src.position.x) + cx + cw / 2
					var sy := int(src.position.y) + cy + ch / 2
					if sx < img.get_width() and sy < img.get_height() and img.get_pixel(sx, sy).a < 0.15:
						continue                                      # empty space: no pixel here
				var lx := float(cx)
				var ly := float(cy)
				if L["flip_h"]:
					lx = src.size.x - cx - cw
				if L["flip_v"]:
					ly = src.size.y - cy - ch
				var local := Vector2(lx, ly) + (L["offset"] as Vector2)
				if L["centered"]:
					local -= src.size * 0.5
				local += Vector2(cw, ch) * 0.5
				var world: Vector2 = (L["xform"] as Transform2D) * local
				_c_layer.append(li)
				_c_src.append(Rect2(src.position + Vector2(cx, cy), Vector2(cw, ch)))
				_c_pos.append(world)
				_c_size.append(Vector2(cw, ch) * scale)
				total_min = total_min.min(world)
				total_max = total_max.max(world)
	cell_count = _c_pos.size()
	var center := (total_min + total_max) * 0.5
	var height := maxf(total_max.y - total_min.y, 1.0)
	for i in range(cell_count):
		var ny := (_c_pos[i].y - total_min.y) / height                # 0 = top of the sprite, 1 = bottom
		_c_th.append(clampf(0.65 * (0.55 * randf() + 0.45 * (1.0 - ny)), 0.0, 0.65))      # top crumbles first, with randomness
		var dir := (_c_pos[i] - center).normalized() if _c_pos[i].distance_to(center) > 0.5 else Vector2.from_angle(randf() * TAU)
		_c_vel.append((dir + Vector2.from_angle(randf() * TAU) * 0.6).normalized() * (0.4 + randf()))
		_c_spin.append(randf_range(-4.0, 4.0))


## The whole sprite painted in one solid color (kept transparent where the sprite is), for the blink.
static func _make_silhouette(img: Image, src: Rect2, color: Color, tint: Color) -> Texture2D:
	if img == null:
		return null
	var region := Image.create(maxi(int(src.size.x), 1), maxi(int(src.size.y), 1), false, Image.FORMAT_RGBA8)
	var ox := int(src.position.x)
	var oy := int(src.position.y)
	for y in range(region.get_height()):
		for x in range(region.get_width()):
			if ox + x < img.get_width() and oy + y < img.get_height():
				var a := img.get_pixel(ox + x, oy + y).a * tint.a
				if a > 0.0:
					region.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(region)


func _process(delta: float) -> void:
	t += delta / maxf(Engine.time_scale, 0.001)             # real time: the slow motion does not slow this down
	if t < blink_seconds:
		phase = "blink"
		var step := blink_seconds / float(maxi(blink_flashes * 2, 1))
		flash = 1.0 if int(t / step) % 2 == 0 else 0.0       # starts on the new color, then flickers
	elif t < blink_seconds + disintegrate_seconds:
		phase = "disintegrate"
		flash = 0.0
	else:
		phase = "done"
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if phase == "blink":
		for L in _layers:
			_draw_layer(L, 1.0, flash)
	elif phase == "disintegrate":
		var u := clampf((t - blink_seconds) / maxf(disintegrate_seconds, 0.01), 0.0, 1.0)
		if disintegrate:
			_draw_pixels(u)
		else:
			for L in _layers:                                  # "turn a different color and fade"
				_draw_layer(L, 1.0 - u, 1.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_layer(L: Dictionary, alpha: float, flash_amount: float) -> void:
	var tex: Texture2D = L["tex"]
	var src: Rect2 = L["src"]
	draw_set_transform_matrix(L["xform"])
	var size := src.size
	var origin: Vector2 = (L["offset"] as Vector2) - (size * 0.5 if L["centered"] else Vector2.ZERO)
	var dest := Rect2(origin, size)
	if L["flip_h"]:
		dest.size.x = -dest.size.x           # a negative size mirrors the picture; the rectangle still starts at its left edge
	if L["flip_v"]:
		dest.size.y = -dest.size.y
	var col: Color = L["color"]
	draw_texture_rect_region(tex, dest, src, Color(col.r, col.g, col.b, col.a * alpha))
	if flash_amount > 0.0 and L["sil"] != null:
		draw_texture_rect(L["sil"], dest, false, Color(1, 1, 1, flash_amount * alpha))


func _draw_pixels(u: float) -> void:
	var flying := 0
	for i in range(cell_count):
		var L: Dictionary = _layers[_c_layer[i]]
		var col: Color = L["color"]
		var th := _c_th[i]
		var pos := _c_pos[i]
		var size := _c_size[i]
		var rot := 0.0
		var alpha := col.a
		var ember := 0.0
		if u >= th:
			flying += 1
			var v := clampf((u - th) / LIFE, 0.0, 1.0)
			pos += _c_vel[i] * spread * v + Vector2(0.0, -rise) * v
			rot = _c_spin[i] * v
			size *= 1.0 - 0.55 * v
			alpha *= pow(1.0 - v, 1.3)
			ember = clampf(v * 2.4, 0.0, 1.0) * 0.9           # turns into a glowing ember quickly, then fades
		else:
			pos += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.6 * u      # a slight shiver before it lets go
		if alpha <= 0.01:
			continue
		draw_set_transform(pos, rot, Vector2.ONE)
		var r := Rect2(-size * 0.5, size)
		var shown := r                                       # (mirrored sprites mirror each little pixel-block too)
		if L["flip_h"]:
			shown.size.x = -shown.size.x
		if L["flip_v"]:
			shown.size.y = -shown.size.y
		draw_texture_rect_region(L["tex"], shown, _c_src[i], Color(col.r, col.g, col.b, alpha))
		if ember > 0.0:
			draw_rect(r, Color(ember_color.r, ember_color.g, ember_color.b, ember * minf(alpha * 1.6, 1.0)))
	released = flying
