extends Node
# NOTE: Do NOT add `class_name` here; it would hide the autoload singleton.

# --- Autoload references ------------------------------------------------------
@onready var _sets := get_node_or_null("/root/EquipmentSets")  # autoload node
# GameManager is also expected as an autoload at /root/GameManager

# --- Equipment state ----------------------------------------------------------
var equipped: Dictionary = {}           # slot -> EquipmentItem
var equipped_pets: Array = []           # list of TamedAnimal
var total_pet_slots: int = 1

# --- Aggregated equipment/system modifiers -----------------------------------
var global_timer_reduce: float = 0.0    # percent as 0.00–1.00
var player_xp_gain: float = 0.0         # percent as 0.00–1.00
var hunt_timer_reduce: float = 0.0      # percent as 0.00–1.00
var explore_drop_bonus: float = 0.0     # percent as 0.00–1.00
var damage_reduce: float = 0.0          # percent as 0.00–1.00
var recovery_boost: float = 0.0         # percent as 0.00–1.00

# Active set-bonus (flat) stats merged from all equipped sets (e.g., strength:+5)
var active_set_bonuses: Dictionary = {}

# --- Equip / Unequip ----------------------------------------------------------
func equip(item) -> void:
	# item: EquipmentItem
	if not item:
		return
	var slot = item.slot
	if equipped.has(slot):
		GameManager.add_item(equipped[slot])
		_remove_bonuses(equipped[slot])
	equipped[slot] = item
	_apply_bonuses(item)

	# Make extra pet slots explicit to avoid type inference issues
	var extra_slots: int = 0
	var v = item.get("extra_pet_slots")
	if v != null:
		extra_slots = int(v)
	total_pet_slots += extra_slots

	_apply_set_bonuses()
	GameManager.log_action("[color=#606060]Equipped " + item.name + " in " + slot + " slot.[/color]")

func unequip(slot: String) -> void:
	if equipped.has(slot):
		var item = equipped[slot]
		GameManager.add_item(item)
		_remove_bonuses(item)
		equipped.erase(slot)

		var extra_slots: int = 0
		var v = item.get("extra_pet_slots")
		if v != null:
			extra_slots = int(v)
		total_pet_slots -= extra_slots

		_apply_set_bonuses()
		GameManager.log_action("[color=#606060]Unequipped " + item.name + " from " + slot + " slot.[/color]")

# --- Pets ---------------------------------------------------------------------
func equip_pet(pet) -> void:
	# pet: TamedAnimal
	if equipped_pets.size() < total_pet_slots:
		equipped_pets.append(pet)
		_apply_bonuses(pet)
		GameManager.log_action("[color=#606060]Equipped pet " + pet.name + ".[/color]")
	else:
		GameManager.log_action("[color=#606060]No more pet slots available.[/color]")

func unequip_pet(index: int) -> void:
	if index >= 0 and index < equipped_pets.size():
		var pet = equipped_pets[index]
		equipped_pets.remove_at(index)
		_remove_bonuses(pet)
		GameManager.add_item(pet)
		GameManager.log_action("[color=#606060]Unequipped pet " + pet.name + ".[/color]")

# --- Apply / Remove item bonuses ---------------------------------------------
func _apply_bonuses(item) -> void:
	for key in item.bonuses:
		if "player_" + key in GameManager:
			GameManager["player_" + key] += item.bonuses[key]
		else:
			match key:
				"timer_reduce":
					global_timer_reduce += item.bonuses[key] / 100.0
				"xp_gain":
					player_xp_gain += item.bonuses[key] / 100.0
				"damage_reduce":
					damage_reduce += item.bonuses[key] / 100.0
				"hunt_timer_reduce":
					hunt_timer_reduce += item.bonuses[key] / 100.0
				"explore_drop_bonus":
					explore_drop_bonus += item.bonuses[key] / 100.0
				"recovery_boost":
					recovery_boost += item.bonuses[key] / 100.0
	GameManager.update_stats()

func _remove_bonuses(item) -> void:
	for key in item.bonuses:
		if "player_" + key in GameManager:
			GameManager["player_" + key] -= item.bonuses[key]
		else:
			match key:
				"timer_reduce":
					global_timer_reduce -= item.bonuses[key] / 100.0
				"xp_gain":
					player_xp_gain -= item.bonuses[key] / 100.0
				"damage_reduce":
					damage_reduce -= item.bonuses[key] / 100.0
				"hunt_timer_reduce":
					hunt_timer_reduce -= item.bonuses[key] / 100.0
				"explore_drop_bonus":
					explore_drop_bonus -= item.bonuses[key] / 100.0
				"recovery_boost":
					recovery_boost -= item.bonuses[key] / 100.0
	GameManager.update_stats()

# --- Durability / Repair ------------------------------------------------------
func apply_durability_loss() -> void:
	for slot in equipped:
		var item = equipped[slot]
		if item:
			item.durability -= 1
			if item.durability <= 0:
				if item.is_ethereal:
					equipped.erase(slot)
					GameManager.log_action("[color=#606060]Ethereal " + item.name + " vanished into the void![/color]")
				else:
					unequip(slot)

func repair(item) -> void:
	# item: EquipmentItem
	for entry in GameManager.inventory:
		if entry["item"].name == "Repair Kit":
			GameManager.remove_item(entry)
			item.durability = min(item.durability + 10, item.max_durability)
			GameManager.log_action("[color=#606060]Repaired " + item.name + " to " + str(item.durability) + "/" + str(item.max_durability) + ".[/color]")
			return
	GameManager.log_action("[color=#606060]No Repair Kit to repair " + item.name + ".[/color]")

# --- Sockets ------------------------------------------------------------------
func socket_item(target, socketable) -> void:
	# target: EquipmentItem, socketable: Gem or Glyph
	if target.sockets > target.socketed.size() and (socketable is Gem or socketable is Glyph):
		var is_equipped = equipped.has(target.slot)
		if is_equipped:
			_remove_bonuses(target)
		target.socketed.append(socketable)
		_apply_socket_bonus(target, socketable)
		if socketable is Glyph:
			_check_runeword(target)
		if is_equipped:
			_apply_bonuses(target)
		GameManager.remove_item_by_name(socketable.name, 1)
		GameManager.log_action("[color=#606060]Socketed " + socketable.name + " into " + target.name + ".[/color]")

func remove_socket(target) -> void:
	if target.socketed.size() > 0:
		var is_equipped = equipped.has(target.slot)
		if is_equipped:
			_remove_bonuses(target)
		var removed = target.socketed.pop_back()
		_remove_socket_bonus(target, removed)
		if is_equipped:
			_apply_bonuses(target)
		GameManager.add_item(removed)
		GameManager.log_action("[color=#606060]Removed " + removed.name + " from socket.[/color]")

func _apply_socket_bonus(target, socketable) -> void:
	if socketable is Gem:
		match socketable.gem_type:
			"Amethyst":
				target.bonuses["vitality"] = target.bonuses.get("vitality", 0) + socketable.bonus_value
			"Diamond":
				target.bonuses["strength"] = target.bonuses.get("strength", 0) + socketable.bonus_value
			"Emerald":
				target.bonuses["dexterity"] = target.bonuses.get("dexterity", 0) + socketable.bonus_value
			"Ruby":
				target.bonuses["endurance"] = target.bonuses.get("endurance", 0) + socketable.bonus_value
			"Sapphire":
				target.bonuses["intelligence"] = target.bonuses.get("intelligence", 0) + socketable.bonus_value
			"Topaz":
				target.bonuses["luck"] = target.bonuses.get("luck", 0) + socketable.bonus_value
			"Quartz":
				target.bonuses["timer_reduce"] = target.bonuses.get("timer_reduce", 0) + socketable.bonus_value
			"Skull":
				target.bonuses["luck"] = target.bonuses.get("luck", 0) + socketable.bonus_value
			"Skull":
				target.bonuses["focus"] = target.bonuses.get("focus", 0) + socketable.bonus_value
	# Glyph direct bonuses are applied via runewords in _check_runeword()

func _remove_socket_bonus(target, socketable) -> void:
	if socketable is Gem:
		match socketable.gem_type:
			"Amethyst":
				target.bonuses["vitality"] = target.bonuses.get("vitality", 0) - socketable.bonus_value
			"Diamond":
				target.bonuses["strength"] = target.bonuses.get("strength", 0) - socketable.bonus_value
			"Emerald":
				target.bonuses["dexterity"] = target.bonuses.get("dexterity", 0) - socketable.bonus_value
			"Ruby":
				target.bonuses["endurance"] = target.bonuses.get("endurance", 0) - socketable.bonus_value
			"Sapphire":
				target.bonuses["intelligence"] = target.bonuses.get("intelligence", 0) - socketable.bonus_value
			"Topaz":
				target.bonuses["luck"] = target.bonuses.get("luck", 0) + socketable.bonus_value
			"Quartz":
				target.bonuses["timer_reduce"] = target.bonuses.get("timer_reduce", 0) + socketable.bonus_value
			"Skull":
				target.bonuses["luck"] = target.bonuses.get("luck", 0) - socketable.bonus_value
			"Skull":
				target.bonuses["focus"] = target.bonuses.get("focus", 0) - socketable.bonus_value
	elif socketable is Glyph:
		_check_runeword(target) # re-evaluate runewords after glyph removal

func _check_runeword(target) -> void:
	var letters = []
	for s in target.socketed:
		if s is Glyph:
			letters.append(s.letter)
	var word = "".join(letters)
	var original_bonuses = target.bonuses.duplicate()
	match word:
		"Faith":
			for key in target.bonuses:
				target.bonuses[key] *= 2
		"Wrath":
			target.bonuses["endurance"] = target.bonuses.get("endurance", 0) + 10
			target.bonuses["agility"] = target.bonuses.get("agility", 0) + 10
			target.bonuses["focus"] = target.bonuses.get("focus", 0) + 10
		"Peace":
			target.bonuses["recovery_boost"] = target.bonuses.get("recovery_boost", 0) + 15
		"Storm":
			target.bonuses["timer_reduce"] = target.bonuses.get("timer_reduce", 0) + 20
	if original_bonuses != target.bonuses:
		GameManager.log_action("[color=#606060]Runeword " + word + " activated on " + target.name + ".[/color]")

# --- Set bonuses --------------------------------------------------------------
func _apply_set_bonuses() -> void:
	_remove_set_bonuses()
	active_set_bonuses.clear()

	var set_counts: Dictionary = {}
	for item in equipped.values():
		if item and item.item_set_name:
			set_counts[item.item_set_name] = set_counts.get(item.item_set_name, 0) + 1

	for equip_set_name in set_counts:
		var bonus: Dictionary = {}
		if _sets and _sets.has_method("get_set_bonus"):
			bonus = _sets.get_set_bonus(equip_set_name, set_counts[equip_set_name])
		# Merge into active_set_bonuses
		for key in bonus:
			active_set_bonuses[key] = active_set_bonuses.get(key, 0) + bonus[key]

	_apply_set_bonuses_to_player()
	GameManager.update_stats()

func _remove_set_bonuses() -> void:
	for key in active_set_bonuses:
		match key:
			"endurance":
				GameManager.player_endurance -= active_set_bonuses.get(key, 0)
			"strength":
				GameManager.player_strength -= active_set_bonuses.get(key, 0)
			"focus":
				GameManager.player_focus -= active_set_bonuses.get(key, 0)
			"intelligence":
				GameManager.player_intelligence -= active_set_bonuses.get(key, 0)
			"timer_reduce":
				global_timer_reduce -= active_set_bonuses.get(key, 0) / 100.0
			"vitality":
				GameManager.player_vitality -= active_set_bonuses.get(key, 0)
			"agility":
				GameManager.player_agility -= active_set_bonuses.get(key, 0)
			"dexterity":
				GameManager.player_dexterity -= active_set_bonuses.get(key, 0)
			"stamina_recovery":
				GameManager.player_stamina_recovery -= active_set_bonuses.get(key, 0)
			"luck":
				GameManager.player_luck -= active_set_bonuses.get(key, 0)
			"health_recovery":
				GameManager.player_health_recovery -= active_set_bonuses.get(key, 0)
			"damage_reduce":
				damage_reduce -= active_set_bonuses.get(key, 0) / 100.0
			"mana_recovery":
				GameManager.player_mana_recovery -= active_set_bonuses.get(key, 0)
			"hunt_timer_reduce":
				hunt_timer_reduce -= active_set_bonuses.get(key, 0) / 100.0
			"explore_drop_bonus":
				explore_drop_bonus -= active_set_bonuses.get(key, 0) / 100.0

func _apply_set_bonuses_to_player() -> void:
	for key in active_set_bonuses:
		match key:
			"endurance":
				GameManager.player_endurance += active_set_bonuses[key]
			"strength":
				GameManager.player_strength += active_set_bonuses[key]
			"focus":
				GameManager.player_focus += active_set_bonuses[key]
			"intelligence":
				GameManager.player_intelligence += active_set_bonuses[key]
			"timer_reduce":
				global_timer_reduce += active_set_bonuses[key] / 100.0
			"vitality":
				GameManager.player_vitality += active_set_bonuses[key]
			"agility":
				GameManager.player_agility += active_set_bonuses[key]
			"dexterity":
				GameManager.player_dexterity += active_set_bonuses[key]
			"stamina_recovery":
				GameManager.player_stamina_recovery += active_set_bonuses[key]
			"luck":
				GameManager.player_luck += active_set_bonuses[key]
			"health_recovery":
				GameManager.player_health_recovery += active_set_bonuses[key]
			"damage_reduce":
				damage_reduce += active_set_bonuses[key] / 100.0
			"mana_recovery":
				GameManager.player_mana_recovery += active_set_bonuses[key]
			"hunt_timer_reduce":
				hunt_timer_reduce += active_set_bonuses[key] / 100.0
			"explore_drop_bonus":
				explore_drop_bonus += active_set_bonuses[key] / 100.0
