extends Node
# Grants a starter Location map using PackedStringArray for typed Resource props.

@onready var LocationScript := preload("res://scripts/Location.gd")

func _ready() -> void:
	if not Engine.is_editor_hint():
		_grant_once()

func _grant_once() -> void:
	if not GameManager:
		return
	# Only on fresh start: no discovered locations and no map item in inventory
	if GameManager.discovered_locations.size() > 0:
		return
	if _has_any_location_item():
		return

	var loc = _make_starter_location()
	GameManager.add_item(loc)
	GameManager.log_action("[color=#606060]Found a map: " + loc.name + "[/color]")

func _has_any_location_item() -> bool:
	for entry in GameManager.inventory:
		var it = entry.get("item")
		# Loosely detect a Location-like resource
		if it and it.has_method("get_display_text") and it.has_method("add_feature"):
			return true
	return false

func _psa(v) -> PackedStringArray:
	# Coerce any array-ish value to PackedStringArray safely
	if v is PackedStringArray:
		return v
	elif v is Array:
		var out := PackedStringArray()
		for x in v:
			out.append(str(x))
		return out
	else:
		return PackedStringArray()

func _make_starter_location():
	var loc = LocationScript.new()

	loc.name = "Greenwood River"
	loc.description = "A lush riverside forest with plenty of game, herbs, and fish."
	loc.identifier = "[W]"
	loc.has_camp = false
	loc.bonuses = {"quest": true}

	# STRICT: use PackedStringArray for all typed array properties on the Resource
	var features := _psa(["Forest", "River"])
	var animals := _psa(["Deer", "Rabbit", "Fox"])
	var fish    := _psa(["Trout", "Catfish", "Bass"])
	var plants  := _psa(["Healing Herb", "Bitterroot", "Sunflower"])
	var shops   := _psa([])  # wilderness: no shops

	# Use set() to avoid setter/type mismatches
	loc.set("features", features)
	loc.set("animal_list", animals)
	loc.set("fish_list", fish)
	loc.set("plant_list", plants)
	loc.set("shops", shops)

	return loc
