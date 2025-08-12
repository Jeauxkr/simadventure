extends Control

@onready var new_game_btn: Button = $Center/VBoxContainer/NewGame
@onready var load_game_btn: Button = $Center/VBoxContainer/LoadGame
@onready var options_btn: Button = $Center/VBoxContainer/Options

var selected_mode: String = "Endless"

func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game)
	load_game_btn.pressed.connect(_on_load_game)
	options_btn.pressed.connect(_on_options)

func _on_new_game() -> void:
	var dlg := PopupMenu.new()
	add_child(dlg)
	dlg.add_item("Endless", 0)
	dlg.add_item("Normal", 1)
	dlg.add_item("Hardcore", 2)
	dlg.id_pressed.connect(func(id: int):
		match id:
			0:
				selected_mode = "Endless"
			1:
				selected_mode = "Normal"
			2:
				selected_mode = "Hardcore"
		_show_slot_picker(true)
	)
	dlg.popup_centered()

func _show_slot_picker(is_new: bool) -> void:
	var pm := PopupMenu.new()
	add_child(pm)
	for i in range(1, SaveSystem.MAX_SLOTS+1):
		var meta: Dictionary = SaveSystem.get_slot_meta(i)
		var label := "Slot %d - " % i
		if meta.is_empty():
			label += "Empty"
		else:
			label += "Lv %d, %s, %s gold, %s" % [
				int(meta.get("level",1)),
				String(meta.get("mode","")),
				int(meta.get("gold",0)),
				String(meta.get("timestamp",""))
			]
		pm.add_item(label, i)
	pm.id_pressed.connect(func(slot_id: int):
		if is_new:
			_init_new_game_state(selected_mode)
			SaveSystem.save(int(slot_id))
			get_tree().change_scene_to_file("res://scenes/MainUI.tscn")
		else:
			if SaveSystem.load(int(slot_id)):
				get_tree().change_scene_to_file("res://scenes/MainUI.tscn")
	)
	pm.popup_centered()

func _init_new_game_state(mode: String) -> void:
	GameManager.mode = mode
	match mode:
		"Endless":
			GameManager.player_lives = 999999
		"Normal":
			GameManager.player_lives = 3
		"Hardcore":
			GameManager.player_lives = 1

	# Reset core stats
	GameManager.gold = 0
	GameManager.player_level = 1
	GameManager.player_xp = 0
	GameManager.player_health = GameManager.player_max_health
	GameManager.player_stamina = GameManager.player_max_stamina
	GameManager.player_mana = GameManager.player_max_mana

	# Clear inventory and locations
	GameManager.inventory.clear()
	GameManager.discovered_locations.clear()

	# Seed starter locations (3)
	var l1 := Location.new()
	l1.name = "Greenwood Forest"
	l1.description = "Old oaks, a clear stream, and game trails."
	l1.climate = "Temperate"
	l1.quality = "Common"
	l1.features = ["Forest","River"]
	l1.animal_list = ["Deer","Rabbit","Boar"]
	l1.fish_list = ["Trout","Perch"]
	l1.plant_list = ["Blue Mountain Flower","Healing Herb","Bitterroot"]
	l1.shops = ["General","Leatherworker","Quests"]
	l1.identifier = "[W]"
	GameManager.add_location(l1)

	var l2 := Location.new()
	l2.name = "Seabright Cove"
	l2.description = "Sheltered beach and weathered docks beside a fishing hamlet."
	l2.climate = "Coastal"
	l2.quality = "Uncommon"
	l2.features = ["Coast","Village"]
	l2.animal_list = ["Crab","Gull","Stray Dog"]
	l2.fish_list = ["Mackerel","Herring","Cod"]
	l2.plant_list = ["Kelp","Sea Lavender"]
	l2.shops = ["General","Blacksmith","Workshop","Alchemist","Quests","Jeweler"]
	l2.identifier = "[V]"
	GameManager.add_location(l2)

	var l3 := Location.new()
	l3.name = "Dustwind Foothills"
	l3.description = "Wind-swept hills and limestone caves rich with ore."
	l3.climate = "Arid"
	l3.quality = "Common"
	l3.features = ["Hills","Cave"]
	l3.animal_list = ["Goat","Wolf"]
	l3.fish_list = []
	l3.plant_list = ["Sage","Ironbloom"]
	l3.shops = []
	l3.identifier = "[W]"
	GameManager.add_location(l3)

	GameManager.current_location = l1

func _on_load_game() -> void:
	_show_slot_picker(false)

func _on_options() -> void:
	var d := AcceptDialog.new()
	d.dialog_text = "Options coming soon."
	add_child(d)
	d.popup_centered()
