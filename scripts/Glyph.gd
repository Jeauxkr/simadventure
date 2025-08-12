extends Item
class_name Glyph

@export var letter: String = ""

func _init(_letter: String = ""):
	letter = _letter
	name = "Glyph of " + letter
	description = "A rune with the letter '" + letter + "' used for runeword crafting."
	value = 15
	stack_max = 1

func get_display_text() -> String:
	return "[b]" + name + "[/b] ('" + letter + "')"
