extends Item
class_name EquipmentItem

@export var slot: String = ""
@export var bonuses: Dictionary = {}
@export var durability: int = 100
@export var max_durability: int = 100
@export var sockets: int = 0
@export var socketed: Array = []
@export var is_ethereal: bool = false
@export var extra_pet_slots: int = 0
@export var item_set_name: String = ""
@export var quality: String = "Common"

func _init(p_name: String = "Equipment", p_slot: String = "", p_quality: String = "Common"):
	super._init(p_name, "Equipment item of quality " + p_quality, 100, 1)
	slot = p_slot
	quality = p_quality
	name = "%s %s" % [p_quality, p_name]
	match p_quality:
		"Common":
			bonuses = {}
			sockets = 0
			durability = 100
			max_durability = 100
		"Uncommon":
			bonuses = {"endurance": 1}
			sockets = 1
			durability = 125
			max_durability = 125
		"Rare":
			bonuses = {"endurance": 3}
			sockets = 2
			durability = 150
			max_durability = 150
		"Epic":
			bonuses = {"endurance": 5, "strength": 3}
			sockets = 2
			durability = 175
			max_durability = 175
		"Legendary":
			bonuses = {"endurance": 8, "strength": 5, "timer_reduce": 10}
			sockets = 3
			durability = 200
			max_durability = 200



func get_description() -> String:
	var parts: Array[String] = []
	if item_set_name != "":
		parts.append("[i]Set:[/i] %s" % item_set_name)
	if bonuses.size() > 0:
		for k in bonuses.keys():
			var v = bonuses[k]
			var line := ""
			match k:
				"endurance": line = "+%d Endurance" % int(v)
				"agility": line = "+%d Agility" % int(v)
				"focus": line = "+%d Focus" % int(v)
				"strength": line = "+%d Strength" % int(v)
				"vitality": line = "+%d Vitality" % int(v)
				"intelligence": line = "+%d Intelligence" % int(v)
				"dexterity": line = "+%d Dexterity" % int(v)
				"crafting": line = "+%d Crafting" % int(v)
				"luck": line = "+%d Luck" % int(v)
				"fishing": line = "+%d Fishing" % int(v)
				"hunting": line = "+%d Hunting" % int(v)
				"field_dressing": line = "+%d Field Dressing" % int(v)
				"foraging": line = "+%d Foraging" % int(v)
				"alchemy": line = "+%d Alchemy" % int(v)
				"health_recovery": line = "+%d%% Health Recovery" % int(v)
				"mana_recovery": line = "+%d%% Mana Recovery" % int(v)
				"stamina_recovery": line = "+%d%% Stamina Recovery" % int(v)
				"timer_reduce": line = "-%d%% Action Time" % int(v)
				"global_timer_reduce": line = "-%d%% All Timers" % int(v)
				"hunt_timer_reduce": line = "-%d%% Hunt Time" % int(v)
				"explore_drop_bonus": line = "+%d%% Explore Drops" % int(v)
				"damage_reduce": line = "-%d%% Damage Taken" % int(v)
				_: line = "%s %+d" % [str(k).capitalize(), int(v)]
			if line != "":
				parts.append(line)
	if sockets > 0:
		parts.append("Sockets: %d" % sockets)
	parts.append("Durability: %d/%d" % [durability, max_durability])
	return "\n".join(parts)

func get_display_text() -> String:
	var qc = preload("res://scripts/QualityColors.gd")
	return qc.bb_name(name, quality)
