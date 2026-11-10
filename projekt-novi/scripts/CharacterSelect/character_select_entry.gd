class_name CharacterSelectEntry
extends Resource
## One character on the Hiring Board (the Character Select screen): who it is, whether it is locked, and the pictures and texts shown for it.
## Pictures are sized for a 1920 x 1080 canvas, like your Photoshop mockup.

@export var display_name: String = "Vow"
## The story under the name. Press Enter in the box to start a new line.
@export_multiline var story: String = ""
## Locked characters are greyed out. Clicking one only makes it shake and blink red.
@export var locked: bool = false
## The CharacterData this character plays with. Leave it empty for Vow: the player then uses its own default.
@export var character_data: Resource

@export_group("Pictures")
## The portrait tile in the column on the left: 145 x 145 with a 24 px margin on every side for its glow.
@export var tile: Texture2D
## The big picture of the character, and where its top-left corner goes.
@export var illustration: Texture2D
@export var illustration_position: Vector2 = Vector2(0.0, 195.0)
## The little sprite standing on the illustration, its soft shadow, and where their top-left corner goes.
@export var sprite: Texture2D
@export var sprite_shadow: Texture2D
@export var sprite_position: Vector2 = Vector2(632.0, 595.0)

@export_group("Ultimate")
## The wide bar above the three abilities (its picture has a 30 px margin for the glow).
@export var ultimate_bar: Texture2D
@export var ultimate_name: String = ""
@export_multiline var ultimate_text: String = ""

@export_group("Ability 1")
@export var ability1_icon: Texture2D
@export var ability1_name: String = ""
@export_multiline var ability1_text: String = ""

@export_group("Ability 2")
@export var ability2_icon: Texture2D
@export var ability2_name: String = ""
@export_multiline var ability2_text: String = ""

@export_group("Ability 3")
@export var ability3_icon: Texture2D
@export var ability3_name: String = ""
@export_multiline var ability3_text: String = ""


func ability_icon(i: int) -> Texture2D:
	match i:
		0: return ability1_icon
		1: return ability2_icon
		_: return ability3_icon


## The name, then the description under it, as one block of text.
func ability_block(i: int) -> String:
	var n := ability1_name
	var t := ability1_text
	if i == 1:
		n = ability2_name
		t = ability2_text
	elif i >= 2:
		n = ability3_name
		t = ability3_text
	return n if t == "" else (n + "\n" + t)


func ultimate_block() -> String:
	return ultimate_name if ultimate_text == "" else (ultimate_name + "\n" + ultimate_text)
