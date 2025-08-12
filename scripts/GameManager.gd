extends Node
const ShopPopupClass = preload("res://scripts/ShopPopup.gd")
const LocationClass = preload("res://scripts/Location.gd")
const QuestNoteClass = preload("res://scripts/QuestNote.gd")

signal inventory_updated
signal action_log_updated
const POTION_TYPES = ["Health", "Stamina", "Mana"]


# -----------------------------
# Small helpers
# -----------------------------
func _psa(v) -> PackedStringArray:
	if v is PackedStringArray:
		return v
	var out := PackedStringArray()
	if v is Array:
		for x in v:
			out.append(str(x))
	return out

func _assign_or_add_list(loc, prop: String, values: Array, add_method: String) -> void:
	if loc.has_method(add_method):
		for v in values:
			loc.call(add_method, str(v))
	elif loc.has_method("set"):
		loc.set(prop, _psa(values))

func _make_test_map(i: int):
	var new_map = LocationClass.new()
	new_map.name = "Test Map " + str(i + 1)
	new_map.description = "A test map for location " + str(i + 1)
	new_map.climate = "Mild"
	_assign_or_add_list(new_map, "features", ["River"], "add_feature")
	_assign_or_add_list(new_map, "animal_list", ["Deer"], "add_animal")
	_assign_or_add_list(new_map, "fish_list", ["Trout"], "add_fish")
	_assign_or_add_list(new_map, "plant_list", ["Blue Mountain Flower"], "add_plant")
	return new_map

# -----------------------------
# Core state
# -----------------------------
var inventory: Array = []
var inventory_capacity: int = 10
var camp_inventories: Dictionary = {}
var camp_capacity: int = 100

var gold: int = 0
var mode: String = "Endless"
var player_lives: int = -1
var player_level: int = 1
var player_xp: int = 0

var player_max_health: int = 100
var player_health: int = 100
var player_max_stamina: int = 100
var player_stamina: int = 100
var player_max_mana: int = 100
var player_mana: int = 100

var player_endurance: int = 10
var player_agility: int = 10
var player_focus: int = 10
var player_strength: int = 0
var player_vitality: int = 0
var player_intelligence: int = 0
var player_dexterity: int = 0
var player_crafting: int = 0
var player_luck: int = 0
var player_fishing: int = 0
var player_hunting: int = 0
var player_field_dressing: int = 0
var player_foraging: int = 0
var player_alchemy: int = 0
var player_woodcutting: int = 0
var player_health_recovery: int = 0
var player_mana_recovery: int = 0
var player_stamina_recovery: int = 0

var equipped_bag = null
var discovered_locations: Array = []
var action_log: Array = ["[color=#606060][New Log Entry][/color]"]

var current_action: bool = false
var current_action_type: String = ""
var current_location = null
var current_item: Dictionary = {}
var current_base: Dictionary = {}
var current_plants: Array = []

var regen_time: float = 0.0
var temp_bonuses: Array = []
var action_timer: Timer = Timer.new()
var action_duration: float = 0.0
var active_potion_effects: Dictionary = {}

var shop_manager = null
var alchemy_manager: AlchemyManager = AlchemyManager.new()
var active_quests: Array = []
var current_quest: Quest = null

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ---- Mineral / Gem generator ----
var _metal_pool: Array[String] = ["Iron Ore","Copper Ore","Silver Ore","Gold Ore","Tin Ore","Lead Ore","Mithril Ore"]
var _stone_pool: Array[String] = ["Stone","Granite","Limestone","Clay","Basalt","Sandstone"]
var _gem_types: Array[String] = ["Ruby","Sapphire","Emerald","Topaz","Amethyst","Diamond","Onyx"]

func _mineral_drop_count(q: String) -> int:
	match q:
		"Ancient": return 10
		"Legendary": return randi() % 2 + 8 # 8-9
		"Unique": return randi() % 2 + 7    # 7-8
		"Rare": return randi() % 2 + 5      # 5-6
		"Uncommon": return randi() % 2 + 3  # 3-4
		_: return 2

func _generate_mineral():
	# Choose a category based on simple weights; then pick an item from that category.
	# Metals and Stones are DropItems; Gems are instances of Gem.
	var roll := rng.randi() % 100
	var category := "metal" if roll < 45 else ("stone" if roll < 80 else "gem")

	if category == "metal":
		var idx := rng.randi() % _metal_pool.size()
		var metal_name: String = String(_metal_pool[idx])
		return DropItem.new(metal_name)

	elif category == "stone":
		var idx := rng.randi() % _stone_pool.size()
		var stone_name: String = String(_stone_pool[idx])
		return DropItem.new(stone_name)

	else:
		# Use Gem factory to produce a random gem appropriate for level
		var g: Gem = Gem.new(_gem_types[rng.randi() % _gem_types.size()], max(1, int(player_level / 10.0)))
		return g

func _ready():
	rng.randomize()
	gold = 1000
	add_item(Potion.new("Health"))
	add_item(EquipmentItem.new("Test Armor", "Chest", "Common"))

	add_child(action_timer)
	shop_manager = ShopManager.new()
	add_child(shop_manager)
	add_child(alchemy_manager)

	action_timer.one_shot = true
	action_timer.timeout.connect(complete_action)

	for i in range(3):
		var loc = MapGenerator.generate_random_location(rng)
		add_location(loc)

	update_stats()

func _process(delta: float):
	regen_time += delta
	if regen_time >= 10.0:
		var recovery_boost: float = EquipmentManager.recovery_boost if EquipmentManager else 0.0

		var health_regen = floor(player_max_health * 0.001 * (player_endurance + player_vitality))
		health_regen = floor(health_regen * (1 + player_health_recovery / 100.0) * (1 + recovery_boost))
		player_health = min(player_health + health_regen, player_max_health)

		var stamina_regen = 0 # base regen disabled; improved only by bonuses
		stamina_regen = floor((player_max_stamina * 0.001) * (player_stamina_recovery / 100.0) * (1 + recovery_boost))
		player_stamina = min(player_stamina + stamina_regen, player_max_stamina)

		var mana_regen = floor(player_max_mana * 0.001 * (player_focus + player_intelligence))
		mana_regen = floor(mana_regen * (1 + player_mana_recovery / 100.0) * (1 + recovery_boost))
		player_mana = min(player_mana + mana_regen, player_max_mana)

		regen_time -= 10.0

# -----------------------------
# Locations & Inventory
# -----------------------------
func add_location(location):
	if location and not discovered_locations.has(location):
		discovered_locations.append(location)
		log_action("[color=#606060]Discovered new location: " + location.name + "[/color]")
		inventory_updated.emit()
		action_log_updated.emit()

func add_item(new_item, to_camp: bool = false) -> bool:
	var target_inventory = camp_inventories.get(current_location, []) if to_camp and current_location else inventory
	var target_capacity = camp_capacity if to_camp else inventory_capacity

	for entry in target_inventory:
		if entry["item"].name == new_item.name and not (new_item is Gem or new_item is Animal or new_item is Fish or new_item is Plant or new_item is EquipmentItem or new_item is Potion or new_item is QuestNote):
			var space_left = new_item.stack_max - entry["count"]
			if space_left > 0:
				entry["count"] += 1
				inventory_updated.emit()
				return true

	if target_inventory.size() < target_capacity:
		target_inventory.append({"item": new_item, "count": 1})
		inventory_updated.emit()
		if new_item is QuestNote and new_item.is_completion:
			check_quest_completion(new_item.quest)
		return true

	log_action("[color=#606060]Inventory full! Cannot add " + new_item.name + ".[/color]")
	return false

func remove_item(entry, from_camp: bool = false, remove_count: int = 1) -> bool:
	var target_inventory = camp_inventories.get(current_location, []) if from_camp and current_location else inventory
	var idx = target_inventory.find(entry)
	if idx != -1:
		target_inventory[idx]["count"] -= remove_count
		if target_inventory[idx]["count"] <= 0:
			target_inventory.remove_at(idx)
		inventory_updated.emit()
		return true
	return false

func remove_item_by_name(item_name, count: int = 1) -> bool:
	for entry in inventory:
		if entry["item"].name == item_name:
			entry["count"] -= count
			if entry["count"] <= 0:
				inventory.erase(entry)
			inventory_updated.emit()
			return true
	return false

func remove_entry(entry, to_camp: bool = false) -> Dictionary:
	var target_inventory = camp_inventories.get(current_location, []) if to_camp and current_location else inventory
	var idx = target_inventory.find(entry)
	if idx != -1:
		var removed = target_inventory[idx]
		target_inventory.remove_at(idx)
		inventory_updated.emit()
		return removed
	return {}

func add_entry(new_entry, to_camp: bool = false):
	var target_inventory = camp_inventories.get(current_location, []) if to_camp and current_location else inventory
	var stacked = false
	for t_entry in target_inventory:
		if t_entry["item"].name == new_entry["item"].name and not (new_entry["item"] is Location or new_entry["item"] is Animal or new_entry["item"] is Fish or new_entry["item"] is Plant or new_entry["item"] is QuestNote):
			t_entry["count"] += new_entry["count"]
			stacked = true
			break
	if not stacked:
		target_inventory.append(new_entry)
	inventory_updated.emit()

func move_to_camp(entry):
	var removed = remove_entry(entry, false)
	if removed.size() > 0:
		add_entry(removed, true)
		log_action("[color=#606060]Stored " + removed["item"].name + " in camp.[/color]")
		action_log_updated.emit()

func move_from_camp(entry):
	var removed = remove_entry(entry, true)
	if removed.size() > 0:
		add_entry(removed, false)
		log_action("[color=#606060]Took " + removed["item"].name + " from camp.[/color]")
		action_log_updated.emit()

# -----------------------------
# Logging / Quests
# -----------------------------
func log_action(message):
	var time_dict = Time.get_time_dict_from_system()
	var stamp = "[%02d:%02d:%02d] " % [time_dict.hour, time_dict.minute, time_dict.second]
	message = stamp + message
	action_log.append(message)
	action_log_updated.emit()

func accept_quest(quest):
	if not active_quests.has(quest):
		active_quests.append(quest)
		log_action("[color=#606060]Accepted quest: " + quest.name + "[/color]")
		action_log_updated.emit()

func check_quest_completion(quest):
	if not quest or quest.status == "completed":
		return
	var completed = true
	for obj in quest.objectives:
		if obj.current < obj.count:
			completed = false
			break
	if completed and (quest.location == null or (current_location and current_location.identifier == "[V]")):
		quest.status = "completed"
		var note = QuestNoteClass.new(quest, true)
		add_item(note)
		log_action("[color=#606060]Quest completed: " + quest.name + ". Received completion note.[/color]")
		action_log_updated.emit()

func complete_quest(quest):
	if quest.status == "completed":
		if quest.rewards.has("gold"):
			gold += quest.rewards.gold
			log_action("[color=#606060]Received " + str(quest.rewards.gold) + " gold for quest: " + quest.name + "[/color]")
		if quest.rewards.has("items"):
			for item in quest.rewards.items:
				add_item(item)
				log_action("[color=#606060]Received " + item.name + " for quest: " + quest.name + "[/color]")
		if quest.rewards.has("xp"):
			player_xp += quest.rewards.xp
			log_action("[color=#606060]Received " + str(quest.rewards.xp) + " XP for quest: " + quest.name + "[/color]")
		active_quests.erase(quest)
		check_level_up()
		action_log_updated.emit()

func update_quest_progress(action_type, target, count: int = 1):
	for quest in active_quests:
		if quest.status == "completed":
			continue
		for obj in quest.objectives:
			if obj.type == action_type and (obj.target == target or obj.target == ""):
				if quest.location == null or quest.location == current_location:
					obj.current = min(obj.current + count, obj.count)
					log_action("[color=#606060]Quest progress: " + quest.name + " (" + obj.type.capitalize() + " " + obj.target + ": " + str(obj.current) + "/" + str(obj.count) + ")[/color]")
					check_quest_completion(quest)
					action_log_updated.emit()

# -----------------------------
# Actions
# -----------------------------
func start_action(loc, action, item = {}):
	if current_action or not loc:
		return

	# Basic costs (kept simple for now)
	var cost_stamina := 1
	var cost_gold := 0

	if action == "Build Camp":
		if gold < 100 or player_stamina < 3:
			log_action("[color=#606060]Not enough gold or stamina to build camp.[/color]")
			return
		cost_gold = 100
		cost_stamina = 3
	elif action == "Craft Base Potion":
		var has_water := false
		for i in inventory:
			if i["item"] is DropItem and i["item"].name == "Water" and i["count"] > 0:
				has_water = true
				break
		if not has_water:
			log_action("[color=#606060]No water to craft base potion.[/color]")
			return
	elif action == "Craft Potion":
		pass
	elif action == "Quest":
		if not loc.bonuses.has("quest"):
			log_action("[color=#606060]No quests available at this location.[/color]")
			return
		var options: Array = []
		if "animal_list" in loc and loc.animal_list.size() > 0:
			options.append({"name":"Local Hunt", "desc":"Hunt 5 %s" % str(loc.animal_list[0]), "obj":[{"type":"hunt","count":5}], "rewards":{"gold": rng.randi_range(50,150), "xp": 40}})
		if "plant_list" in loc and loc.plant_list.size() > 0:
			options.append({"name":"Local Harvest", "desc":"Harvest 5 %s" % str(loc.plant_list[0]), "obj":[{"type":"harvest","count":5}], "rewards":{"gold": rng.randi_range(50,150), "xp": 30}})
		if "fish_list" in loc and loc.fish_list.size() > 0:
			options.append({"name":"Local Fish", "desc":"Catch 5 %s" % str(loc.fish_list[0]), "obj":[{"type":"fish","count":5}], "rewards":{"gold": rng.randi_range(50,150), "xp": 30}})
		if options.size() == 0:
			options.append({"name":"Local Errand", "desc":"Explore the area.", "obj":[{"type":"explore","count":3}], "rewards":{"gold": rng.randi_range(30,100), "xp": 20}})
		var qd = options[rng.randi() % options.size()]
		var quest = Quest.new(qd["name"], qd["desc"], qd["obj"], qd["rewards"], loc)
		current_quest = quest
	# Spend costs
	gold -= cost_gold
	player_stamina = max(0, player_stamina - cost_stamina)

	current_action = true
	current_action_type = action
	current_location = loc
	current_item = item

	# Base duration and timers
	var base_duration: float = 5.0
	match action:
		"Explore":
			var _equipment_global_timer_reduce: float = EquipmentManager.global_timer_reduce if EquipmentManager else 0.0
			match loc.climate:
				"Mild":
					base_duration = 5.0
				"Moderate":
					base_duration = 10.0
				"Harsh":
					base_duration = 15.0
			base_duration *= (1 - _equipment_global_timer_reduce)
		"Hunt":
			var _equipment_hunt_timer_reduce: float = EquipmentManager.hunt_timer_reduce if EquipmentManager else 0.0
			var _equipment_global_timer_reduce: float = EquipmentManager.global_timer_reduce if EquipmentManager else 0.0
			base_duration = 10.0 * (1 - 0.005 * player_hunting) * (1 - _equipment_hunt_timer_reduce)
			base_duration *= (1 - _equipment_global_timer_reduce)
		"Fish":
			var _equipment_global_timer_reduce: float = EquipmentManager.global_timer_reduce if EquipmentManager else 0.0
			base_duration = 10.0 * (1 - 0.005 * player_fishing)
			base_duration *= (1 - _equipment_global_timer_reduce)
		"Harvest":
			var _equipment_global_timer_reduce: float = EquipmentManager.global_timer_reduce if EquipmentManager else 0.0
			base_duration = 10.0 * (1 - 0.005 * player_foraging)
			base_duration *= (1 - _equipment_global_timer_reduce)
		"Skin":
			var _equipment_global_timer_reduce: float = EquipmentManager.global_timer_reduce if EquipmentManager else 0.0
			base_duration = 5.0 * (1 - 0.005 * player_field_dressing)
			base_duration *= (1 - _equipment_global_timer_reduce)
		"Fillet":
			var _equipment_global_timer_reduce: float = EquipmentManager.global_timer_reduce if EquipmentManager else 0.0
			base_duration = 5.0 * (1 - 0.005 * player_field_dressing)
			base_duration *= (1 - _equipment_global_timer_reduce)
		"Build Camp":
			base_duration = 30.0
		"Gather Water":
			base_duration = 5.0
		"Cave", "Dungeon", "Trial", "Quest":
			base_duration = 10.0
		_:
			base_duration = 5.0

	if loc.bonuses.has("timer_reduction"):
		base_duration *= (1 - loc.bonuses.timer_reduction)

	action_duration = base_duration
	action_timer.start(action_duration)

	var msg = "[color=#606060]Started " + action
	if loc:
		msg += " at " + loc.name
	if item.size() > 0:
		msg += " on " + item["item"].name
	msg += ".[/color]"
	log_action(msg)
	action_log_updated.emit()

func complete_action():
	if not current_action or not current_location:
		return

	var damage: int = 0
	var xp_multiplier = 1.0
	if current_location.bonuses.has("xp_boost"):
		xp_multiplier += current_location.bonuses.xp_boost

	var target = ""

	match current_action_type:
		"Explore":
			# Compute drop chance once (equipment + location)
			var _equipment_explore_drop_bonus: float = EquipmentManager.explore_drop_bonus if EquipmentManager else 0.0
			var base_drop_chance := 0.1 + 0.001 * player_luck
			var drop_chance := base_drop_chance * (1.0 + _equipment_explore_drop_bonus)
			if current_location.bonuses.has("drop_chance"):
				drop_chance *= (1.0 + current_location.bonuses.drop_chance)

			log_action("[color=#606060]Explored " + current_location.name + ".[/color]")

			# Treasure roll
			if rng.randi() % 3 == 0 and inventory.size() < inventory_capacity:
				if current_location.has_treasure:
					current_location.has_treasure = false
					if rng.randi() % 2 == 0:
						var treasure_gold = rng.randi_range(100, 500)
						gold += treasure_gold
						log_action("[color=#606060]Found treasure: " + str(treasure_gold) + " gold![/color]")
					else:
						var pot = Potion.new(POTION_TYPES[rng.randi() % POTION_TYPES.size()], [])

						add_item(pot)
						log_action("[color=#606060]Found treasure: " + pot.name + "![/color]")

			# Map drop
			if inventory.size() < inventory_capacity and rng.randf() < drop_chance * 0.5:
				var new_map = _roll_random_location()
				if true:
					var dup := false
					for dloc in discovered_locations:
						if dloc.name == new_map.name:
							dup = true
							break
					if not dup:
						add_item(new_map)
						log_action("[color=#606060]Found a map: " + new_map.name + "[/color]")

			# Small drops
			if rng.randf() < drop_chance:
				add_item(Potion.new("Health", ["Restore Health"]))
				log_action("[color=#606060]Found a small drop: Health Potion![/color]")
			if rng.randf() < drop_chance:
				add_item(Potion.new("Mana", ["Restore Magicka"]))
				log_action("[color=#606060]Found a small drop: Mana Potion![/color]")
			if rng.randf() < drop_chance:
				add_item(DropItem.new("Repair Kit"))
				log_action("[color=#606060]Found a small drop: Repair Kit![/color]")
			if rng.randf() < 0.1:
				add_item(DropItem.new("Repair Kit"))
				log_action("[color=#606060]Found Repair Kit![/color]")

			if EquipmentManager:
				EquipmentManager.apply_durability_loss()

			update_quest_progress("explore", "")
			player_xp += int(1 * (1 + (EquipmentManager.player_xp_gain if EquipmentManager else 0.0)) * xp_multiplier)

		"Hunt":
			var equipment_xp_gain: float = EquipmentManager.player_xp_gain if EquipmentManager else 0.0
			if current_location.animal_list.size() > 0:
				var species = current_location.animal_list[rng.randi() % current_location.animal_list.size()]
				var max_wt = get_animal_max_weight(species)
				var skill_bonus = player_hunting * 0.01
				var animal_weight = rng.randf_range(0.8 * max_wt, max_wt * (1 + skill_bonus))
				var animal = Animal.new(species, max_wt)
# patched: initialize animal properties formerly passed to Animal.new(species, max_wt)
				animal.animal_weight = animal_weight
				animal.quality = animal.calculate_quality(animal_weight / max_wt)
				animal.quality_color = LocationClass.get_color_for_quality(animal.quality)
				add_item(animal)
				log_action("[color=#606060]Hunted and caught [/color][color=" + animal.quality_color.to_lower() + "]" + animal.name + "[/color][color=#606060].[/color]")
				target = species
			else:
				log_action("[color=#606060]No animals to hunt here.[/color]")
			player_hunting += int(1 * xp_multiplier)
			player_xp += int(1 * (1 + equipment_xp_gain) * xp_multiplier)
			update_quest_progress("hunt", target)

		"Fish":
			var equipment_xp_gain: float = EquipmentManager.player_xp_gain if EquipmentManager else 0.0
			if current_location.fish_list.size() > 0:
				var species = current_location.fish_list[rng.randi() % current_location.fish_list.size()]
				var max_len_wt = get_fish_max(species)
				var skill_bonus = player_fishing * 0.01
				var length = rng.randf_range(0.8 * max_len_wt[0], max_len_wt[0] * (1 + skill_bonus))
				var weight = rng.randf_range(0.8 * max_len_wt[1], max_len_wt[1] * (1 + skill_bonus))
				var fish = Fish.new(species, max_len_wt[0], max_len_wt[1])
# patched: initialize fish properties formerly passed to Fish.new(species, max_len_wt[0], max_len_wt[1])
				fish.length = length
				fish.weight = weight
				fish.quality = fish.calculate_quality(length / max_len_wt[0])
				fish.quality_color = LocationClass.get_color_for_quality(fish.quality)
				add_item(fish)
				log_action("[color=#606060]Fished and caught [/color][color=" + fish.quality_color.to_lower() + "]" + fish.name + "[/color][color=#606060].[/color]")
				target = species
			else:
				log_action("[color=#606060]No fish to catch here.[/color]")
			player_fishing += int(1 * xp_multiplier)
			player_xp += int(1 * (1 + equipment_xp_gain) * xp_multiplier)
			update_quest_progress("fish", target)

		"Harvest":
			var equipment_xp_gain: float = EquipmentManager.player_xp_gain if EquipmentManager else 0.0
			if current_location.plant_list.size() > 0:
				var species = current_location.plant_list[rng.randi() % current_location.plant_list.size()]
				var plant = Plant.new(species)
# patched: initialize plant properties formerly passed to Plant.new(species)
				if player_foraging > 50 and rng.randf() < 0.2:
					plant.effects.append("Restore Health")
				add_item(plant)
				log_action("[color=#606060]Harvested " + plant.name + ".[/color]")
				target = species
			else:
				log_action("[color=#606060]No plants to harvest here.[/color]")
			player_foraging += int(1 * xp_multiplier)
			player_xp += int(1 * (1 + equipment_xp_gain) * xp_multiplier)
			update_quest_progress("harvest", target)

		"Skin":
			var equipment_xp_gain: float = EquipmentManager.player_xp_gain if EquipmentManager else 0.0
			if current_item.has("item") and current_item["item"] is Animal:
				var wt = current_item["item"].animal_weight
				var meat_count = floor(wt / 10.0)
				for i in range(meat_count):
					var meat = DropItem.new()
# patched: initialize meat properties formerly passed to DropItem.new("Raw Meat")
					add_item(meat)
				var drop_name = get_animal_drop(current_item["item"].name)
				if drop_name:
					var drop = DropItem.new()
# patched: initialize drop properties formerly passed to DropItem.new(drop_name)
					add_item(drop)
				target = current_item["item"].name
				remove_item(current_item)
				log_action("[color=#606060]Skinned and dressed [/color][color=" + current_item["item"].quality_color.to_lower() + "]" + current_item["item"].name + "[/color][color=#606060]. Added " + str(meat_count) + " Raw Meat and " + drop_name + ".[/color]")
			player_field_dressing += int(1 * xp_multiplier)
			player_xp += int(1 * (1 + equipment_xp_gain) * xp_multiplier)
			update_quest_progress("skin", target)

		"Fillet":
			var equipment_xp_gain: float = EquipmentManager.player_xp_gain if EquipmentManager else 0.0
			if current_item.has("item") and current_item["item"] is Fish:
				var wt = current_item["item"].weight
				var fillet_count = floor(wt / 2)
				for i in range(fillet_count):
					var fillet = DropItem.new()
# patched: initialize fillet properties formerly passed to DropItem.new("Fish Fillet")
					add_item(fillet)
				target = current_item["item"].name
				remove_item(current_item)
				log_action("[color=#606060]Filleted [/color][color=" + current_item["item"].quality_color.to_lower() + "]" + current_item["item"].name + "[/color][color=#606060]. Added " + str(fillet_count) + " Fish Fillet.[/color]")
			else:
				log_action("[color=#606060]Invalid item for filleting.[/color]")
			player_field_dressing += int(1 * xp_multiplier)
			player_xp += int(1 * (1 + equipment_xp_gain) * xp_multiplier)
			update_quest_progress("fillet", target)

		"Build Camp":
			if !current_location.has_camp:
				current_location.has_camp = true
				camp_inventories[current_location] = []
				log_action("[color=#606060]Built permanent camp at " + current_location.name + ".[/color]")

		"Gather Water":
			add_item(Water.new())
			log_action("[color=#606060]Gathered Water.[/color]")
			update_quest_progress("gather_water", "")

		"Craft Base Potion":
			remove_item(current_item)
			alchemy_manager.craft_base()

		"Craft Potion":
			remove_item(current_base)
			var plant_entries: Array = []
			for plant in current_plants:
				for entry in inventory:
					if entry["item"] == plant:
						plant_entries.append(entry)
						remove_item(entry)
						break
			alchemy_manager.craft_enchanted(plant_entries)

		"Blacksmith":
			if shop_manager:
				shop_manager.display_blacksmith(current_location)
			var popup = ShopPopupClass.new()
			if popup.has_method("configure"):
				popup.configure("Blacksmith")
			get_node("/root/MainUi").add_child(popup)
			popup.popup_centered()

		"Leatherworker":
			if shop_manager:
				shop_manager.display_leatherworker(current_location)
			var popup = ShopPopupClass.new()
			if popup.has_method("configure"):
				popup.configure("Leatherworker")
			get_node("/root/MainUi").add_child(popup)
			popup.popup_centered()

		"Alchemist":
			var popup = ShopPopupClass.new()
			if popup.has_method("configure"):
				popup.configure("Alchemist")
			get_node("/root/MainUi").add_child(popup)
			popup.popup_centered()

		"Forge":
			var popup = ShopPopupClass.new()
			if popup.has_method("configure"):
				popup.configure("Forge")
			get_node("/root/MainUi").add_child(popup)
			popup.popup_centered()
			log_action("[color=#606060]Entered Forge to craft weapons/armor.[/color]")

		"Workshop":
			var popup = ShopPopupClass.new()
			if popup.has_method("configure"):
				popup.configure("Workshop")
			get_node("/root/MainUi").add_child(popup)
			popup.popup_centered()
			log_action("[color=#606060]Entered Workshop to craft leather/cloth items.[/color]")

		"Quests":
			if shop_manager:
				shop_manager.display_quests(current_location)
			var popup = ShopPopupClass.new()
			if popup.has_method("configure"):
				popup.configure("Quests")
			get_node("/root/MainUi").add_child(popup)
			popup.popup_centered()

		"Cave":
			var _equipment_damage_reduce: float = EquipmentManager.damage_reduce if EquipmentManager else 0.0
			damage = floor(10 * 1.1 * (1 - 0.001 * player_strength) * (1 - _equipment_damage_reduce))
			var cave_slots = ["Head", "Chest", "Shoulders"]
			var slot = cave_slots[rng.randi() % cave_slots.size()]
			var qualities = ["Common", "Uncommon", "Rare"]
			var quality = qualities[rng.randi() % qualities.size()]
			var gear_name = slot.capitalize() + " Armor"
			var gear = EquipmentItem.new(gear_name, slot, quality)
# patched: initialize gear properties formerly passed to EquipmentItem.new(gear_name, slot, quality)
			add_item(gear)
			# Minerals drop in caves based on location quality (2–10)
			var _q2: String = "Common"
			if current_location.get("quality") != null:
				_q2 = str(current_location.get("quality"))
			var _drop_ct2: int = _mineral_drop_count(_q2)
			var _bag2: Dictionary = {}
			for _i2 in range(_drop_ct2):
				var _min2 = _generate_mineral()
				if add_item(_min2):
					var _key2: String = _min2.name
					_bag2[_key2] = (_bag2.get(_key2, 0) + 1)
				else:
					log_action("[color=#606060]Inventory full, some minerals left behind.[/color]")
					break
			if _bag2.size() > 0:
				var _parts2: Array = []
				for _k2 in _bag2.keys():
					_parts2.append(str(_bag2[_k2]) + "x " + str(_k2))
				var _summary2 := ""
				for _j2 in range(_parts2.size()):
					_summary2 += _parts2[_j2]
					if _j2 < _parts2.size() - 1:
						_summary2 += ", "
				log_action("[color=#606060]Collected minerals: " + _summary2 + "[/color]")
			log_action("[color=#606060]Completed Cave adventure. Found " + gear.name + "![/color]")
			update_quest_progress("cave", "")
			# Mineral drops based on location quality
			var q: String = (current_location.quality if current_location else "Common")
			var base_by_q := {'Common':2,'Uncommon':3,'Rare':5,'Unique':7,'Legendary':9,'Ancient':10}
			var base_ct := int(base_by_q.get(q,2))
			var extra := rng.randi_range(0, 2)
			var total := max(1, base_ct + extra)
			for k in range(total):
				var roll = rng.randi() % 100
				var cat: String = 'Metal' if roll < 50 else ('Stone' if roll < 80 else 'Gem')
				var m := Mineral.random_mineral(rng, cat, q)
				add_item(m)
				log_action('[color=#606060]Found ' + m.name + ' in the cave.[/color]')
			player_xp += int(1 * (1 + (EquipmentManager.player_xp_gain if EquipmentManager else 0.0)) * xp_multiplier)

		"Dungeon":
			var _equipment_damage_reduce: float = EquipmentManager.damage_reduce if EquipmentManager else 0.0
			damage = floor(10 * 1.25 * (1 - 0.001 * player_strength) * (1 - _equipment_damage_reduce))
			var dungeon_slots = ["Hands", "Waist", "Legs", "Feet"]
			var slot = dungeon_slots[rng.randi() % dungeon_slots.size()]
			var qualities = ["Common", "Uncommon", "Rare"]
			var quality = qualities[rng.randi() % qualities.size()]
			var gear_name = slot.capitalize() + " Armor"
			var gear = EquipmentItem.new(gear_name, slot, quality)
# patched: initialize gear properties formerly passed to EquipmentItem.new(gear_name, slot, quality)
			add_item(gear)
			log_action("[color=#606060]Completed Dungeon adventure. Found " + gear.name + "![/color]")
			update_quest_progress("dungeon", "")
			player_xp += int(1 * (1 + (EquipmentManager.player_xp_gain if EquipmentManager else 0.0)) * xp_multiplier)

		"Trial":
			var _equipment_damage_reduce: float = EquipmentManager.damage_reduce if EquipmentManager else 0.0
			damage = floor(10 * 2.0 * (1 - 0.001 * player_strength) * (1 - _equipment_damage_reduce))
			var trial_slots = ["Ring", "Amulet"]
			var slot = trial_slots[rng.randi() % trial_slots.size()]
			var qualities = ["Rare", "Unique", "Legendary"]
			var quality = qualities[rng.randi() % qualities.size()]
			var gear_name = slot.capitalize()
			var gear = EquipmentItem.new(gear_name, slot, quality)
# patched: initialize gear properties formerly passed to EquipmentItem.new(gear_name, slot, quality)
			add_item(gear)
			log_action("[color=#606060]Completed Trial adventure. Found " + gear.name + "![/color]")
			update_quest_progress("trial", "")
			player_xp += int(1 * (1 + (EquipmentManager.player_xp_gain if EquipmentManager else 0.0)) * xp_multiplier)

	player_health = max(1, player_health - damage)
	if damage > 0:
		log_action("[color=#606060]You took " + str(damage) + " damage![/color]")

	check_level_up()
	current_action = false
	current_action_type = ""
	current_location = null
	current_item = {}
	current_base = {}
	current_plants = []
	inventory_updated.emit()
	action_log_updated.emit()

func check_level_up():
	if player_xp >= 100:
		player_xp -= 100
		player_level += 1

		var gain_end = rng.randi_range(1, 5)
		player_endurance += gain_end
		log_action("[color=#606060]Gained +" + str(gain_end) + " Endurance![/color]")

		var gain_agi = rng.randi_range(1, 5)
		player_agility += gain_agi
		log_action("[color=#606060]Gained +" + str(gain_agi) + " Agility![/color]")

		var gain_foc = rng.randi_range(1, 5)
		player_focus += gain_foc
		log_action("[color=#606060]Gained +" + str(gain_foc) + " Focus![/color]")

		var gain_str = rng.randi_range(1, 5)
		player_strength += gain_str
		log_action("[color=#606060]Gained +" + str(gain_str) + " Strength![/color]")

		var gain_vit = rng.randi_range(1, 5)
		player_vitality += gain_vit
		log_action("[color=#606060]Gained +" + str(gain_vit) + " Vitality![/color]")

		var gain_int = rng.randi_range(1, 5)
		player_intelligence += gain_int
		log_action("[color=#606060]Gained +" + str(gain_int) + " Intelligence![/color]")

		var gain_dex = rng.randi_range(1, 5)
		player_dexterity += gain_dex
		log_action("[color=#606060]Gained +" + str(gain_dex) + " Dexterity![/color]")

		var gain_cra = rng.randi_range(1, 5)
		player_crafting += gain_cra
		log_action("[color=#606060]Gained +" + str(gain_cra) + " Crafting![/color]")

		var gain_luc = rng.randi_range(1, 5)
		player_luck += gain_luc
		log_action("[color=#606060]Gained +" + str(gain_luc) + " Luck![/color]")

		var gain_for = rng.randi_range(1, 5)
		player_foraging += gain_for
		log_action("[color=#606060]Gained +" + str(gain_for) + " Foraging![/color]")

		var gain_alc = rng.randi_range(1, 5)
		player_alchemy += gain_alc
		log_action("[color=#606060]Gained +" + str(gain_alc) + " Alchemy![/color]")

		update_stats()
		log_action("[color=#606060]Leveled up to level " + str(player_level) + "![/color]")
		action_log_updated.emit()

func update_stats():
	player_max_health = 50 + player_endurance * 5 + player_vitality * 5
	player_health = min(player_health, player_max_health)

	player_max_stamina = 50 + player_agility * 5 + player_dexterity * 5
	player_stamina = min(player_stamina, player_max_stamina)

	player_max_mana = 50 + player_focus * 5 + player_intelligence * 5
	player_mana = min(player_mana, player_max_mana)

	inventory_updated.emit()

func add_temp_bonus(stat, value: int, duration: float):
	var full_stat = "player_" + stat
	if full_stat in self:
		self[full_stat] += value
		update_stats()
		var timer = Timer.new()
		add_child(timer)
		timer.one_shot = true
		timer.timeout.connect(_remove_temp_bonus.bind(stat, value, timer))
		timer.start(duration)
		temp_bonuses.append({"stat": stat, "value": value, "timer": timer})

func _remove_temp_bonus(stat, value: int, timer):
	var full_stat = "player_" + stat
	if full_stat in self:
		self[full_stat] -= value
		update_stats()
	temp_bonuses.erase(temp_bonuses.filter(func(b): return b["timer"] == timer)[0])
	timer.queue_free()

func get_animal_max_weight(species) -> float:
	match species:
		"Deer": return 300.0
		"Rabbit": return 5.0
		"Fox": return 15.0
		"Buffalo": return 2000.0
		"Zebra": return 900.0
		"Lion": return 500.0
		"Camel": return 1300.0
		"Hyena": return 150.0
		"Ostrich": return 300.0
		_: return 100.0

func get_fish_max(species) -> Array:
	match species:
		"Trout": return [30.0, 8.0]
		"Catfish": return [40.0, 20.0]
		"Bass": return [30.0, 22.0]
		"Pike": return [40.0, 20.0]
		"Tuna": return [60.0, 100.0]
		"Cod": return [72.0, 200.0]
		_: return [20.0, 5.0]

func get_animal_drop(species) -> String:
	match species:
		"Deer": return "Deer Hide"
		"Rabbit": return "Rabbit Fur"
		"Fox": return "Fox Fur"
		"Buffalo": return "Buffalo Hide"
		"Zebra": return "Zebra Hide"
		"Lion": return "Lion Hide"
		"Camel": return "Camel Hide"
		"Hyena": return "Hyena Hide"
		"Ostrich": return "Ostrich Skin"
		_: return ""

func use_potion(potion):
	if potion:
		potion.use()
		log_action("[color=#606060]Used potion: " + potion.name + "[/color]")
		action_log_updated.emit()

func repair_item(slot):
	if EquipmentManager and EquipmentManager.equipped.has(slot):
		var item = EquipmentManager.equipped[slot]
		if item:
			EquipmentManager.repair(item)
	else:
		log_action("[color=#606060]No item equipped in slot: " + slot + " to repair.[/color]")
	action_log_updated.emit()

func equip_bag(bag):
	equipped_bag = bag
	inventory_capacity += bag.bag_capacity if bag else 0
	log_action("[color=#606060]Equipped bag: " + (bag.name if bag else "No bag") + "[/color]")
	inventory_updated.emit()

func unequip_bag():
	if equipped_bag:
		add_item(equipped_bag)
		equipped_bag = null
		inventory_capacity = 10
		log_action("[color=#606060]Unequipped bag[/color]")
		inventory_updated.emit()

func use_note(note):
	if note:
		if note.is_completion:
			complete_quest(note.quest)
		else:
			accept_quest(note.quest)
		log_action("[color=#606060]Used quest note: " + note.name + "[/color]")
		action_log_updated.emit()

func _roll_random_location():
	return MapGenerator.generate_random_location(rng)
