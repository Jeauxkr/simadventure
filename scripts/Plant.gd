extends Item

class_name Plant

var effects: Array[String] = []

func _init(species: String):
	super._init(species, "Plant with effects", 10, 20)
	name = species
	effects = Plants.PLANTS.get(species, [])
	description = "Plant with effects: " + ", ".join(effects)
