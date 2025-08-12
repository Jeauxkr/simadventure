# Animal.gd
extends Item
class_name Animal

var animal_weight: float = 0.0
var quality: String = ""
var quality_color: String = ""

func _init(species: String, max_wt: float):
	name = species
	animal_weight = randf_range(0.8 * max_wt, max_wt)
	quality = calculate_quality(animal_weight / max_wt)
	quality_color = Location.get_color_for_quality(quality)
	description = "Weight: %.1f Lbs" % animal_weight
	value = floor(animal_weight * 0.5)

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
