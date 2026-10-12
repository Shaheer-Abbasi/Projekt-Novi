class_name UISkin
extends Resource
## One place to restyle the game's conversations and pop-ups.
## Every picture slot is a StyleBox: to use your own sprite, click the slot, choose
## "New StyleBoxTexture", drag your image onto its Texture, and set the Margins so the
## corners don't stretch (that is a 9-slice: the edges stay crisp at any box size).
## Anything left empty uses the built-in look.
##
## Make ONE of these (File > Save as, e.g. ui_skin.tres) and assign it everywhere:
## the Tutorial Director, the Story Level, a Dialogue Box node, a Video Cutscene.

const LIME := Color(0.78, 0.95, 0.10)

enum PortraitStyle { IN_BOX, STAGE }

@export_group("Dialogue box")
## The picture behind the conversation text.
@export var dialogue_box: StyleBox
## Height of the box in pixels.
@export var dialogue_height: float = 192.0
## Gap between the box and each side of the screen, as a fraction of the screen width (0.07 = 7%).
@export_range(0.0, 0.4, 0.001) var dialogue_side_margin: float = 0.07
## Gap between the box and the bottom of the screen, in pixels.
@export var dialogue_bottom_margin: float = 22.0
## Size of the speaker portrait (left or right end of the box).
@export var portrait_size: Vector2 = Vector2(150, 150)
## Typewriter speed, in characters per second.
@export var text_speed: float = 55.0
## Leave empty for the default font.
@export var font: Font
@export var name_font_size: int = 30
@export var text_font_size: int = 26
@export var text_color: Color = Color.WHITE
## Name color for speakers that have no color of their own.
@export var default_name_color: Color = LIME

@export_group("Name plate (a separate tab for the speaker's name)")
## A picture for the name tab, like a yellow label overlapping the corner of the box.
## Empty = the name is written inside the box instead.
@export var name_plate: StyleBox
## Where the plate's top-left corner sits, measured from the BOX's top-left corner. Negative = up / left, outside the box.
@export var name_plate_offset: Vector2 = Vector2(-24.0, -10.0)
## The plate is at least this big (it grows if the name is longer).
@export var name_plate_min_size: Vector2 = Vector2(180.0, 36.0)
@export var name_plate_text_color: Color = Color.BLACK
@export var name_plate_align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER

@export_group("Stage portraits (big art behind the box)")
## In Box = a small portrait inside the box. Stage = a big picture standing at the side of the screen, BEHIND the box.
@export var portrait_style: PortraitStyle = PortraitStyle.IN_BOX
## Height of the stage portrait as a fraction of the screen height. 1.0 = full height.
@export var stage_portrait_height: float = 1.0
## How far in from the left / right edge of the screen the portrait stands, in pixels (negative = partly off-screen).
@export var stage_portrait_margin: float = 0.0
## Moves every stage portrait up (negative) or down (positive), in pixels.
@export var stage_portrait_offset_y: float = 0.0
## Seconds the portrait takes to fade in when a new character speaks. 0 = instant.
@export var stage_portrait_fade_seconds: float = 0.2
## ON: when someone else speaks, the previous character stays on screen (dimmed) instead of leaving.
## Each side keeps its last speaker until the conversation ends. A line with no portrait (an intercom) dims both.
@export var stage_keep_other_visible: bool = true
## What the character who is NOT speaking looks like. Darker = more dimmed. White = not dimmed at all.
@export var stage_dim_color: Color = Color(0.42, 0.42, 0.48, 1.0)
## Seconds the portrait takes to brighten / dim when the speaker changes.
@export var stage_dim_seconds: float = 0.25
## ON: the portrait is drawn in FRONT of the box. OFF (default): behind it, so a see-through box lets her show through.
@export var stage_portrait_in_front_of_box: bool = false

@export_group("Dialogue buttons")
@export var next_text: String = "Next"
@export var skip_text: String = "Skip"
## Shown instead of Next on the last line.
@export var end_text: String = "End"
@export var show_skip_button: bool = true
@export var button_size: Vector2 = Vector2(110, 40)
@export var button_normal: StyleBox
@export var button_hover: StyleBox
@export var button_pressed: StyleBox
@export var button_font_size: int = 22
@export var button_font_color: Color = Color.WHITE

@export_group("Skip / Next hint bar (outside the box)")
## ON: Skip / Next / End sit BELOW the box at its bottom-right, like a row of key hints, instead of inside the box.
@export var buttons_below_box: bool = false
## Key pictures shown before the word "Next" / "End" (for example one ENTER key).
@export var next_key_icons: Array[Texture2D] = []
## Key pictures shown before "Skip". Several are shown in a row with the separator between them (SHIFT + ENTER).
@export var skip_key_icons: Array[Texture2D] = []
@export var key_icon_size: Vector2 = Vector2(28.0, 16.0)
@export var key_separator: String = "+"
## Where the bar sits. x = from the box's RIGHT edge (negative = further left).
## y = how far BELOW the box's bottom edge the bar's vertical CENTER is. Leave room: raise Dialogue Bottom Margin to at least this + half the bar's height.
@export var hints_offset: Vector2 = Vector2(-24.0, 16.0)
@export var hints_spacing: float = 24.0
## Shift + Enter skips the whole conversation. (Enter / Space / click always go to the next line.)
@export var skip_with_shift_enter: bool = true

@export_group("Freeze prompt (\"Press SHIFT to dash\")")
@export var prompt_box: StyleBox
## The word before the key name, e.g. PRESS  [ SHIFT ]
@export var press_text: String = "PRESS"
@export var prompt_title_color: Color = LIME
@export var prompt_key_size: int = 60
@export var prompt_text_size: int = 26

@export_group("Hint and message banners")
## Used by the tutorial hints and the story-mode messages ("Defeat all the enemies...").
@export var banner_box: StyleBox
@export var banner_font_size: int = 28
## How far down from the top of the screen the banner sits (pixels). Raise it to clear a taller HUD.
@export var banner_top: float = 76.0
## How wide the banner is (pixels). Keep it narrower than the gap between your HUD's left block and right counters.
@export var banner_width: float = 500.0

@export_group("Characters")
## Who can talk, with their portraits. See DialogueSpeaker.
@export var speakers: Array[DialogueSpeaker] = []


## Finds a speaker by the name used in the dialogue text (not case sensitive).
func find_speaker(who: String) -> DialogueSpeaker:
	var key := who.strip_edges().to_lower()
	if key.is_empty():
		return null
	for s in speakers:
		if s != null and s.speaker_name.strip_edges().to_lower() == key:
			return s
	return null


# --- helpers shared by every UI that uses a skin ---

func box_or_default(custom: StyleBox, margin: int = 14) -> StyleBox:
	if custom != null:
		return custom
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.90)
	sb.border_color = LIME
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(margin)
	return sb
