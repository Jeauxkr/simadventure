# Potion.gd
class_name Potion
extends Item

var potion_type: String = ""
var effects: Array[String] = []

func _init(p_type: String, p_effects: Array[String] = []):
	potion_type = p_type
	effects = p_effects
	name = p_type + " Potion"
	description = "Potion with effects: " + ", ".join(effects) if effects.size() > 0 else "Potion with no effects"

func use():
	if not GameManager:
		return
	for effect in effects:
		var data = Alchemy.EFFECT_MAP.get(effect, {})
		if data.is_empty() or not data.has_all(["type", "stat", "value"]):
			continue
		if data["type"] == "instant":
			var stat = "player_" + data["stat"]
			var max_stat = "player_max_" + data["stat"]
			if stat in GameManager and max_stat in GameManager:
				GameManager[stat] = min(GameManager[stat] + data["value"], GameManager[max_stat])
		elif data["type"] == "temp" and data.has("duration"):
			GameManager.add_temp_bonus(data["stat"], data["value"], data["duration"])
	GameManager.log_action("[color=#606060]Used " + name + ".[/color]")


func get_display_text() -> String:
	return name
