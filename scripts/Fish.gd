# Fish.gd
extends Item
class_name Fish

var length: float = 0.0
var weight: float = 0.0
var quality: String = ""
var quality_color: String = ""

func _init(species: String, max_len: float, max_wt: float):
	name = species + " Fish"
	length = randf_range(0.8 * max_len, max_len)
	weight = randf_range(0.8 * max_wt, max_wt)
	quality = calculate_quality(length / max_len)
	quality_color = Location.get_color_for_quality(quality)
	description = "Length: %.1f in, Weight: %.1f Lbs" % [length, weight]
	value = floor(weight * 1.0)

func calculate_quality(perc: float) -> String:
	if perc > 0.99:
		return "Legendary"
	elif perc > 0.95:
		return "Rare"
	elif perc > 0.8:
		return "Uncommon"
	return "Common"

func get_display_text() -> String:
	return "[color=" + quality_color.to_lower() + "]" + name + "[/color] - " + description
