extends Button

func _pressed():
	for i in range(3):
		var loc = Location.new()
		loc.name = "Test Location " + str(i+1)
		loc.description = "Test desc"
		loc.climate = "Mild"
		loc.features = ["River"]
		loc.animal_list = ["Deer"]
		loc.fish_list = ["Trout"]
		loc.plant_list = ["Blue Mountain Flower"]
		GameManager.add_item(loc)
	GameManager.log_action("Added test maps.")
