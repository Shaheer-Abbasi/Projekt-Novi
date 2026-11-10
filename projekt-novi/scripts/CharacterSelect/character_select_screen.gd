class_name CharacterSelectScreen
extends Control
## The Hiring Board: the Character Select screen, built to your Photoshop mockup.
##
## It shows one portrait tile per entry on the left. Click an unlocked character to see their illustration, story and abilities; click
## "Select Character to Continue" (or press Enter on the selected one) to go on to the next scene. Locked characters are greyed out:
## pointing at them works, but clicking one makes it blink red and shake, and nothing is selected.
##
## Everything is drawn in code from the pictures and entries below, sized for a 1920 x 1080 canvas like your mockup, and scaled to the window.

## A character was chosen (clicked, or Enter pressed on it).
signal character_selected(entry: CharacterSelectEntry, index: int)
## A locked character was clicked.
signal character_denied(entry: CharacterSelectEntry, index: int)
## The player pressed "Continue" with this character selected.
signal character_confirmed(entry: CharacterSelectEntry)

## The CharacterData of the character that was chosen (null = none chosen, or Vow, who uses the player's own default).
## Read it from anywhere as CharacterSelectScreen.selected_character. It is kept while the game runs.
static var selected_character: Resource = null
## The display name of the character that was chosen last, so coming back to this screen remembers it.
static var selected_name: String = ""

## One entry per character, top to bottom.
@export var entries: Array[CharacterSelectEntry] = []
## The scene opened by "Continue", and by pressing Esc (back). Leave empty to do nothing but send the signals.
@export_file("*.tscn") var next_scene: String = "res://scenes/TempScenes/survivalscene_corphq.tscn"
@export_file("*.tscn") var back_scene: String = "res://scenes/MainMenuScenes/main_menu.tscn"

@export_group("Pictures")
@export var background: Texture2D
@export var title_triangle: Texture2D
@export var heading: Texture2D
@export var heading_glow: Texture2D
@export var divider: Texture2D
@export var divider_glow: Texture2D
@export var desc_panel: Texture2D
@export var desc_glow: Texture2D
@export var tile_glow_normal: Texture2D
@export var tile_glow_selected: Texture2D
@export var continue_text: Texture2D
@export var continue_glow: Texture2D
@export var continue_arrow: Texture2D

@export_group("Text")
## Your font (the mockup uses Cascadia Code SemiBold). Without one the engine's default font is used.
@export var font: Font
@export var title_text: String = "HIRING BOARD"
@export var text_color: Color = Color.WHITE
## Small nudges (pixels on the 1920 x 1080 canvas) that line the letters up with the mockup. Change them if you use a different font.
@export var title_nudge: Vector2 = Vector2(-5.0, -16.0)
@export var name_nudge: Vector2 = Vector2(-1.0, -11.0)
@export var body_nudge: Vector2 = Vector2(-1.0, -4.0)
## Extra space between lines of the story and ability texts (negative = tighter).
@export var body_line_spacing: float = -2.0

@export_group("Layout (pixels on a 1920 x 1080 canvas, like your mockup)")
@export var title_triangle_position: Vector2 = Vector2(26.0, 44.0)
## Where the letters of the title start.
@export var title_position: Vector2 = Vector2(102.0, 44.0)
## The first tile's top-left corner, the size of a tile, and the step from one tile to the next.
@export var tile_origin: Vector2 = Vector2(89.0, 301.0)
@export var tile_size: float = 145.0
@export var tile_step: Vector2 = Vector2(0.0, 166.0)
## How many tiles fit in the column; with more characters the column scrolls (mouse wheel, or up / down).
@export var tiles_visible: int = 3
@export var desc_panel_position: Vector2 = Vector2(0.0, 800.0)
@export var name_position: Vector2 = Vector2(27.0, 820.0)
@export var story_position: Vector2 = Vector2(42.0, 878.0)
@export var heading_position: Vector2 = Vector2(1356.0, 28.0)
@export var ultimate_bar_position: Vector2 = Vector2(1288.0, 124.0)
## The box the Ultimate's name and text are centred in.
@export var ultimate_text_box: Rect2 = Rect2(1318.0, 302.0, 411.0, 58.0)
@export var divider_position: Vector2 = Vector2(1164.0, 365.0)
@export var ability_icon_positions: PackedVector2Array = PackedVector2Array([Vector2(1220.0, 427.0), Vector2(1220.0, 588.0), Vector2(1220.0, 747.0)])
@export var ability_text_positions: PackedVector2Array = PackedVector2Array([Vector2(1372.0, 469.0), Vector2(1372.0, 629.0), Vector2(1372.0, 790.0)])
@export var continue_text_position: Vector2 = Vector2(1255.0, 974.0)
@export var continue_arrow_position: Vector2 = Vector2(1834.0, 1001.0)
## The area that reacts to the mouse for "Continue".
@export var continue_hit_rect: Rect2 = Rect2(1270.0, 998.0, 640.0, 66.0)

@export_group("Locked characters")
## 1 = fully grey. The dimmer, the darker.
@export_range(0.0, 1.0) var locked_gray: float = 1.0
@export_range(0.0, 1.0) var locked_dim: float = 0.5
## How far a locked tile shakes sideways (pixels on the 1920 canvas) and for how long.
@export var shake_pixels: float = 14.0
@export var shake_seconds: float = 0.45
## How many times it blinks red.
@export var blink_count: int = 2

@export_group("Feedback")
## A tile you point at (not the selected one) grows by this much.
@export var hover_scale: float = 1.05
@export var fade_seconds: float = 0.2
## How far the arrow slides to the right when you point at Continue (pixels on the 1920 canvas).
@export var arrow_slide: float = 14.0

@export_group("Sounds")
@export var hover_sound: AudioStream
@export var select_sound: AudioStream
@export var deny_sound: AudioStream
@export var confirm_sound: AudioStream
@export var sound_bus: StringName = &"Master"

@export_group("Opening")
## How long the screen takes to slide in when it opens (0 = at once).
@export var intro_seconds: float = 0.8
## The fade to black when leaving the screen.
@export var leave_fade_seconds: float = 0.3

const TILE_MARGIN := 24.0
const TILE_GLOW_MARGIN := 70.0
const TILE_GLOW_NORMAL_MARGIN := 30.0
const DESC_GLOW_OFFSET := Vector2(0.0, 30.0)

const SHADER_NORMAL := """
shader_type canvas_item;
uniform float gray : hint_range(0.0, 1.0) = 0.0;
uniform float dim : hint_range(0.0, 1.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.1, 0.1, 1.0);
void fragment() {
	float g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	vec3 c = mix(COLOR.rgb, vec3(g), gray) * dim;
	c = mix(c, flash_color.rgb * (0.30 + g * 1.1), flash);
	COLOR.rgb = c;
}
"""
const SHADER_ADD := """
shader_type canvas_item;
render_mode blend_add;
uniform float gray : hint_range(0.0, 1.0) = 0.0;
uniform float dim : hint_range(0.0, 1.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.1, 0.1, 1.0);
void fragment() {
	float g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	vec3 c = mix(COLOR.rgb, vec3(g), gray) * dim;
	c = mix(c, flash_color.rgb * g * 2.5, flash);
	COLOR.rgb = c;
}
"""

var _k: float = 1.0
var _bg: TextureRect
var _stage: Control
var _art_group: Control
var _tiles_group: Control
var _tiles_clip: Control                 # the window the tile column scrolls inside
var _scroll: float = 0.0                 # first visible tile (animated)
var _scroll_target: int = 0
var _scroll_tw: Tween
var _arrow_up: Label
var _arrow_down: Label
var _desc_group: Control
var _title_group: Control
var _heading_group: Control
var _info_left: Control
var _info_right: Control
var _continue_group: Control
var _fade: ColorRect
var _ill: TextureRect
var _sh: TextureRect
var _sp: TextureRect
var _triangle: TextureRect
var _title_label: Label
var _desc_panel_rect: TextureRect
var _desc_glow_rect: TextureRect
var _name_label: Label
var _story_label: Label
var _heading_rect: TextureRect
var _heading_glow_rect: TextureRect
var _divider_rect: TextureRect
var _divider_glow_rect: TextureRect
var _ult_bar: TextureRect
var _ult_label: Label
var _ab_icons: Array[TextureRect] = []
var _ab_labels: Array[Label] = []
var _c_text: TextureRect
var _c_glow: TextureRect
var _c_arrow: TextureRect
var _tiles: Array[TileNode] = []
var _shader_normal: Shader
var _shader_add: Shader
var _hover_player: AudioStreamPlayer
var _select_player: AudioStreamPlayer
var _deny_player: AudioStreamPlayer
var _confirm_player: AudioStreamPlayer
var _selected: int = 0
var _hover_index: int = -1
var _mouse_mode: bool = true
var _continue_hover: bool = false
var _leaving: bool = false
var _swap_tw: Tween
var _arrow_tw: Tween
var _glow_tw: Tween


func _ready() -> void:
	_shader_normal = Shader.new()
	_shader_normal.code = SHADER_NORMAL
	_shader_add = Shader.new()
	_shader_add.code = SHADER_ADD
	# Who is unlocked comes from the save (the Premium Shop's gacha unlocks characters).
	for e in entries:
		if e != null:
			e.locked = not SaveData.is_unlocked(e.display_name)
	_build()
	if entries.is_empty():
		push_warning("CharacterSelectScreen: there are no entries, so nothing can be chosen.")
	else:
		_selected = _initial_index()
		_scroll_target = clampi(_selected - tiles_visible + 1, 0, _max_scroll())     # start with the chosen character in view
		_scroll = float(_scroll_target)
		selected_character = entries[_selected].character_data
		selected_name = entries[_selected].display_name
		_fill_entry(entries[_selected])
	_layout()
	_refresh_tiles(false)
	get_viewport().size_changed.connect(_layout)
	_play_intro()


# ----------------------------------------------------------------------------- building

func _tex_rect(tex: Texture2D, additive: bool = false) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		t.material = m
	return t


func _group(parent: Control, group_name: String) -> Control:
	var g := Control.new()
	g.name = group_name
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)
	return g


func _make_label(centered: bool = false) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return l


func _build() -> void:
	_bg = _tex_rect(background)
	_bg.name = "Background"
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_bg)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_art_group = _group(_stage, "Illustration")
	_ill = _tex_rect(null)
	_sh = _tex_rect(null)
	_sp = _tex_rect(null)
	_art_group.add_child(_ill)
	_art_group.add_child(_sh)
	_art_group.add_child(_sp)
	_tiles_group = _group(_stage, "Tiles")
	_tiles_clip = Control.new()
	_tiles_clip.name = "ScrollWindow"
	_tiles_clip.mouse_filter = Control.MOUSE_FILTER_PASS     # no clipping (it would cut the selection glow): tiles outside the window fade out instead
	_tiles_group.add_child(_tiles_clip)
	for i in range(entries.size()):
		var t := TileNode.new(i, self)
		t.name = "Tile%d" % (i + 1)
		_tiles_clip.add_child(t)
		t.hovered.connect(_on_tile_hover)
		t.unhovered.connect(_on_tile_unhover)
		t.clicked.connect(_on_tile_clicked)
		_tiles.append(t)
	_arrow_up = _make_label(true)
	_arrow_up.text = "▲"
	_arrow_down = _make_label(true)
	_arrow_down.text = "▼"
	for a in [_arrow_up, _arrow_down]:
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tiles_group.add_child(a)
	_desc_group = _group(_stage, "DescriptionPanel")
	_desc_panel_rect = _tex_rect(desc_panel)
	_desc_glow_rect = _tex_rect(desc_glow, true)
	_desc_group.add_child(_desc_panel_rect)
	_desc_group.add_child(_desc_glow_rect)
	_title_group = _group(_stage, "Title")
	_triangle = _tex_rect(title_triangle)
	_title_label = _make_label()
	_title_label.text = title_text
	_title_group.add_child(_triangle)
	_title_group.add_child(_title_label)
	_heading_group = _group(_stage, "AbilitiesHeading")
	_heading_rect = _tex_rect(heading)
	_heading_glow_rect = _tex_rect(heading_glow, true)
	_divider_rect = _tex_rect(divider)
	_divider_glow_rect = _tex_rect(divider_glow, true)
	for r in [_heading_rect, _heading_glow_rect, _divider_rect, _divider_glow_rect]:
		_heading_group.add_child(r)
	_info_left = _group(_stage, "NameAndStory")
	_name_label = _make_label()
	_story_label = _make_label()
	_info_left.add_child(_name_label)
	_info_left.add_child(_story_label)
	_info_right = _group(_stage, "Abilities")
	_ult_bar = _tex_rect(null)
	_ult_label = _make_label(true)
	_info_right.add_child(_ult_bar)
	_info_right.add_child(_ult_label)
	for i in range(3):
		var ic := _tex_rect(null)
		var lb := _make_label()
		_info_right.add_child(ic)
		_info_right.add_child(lb)
		_ab_icons.append(ic)
		_ab_labels.append(lb)
	_continue_group = _group(_stage, "Continue")
	_continue_group.mouse_filter = Control.MOUSE_FILTER_STOP
	_continue_group.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_c_text = _tex_rect(continue_text)
	_c_glow = _tex_rect(continue_glow, true)
	_c_arrow = _tex_rect(continue_arrow)
	for r in [_c_text, _c_glow, _c_arrow]:
		_continue_group.add_child(r)
	_continue_group.mouse_entered.connect(_on_continue_hover.bind(true))
	_continue_group.mouse_exited.connect(_on_continue_hover.bind(false))
	_continue_group.gui_input.connect(_on_continue_input)
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	for pl in [["_hover_player", hover_sound], ["_select_player", select_sound], ["_deny_player", deny_sound], ["_confirm_player", confirm_sound]]:
		var p := AudioStreamPlayer.new()
		p.bus = sound_bus
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		set(pl[0], p)


func _initial_index() -> int:
	if selected_name != "":
		for i in range(entries.size()):
			if entries[i].display_name == selected_name and not entries[i].locked:
				return i
	for i in range(entries.size()):
		if not entries[i].locked:
			return i
	return 0


## The text font: your font (or the default) with the letters spaced out by `spacing` canvas pixels.
func _font_for(spacing: float) -> Font:
	var fv := FontVariation.new()
	fv.base_font = font if font != null else ThemeDB.fallback_font
	fv.spacing_glyph = int(round(spacing * _k))
	return fv


func _style_label(l: Label, design_size: float, spacing: float, line_spacing: float = 0.0) -> void:
	l.add_theme_font_override("font", _font_for(spacing))
	l.add_theme_font_size_override("font_size", maxi(int(round(design_size * _k)), 6))
	l.add_theme_color_override("font_color", text_color)
	l.add_theme_constant_override("line_spacing", int(round(line_spacing * _k)))


# ----------------------------------------------------------------------------- layout

func _put(node: Control, design_pos: Vector2, tex: Texture2D = null) -> void:
	node.position = design_pos * _k
	if tex != null:
		node.size = tex.get_size() * _k
	elif node is TextureRect and (node as TextureRect).texture != null:
		node.size = (node as TextureRect).texture.get_size() * _k


## Sizes and places everything for the current window.
func _layout() -> void:
	if _stage == null:
		return
	var vs := get_viewport().get_visible_rect().size
	_k = minf(vs.y / 1080.0, vs.x / 1920.0)
	_bg.position = Vector2.ZERO
	_bg.size = vs
	_fade.position = Vector2.ZERO
	_fade.size = vs
	var cs := Vector2(1920.0, 1080.0) * _k
	_stage.size = cs
	_stage.position = (vs - cs) * 0.5
	for g in [_art_group, _tiles_group, _desc_group, _title_group, _heading_group, _info_left, _info_right]:
		(g as Control).position = Vector2.ZERO
		(g as Control).size = cs
	_put(_triangle, title_triangle_position)
	_style_label(_title_label, 71.7, 23.3)
	_title_label.position = (title_position + title_nudge) * _k
	_put(_desc_panel_rect, desc_panel_position)
	_put(_desc_glow_rect, desc_panel_position + DESC_GLOW_OFFSET)
	_style_label(_name_label, 45.5, 14.8)
	_name_label.position = (name_position + name_nudge) * _k
	_style_label(_story_label, 18.0, 0.0, body_line_spacing)
	_story_label.position = (story_position + body_nudge) * _k
	_put(_heading_rect, heading_position)
	_put(_heading_glow_rect, heading_position)
	_put(_divider_rect, divider_position)
	_put(_divider_glow_rect, divider_position)
	_style_label(_ult_label, 18.0, 0.0, body_line_spacing)
	_ult_label.position = (ultimate_text_box.position + body_nudge) * _k
	_ult_label.custom_minimum_size = Vector2(ultimate_text_box.size.x, 0.0) * _k
	_ult_label.size = Vector2(ultimate_text_box.size.x * _k, 0.0)
	_put(_ult_bar, ultimate_bar_position)
	for i in range(3):
		_put(_ab_icons[i], ability_icon_positions[i])
		_style_label(_ab_labels[i], 18.0, 0.0, body_line_spacing)
		_ab_labels[i].position = (ability_text_positions[i] + body_nudge) * _k
	var clip_top := tile_origin.y - TILE_GLOW_MARGIN
	_tiles_clip.position = Vector2(0.0, clip_top) * _k
	_tiles_clip.size = Vector2(tile_origin.x * 2.0 + tile_size + TILE_GLOW_MARGIN, tile_step.y * (tiles_visible - 1) + tile_size + TILE_GLOW_MARGIN * 1.6) * _k
	for i in range(_tiles.size()):
		_tiles[i].k = _k
		_tiles[i].setup(entries[i])
	_place_tiles()
	for a in [_arrow_up, _arrow_down]:
		_style_label(a, 26.0, 0.0)
		a.size = Vector2(tile_size, 30.0) * _k
	_arrow_up.position = Vector2(tile_origin.x, tile_origin.y - 48.0) * _k
	_arrow_down.position = Vector2(tile_origin.x, tile_origin.y + tile_step.y * (tiles_visible - 1) + tile_size + 4.0) * _k
	_update_arrows()
	_continue_group.position = continue_hit_rect.position * _k
	_continue_group.size = continue_hit_rect.size * _k
	_put(_c_text, continue_text_position - continue_hit_rect.position)
	_put(_c_glow, continue_text_position - continue_hit_rect.position)
	_c_arrow.texture = continue_arrow
	_c_arrow.size = continue_arrow.get_size() * _k if continue_arrow != null else Vector2.ZERO
	_c_arrow.position = (continue_arrow_position - continue_hit_rect.position + Vector2(arrow_slide if _continue_hover else 0.0, 0.0)) * _k
	if not entries.is_empty():
		_fit_entry(entries[_selected])


## The pictures and texts that belong to one character.
func _fill_entry(e: CharacterSelectEntry) -> void:
	_name_label.text = e.display_name
	if not e.locked:
		_name_label.text += "  " + SaveData.star_text(SaveData.get_stars(e.display_name))
	_story_label.text = e.story
	_ult_bar.texture = e.ultimate_bar
	_ult_label.text = e.ultimate_block()
	for i in range(3):
		_ab_icons[i].texture = e.ability_icon(i)
		_ab_labels[i].text = e.ability_block(i)
	_ill.texture = e.illustration
	_sh.texture = e.sprite_shadow
	_sp.texture = e.sprite
	_fit_entry(e)


func _fit_entry(e: CharacterSelectEntry) -> void:
	_put(_ult_bar, ultimate_bar_position)
	for i in range(3):
		_put(_ab_icons[i], ability_icon_positions[i])
	_put(_ill, e.illustration_position)
	_put(_sh, e.sprite_position)
	_put(_sp, e.sprite_position)


# ----------------------------------------------------------------------------- scrolling the tile column

func _max_scroll() -> int:
	return maxi(entries.size() - tiles_visible, 0)


## Puts every tile at its place in the column, shifted by the current scroll.
func _place_tiles() -> void:
	if _tiles_clip == null:
		return
	var offset := Vector2(0.0, tile_origin.y - TILE_GLOW_MARGIN)
	for i in range(_tiles.size()):
		var t := _tiles[i]
		t.rest = (tile_origin + tile_step * (float(i) - _scroll) - offset) * _k
		t.position = t.rest
		var rel := float(i) - _scroll
		var shown := clampf(1.0 - maxf(-rel, rel - float(tiles_visible - 1)), 0.0, 1.0)
		t.visible = shown > 0.01
		if t.visible and shown < 1.0:
			t.modulate.a = shown
		elif t.visible and _scroll_tw != null and _scroll_tw.is_valid():
			t.modulate.a = 1.0


func _set_scroll_value(v: float) -> void:
	_scroll = v
	_place_tiles()


func _scroll_to(target: int) -> void:
	target = clampi(target, 0, _max_scroll())
	if target == _scroll_target:
		return
	_scroll_target = target
	if _scroll_tw != null and _scroll_tw.is_valid():
		_scroll_tw.kill()
	_scroll_tw = create_tween()
	_scroll_tw.tween_method(_set_scroll_value, _scroll, float(target), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_update_arrows()


## Scrolls just enough that tile `i` is in view.
func _scroll_into_view(i: int) -> void:
	if i < _scroll_target:
		_scroll_to(i)
	elif i >= _scroll_target + tiles_visible:
		_scroll_to(i - tiles_visible + 1)


func _update_arrows() -> void:
	if _arrow_up == null:
		return
	_arrow_up.visible = _scroll_target > 0
	_arrow_down.visible = _scroll_target < _max_scroll()


# ----------------------------------------------------------------------------- the opening

func _play_intro() -> void:
	var t := intro_seconds
	if t <= 0.0:
		_fade.color.a = 0.0
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_fade, "color:a", 0.0, 0.4)
	var slide_l := 70.0 * _k
	var slide_r := 90.0 * _k
	var moves := [[_title_group, Vector2(-slide_l, 0.0), 0.0], [_art_group, Vector2(-slide_l * 1.4, 0.0), 0.08], [_desc_group, Vector2(-slide_l, 0.0), 0.2],
		[_info_left, Vector2(-slide_l, 0.0), 0.2], [_heading_group, Vector2(slide_r, 0.0), 0.1], [_info_right, Vector2(slide_r, 0.0), 0.16], [_continue_group, Vector2(0.0, slide_l * 0.5), 0.3]]
	for m in moves:
		var g: Control = m[0]
		var rest: Vector2 = g.position
		g.position = rest + m[1]
		g.modulate.a = 0.0
		tw.tween_property(g, "position", rest, t * 0.7).set_delay(m[2]).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(g, "modulate:a", 1.0, t * 0.55).set_delay(m[2])
	for i in range(_tiles.size()):
		var tile := _tiles[i]
		var rest_t := tile.rest
		tile.position = rest_t + Vector2(-slide_l, 0.0)
		tile.modulate.a = 0.0
		tw.tween_property(tile, "position", rest_t, t * 0.6).set_delay(0.1 + float(i) * 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tile, "modulate:a", 1.0, t * 0.5).set_delay(0.1 + float(i) * 0.09)


# ----------------------------------------------------------------------------- tiles: pointing, choosing, refusing

func _refresh_tiles(animate: bool) -> void:
	for i in range(_tiles.size()):
		_tiles[i].is_selected = (i == _selected)
		_tiles[i].is_hover = (i == _hover_index)
		_tiles[i].apply_state(animate)


func _on_tile_hover(i: int) -> void:
	if _leaving:
		return
	_mouse_mode = true
	if _hover_index != i:
		_hover_index = i
		_refresh_tiles(true)
		_play(_hover_player)


func _on_tile_unhover(i: int) -> void:
	if _hover_index == i and _mouse_mode:
		_hover_index = -1
		_refresh_tiles(true)


func _on_tile_clicked(i: int) -> void:
	if _leaving:
		return
	_mouse_mode = true
	_choose(i)


## Choose a tile: an unlocked one is selected, a locked one blinks red and shakes.
func _choose(i: int) -> void:
	if i < 0 or i >= entries.size():
		return
	if entries[i].locked:
		_tiles[i].deny()
		_play(_deny_player)
		character_denied.emit(entries[i], i)
		return
	if i == _selected:
		return
	_selected = i
	selected_character = entries[i].character_data
	selected_name = entries[i].display_name
	_refresh_tiles(true)
	_swap_to(entries[i])
	_play(_select_player)
	character_selected.emit(entries[i], i)


## Fades the name, story, abilities and illustration out, changes them, and fades them back in.
func _swap_to(e: CharacterSelectEntry) -> void:
	if _swap_tw != null and _swap_tw.is_valid():
		_swap_tw.kill()
	var groups := [_art_group, _info_left, _info_right]
	_swap_tw = create_tween().set_parallel(true)
	for g in groups:
		_swap_tw.tween_property(g, "modulate:a", 0.0, fade_seconds * 0.5)
	_swap_tw.chain().tween_callback(_fill_entry.bind(e))
	_swap_tw.chain().tween_property(groups[0], "modulate:a", 1.0, fade_seconds * 1.2)
	for g in range(1, groups.size()):
		_swap_tw.tween_property(groups[g], "modulate:a", 1.0, fade_seconds * 1.2)


# ----------------------------------------------------------------------------- continue, leaving

func _on_continue_hover(entered: bool) -> void:
	_continue_hover = entered
	if _leaving:
		return
	_mouse_mode = true
	if _arrow_tw != null and _arrow_tw.is_valid():
		_arrow_tw.kill()
	_arrow_tw = create_tween().set_parallel(true)
	var slide := (arrow_slide if entered else 0.0) * _k
	var base := (continue_arrow_position - continue_hit_rect.position) * _k
	_arrow_tw.tween_property(_c_arrow, "position", base + Vector2(slide, 0.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_arrow_tw.tween_property(_c_text, "modulate", Color(1.25, 1.25, 1.25, 1.0) if entered else Color.WHITE, 0.16)
	_arrow_tw.tween_property(_c_glow, "modulate:a", 1.6 if entered else 1.0, 0.16)
	if entered:
		_play(_hover_player)


func _on_continue_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_confirm()


func _confirm() -> void:
	if _leaving or entries.is_empty():
		return
	var e := entries[_selected]
	if e.locked:
		_tiles[_selected].deny()
		return
	selected_character = e.character_data
	selected_name = e.display_name
	_play(_confirm_player)
	character_confirmed.emit(e)
	_leave(next_scene)


func _go_back() -> void:
	_leave(back_scene)


func _leave(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	if _glow_tw != null and _glow_tw.is_valid():
		_glow_tw.kill()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, maxf(leave_fade_seconds, 0.01))
	await tw.finished
	if path != "" and ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		_fade.color.a = 0.0
		_leaving = false


func _play(p: AudioStreamPlayer) -> void:
	if p != null and p.stream != null:
		p.play()


# ----------------------------------------------------------------------------- keyboard and controller

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _tiles_clip != null \
			and _tiles_clip.get_global_rect().has_point(event.position):
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_to(_scroll_target + 1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_to(_scroll_target - 1)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion:
		_mouse_mode = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		_mouse_mode = false


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or entries.is_empty():
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var step := 1 if event.is_action_pressed("ui_down") else -1
		var from := _hover_index if _hover_index >= 0 else _selected          # the first key press moves away from the selected character
		_hover_index = (from + step + entries.size()) % entries.size()
		_scroll_into_view(_hover_index)
		_refresh_tiles(true)
		_play(_hover_player)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		var idx := _hover_index if _hover_index >= 0 else _selected
		if entries[idx].locked or idx != _selected:
			_choose(idx)
		else:
			_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


# ----------------------------------------------------------------------------- one portrait tile

class TileNode extends Control:
	signal hovered(index: int)
	signal unhovered(index: int)
	signal clicked(index: int)

	var index: int = 0
	var screen: CharacterSelectScreen
	var k: float = 1.0
	var rest: Vector2 = Vector2.ZERO
	var locked: bool = false
	var is_selected: bool = false
	var is_hover: bool = false
	var art: TextureRect
	var glow_normal: TextureRect
	var glow_sel: TextureRect
	var dim_value: float = 1.0:
		set(v):
			dim_value = v
			_push()
	var gray_value: float = 0.0:
		set(v):
			gray_value = v
			_push()
	var flash_value: float = 0.0:
		set(v):
			flash_value = v
			_push()
	var _mats: Array[ShaderMaterial] = []
	var _tw: Tween
	var _tw_scale: Tween
	var _tw_shake: Tween
	var _tw_flash: Tween

	func _init(i: int, s: CharacterSelectScreen) -> void:
		index = i
		screen = s
		mouse_filter = Control.MOUSE_FILTER_STOP
		art = _layer(false)                       # the picture first, then the glows ON TOP of it (like Photoshop: they also brighten the border and the inside)
		glow_normal = _layer(true)
		glow_sel = _layer(true)
		mouse_entered.connect(func(): hovered.emit(index))
		mouse_exited.connect(func(): unhovered.emit(index))

	func _layer(additive: bool) -> TextureRect:
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = screen._shader_add if additive else screen._shader_normal
		t.material = m
		_mats.append(m)
		add_child(t)
		return t

	func _push() -> void:
		for m in _mats:
			m.set_shader_parameter("gray", gray_value)
			m.set_shader_parameter("dim", dim_value)
			m.set_shader_parameter("flash", flash_value)

	func setup(entry: CharacterSelectEntry) -> void:
		locked = entry.locked
		size = Vector2.ONE * screen.tile_size * k
		pivot_offset = size * 0.5
		position = rest
		art.texture = entry.tile
		art.position = Vector2.ONE * -CharacterSelectScreen.TILE_MARGIN * k
		art.size = (entry.tile.get_size() * k) if entry.tile != null else Vector2.ZERO
		glow_normal.texture = screen.tile_glow_normal
		glow_normal.position = Vector2.ONE * -CharacterSelectScreen.TILE_GLOW_NORMAL_MARGIN * k
		glow_normal.size = (screen.tile_glow_normal.get_size() * k) if screen.tile_glow_normal != null else Vector2.ZERO
		glow_sel.texture = screen.tile_glow_selected
		glow_sel.position = Vector2.ONE * -CharacterSelectScreen.TILE_GLOW_MARGIN * k
		glow_sel.size = (screen.tile_glow_selected.get_size() * k) if screen.tile_glow_selected != null else Vector2.ZERO
		mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if locked else Control.CURSOR_POINTING_HAND
		apply_state(false)

	## Picks the look for the current state: selected, pointed at, locked, or plain.
	func apply_state(animate: bool) -> void:
		var t_dim := 1.0
		var t_gray := 0.0
		var t_normal := 1.0
		var t_sel := 0.0
		var t_scale := 1.0
		if locked:
			t_gray = screen.locked_gray
			t_dim = screen.locked_dim + (0.22 if is_hover else 0.0)
			t_normal = 0.55 if is_hover else 0.35
		elif is_selected:
			t_normal = 0.0
			t_sel = 1.0
		elif is_hover:
			t_normal = 0.5
			t_sel = 0.55
			t_scale = screen.hover_scale
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if _tw_scale != null and _tw_scale.is_valid():
			_tw_scale.kill()
		if not animate:
			dim_value = t_dim
			gray_value = t_gray
			glow_normal.modulate.a = t_normal
			glow_sel.modulate.a = t_sel
			scale = Vector2.ONE * t_scale
			return
		var d := screen.fade_seconds
		_tw = create_tween().set_parallel(true)
		_tw.tween_property(self, "dim_value", t_dim, d)
		_tw.tween_property(self, "gray_value", t_gray, d)
		_tw.tween_property(glow_normal, "modulate:a", t_normal, d)
		_tw.tween_property(glow_sel, "modulate:a", t_sel, d)
		_tw_scale = create_tween()
		_tw_scale.tween_property(self, "scale", Vector2.ONE * t_scale, d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## "Not available": blinks red and shakes from side to side.
	func deny() -> void:
		for t in [_tw_shake, _tw_flash]:
			if t != null and t.is_valid():
				t.kill()
		position = rest
		flash_value = 0.0
		_tw_shake = create_tween()
		_tw_shake.tween_method(_shake, 0.0, 1.0, screen.shake_seconds)
		_tw_shake.tween_callback(func(): position = rest)
		_tw_flash = create_tween()
		var on := 0.07
		var off := 0.07
		for i in range(maxi(screen.blink_count, 1)):
			_tw_flash.tween_property(self, "flash_value", 0.9, on)
			_tw_flash.tween_property(self, "flash_value", 0.0, off if i < screen.blink_count - 1 else 0.14)

	func _shake(t: float) -> void:
		position = rest + Vector2(sin(t * TAU * 5.0) * screen.shake_pixels * k * (1.0 - t), 0.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(index)
