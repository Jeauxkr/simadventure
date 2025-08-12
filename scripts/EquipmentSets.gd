extends Node
func get_set_bonus(p_set_name: String, count: int) -> Dictionary:
	var bonus: Dictionary = {}
	match p_set_name:
		"Warrior's Resolve":
			if count >= 2:
				bonus["strength"] = bonus.get("strength", 0) + 5
				bonus["endurance"] = bonus.get("endurance", 0) + 5
			if count >= 4:
				bonus["damage_reduce"] = bonus.get("damage_reduce", 0) + 10
		"Mystic's Insight":
			if count >= 2:
				bonus["intelligence"] = bonus.get("intelligence", 0) + 5
				bonus["mana_recovery"] = bonus.get("mana_recovery", 0) + 2
			if count >= 3:
				bonus["timer_reduce"] = bonus.get("timer_reduce", 0) + 15
		"Hunter's Grace":
			if count >= 2:
				bonus["agility"] = bonus.get("agility", 0) + 5
				bonus["hunt_timer_reduce"] = bonus.get("hunt_timer_reduce", 0) + 10
			if count >= 4:
				bonus["explore_drop_bonus"] = bonus.get("explore_drop_bonus", 0) + 20
		"Frostwarden":
			if count >= 2:
				bonus["vitality"] = bonus.get("vitality", 0) + 5
				bonus["health_recovery"] = bonus.get("health_recovery", 0) + 5
			if count >= 3:
				bonus["endurance"] = bonus.get("endurance", 0) + 5
			if count >= 4:
				bonus["damage_reduce"] = bonus.get("damage_reduce", 0) + 10
		"Sandstrider":
			if count >= 2:
				bonus["dexterity"] = bonus.get("dexterity", 0) + 5
			if count >= 3:
				bonus["gather_timer_reduce"] = bonus.get("gather_timer_reduce", 0) + 10
			if count >= 4:
				bonus["stamina_recovery"] = bonus.get("stamina_recovery", 0) + 10
		"Stormcaller":
			if count >= 2:
				bonus["intelligence"] = bonus.get("intelligence", 0) + 5
			if count >= 3:
				bonus["fish_timer_reduce"] = bonus.get("fish_timer_reduce", 0) + 10
			if count >= 4:
				bonus["xp_gain"] = bonus.get("xp_gain", 0) + 10
		_:
			pass
	return bonus
