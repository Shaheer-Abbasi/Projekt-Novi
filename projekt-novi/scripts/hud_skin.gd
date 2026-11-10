class_name HudSkin
extends Node
## Restyles the HUD's top-left corner with YOUR pictures: the portrait, the health bar, the XP bar and the level badge.
##
## Add it as a child of the HUD node (the one with playtest_hud.gd), then drag your pictures onto its fields. It does NOT change your HUD script:
## the HUD keeps filling its own health bar, XP bar and level label as before; this node hides those and draws your pictures in their place,
## following the same values. Everything is positioned like your Photoshop mockup (pixels of a 1920 x 1080 canvas) and scales to the window.

@export var enabled: bool = true:
	set(v):
		enabled = v
		if _root != null:
			_apply_enabled()
## Hide the old health bar, XP bar, name, HP text, level text and portrait of the HUD (they still receive their values, you just don't see them).
@export var hide_old_cluster: bool = true

@export_group("Your pictures")
## The portrait, with its frame drawn into the picture.
@export var portrait: Texture2D
@export var hp_background: Texture2D
## The part that goes DOWN when health is lost.
@export var hp_fill: Texture2D
@export var xp_background: Texture2D
## The part that GROWS as XP is gained.
@export var xp_fill: Texture2D
## The box behind the level number.
@export var level_badge: Texture2D

@export_group("Layout (pixels on a 1920 x 1080 canvas, like your mockup)")
## Everything scales with the window height; this makes the whole corner bigger or smaller on top of that.
@export var hud_scale: float = 1.0
## Where the PICTURE's own top-left corner goes (the frame inside it starts a few pixels further in).
@export var portrait_position: Vector2 = Vector2(-1.0, 22.0)
## 1.0 = the picture's own size, as in your mockup.
@export var portrait_scale: float = 1.0
@export var hp_position: Vector2 = Vector2(266.0, 41.0)
@export var xp_position: Vector2 = Vector2(347.0, 67.0)
@export var level_position: Vector2 = Vector2(264.0, 65.0)

@export_group("Bars")
## Where the fill sits inside its background, in the picture's own pixels (0, 0 = the top-left corners line up).
@export var hp_fill_offset: Vector2 = Vector2.ZERO
@export var xp_fill_offset: Vector2 = Vector2.ZERO
## ON: as the bar shrinks, its two ends keep their shape (the slanted end of the health bar stays slanted). OFF: the picture is simply cut off.
@export var keep_end_shapes: bool = true
## How many pixels at the RIGHT end of the health fill are the slanted end that must keep its shape.
@export var hp_end_cap_px: int = 14
@export var hp_start_cap_px: int = 0
@export var xp_end_cap_px: int = 2
@export var xp_start_cap_px: int = 2
## How quickly a bar slides to a new value (0 = instantly).
@export var smooth_seconds: float = 0.15

@export_group("Level number")
## {level} becomes the number. "{level}" = just the digit; "LV {level}" = LV 3.
@export var level_format: String = "{level}"
@export var font: Font
@export var level_font_size: int = 28
@export var level_color: Color = Color(0.60, 0.95, 0.95)
## Nudge the number inside the badge (pixels on the 1920 x 1080 canvas).
@export var level_text_offset: Vector2 = Vector2(0.0, -2.0)

const DESIGN_H := 1080.0

var _root: Control
var _portrait_rect: TextureRect
var _hp: SpriteBar
var _xp: SpriteBar
var _badge: TextureRect
var _level_label: Label
var _old_hp: Range
var _old_xp: Range
var _old_nodes: Array = []
var _hp_shown: float = 1.0
var _xp_shown: float = 0.0
var _first: bool = true
var _xpm: Node
var _last_level: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS              # keep following the values while the game is paused (the level-up screen)
	_xpm = get_node_or_null("/root/XpManager")
	_old_hp = _find("HPBar") as Range
	_old_xp = _find("XPBar") as Range
	for n in ["HPBar", "XPBar", "NameLabel", "HPLabel", "LevelLabel"]:
		var node := _find(n)
		if node != null:
			_old_nodes.append(node)
	_build()
	_apply_enabled()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _exit_tree() -> void:
	_set_old_visible(true)


## Finds a HUD node by its unique name (%Name) or, failing that, by its name anywhere under the HUD.
func _find(node_name: String) -> Node:
	var n := get_node_or_null("%" + node_name)
	if n == null and get_parent() != null:
		n = get_parent().find_child(node_name, true, false)
	return n


func _build() -> void:
	_root = Control.new()
	_root.name = "SkinRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_hp = SpriteBar.new()
	_hp.name = "HealthBar"
	_root.add_child(_hp)
	_xp = SpriteBar.new()
	_xp.name = "XpBar"
	_root.add_child(_xp)
	_badge = TextureRect.new()
	_badge.name = "LevelBadge"
	_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge.stretch_mode = TextureRect.STRETCH_SCALE
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_badge)
	_level_label = Label.new()
	_level_label.name = "LevelNumber"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_level_label)
	_portrait_rect = TextureRect.new()
	_portrait_rect.name = "Portrait"
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_portrait_rect)


func _apply_enabled() -> void:
	_root.visible = enabled
	_set_old_visible(not (enabled and hide_old_cluster))


func _set_old_visible(v: bool) -> void:
	for n in _old_nodes:
		if is_instance_valid(n) and n is CanvasItem:
			n.visible = v
	# the old portrait (a Sprite2D) and the group that holds the old cluster
	if _old_hp != null and is_instance_valid(_old_hp):
		var cluster := _old_hp.get_parent()
		if cluster is Node2D:                                    # the Node2D that holds the old bars, labels and portrait
			(cluster as Node2D).visible = v
		elif cluster != null:
			for s in cluster.find_children("*", "Sprite2D", false, false):
				(s as Sprite2D).visible = v


## Sizes and places everything for the current window.
func _layout() -> void:
	if _root == null:
		return
	var k := get_viewport().get_visible_rect().size.y / DESIGN_H * hud_scale
	_portrait_rect.texture = portrait
	_portrait_rect.position = portrait_position * k
	_portrait_rect.size = (portrait.get_size() * portrait_scale * k) if portrait != null else Vector2.ZERO
	_hp.setup(hp_background, hp_fill, hp_fill_offset, float(hp_start_cap_px), float(hp_end_cap_px), keep_end_shapes, k)
	_hp.position = hp_position * k
	_xp.setup(xp_background, xp_fill, xp_fill_offset, float(xp_start_cap_px), float(xp_end_cap_px), keep_end_shapes, k)
	_xp.position = xp_position * k
	_badge.texture = level_badge
	_badge.position = level_position * k
	_badge.size = (level_badge.get_size() * k) if level_badge != null else Vector2.ZERO
	_level_label.position = _badge.position + level_text_offset * k
	_level_label.size = _badge.size
	_level_label.add_theme_font_size_override("font_size", int(float(level_font_size) * k))
	_level_label.add_theme_color_override("font_color", level_color)
	if font != null:
		_level_label.add_theme_font_override("font", font)
	_refresh_level(true)


func _process(delta: float) -> void:
	if not enabled or _root == null:
		return
	var step := 1.0
	if smooth_seconds > 0.0 and not _first:
		step = 1.0 - exp(-minf(delta / maxf(Engine.time_scale, 0.001), 0.1) / smooth_seconds)
	_hp_shown = lerpf(_hp_shown, _ratio(_old_hp, 1.0), step) if not _first else _ratio(_old_hp, 1.0)
	_xp_shown = lerpf(_xp_shown, _ratio(_old_xp, 0.0), step) if not _first else _ratio(_old_xp, 0.0)
	_first = false
	_hp.set_ratio(_hp_shown)
	_xp.set_ratio(_xp_shown)
	_refresh_level(false)


func _ratio(bar: Range, fallback: float) -> float:
	if bar == null or not is_instance_valid(bar):
		return fallback
	var span := bar.max_value - bar.min_value
	return clampf((bar.value - bar.min_value) / span, 0.0, 1.0) if span > 0.0 else fallback


func _refresh_level(force: bool) -> void:
	var lv: int = int(_xpm.get("level")) if _xpm != null and _xpm.get("level") != null else 1
	if force or lv != _last_level:
		_last_level = lv
		_level_label.text = level_format.replace("{level}", str(lv))


## One bar drawn from two pictures: a background, and a fill that is drawn up to `ratio` of its width.
## With "keep end shapes", the ends of the fill keep their own shape while the middle stretches (so a slanted end stays slanted).
class SpriteBar extends Control:
	var bg: Texture2D
	var fill: Texture2D
	var fill_offset: Vector2 = Vector2.ZERO
	var cap_left: float = 0.0
	var cap_right: float = 0.0
	var keep_shape: bool = true
	var art_scale: float = 1.0
	var ratio: float = 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(b: Texture2D, f: Texture2D, offset: Vector2, cl: float, cr: float, keep: bool, k: float) -> void:
		bg = b
		fill = f
		fill_offset = offset
		cap_left = cl
		cap_right = cr
		keep_shape = keep
		art_scale = k
		var base: Texture2D = b if b != null else f
		size = (base.get_size() * k) if base != null else Vector2.ZERO
		queue_redraw()

	func set_ratio(r: float) -> void:
		if absf(r - ratio) > 0.0004:
			ratio = r
			queue_redraw()

	## The pieces of the fill to draw: [destination rectangle, source rectangle in the picture]. (Public so it can be tested.)
	func fill_pieces() -> Array:
		var out: Array = []
		if fill == null or ratio <= 0.0005:
			return out
		var fs := fill.get_size()
		var k := art_scale
		var origin := fill_offset * k
		var w := fs.x * k * ratio
		if not keep_shape or ratio >= 0.9995:
			out.append([Rect2(origin, Vector2(w, fs.y * k)), Rect2(Vector2.ZERO, Vector2(fs.x * ratio, fs.y))])
			return out
		var cl := minf(cap_left, fs.x * 0.5)
		var cr := minf(cap_right, fs.x * 0.5)
		var wl := cl * k
		var wr := cr * k
		if w < wl + wr:                                           # nearly empty: squeeze the two ends together
			var f2 := w / maxf(wl + wr, 0.001)
			wl *= f2
			wr *= f2
		if cl > 0.0:
			out.append([Rect2(origin, Vector2(wl, fs.y * k)), Rect2(0.0, 0.0, cl, fs.y)])
		var mid_w := w - wl - wr
		if mid_w > 0.0:
			out.append([Rect2(origin + Vector2(wl, 0.0), Vector2(mid_w, fs.y * k)), Rect2(cl, 0.0, fs.x - cl - cr, fs.y)])
		if cr > 0.0:
			out.append([Rect2(origin + Vector2(w - wr, 0.0), Vector2(wr, fs.y * k)), Rect2(fs.x - cr, 0.0, cr, fs.y)])
		return out

	func _draw() -> void:
		if bg != null:
			draw_texture_rect(bg, Rect2(Vector2.ZERO, bg.get_size() * art_scale), false)
		for piece in fill_pieces():
			draw_texture_rect_region(fill, piece[0], piece[1])
