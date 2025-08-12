extends Item
class_name Bag

var bag_capacity: int = 10
var quality: String = "Common"

func _init(q: String = "Common"):
	quality = q
	name = q + " Bag"
	description = "Increases inventory capacity."
	match q:
		"Common":
			bag_capacity = 10
		"Uncommon":
			bag_capacity = 50
		"Rare":
			bag_capacity = 100
		"Epic":
			bag_capacity = 150
		"Legendary":
			bag_capacity = 200
