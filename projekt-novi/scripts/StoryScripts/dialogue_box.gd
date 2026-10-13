class_name DialogueBox
extends CanvasLayer
## A conversation box you can restyle completely (see UISkin).
##   - the box picture, fonts and colors, and where the box sits
##   - a portrait on the LEFT, on the RIGHT, or none (per speaker): small inside the box,
##     or BIG "stage" art standing behind the box
##   - an optional separate NAME PLATE tab overlapping the box corner
##   - Next / Skip / End: as buttons inside the box, or as a hint bar below it with key icons
## Use it from code:    box.play_text("VOW: Hello.\nINTERCOM: Welcome back.")   then   await box.finished
## or drop a DialogueBox node into any scene and call play_sequence() / play_text().
## Click, Space or Enter = Next.  Shift + Enter = Skip.  The game is frozen while the box is open.

signal finished

@export var skin: UISkin:
	set(value):
		skin = value
		if _built:
			apply_skin()
## Freeze the game while the box is open. Turn off for a box over a menu or cutscene screen.
@export var pause_game: bool = true

## Fallback portraits for speakers that are not in the skin: {"NAME": Texture2D}
var extra_portraits: Dictionary = {}
var is_open: bool = false

var _built: bool = false
var _eff: UISkin
var _was_paused: bool = false
var _lines: Array = []
var _index: int = 0
var _typing: bool = false
var _chars: float = 0.0

var _root: Control
var _stage_left: TextureRect
var _stage_right: TextureRect
var _panel: PanelContainer
var _left: TextureRect
var _right: TextureRect
var _col: VBoxContainer
var _name: Label
var _text: RichTextLabel
var _holder: HBoxContainer
var _btn_next: Button
var _btn_skip: Button
var _btn_end: Button
var _plate: PanelContainer
var _plate_label: Label
var _warned_speakers: Dictionary = {}     # names already reported as "not in the skin"
var _left_sp: DialogueSpeaker       # who is standing on the left / right of the stage
var _right_sp: DialogueSpeaker


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS     # must keep working while the game is frozen
	_build()
	apply_skin()
	_panel.visible = false


func _exit_tree() -> void:
	if is_open and pause_game and get_tree() != null:
		get_tree().paused = _was_paused          # never leave the next scene frozen


# --- public ------------------------------------------------------------------

## lines = [[speaker, text], ...]. Text may use BBCode.
func play(lines: Array) -> void:
	if lines.is_empty():
		finished.emit()
		return
	if not _built:
		_build()
		apply_skin()
	if is_open:
		_close()          # finish the previous conversation first, so anything waiting on it can continue
	_lines = lines
	_index = 0
	_stage_left.visible = false           # a new conversation starts with an empty stage
	_stage_right.visible = false
	_left_sp = null
	_right_sp = null
	if not is_open:
		_was_paused = get_tree().paused
	is_open = true
	if pause_game:
		get_tree().paused = true
	_panel.visible = true
	_show_line()


func play_text(raw: String) -> void:
	play(DialogueSequence.parse(raw))


func play_sequence(seq: DialogueSequence) -> void:
	if seq == null:
		finished.emit()
		return
	play(seq.get_lines())


## Ends the conversation right now (what the Skip button does).
func skip() -> void:
	if is_open:
		_close()


# --- building ---------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_stage_left = _make_stage()
	_stage_right = _make_stage()
	_root.add_child(_stage_left)
	_root.add_child(_stage_right)

	_panel = PanelContainer.new()
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN     # a long text makes the box grow UPWARD, never clip
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_panel.add_child(row)

	_left = _make_portrait()
	row.add_child(_left)

	_col = VBoxContainer.new()
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_theme_constant_override("separation", 4)
	row.add_child(_col)

	_name = Label.new()
	_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_name.add_theme_constant_override("outline_size", 8)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(_name)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.fit_content = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_color_override("font_outline_color", Color.BLACK)
	_text.add_theme_constant_override("outline_size", 6)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(_text)

	_holder = HBoxContainer.new()
	_holder.alignment = BoxContainer.ALIGNMENT_END
	_holder.add_theme_constant_override("separation", 10)
	_col.add_child(_holder)
	_btn_skip = _make_button()
	_btn_next = _make_button()
	_btn_end = _make_button()
	_holder.add_child(_btn_skip)
	_holder.add_child(_btn_next)
	_holder.add_child(_btn_end)
	_btn_skip.pressed.connect(skip)
	_btn_next.pressed.connect(_next)
	_btn_end.pressed.connect(_next)

	_right = _make_portrait()
	row.add_child(_right)

	# the name plate sits in the root (not in the box), so it can overlap the box's corner
	_plate = PanelContainer.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.visible = false
	_root.add_child(_plate)
	_plate_label = Label.new()
	_plate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plate.add_child(_plate_label)
	_built = true


func _make_portrait() -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.visible = false
	return t


func _make_stage() -> TextureRect:
	var t := _make_portrait()
	t.stretch_mode = TextureRect.STRETCH_SCALE        # we size it to the picture's own proportions
	return t


func _make_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE          # Space must not "press" a focused button AND advance
	b.visible = false
	# the row is used when key icons are shown (icons + word); otherwise the Button's own text is used
	var row := HBoxContainer.new()
	row.name = "Row"
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.visible = false
	b.add_child(row)
	b.mouse_entered.connect(func(): b.modulate = Color(1.25, 1.25, 1.1))
	b.mouse_exited.connect(func(): b.modulate = Color.WHITE)
	return b


## Applies the skin (or the built-in look when there is none).
func apply_skin() -> void:
	_eff = skin if skin != null else UISkin.new()

	# --- the box and where it sits ---
	_panel.anchor_left = _eff.dialogue_side_margin
	_panel.anchor_right = 1.0 - _eff.dialogue_side_margin
	_panel.add_theme_stylebox_override("panel", _eff.box_or_default(_eff.dialogue_box, 16))
	_panel.offset_bottom = -_eff.dialogue_bottom_margin
	_panel.offset_top = -(_eff.dialogue_height + _eff.dialogue_bottom_margin)
	_left.custom_minimum_size = _eff.portrait_size
	_right.custom_minimum_size = _eff.portrait_size

	_name.add_theme_font_size_override("font_size", _eff.name_font_size)
	_text.add_theme_font_size_override("normal_font_size", _eff.text_font_size)
	_text.add_theme_font_size_override("bold_font_size", _eff.text_font_size)
	_text.add_theme_color_override("default_color", _eff.text_color)
	if _eff.font != null:
		_name.add_theme_font_override("font", _eff.font)
		_text.add_theme_font_override("normal_font", _eff.font)
		_text.add_theme_font_override("bold_font", _eff.font)

	# --- name plate ---
	if _eff.name_plate != null:
		_plate.add_theme_stylebox_override("panel", _eff.name_plate)
	_plate.custom_minimum_size = _eff.name_plate_min_size
	_plate_label.add_theme_font_size_override("font_size", _eff.name_font_size)
	_plate_label.add_theme_color_override("font_color", _eff.name_plate_text_color)
	_plate_label.horizontal_alignment = _eff.name_plate_align
	if _eff.font != null:
		_plate_label.add_theme_font_override("font", _eff.font)

	# --- stage portrait order: behind the box (default) or in front of it ---
	var panel_index := _panel.get_index()
	if _eff.stage_portrait_in_front_of_box:
		_root.move_child(_stage_left, panel_index)
		_root.move_child(_stage_right, panel_index)
		_root.move_child(_panel, _stage_left.get_index())       # box first, then the portraits
		_root.move_child(_plate, _root.get_child_count() - 1)
	else:
		_root.move_child(_stage_left, 0)
		_root.move_child(_stage_right, 1)

	# --- the Next / Skip / End buttons: inside the box, or a hint bar below it ---
	var outside := _eff.buttons_below_box
	if outside and _holder.get_parent() != _root:
		_holder.get_parent().remove_child(_holder)
		_root.add_child(_holder)
	elif not outside and _holder.get_parent() != _col:
		_holder.get_parent().remove_child(_holder)
		_col.add_child(_holder)
	_holder.add_theme_constant_override("separation", int(_eff.hints_spacing) if outside else 10)

	var normal: StyleBox
	var hover: StyleBox
	var pressed: StyleBox
	if outside and _eff.button_normal == null:
		normal = StyleBoxEmpty.new()          # a hint bar has no button boxes unless you supply them
		hover = StyleBoxEmpty.new()
		pressed = StyleBoxEmpty.new()
	else:
		normal = _eff.button_normal if _eff.button_normal != null else _flat_button(Color(0.07, 0.09, 0.13, 0.95))
		hover = _eff.button_hover if _eff.button_hover != null else _flat_button(Color(0.16, 0.22, 0.10, 0.98))
		pressed = _eff.button_pressed if _eff.button_pressed != null else _flat_button(Color(0.30, 0.40, 0.08, 1.0))
	for b in [_btn_skip, _btn_next, _btn_end]:
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", pressed)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_font_size_override("font_size", _eff.button_font_size)
		b.add_theme_color_override("font_color", _eff.button_font_color)
		b.add_theme_color_override("font_hover_color", _eff.button_font_color)
		b.add_theme_color_override("font_pressed_color", _eff.button_font_color)
		if _eff.font != null:
			b.add_theme_font_override("font", _eff.font)
	_set_button_content(_btn_next, _eff.next_key_icons, _eff.next_text)
	_set_button_content(_btn_skip, _eff.skip_key_icons, _eff.skip_text)
	_set_button_content(_btn_end, _eff.next_key_icons, _eff.end_text)
	if is_open:
		_show_line()


## With key icons: icons (joined by the separator) + the word. Without: the Button's own text.
func _set_button_content(b: Button, icons: Array[Texture2D], word: String) -> void:
	var row := b.get_node("Row") as HBoxContainer
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	if icons.is_empty():
		b.text = word
		row.visible = false
		b.custom_minimum_size = _eff.button_size
		return
	b.text = ""
	row.visible = true
	var total_w := 0.0
	var total_h := _eff.key_icon_size.y
	var pieces := 0
	for i in range(icons.size()):
		if i > 0:
			var sep := _hint_label(_eff.key_separator)
			row.add_child(sep)
			total_w += sep.get_minimum_size().x
			pieces += 1
		var t := TextureRect.new()
		t.texture = icons[i]
		t.custom_minimum_size = _eff.key_icon_size
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(t)
		total_w += _eff.key_icon_size.x
		pieces += 1
	var word_label := _hint_label(word)
	row.add_child(word_label)
	total_w += word_label.get_minimum_size().x
	total_h = maxf(total_h, word_label.get_minimum_size().y)
	pieces += 1
	total_w += 6.0 * float(pieces - 1)
	b.custom_minimum_size = Vector2(total_w + 8.0, total_h + 4.0)


func _hint_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", _eff.button_font_size)
	l.add_theme_color_override("font_color", _eff.button_font_color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	if _eff.font != null:
		l.add_theme_font_override("font", _eff.font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _flat_button(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = UISkin.LIME
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	return sb


# --- showing lines ------------------------------------------------------------

func _show_line() -> void:
	var line: Array = _lines[_index]
	var who := String(line[0])
	var sp := _eff.find_speaker(who)
	var shown_name := who
	var color := _eff.default_name_color
	var tex: Texture2D = null
	var side := DialogueSpeaker.PortraitSide.LEFT
	if sp != null:
		shown_name = sp.display_name if sp.display_name != "" else who
		color = sp.name_color
		tex = sp.portrait
		side = sp.side
	elif extra_portraits.has(who):
		tex = extra_portraits[who]
	elif who != "" and not _eff.speakers.is_empty() and not _warned_speakers.has(who):
		_warned_speakers[who] = true
		print("Dialogue: '%s' has no portrait. Fine for an INTERCOM. For a character, give that name a picture (on the Mission node under 'Dialogue characters', or in the skin); the name must match the text before the colon." % who)

	# this character's own box / plate (or the skin's)
	var box_style: StyleBox = sp.box_style if (sp != null and sp.box_style != null) else _eff.box_or_default(_eff.dialogue_box, 16)
	_panel.add_theme_stylebox_override("panel", box_style)
	var plate_style: StyleBox = sp.name_plate_style if (sp != null and sp.name_plate_style != null) else _eff.name_plate
	var plated := plate_style != null
	_name.text = shown_name
	_name.visible = who != "" and not plated
	_name.add_theme_color_override("font_color", color)
	_plate.visible = plated and who != ""
	if plated:
		_plate.add_theme_stylebox_override("panel", plate_style)
	_plate_label.text = shown_name
	_plate_label.add_theme_color_override("font_color", sp.plate_text_color if (sp != null and sp.use_own_plate_text_color) else _eff.name_plate_text_color)
	_plate.modulate = sp.plate_tint if sp != null else Color.WHITE

	# the portrait: small inside the box, or big on the stage behind it
	var stage := _eff.portrait_style == UISkin.PortraitStyle.STAGE
	var want_left := tex != null and side == DialogueSpeaker.PortraitSide.LEFT
	var want_right := tex != null and side == DialogueSpeaker.PortraitSide.RIGHT
	_left.texture = tex
	_right.texture = tex
	_left.visible = want_left and not stage
	_right.visible = want_right and not stage
	if stage:
		var keep := _eff.stage_keep_other_visible
		if want_left:
			_set_slot(_stage_left, tex, sp, true)
			_dim_or_hide(_stage_right, keep)
		elif want_right:
			_set_slot(_stage_right, tex, sp, true)
			_dim_or_hide(_stage_left, keep)
		else:
			_dim_or_hide(_stage_left, keep)       # a line with no portrait: whoever is on stage is dimmed
			_dim_or_hide(_stage_right, keep)
	else:
		_stage_left.visible = false
		_stage_right.visible = false

	_text.text = String(line[1])
	_text.visible_characters = 0
	_chars = 0.0
	_typing = true
	_holder.visible = true
	_update_buttons()


## Puts a character on one side of the stage, bright or dimmed. Fades in only when the picture is new.
func _set_slot(node: TextureRect, tex: Texture2D, sp: DialogueSpeaker, bright: bool) -> void:
	var is_left := node == _stage_left
	if is_left:
		_left_sp = sp
	else:
		_right_sp = sp
	var appeared := (not node.visible) or node.texture != tex
	node.texture = tex
	var screen := get_viewport().get_visible_rect().size
	var mult := sp.stage_scale if sp != null else 1.0
	var nudge := sp.stage_offset if sp != null else Vector2.ZERO
	var h := screen.y * _eff.stage_portrait_height * mult
	var w := h * float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
	node.size = Vector2(w, h)
	var y := screen.y - h + _eff.stage_portrait_offset_y + nudge.y
	if is_left:
		node.position = Vector2(_eff.stage_portrait_margin + nudge.x, y)
	else:
		node.position = Vector2(screen.x - w - _eff.stage_portrait_margin - nudge.x, y)
	node.visible = true
	var target := Color.WHITE if bright else _eff.stage_dim_color
	if node.has_meta("fade"):
		var old = node.get_meta("fade")
		if old is Tween and old.is_valid():
			old.kill()
	if appeared:
		node.modulate = Color(target.r, target.g, target.b, 0.0)
		_tween_color(node, target, _eff.stage_portrait_fade_seconds)
	elif not node.modulate.is_equal_approx(target):
		_tween_color(node, target, _eff.stage_dim_seconds)


func _tween_color(node: TextureRect, target: Color, seconds: float) -> void:
	if seconds <= 0.0:
		node.modulate = target
		return
	var tw := create_tween()
	tw.tween_property(node, "modulate", target, seconds)
	node.set_meta("fade", tw)


## The character who is not speaking: dim them (and keep them on stage), or send them away.
func _dim_or_hide(node: TextureRect, keep: bool) -> void:
	if not node.visible:
		return
	if not keep:
		node.visible = false
		return
	var sp := _left_sp if node == _stage_left else _right_sp
	_set_slot(node, node.texture, sp, false)


func _update_buttons() -> void:
	var last := _index >= _lines.size() - 1
	_btn_next.visible = not last
	_btn_end.visible = last
	_btn_skip.visible = _eff.show_skip_button and not last


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1


func _next() -> void:
	if not is_open:
		return
	if _typing:
		_finish_typing()
		return
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_line()


func _close() -> void:
	is_open = false
	_panel.visible = false
	_plate.visible = false
	_holder.visible = false          # the hint bar can live outside the box, so hide it too
	_stage_left.visible = false
	_stage_right.visible = false
	if pause_game:
		get_tree().paused = _was_paused
	finished.emit()


func _process(delta: float) -> void:
	if not is_open:
		return
	_place_attachments()
	if not _typing:
		return
	_chars += delta * _eff.text_speed
	if _chars >= float(_text.get_total_character_count()):
		_finish_typing()
	else:
		_text.visible_characters = int(_chars)


## The plate and the hint bar are not inside the box, so they follow the box's corners.
func _place_attachments() -> void:
	var pr := _panel.get_rect()
	_plate.position = pr.position + _eff.name_plate_offset
	if _eff.buttons_below_box:
		_holder.position = Vector2(pr.end.x - _holder.size.x + _eff.hints_offset.x, pr.end.y + _eff.hints_offset.y - _holder.size.y * 0.5)


func _input(event: InputEvent) -> void:
	if not is_open or event.is_echo():
		return
	if event is InputEventKey and event.pressed:
		var enter: bool = event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
		if enter and event.shift_pressed and _eff.skip_with_shift_enter and _eff.show_skip_button:
			skip()
			get_viewport().set_input_as_handled()
		elif enter or event.keycode == KEY_SPACE:
			_next()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for b in [_btn_next, _btn_skip, _btn_end]:
			if b.visible and b.get_global_rect().has_point(event.position):
				return                      # the button handles its own click
		_next()
		get_viewport().set_input_as_handled()
