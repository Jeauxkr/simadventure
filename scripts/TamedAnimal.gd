extends Item
class_name TamedAnimal

@export var bonuses: Dictionary = {}

func _init(_name: String = "Pet"):
	name = _name
	description = "A loyal companion that provides bonuses."
	value = 50
	stack_max = 1
	bonuses = _generate_bonuses()

func get_display_text() -> String:
	return "[b]" + name + "[/b] (Pet)"

func _generate_bonuses() -> Dictionary:
	var possible_bonuses = [
		"strength", "vitality", "dexterity", "luck", "explore_drop_bonus", "hunt_timer_reduce"
	]
	var result: Dictionary = {}
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var bonus_count = rng.randi_range(1, 2)
	for i in range(bonus_count):
		var stat = possible_bonuses[rng.randi() % possible_bonuses.size()]
		var bonus_value = rng.randi_range(5, 10)
		result[stat] = bonus_value
		possible_bonuses.erase(stat)
	return result
