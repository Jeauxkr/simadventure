# AlchemyManager.gd
extends Node
class_name AlchemyManager

const EFFECT_MAP: Dictionary = {
	"Restore Stamina": {"type": "instant", "stat": "stamina", "value": 50},
	"Increase Weapon Power": {"type": "temp", "stat": "strength", "value": 10, "duration": 30},
	"Speed": {"type": "temp", "stat": "agility", "value": 10, "duration": 30},
	"Restore Health": {"type": "instant", "stat": "health", "value": 50},
	"Invisible": {"type": "temp", "stat": "luck", "value": 10, "duration": 30},
	"Increase Spell Resist": {"type": "temp", "stat": "endurance", "value": 10, "duration": 30},
	"Unstoppable": {"type": "temp", "stat": "vitality", "value": 10, "duration": 30},
	"Increase Spell Power": {"type": "temp", "stat": "intelligence", "value": 10, "duration": 30},
	"Detection": {"type": "temp", "stat": "luck", "value": 10, "duration": 30},
	"Restore Magicka": {"type": "instant", "stat": "mana", "value": 50},
	"Weapon Crit": {"type": "temp", "stat": "dexterity", "value": 10, "duration": 30},
	"Protection": {"type": "temp", "stat": "endurance", "value": 10, "duration": 30},
	"Spell Crit": {"type": "temp", "stat": "focus", "value": 10, "duration": 30},
	"Vitality": {"type": "temp", "stat": "vitality", "value": 10, "duration": 30},
	"Lingering Health": {"type": "temp", "stat": "health_recovery", "value": 20, "duration": 30},
	"Sustained Restore Health": {"type": "temp", "stat": "health_recovery", "value": 10, "duration": 30},
	"Increase Armor": {"type": "temp", "stat": "endurance", "value": 10, "duration": 30}
}

func craft_base() -> void:
	if not GameManager:
		push_error("GameManager not found")
		return
	var potion = MundanePotion.new()
	if GameManager.add_item(potion):
		GameManager.player_alchemy += 1
		GameManager.log_action("[color=#606060]Crafted Mundane Potion.[/color]")

func craft_enchanted(plants: Array[Dictionary]) -> void:
	if not GameManager or plants.size() == 0:
		push_error("GameManager not found or no plants provided")
		return
	var combined_effects: Array[String] = []
	for plant_entry in plants:
		if plant_entry.get("item") is Plant:
			var plant = plant_entry["item"]
			combined_effects.append_array(plant.effects)
	combined_effects = unique(combined_effects)
	if combined_effects.size() == 0:
		return
	var pot = Potion.new("Enchanted", combined_effects)
# patched: initialize pot properties formerly passed to Potion.new("Enchanted", combined_effects)
	if GameManager.add_item(pot):
		GameManager.player_alchemy += 1
		GameManager.log_action("[color=#606060]Crafted Enchanted Potion with effects: " + ", ".join(combined_effects) + ".[/color]")

func unique(arr: Array[String]) -> Array[String]:
	var res: Array[String] = []
	for item in arr:
		if not res.has(item):
			res.append(item)
	return res
