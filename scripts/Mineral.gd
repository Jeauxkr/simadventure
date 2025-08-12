extends Resource
class_name Mineral

var name: String = ""
var category: String = "" # "Metal","Stone","Gem"
var rarity: String = "Common"
var stack_max: int = 99

static func from_values(_name: String, _category: String, _rarity: String) -> Mineral:
	var m := Mineral.new()
	m.name = _name
	m.category = _category
	m.rarity = _rarity
	return m

static func random_mineral(rng: RandomNumberGenerator, _category: String, _rarity: String) -> Mineral:
	var metals = ["Iron Ore","Copper Ore","Tin Ore","Silver Ore","Gold Ore"]
	var stones = ["Stone","Limestone","Granite","Clay","Sandstone"]
	var gems = ["Chipped Ruby","Chipped Sapphire","Chipped Emerald","Chipped Topaz","Chipped Amethyst"]
	var pool: Array = []
	match _category:
		"Metal": pool = metals
		"Stone": pool = stones
		"Gem": pool = gems
		_: pool = metals
	var idx = rng.randi_range(0, pool.size() - 1)
	return from_values(pool[idx], _category, _rarity)

func get_display_text() -> String:
	return QualityColors.bb_name(name, rarity)
