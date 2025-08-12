extends Resource
class_name MapGenerator

const LocationClass = preload("res://scripts/Location.gd")
const QualityColors = preload("res://scripts/QualityColors.gd")

static func _roll_quality(rng: RandomNumberGenerator) -> String:
	# Ordered lowest -> highest
	var rolls := [
		{"q":"Common", "p": 0.65},
		{"q":"Uncommon", "p": 0.20},
		{"q":"Rare", "p": 0.10},
		{"q":"Unique", "p": 0.035},
		{"q":"Legendary", "p": 0.013},
		{"q":"Ancient", "p": 0.002},
	]
	var r = rng.randf()
	var acc := 0.0
	for e in rolls:
		acc += e.p
		if r <= acc:
			return e.q
	return "Common"

static func _quality_bonuses(q: String) -> Dictionary:
	var d := {}
	match q:
		"Uncommon":
			d.drop_chance = 0.05
		"Rare":
			d.drop_chance = 0.10
			d.timer_reduction = 0.05
		"Unique":
			d.drop_chance = 0.15
			d.timer_reduction = 0.10
			d.xp_boost = 0.05
		"Legendary":
			d.drop_chance = 0.20
			d.timer_reduction = 0.15
			d.xp_boost = 0.10
		"Ancient":
			d.drop_chance = 0.25
			d.timer_reduction = 0.20
			d.xp_boost = 0.15
		_:
			pass
	return d

static func _choose(rng: RandomNumberGenerator, pool: Array, count: int) -> Array:
	var copy := pool.duplicate()
	var res: Array = []
	count = min(count, copy.size())
	while res.size() < count and copy.size() > 0:
		var idx := rng.randi_range(0, copy.size() - 1)
		res.append(copy[idx])
		copy.remove_at(idx)
	return res

static func _name_for(rng: RandomNumberGenerator, quality: String) -> String:
	var base_names = ["Greenwood", "Stonevale", "Duskmoor", "Riverbend", "Frostfield", "Sunmeadow", "Stormwatch", "Oakridge", "Ironpass", "Hearthglen"]
	var suffixes = ["Forest", "River", "Hills", "Marsh", "Coast", "Lake", "Valley", "Peaks", "Flats"]
	var name = base_names[rng.randi() % base_names.size()] + " " + suffixes[rng.randi() % suffixes.size()]
	return name + " [" + quality + "]"

static func _has_water(features: PackedStringArray) -> bool:
	for f in features:
		if f in ["River","Spring","Lake","Sea"]:
			return true
	return false

static func _resource_lists(rng: RandomNumberGenerator, features: PackedStringArray) -> Dictionary:
	var animals: PackedStringArray = []
	var fish: PackedStringArray = []
	var plants: PackedStringArray = []

	if "Forest" in features:
		animals.append_array(["Deer","Rabbit","Fox","Boar"])
		plants.append_array(["Blue Mountain Flower","Healing Herb","Bitterroot"])

	if "Mountains" in features:
		animals.append_array(["Goat","Wolf"])
		plants.append("Frostroot")

	if "Village" in features:
		plants.append("Wheat")

	if "Sea" in features or "Beach" in features:
		fish.append_array(["Cod","Tuna","Mackerel"])

	if "River" in features or "Lake" in features or "Spring" in features:
		fish.append_array(["Trout","Catfish","Bass"])
		plants.append("Watercress")

	if animals.size() == 0:
		animals.append_array(["Deer","Rabbit"])
	if plants.size() == 0:
		plants.append_array(["Healing Herb"])

	return {"animals": animals, "fish": fish, "plants": plants}

static func _shops_for_village(rng: RandomNumberGenerator) -> Array:
	var pool = ["General","Blacksmith","Leatherworker","Workshop","Alchemist","Quests"]
	var shops: Array = []
	for s in pool:
		if rng.randi() % 100 < 60:
			shops.append(s)
	if rng.randi() % 100 < 35 and not "Jeweler" in shops:
		shops.append("Jeweler")
	return shops

static func generate_random_location(rng: RandomNumberGenerator) -> Resource:
	var loc = LocationClass.new()
	loc.has_treasure = true

	# Quality
	var quality := _roll_quality(rng)
	loc.quality = quality

	# Feature count scales with quality
	var count_by_q := {
		"Common": [1,2],
		"Uncommon": [2,3],
		"Rare": [3,4],
		"Unique": [4,5],
		"Legendary": [5,6],
		"Ancient": [6,7],
	}
	var minmax: Array = count_by_q.get(quality, [1,2])
	var want_count := rng.randi_range(minmax[0], minmax[1])

	var base_pool = ["Mountains","River","Spring","Lake","Sea","Forest","Village","Plains","Cave"] # last is direct cave outside mountains
	var chosen: Array = []

	# roll base features (will enforce dependencies later)
	chosen = _choose(rng, base_pool, want_count)

	# Dependency rules:
	# - Beach requires Sea
	if "Sea" in chosen and rng.randi() % 100 < 60 and not "Beach" in chosen:
		chosen.append("Beach")
	# - Rich Soil needs water
	var water_present := _has_water(PackedStringArray(chosen))
	if water_present and rng.randi() % 100 < 55 and not "Rich Soil" in chosen:
		chosen.append("Rich Soil")
	elif not water_present:
		chosen.append("Poor Soil")

	# - Caves/Dungeons/Trials arise mostly from Mountains
	var sub_feats: Dictionary = {}
	if "Mountains" in chosen:
		# chance for cave
		if rng.randi() % 100 < 65 and not "Cave" in chosen:
			chosen.append("Cave")
			sub_feats["Cave"] = {"can_trial": rng.randi() % 100 < 25, "can_dungeon": rng.randi() % 100 < 15}
		# sometimes both trial and dungeon
		if "Cave" in sub_feats and sub_feats["Cave"].can_trial:
			chosen.append("Trial")
		if "Cave" in sub_feats and sub_feats["Cave"].can_dungeon:
			chosen.append("Dungeon")
	else:
		# small chance for a cave elsewhere
		if rng.randi() % 100 < 10 and not "Cave" in chosen:
			chosen.append("Cave")

	# Assign features
	loc.features = PackedStringArray(chosen)

	# Lists (animals/fish/plants)
	var lists := _resource_lists(rng, loc.features)
	loc.animal_list = PackedStringArray(lists.animals)
	loc.fish_list = PackedStringArray(lists.fish)
	loc.plant_list = PackedStringArray(lists.plants)

	# Bonuses by quality
	loc.bonuses = _quality_bonuses(quality)

	# Identifier / shops
	loc.identifier = "[W]"
	if "Village" in loc.features:
		loc.identifier = "[V]"
		loc.shops = _shops_for_village(rng)

	loc.name = _name_for(rng, quality)

	# Description with resources (for UI)
	var parts: Array = []
	parts.append("Features: " + ", ".join(loc.features))
	if loc.animal_list.size() > 0:
		parts.append("Animals: " + ", ".join(loc.animal_list))
	if loc.fish_list.size() > 0:
		parts.append("Fish: " + ", ".join(loc.fish_list))
	if loc.plant_list.size() > 0:
		parts.append("Plants: " + ", ".join(loc.plant_list))
	if loc.identifier == "[V]" and loc.shops and loc.shops.size() > 0:
		parts.append("Shops: " + ", ".join(loc.shops))
	loc.description = parts.join("\n")

	return loc
