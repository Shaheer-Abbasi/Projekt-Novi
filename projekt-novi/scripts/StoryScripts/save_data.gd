class_name SaveData
extends RefCounted
## A tiny save file (user://save.cfg) for things that must survive closing the game.
## Right now it remembers one thing: whether the player has already seen the tutorial.
##
## To see the tutorial again as a brand-new player:
##   - in Godot: Project > Open User Data Folder, then delete save.cfg
##   - or call SaveData.reset_tutorial() from anywhere

const PATH := "user://save.cfg"


static func get_flag(key: String, default_value: bool = false) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return default_value
	return bool(cfg.get_value("flags", key, default_value))


static func set_flag(key: String, value: bool = true) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # fine if the file does not exist yet
	cfg.set_value("flags", key, value)
	cfg.save(PATH)


static func is_tutorial_done() -> bool:
	return get_flag("tutorial_done")


static func mark_tutorial_done() -> void:
	set_flag("tutorial_done", true)


static func reset_tutorial() -> void:
	set_flag("tutorial_done", false)


# --- Gacha: coins, characters and their stars ------------------------------
# A character's stars: 0 = locked, 1 = unlocked, each duplicate pull adds one (max 5).
# Every star above the first is +5% damage for that character.

const STARTING_COINS := 5
const MAX_STARS := 5
const DAMAGE_PER_STAR := 0.05
## Characters everyone owns from the start.
const STARTER_CHARACTERS := ["Vow"]


static func _read(section: String, key: String, default_value: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return default_value
	return cfg.get_value(section, key, default_value)


static func _write(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value(section, key, value)
	cfg.save(PATH)


static func get_coins() -> int:
	return int(_read("gacha", "coins", STARTING_COINS))


static func add_coins(amount: int) -> void:
	_write("gacha", "coins", maxi(get_coins() + amount, 0))


## Takes `amount` coins if there are enough. Returns false (and takes nothing) otherwise.
static func spend_coins(amount: int) -> bool:
	var have := get_coins()
	if have < amount:
		return false
	_write("gacha", "coins", have - amount)
	return true


## How many pulls this save has made (the first two are scripted, see PremiumShop).
static func get_pulls() -> int:
	return int(_read("gacha", "pulls", 0))


static func count_pull() -> void:
	_write("gacha", "pulls", get_pulls() + 1)


static func get_stars(character: String) -> int:
	var key := character.to_lower()
	var default_stars := 1 if character in STARTER_CHARACTERS else 0
	return int(_read("stars", key, default_stars))


static func is_unlocked(character: String) -> bool:
	return get_stars(character) > 0


## Adds one copy of a character: unlocks it, or adds a star. Returns the new star count.
static func add_copy(character: String) -> int:
	var stars := mini(get_stars(character) + 1, MAX_STARS)
	_write("stars", character.to_lower(), stars)
	return stars


## Damage multiplier from stars: 1 star = x1.00, 5 stars = x1.20.
static func damage_multiplier(character: String) -> float:
	return 1.0 + DAMAGE_PER_STAR * maxf(get_stars(character) - 1, 0)


## "★★☆☆☆"
static func star_text(stars: int) -> String:
	return "★".repeat(stars) + "☆".repeat(MAX_STARS - stars)


## Showcase reset: coins, pulls and characters back to a brand-new save (the tutorial flag is kept).
static func reset_gacha() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	for section in ["gacha", "stars"]:
		if cfg.has_section(section):
			cfg.erase_section(section)
	cfg.save(PATH)
