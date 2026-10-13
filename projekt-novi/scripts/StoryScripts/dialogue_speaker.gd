class_name DialogueSpeaker
extends Resource
## One character who can talk in a dialogue box.
## Add these to the "Speakers" list of your UISkin. A speaker NOT in the list still works:
## it just has no portrait (perfect for an "INTERCOM" or a narrator).

enum PortraitSide { LEFT, RIGHT, NONE }

## The name written in the dialogue text, before the colon. Example: "VOW" for the line  VOW: Hello.
@export var speaker_name: String = ""
## What the box shows as the name. Leave empty to show the speaker name as written.
@export var display_name: String = ""
## Portrait picture. Leave empty for no portrait.
@export var portrait: Texture2D
## Which end of the box the portrait sits on. NONE = never show a portrait for this speaker.
@export var side: PortraitSide = PortraitSide.LEFT
@export var name_color: Color = Color(0.78, 0.95, 0.10)

@export_group("Big (stage) portrait tweaks")
## Only used when the skin's Portrait Style is "Stage". Makes this character's picture bigger / smaller.
@export var stage_scale: float = 1.0
## Nudge this character's stage portrait, in pixels (x: toward the screen's center, y: down).
@export var stage_offset: Vector2 = Vector2.ZERO

@export_group("This character's own look (all optional)")
## A different box picture while THIS character speaks (for example a red-bordered box for an enemy). Empty = the skin's box.
@export var box_style: StyleBox
## A different name plate picture for this character. Empty = the skin's plate.
@export var name_plate_style: StyleBox
## Tints the name plate (white = the picture's own colors).
@export var plate_tint: Color = Color.WHITE
## ON: use the color below for this character's name instead of the skin's Name Plate Text Color.
@export var use_own_plate_text_color: bool = false
@export var plate_text_color: Color = Color.WHITE
