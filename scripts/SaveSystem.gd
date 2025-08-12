extends Node
## Autoload as "SaveSystem"
const SAVE_DIR := "user://saves"
const MAX_SLOTS := 5

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _slot_path(slot: int) -> String:
	return "%s/slot_%d.save" % [SAVE_DIR, slot]

func has_slot(slot: int) -> bool:
	return slot >= 1 and slot <= MAX_SLOTS and FileAccess.file_exists(_slot_path(slot))

func get_slot_meta(slot: int) -> Dictionary:
	var meta: Dictionary = {}
	if not has_slot(slot):
		return meta
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		return meta
	var raw := file.get_as_text()
	file.close()
	if raw == "" or raw.strip_edges() == "":
		return meta
	var json := JSON.new()
	var err := json.parse(raw)
	if err != OK:
		return meta
	var data_dict = json.data
	if typeof(data_dict) == TYPE_DICTIONARY:
		meta["timestamp"] = data_dict.get("timestamp","")
		meta["mode"] = data_dict.get("mode","")
		meta["level"] = int(data_dict.get("level",1))
		meta["gold"] = int(data_dict.get("gold",0))
	return meta

func save(slot: int) -> bool:
	if slot < 1 or slot > MAX_SLOTS:
		return false
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false

	# Inventory
	var inv_dump: Array = []
	for entry in GameManager.inventory:
		var item = entry.get("item")
		var count = int(entry.get("count", 1))
		var item_name := ""
		var item_type := ""
		var item_quality := ""
		if item:
			if item is Location:
				item_type = "Location"
				item_name = item.name
				if "quality" in item: # in case older Location script lacks it
					item_quality = item.quality
			elif item is QuestNote:
				item_type = "QuestNote"
				item_name = item.name
			elif item is Potion:
				item_type = "Potion"
				item_name = item.name
			elif item is EquipmentItem:
				item_type = "EquipmentItem"
				item_name = item.name
				item_quality = item.quality
			elif item is Animal:
				item_type = "Animal"
				item_name = item.name
				if "rarity" in item:
					item_quality = item.rarity
			elif item is Fish:
				item_type = "Fish"
				item_name = item.name
				if "rarity" in item:
					item_quality = item.rarity
			elif item is Plant:
				item_type = "Plant"
				item_name = item.name
				if "rarity" in item:
					item_quality = item.rarity
			elif item is Bag:
				item_type = "Bag"
				item_name = item.name
				item_quality = item.quality
			elif item is DropItem:
				item_type = "DropItem"
				item_name = item.name
			else:
				item_type = "Item"
				if "name" in item:
					item_name = item.name
		inv_dump.append({
			"name": item_name,
			"type": item_type,
			"quality": item_quality,
			"count": count
		})

	# Locations
	var loc_dump: Array = []
	for loc in GameManager.discovered_locations:
		if loc:
			loc_dump.append({
				"name": loc.name,
				"description": loc.description,
				"identifier": loc.identifier,
				"climate": loc.climate,
				"quality": loc.quality,
				"features": loc.features,
				"animal_list": loc.animal_list,
				"plant_list": loc.plant_list,
				"fish_list": loc.fish_list,
				"has_treasure": loc.has_treasure,
				"has_camp": loc.has_camp,
				"shops": loc.shops,
				"bonuses": loc.bonuses
			})

	var data := {
		"version": 2,
		"mode": GameManager.mode,
		"lives": GameManager.player_lives,
		"gold": GameManager.gold,
		"level": GameManager.player_level,
		"xp": GameManager.player_xp,
		"health": GameManager.player_health,
		"health_max": GameManager.player_max_health,
		"stamina": GameManager.player_stamina,
		"stamina_max": GameManager.player_max_stamina,
		"mana": GameManager.player_mana,
		"mana_max": GameManager.player_max_mana,
		"inventory": inv_dump,
		"locations": loc_dump,
		"current_location_index": GameManager.discovered_locations.find(GameManager.current_location),
		"timestamp": Time.get_datetime_string_from_system()
	}

	f.store_string(JSON.stringify(data))
	f.close()
	return true

func _rebuild_item(e: Dictionary) -> Resource:
	var t := String(e.get("type","Item"))
	var n := String(e.get("name","Item"))
	match t:
		"Location":
			var loc = Location.new()
			loc.name = n
			return loc
		"QuestNote":
			var q = Quest.new(n, "Recovered note", [], {"xp": 25}, null)
			return QuestNote.new(q, false)
		"Potion":
			var p_type := n.substr(0, n.length() - 7) if n.ends_with(" Potion") else n
			return Potion.new(p_type, [])
		"EquipmentItem":
			return EquipmentItem.new(n, "Chest", "Common")
		"Animal":
			return Animal.new(n, 100.0)
		"Fish":
			var species := n.substr(0, n.length() - 5) if n.ends_with(" Fish") else n
			return Fish.new(species, 12.0, 2.0)
		"Plant":
			return Plant.new(n)
		"Bag":
			var bag_q := String(e.get("quality","Common"))
			return Bag.new(bag_q)
		"DropItem":
			return DropItem.new(n)
		_:
			return Item.new(n)

func _rebuild_location(d: Dictionary) -> Location:
	var loc = Location.new()
	loc.name = d.get("name","")
	loc.description = d.get("description","")
	loc.identifier = d.get("identifier","[L]")
	loc.climate = d.get("climate","Mild")
	loc.quality = d.get("quality","Common")
	loc.features = d.get("features", [])
	loc.animal_list = d.get("animal_list", [])
	loc.plant_list = d.get("plant_list", [])
	loc.fish_list = d.get("fish_list", [])
	loc.has_treasure = d.get("has_treasure", false)
	loc.has_camp = d.get("has_camp", false)
	loc.shops = d.get("shops", [])
	loc.bonuses = d.get("bonuses", {})
	return loc

func load(slot: int) -> bool:
	if slot < 1 or slot > MAX_SLOTS:
		return false
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if f == null:
		return false
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false

	# Core
	GameManager.gold = int(data.get("gold", 0))
	GameManager.player_level = int(data.get("level", 1))
	GameManager.player_xp = int(data.get("xp", 0))
	GameManager.player_health = int(data.get("health", 100))
	GameManager.player_max_health = int(data.get("health_max", 100))
	GameManager.player_stamina = int(data.get("stamina", 100))
	GameManager.player_max_stamina = int(data.get("stamina_max", 100))
	GameManager.player_mana = int(data.get("mana", 0))
	GameManager.player_max_mana = int(data.get("mana_max", 0))
	if data.has("lives"):
		GameManager.player_lives = int(data["lives"])
	if data.has("mode"):
		GameManager.mode = String(data["mode"])

	# Inventory
	var inv_dump: Array = []
	for entry in GameManager.inventory:
		var item = entry.get("item")
		var count = int(entry.get("count", 1))
		var item_name := ""
		var item_type := ""
		var item_quality := ""
		if item:
			if item is Location:
				item_type = "Location"
				item_name = item.name
				if "quality" in item: # in case older Location script lacks it
					item_quality = item.quality
			elif item is QuestNote:
				item_type = "QuestNote"
				item_name = item.name
			elif item is Potion:
				item_type = "Potion"
				item_name = item.name
			elif item is EquipmentItem:
				item_type = "EquipmentItem"
				item_name = item.name
				item_quality = item.quality
			elif item is Animal:
				item_type = "Animal"
				item_name = item.name
				if "rarity" in item:
					item_quality = item.rarity
			elif item is Fish:
				item_type = "Fish"
				item_name = item.name
				if "rarity" in item:
					item_quality = item.rarity
			elif item is Plant:
				item_type = "Plant"
				item_name = item.name
				if "rarity" in item:
					item_quality = item.rarity
			elif item is Bag:
				item_type = "Bag"
				item_name = item.name
				item_quality = item.quality
			elif item is DropItem:
				item_type = "DropItem"
				item_name = item.name
			else:
				item_type = "Item"
				if "name" in item:
					item_name = item.name
		inv_dump.append({
			"name": item_name,
			"type": item_type,
			"quality": item_quality,
			"count": count
		})

	# Locations
	GameManager.discovered_locations.clear()
	var locs = data.get("locations", [])
	for d in locs:
		if typeof(d) == TYPE_DICTIONARY:
			var loc = _rebuild_location(d)
			GameManager.add_location(loc)

	var idx := int(data.get("current_location_index", 0))
	if idx >= 0 and idx < GameManager.discovered_locations.size():
		GameManager.current_location = GameManager.discovered_locations[idx]
	elif GameManager.discovered_locations.size() > 0:
		GameManager.current_location = GameManager.discovered_locations[0]

	GameManager.inventory_updated.emit()
	GameManager.action_log_updated.emit()
	return true
