extends Resource
class_name Location

@export var name: String = ""
@export var description: String = ""
@export var identifier: String = ""   # [W]ilderness, [V]illage, etc.
@export var climate: String = "Mild"
@export var features: PackedStringArray = []
@export var animal_list: PackedStringArray = []
@export var fish_list: PackedStringArray = []
@export var plant_list: PackedStringArray = []
@export var bonuses := {}             # {drop_chance: float, timer_reduction: float, xp_boost: float, wood_yield: float}
@export var quality: String = "Common"
@export var has_treasure: bool = false
@export var has_camp: bool = false
@export var shops: Array = []         # for villages only

static func get_color_for_quality(q: String) -> String:
	# Use shared map so colors are consistent everywhere
	var qc = preload("res://scripts/QualityColors.gd")
	return qc.hex_for(q)


func build_description_from_lists() -> void:
	var animals = ", ".join(animal_list)
	var fishs = ", ".join(fish_list)
	var plants = ", ".join(plant_list)
	var feats = ", ".join(features)
	var parts: Array[String] = []
	if feats != "":
		parts.append("[b]Features:[/b] " + feats)
	if animals != "":
		parts.append("[b]Animals:[/b] " + animals)
	if fishs != "":
		parts.append("[b]Fish:[/b] " + fishs)
	if plants != "":
		parts.append("[b]Plants:[/b] " + plants)
	description = "\n".join(parts) if parts.size() > 0 else description

func get_display_text() -> String:
	# Colored + bold name for UI lists
	var qc = preload("res://scripts/QualityColors.gd")
	return qc.bb_name(name, quality)

# Nested per-feature data (e.g., cave has trial/dungeon flags)
var feature_details: Dictionary = {}

func describe() -> String:
	var lines: Array = []
	lines.append(description)
	if animal_list and animal_list.size() > 0:
		lines.append("Animals: " + ", ".join(animal_list))
	if fish_list and fish_list.size() > 0:
		lines.append("Fish: " + ", ".join(fish_list))
	if plant_list and plant_list.size() > 0:
		lines.append("Plants: " + ", ".join(plant_list))
	return "\n".join(lines)
