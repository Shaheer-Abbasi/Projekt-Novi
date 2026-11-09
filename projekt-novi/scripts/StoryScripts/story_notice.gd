class_name StoryNotice
extends CanvasLayer
## The on-screen message for story levels, like "Defeat all the enemies to move on!"
## with a live counter under it ("Tanks 2/5   Grunts 1/3"), plus a big centered text
## for moments like LEVEL COMPLETE. StoryEncounter and StoryLevel create and drive it.
## Restyle the box with a UISkin ("Banner Box").

## PLAIN = the original dark box with a lime border. CYBER (the default) = an angled dark bar with a colored icon block (Cyberpunk 2077 style),
## drawn in code. SPRITES = your own picture (box_texture), stretched like a 9-slice.
enum Style { PLAIN, CYBER, SPRITES }

## Set before adding to the scene to restyle it.
var skin: UISkin
var style: int = Style.CYBER                     # the new look is the default; set Style.PLAIN for the original box
var accent: Color = Color(1.0, 0.2, 0.25)       # CYBER: icon block, outline and highlights
var icon: Texture2D                             # a small picture at the left (CYBER without one draws a warning triangle)
var uppercase: bool = true                      # CYBER: write messages in CAPITALS
var box_texture: Texture2D                      # SPRITES: the box picture
var box_margin: int = 16                        # SPRITES: pixels at each edge that must not stretch

var _eff: UISkin
var _panel: PanelContainer
var _frame: Control
var _message: RichTextLabel
var _progress: Label
var _big: Label
var _msg_timer: Timer
var _big_timer: Timer
var _has_message: bool = false
var _has_progress: bool = false


func _ready() -> void:
	layer = 60
	add_to_group("story_notice")
	_eff = skin if skin != null else UISkin.new()

	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _make_box())
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -_eff.banner_width * 0.5
	_panel.offset_right = _eff.banner_width * 0.5
	_panel.offset_top = _eff.banner_top
	_panel.offset_bottom = _eff.banner_top
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if style == Style.CYBER:
		_panel.custom_minimum_size = Vector2(0.0, CyberFrame.ICON_W - 4.0)       # tall enough that the icon block is about square
	_panel.visible = false
	root.add_child(_panel)
	if style == Style.CYBER:
		_frame = CyberFrame.new()                 # first child, so it is drawn BEHIND the text
		_frame.setup(accent, icon)
		_panel.add_child(_frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	if style == Style.CYBER:
		var pad_box := MarginContainer.new()      # the padding lives here, so the frame behind it can fill the WHOLE panel
		pad_box.add_theme_constant_override("margin_top", 12)
		pad_box.add_theme_constant_override("margin_bottom", 12)
		pad_box.add_theme_constant_override("margin_right", 38)         # room for the little glyph at the right
		pad_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(pad_box)
		pad_box.add_child(row)
	else:
		_panel.add_child(row)
	if style == Style.CYBER:
		var pad := Control.new()                  # keeps the text clear of the icon block
		pad.custom_minimum_size = Vector2(CyberFrame.ICON_W + 4.0, 0.0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pad)
	elif icon != null:
		var pic := TextureRect.new()
		pic.texture = icon
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(40.0, 40.0)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)

	_message = RichTextLabel.new()
	_message.bbcode_enabled = true
	_message.scroll_active = false
	_message.fit_content = true
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if style == Style.CYBER else HORIZONTAL_ALIGNMENT_CENTER
	_message.custom_minimum_size = Vector2(maxf(_eff.banner_width - 60.0 - (CyberFrame.ICON_W if style == Style.CYBER else 0.0), 100.0), 0)
	var msg_size := _eff.banner_font_size if style != Style.CYBER else maxi(int(_eff.banner_font_size * 0.62), 14)
	_message.add_theme_font_size_override("normal_font_size", msg_size)
	_message.add_theme_font_size_override("bold_font_size", msg_size)
	_message.add_theme_color_override("default_color", _eff.text_color if style != Style.CYBER else Color(0.93, 0.95, 1.0))
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 6)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.visible = false
	col.add_child(_message)

	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if style == Style.CYBER else HORIZONTAL_ALIGNMENT_CENTER
	_progress.add_theme_font_size_override("font_size", int(msg_size * (1.0 if style == Style.CYBER else 0.85)))
	_progress.add_theme_color_override("font_color", accent if style == Style.CYBER else _eff.default_name_color)
	_progress.add_theme_color_override("font_outline_color", Color.BLACK)
	_progress.add_theme_constant_override("outline_size", 6)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.visible = false
	col.add_child(_progress)
	if _eff.font != null:
		_message.add_theme_font_override("normal_font", _eff.font)
		_progress.add_theme_font_override("font", _eff.font)
	if style == Style.CYBER:
		var spaced := FontVariation.new()           # a little space between the letters, like the real thing
		spaced.base_font = _eff.font if _eff.font != null else ThemeDB.fallback_font
		spaced.spacing_glyph = 2
		_message.add_theme_font_override("normal_font", spaced)
		_progress.add_theme_font_override("font", spaced)
		_message.add_theme_constant_override("outline_size", 0)
		_progress.add_theme_constant_override("outline_size", 0)

	_big = Label.new()
	_big.anchor_right = 1.0
	_big.anchor_top = 0.4
	_big.anchor_bottom = 0.4
	_big.offset_top = -80.0
	_big.offset_bottom = 80.0
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.add_theme_font_size_override("font_size", 110)
	_big.add_theme_color_override("font_outline_color", Color.BLACK)
	_big.add_theme_constant_override("outline_size", 14)
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.modulate.a = 0.0
	root.add_child(_big)

	_msg_timer = Timer.new()
	_msg_timer.one_shot = true
	_msg_timer.timeout.connect(hide_message)
	add_child(_msg_timer)
	_big_timer = Timer.new()
	_big_timer.one_shot = true
	_big_timer.timeout.connect(_hide_big)
	add_child(_big_timer)


## Shows a message at the top. seconds = 0 keeps it until you call hide_message().
func show_message(text: String, seconds: float = 0.0) -> void:
	_message.text = _styled_text(text)
	_has_message = not text.strip_edges().is_empty()
	_message.visible = _has_message
	if seconds > 0.0 and _has_message:
		_msg_timer.start(seconds)
	else:
		_msg_timer.stop()
	_refresh()


func hide_message() -> void:
	_has_message = false
	_message.visible = false
	_refresh()


## The live counter line under the message. Empty text hides it.
func set_progress(text: String) -> void:
	_has_progress = not text.strip_edges().is_empty()
	_progress.text = text
	_progress.visible = _has_progress
	_refresh()


func clear_progress() -> void:
	set_progress("")


## Big centered text (LEVEL COMPLETE...). Fades in, stays `seconds`, fades out.
func show_big(text: String, seconds: float = 3.0, color: Color = Color.WHITE) -> void:
	_big.text = text
	_big.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_property(_big, "modulate:a", 1.0, 0.4)
	if seconds > 0.0:
		_big_timer.start(maxf(seconds, 0.5))


func _hide_big() -> void:
	var tw := create_tween()
	tw.tween_property(_big, "modulate:a", 0.0, 0.5)


func _refresh() -> void:
	var show := _has_message or _has_progress
	if show and not _panel.visible:
		_panel.modulate.a = 0.0
		_panel.visible = true
		if style == Style.CYBER:                   # a quick electronic flicker as it switches on
			var tw := create_tween()
			tw.tween_property(_panel, "modulate:a", 1.0, 0.05)
			tw.tween_property(_panel, "modulate:a", 0.15, 0.05)
			tw.tween_property(_panel, "modulate:a", 1.0, 0.05)
			tw.tween_property(_panel, "modulate:a", 0.55, 0.04)
			tw.tween_property(_panel, "modulate:a", 1.0, 0.08)
		else:
			create_tween().tween_property(_panel, "modulate:a", 1.0, 0.25)
	elif not show:
		_panel.visible = false


## The panel's background for the chosen style.
func _make_box() -> StyleBox:
	if style == Style.CYBER:
		return StyleBoxEmpty.new()                 # the CyberFrame draws the background
	if style == Style.SPRITES and box_texture != null:
		var t := StyleBoxTexture.new()
		t.texture = box_texture
		t.set_texture_margin_all(float(box_margin))
		t.set_content_margin_all(float(box_margin) * 0.8)
		return t
	return _eff.box_or_default(_eff.banner_box, 14)


## CYBER writes in capitals, but never inside [color=...] style tags.
func _styled_text(text: String) -> String:
	if style != Style.CYBER or not uppercase:
		return text
	var out := ""
	var in_tag := false
	for ch in text:
		if ch == "[":
			in_tag = true
		if in_tag:
			out += ch
		else:
			out += ch.to_upper()
		if ch == "]":
			in_tag = false
	return out


## The CYBER style's background, drawn in code: a dark angled bar with an outline, faint scanlines, a colored icon block at the
## left (a warning triangle, or your icon), a bright highlight on the top edge and a little glyph at the right.
class CyberFrame extends Control:
	const ICON_W := 46.0
	const CUT := 9.0
	var accent: Color = Color(1.0, 0.2, 0.25)
	var icon: Texture2D

	func setup(a: Color, i: Texture2D) -> void:
		accent = a
		icon = i
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var c := CUT
		var body := PackedVector2Array([Vector2(0, 0), Vector2(w - c, 0), Vector2(w, c), Vector2(w, h), Vector2(c, h), Vector2(0, h - c)])
		draw_colored_polygon(body, Color(0.03, 0.04, 0.07, 0.86))
		var y := 2.0
		while y < h:                                                      # faint scanlines
			draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.03))
			y += 3.0
		var outline := body.duplicate()
		outline.append(body[0])
		draw_polyline(outline, Color(accent.r, accent.g, accent.b, 0.55), 1.0)
		var block := PackedVector2Array([Vector2(0, 0), Vector2(ICON_W, 0), Vector2(ICON_W, h), Vector2(c, h), Vector2(0, h - c)])
		draw_colored_polygon(block, Color(accent.r, accent.g, accent.b, 0.92))
		var cx := ICON_W * 0.5
		var cy := h * 0.5
		if icon != null:
			var box := minf(ICON_W - 14.0, h - 12.0)
			var ts := icon.get_size()
			var sc := minf(box / maxf(ts.x, 1.0), box / maxf(ts.y, 1.0))
			var sz := ts * sc
			draw_texture_rect(icon, Rect2(Vector2(cx - sz.x * 0.5, cy - sz.y * 0.5), sz), false)
		else:
			var r := minf(13.0, h * 0.3)                                  # the built-in warning triangle with a "!"
			var tri := PackedVector2Array([Vector2(cx, cy - r), Vector2(cx + r * 1.15, cy + r * 0.8), Vector2(cx - r * 1.15, cy + r * 0.8)])
			draw_colored_polygon(tri, Color(0.04, 0.04, 0.06, 0.95))
			draw_rect(Rect2(cx - 1.5, cy - r * 0.38, 3.0, r * 0.62), accent)
			draw_rect(Rect2(cx - 1.5, cy + r * 0.38, 3.0, 3.0), accent)
		draw_line(Vector2(ICON_W + 10.0, 0.5), Vector2(ICON_W + 84.0, 0.5), accent, 2.0)      # the bright highlight
		var gx := w - 22.0
		draw_arc(Vector2(gx, h * 0.5), 7.0, 0.0, TAU, 20, Color(accent.r, accent.g, accent.b, 0.8), 1.5)
		draw_circle(Vector2(gx, h * 0.5), 2.0, accent)
