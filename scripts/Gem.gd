extends Item
class_name Gem

@export var gem_type: String = ""
@export var bonus_value: int = 0

func _init(_gem_type: String = "", _bonus_value: int = 0):
	gem_type = _gem_type
	bonus_value = _bonus_value
	name = gem_type + " Gem"
	description = "A gem that provides a +" + str(bonus_value) + " bonus to " + gem_type + "."
	value = bonus_value * 10
	stack_max = 1

func get_display_text() -> String:
	return "[b]" + name + "[/b] (+" + str(bonus_value) + " " + gem_type + ")"


static func random_gem(level: int) -> Gem:
	var types: Array[String] = ["Ruby","Sapphire","Emerald","Topaz","Amethyst","Diamond","Onyx"]
	var t = types[randi() % types.size()]
	var bonus = clamp(1 + int(level / 10), 1, 10)
	return Gem.new(t, bonus)
