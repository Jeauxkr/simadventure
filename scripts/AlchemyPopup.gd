# AlchemyPopup.gd
extends Popup
class_name AlchemyPopup

var base_slot: Label = Label.new()
var plant_slots: Array[Label] = [Label.new(), Label.new(), Label.new()]
var current_base: Dictionary = {}
var current_plants: Array = [null, null, null]

func _ready() -> void:
	if not GameManager:
		push_error("GameManager not found")
		return
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	var alchemy_label = Label.new()
	alchemy_label.text = "Alchemy Crafting"
	vbox.add_child(alchemy_label)
	
	var base_btn = Button.new()
	base_btn.text = "Select Base (Mundane Potion)"
	base_btn.pressed.connect(_select_base)
	vbox.add_child(base_btn)
	
	base_slot.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(base_slot)
	
	for i in 3:
		var plant_btn = Button.new()
		plant_btn.text = "Select Plant " + str(i + 1)
		plant_btn.pressed.connect(_select_plant.bind(i))
		vbox.add_child(plant_btn)
		plant_slots[i].custom_minimum_size = Vector2(200, 0)
		vbox.add_child(plant_slots[i])
	
	var craft_btn = Button.new()
	craft_btn.text = "Craft Potion"
	craft_btn.pressed.connect(_craft)
	vbox.add_child(craft_btn)

func _select_base() -> void:
	for entry in GameManager.inventory:
		if entry["item"] is MundanePotion:
			current_base = entry
			base_slot.text = entry["item"].name
			break

func _select_plant(slot: int) -> void:
	for entry in GameManager.inventory:
		if entry["item"] is Plant and not current_plants.has(entry):
			current_plants[slot] = entry
			plant_slots[slot].text = entry["item"].name
			break

func _craft() -> void:
	if current_base.size() == 0 or current_plants.all(func(p): return p == null):
		GameManager.log_action("[color=#606060]Need base and at least 1 plant.[/color]")
		return
	GameManager.current_base = current_base
	GameManager.current_plants = current_plants.filter(func(p): return p != null)
	GameManager.start_action(GameManager.current_location, "Craft Potion")
	queue_free()
