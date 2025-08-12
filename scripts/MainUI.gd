extends Control

const ShopPopupClass = preload("res://scripts/ShopPopup.gd")

@onready var inventory_vbox: VBoxContainer = $InventoryPanel/InventorySubPanel/InventoryScrollContainer/InventoryVBox
@onready var gold_label: RichTextLabel = $InventoryPanel/Gold
@onready var backpack_slots_label: RichTextLabel = $InventoryPanel/BackpackSlots
@onready var backpack_button: RichTextLabel = $InventoryPanel/BackpackButton
@onready var buy_button: Button = $InventoryPanel/BuyButton
@onready var sell_button: Button = $InventoryPanel/SellButton
@onready var level_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/CharacterLevel
@onready var xp_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Experience
@onready var health_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Health
@onready var stamina_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Stamina
@onready var mana_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Mana
@onready var endurance_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Endurance
@onready var agility_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Agility
@onready var focus_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Focus
@onready var strength_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Strength
@onready var vitality_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Vitality
@onready var intelligence_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Intelligence
@onready var dexterity_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Dexterity
@onready var crafting_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Crafting
@onready var luck_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Luck
@onready var fishing_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Fishing
@onready var hunting_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Hunting
@onready var woodcutting_label: RichTextLabel = get_node("CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/Woodcutting")
@onready var field_dressing_label: RichTextLabel = $CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox/FieldDressing
@onready var feed_text: RichTextLabel = $FeedPanel/FeedSubPanel/FeedScrollContainer/FeedText
@onready var feed_scroll: ScrollContainer = (feed_text.get_parent() as ScrollContainer)
@onready var location_vbox: VBoxContainer = $LocationPanel/LocationSubPanel/LocationScrollContainer/LocationVBox
@onready var location_desc: RichTextLabel = $LocationPanel/DescriptionSubPanel/DescriptionScrollContainer/DescriptionVBox/DescriptionInput
@onready var context_menu: PopupMenu = $ContextMenu
@onready var timer_bar: ProgressBar = $TimerPanel/TimerBar
@onready var action_display: RichTextLabel = $TimerPanel/ActionDisplay
@onready var equipment_vbox: VBoxContainer = $Equipment/Equipment/EquipmentScrollContainer/EquipmentVBox
@onready var quest_vbox: VBoxContainer = $Equipment/QuestPanel/QuestScroll/quest_vbox

var current_selected_item: Dictionary = {}
var current_selected_location = null
var current_selected_slot: String = ""
var action_duration: float = 0.0
var confirm_dialog: ConfirmationDialog
var current_confirm_type: String = ""
var current_confirm_item: Dictionary = {}
var current_confirm_count: int = 0
var tooltip_popup: PopupPanel
var tooltip_label: RichTextLabel
var prev_stats: Dictionary = {}

func _ready():
	_tune_stat_labels_for_scroll()
	print("quest_vbox: ", quest_vbox)
	if backpack_button:
		backpack_button.text = "No Bag Equipped"
		backpack_button.gui_input.connect(_on_backpack_gui_input)
	if buy_button:
		buy_button.pressed.connect(_on_buy_pressed)
	if sell_button:
		sell_button.pressed.connect(_on_sell_pressed)
	# Ensure built-in signal connections exist without duplicating them.  The
	# scene (.tscn) file already connects `id_pressed` from ContextMenu and
	# `timeout` from ActionTimer to their respective handlers.  When running
	# this script at runtime we guard against duplicate connections by
	# checking with `is_connected` before connecting.  The old signal API
	# accepts the target object and method name as arguments.
	if context_menu:
		if not context_menu.is_connected("id_pressed", Callable(self, "_on_ContextMenu_id_pressed")):
			context_menu.id_pressed.connect(_on_ContextMenu_id_pressed)
	if has_node("TimerPanel/ActionTimer"):
		var action_timer = $TimerPanel/ActionTimer
		if not action_timer.is_connected("timeout", Callable(self, "_on_action_timer_timeout")):
			action_timer.timeout.connect(_on_action_timer_timeout)
	confirm_dialog = ConfirmationDialog.new()
	add_child(confirm_dialog)
	confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	confirm_dialog.canceled.connect(_on_confirm_dialog_canceled)
	if equipment_vbox:
		for child in equipment_vbox.get_children():
			if child.name != "MainHand2":
				child.gui_input.connect(_on_equipment_gui_input.bind(child.name))
	tooltip_popup = PopupPanel.new()
	add_child(tooltip_popup)
	tooltip_label = RichTextLabel.new()
	tooltip_label.bbcode_enabled = true
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label.fit_content = true
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.custom_minimum_size = Vector2(200, 0)
	tooltip_popup.add_child(tooltip_label)
	var stat_labels = {
		"endurance": endurance_label,
		"agility": agility_label,
		"focus": focus_label,
		"strength": strength_label,
		"vitality": vitality_label,
		"intelligence": intelligence_label,
		"dexterity": dexterity_label,
		"crafting": crafting_label,
		"luck": luck_label,
		"fishing": fishing_label,
		"hunting": hunting_label,
		"woodcutting": woodcutting_label,
		"field_dressing": field_dressing_label,
		"health": health_label,
		"stamina": stamina_label,
		"mana": mana_label
	}
	for stat in stat_labels:
		if stat_labels[stat]:
			stat_labels[stat].mouse_entered.connect(_show_stat_tooltip.bind(stat))
			stat_labels[stat].mouse_exited.connect(_hide_tooltip)
	if GameManager:
		GameManager.inventory_updated.connect(update_ui)
		GameManager.action_log_updated.connect(update_ui)
	call_deferred("update_ui")
	_update_prev_stats()

func _process(_delta):
	if GameManager and GameManager.current_action:
		var remaining = GameManager.action_timer.time_left
		timer_bar.value = (action_duration - remaining) / action_duration * 100
	else:
		timer_bar.value = 0

func _update_prev_stats():
	if not GameManager:
		return
	prev_stats = {
		"endurance": GameManager.player_endurance,
		"agility": GameManager.player_agility,
		"focus": GameManager.player_focus,
		"strength": GameManager.player_strength,
		"vitality": GameManager.player_vitality,
		"intelligence": GameManager.player_intelligence,
		"dexterity": GameManager.player_dexterity,
		"crafting": GameManager.player_crafting,
		"luck": GameManager.player_luck,
		"fishing": GameManager.player_fishing,
		"hunting": GameManager.player_hunting,
		"woodcutting": GameManager.player_woodcutting,
		"field_dressing": GameManager.player_field_dressing,
		"health": GameManager.player_health,
		"stamina": GameManager.player_stamina,
		"mana": GameManager.player_mana
	}

func _flash_label(label: RichTextLabel, color: String):
	if not label:
		return
	var tween = create_tween()
	tween.tween_property(label, "modulate", Color(color), 0.2)
	tween.tween_property(label, "modulate", Color.WHITE, 0.2)
	tween.tween_property(label, "modulate", Color(color), 0.2)
	tween.tween_property(label, "modulate", Color.WHITE, 0.2)

func _get_stat_bonuses(stat: String) -> int:
	var total_bonus = 0
	if EquipmentManager:
		for slot in EquipmentManager.equipped:
			var item = EquipmentManager.equipped[slot]
			if item and item.bonuses.has(stat):
				total_bonus += item.bonuses[stat]
			for socket in item.socketed:
				if socket is Gem and socket.gem_type.to_lower() == stat:
					total_bonus += socket.bonus_value
	if GameManager and GameManager.active_potion_effects.has(stat):
		total_bonus += GameManager.active_potion_effects[stat]
	return total_bonus

func update_ui():
	if not inventory_vbox:
		return
	for child in inventory_vbox.get_children():
		child.queue_free()
	var player_title = RichTextLabel.new()
	player_title.text = "- Player Inventory -"
	inventory_vbox.add_child(player_title)
	for entry in GameManager.inventory:
		var item_label = RichTextLabel.new()
		item_label.bbcode_enabled = true
		var text = entry["item"].get_display_text()
		if entry["count"] > 1:
			text += " (x" + str(entry["count"]) + ")"
		item_label.text = text
		item_label.fit_content = true
		item_label.scroll_active = false
		item_label.selection_enabled = true
		item_label.gui_input.connect(_on_item_gui_input.bind(entry, "player"))
		item_label.mouse_entered.connect(_show_tooltip.bind(entry["item"]))
		item_label.mouse_exited.connect(_hide_tooltip)
		inventory_vbox.add_child(item_label)
	if current_selected_location and current_selected_location.has_camp:
		var camp_title = RichTextLabel.new()
		camp_title.text = "- Camp Storage -"
		inventory_vbox.add_child(camp_title)
		var camp_inv = GameManager.camp_inventories.get(current_selected_location, [])
		for entry in camp_inv:
			var item_label = RichTextLabel.new()
			item_label.bbcode_enabled = true
			var text = entry["item"].get_display_text()
			if entry["count"] > 1:
				text += " (x" + str(entry["count"]) + ")"
			item_label.text = text
			item_label.fit_content = true
			item_label.scroll_active = false
			item_label.selection_enabled = true
			item_label.gui_input.connect(_on_item_gui_input.bind(entry, "camp"))
			item_label.mouse_entered.connect(_show_tooltip.bind(entry["item"]))
			item_label.mouse_exited.connect(_hide_tooltip)
			inventory_vbox.add_child(item_label)
	gold_label.text = "Gold: " + str(GameManager.gold)
	var used = GameManager.inventory.size()
	backpack_slots_label.text = "Space: " + str(used) + " / " + str(GameManager.inventory_capacity)
	if GameManager.equipped_bag:
		backpack_button.text = GameManager.equipped_bag.name
	else:
		backpack_button.text = "No Bag Equipped"
	var stats = {
		"endurance": [endurance_label, GameManager.player_endurance, "Endurance"],
		"agility": [agility_label, GameManager.player_agility, "Agility"],
		"focus": [focus_label, GameManager.player_focus, "Focus"],
		"strength": [strength_label, GameManager.player_strength, "Strength"],
		"vitality": [vitality_label, GameManager.player_vitality, "Vitality"],
		"intelligence": [intelligence_label, GameManager.player_intelligence, "Intelligence"],
		"dexterity": [dexterity_label, GameManager.player_dexterity, "Dexterity"],
		"crafting": [crafting_label, GameManager.player_crafting, "Crafting"],
		"luck": [luck_label, GameManager.player_luck, "Luck"],
		"fishing": [fishing_label, GameManager.player_fishing, "Fishing"],
		"hunting": [hunting_label, GameManager.player_hunting, "Hunting"],
		"field_dressing": [field_dressing_label, GameManager.player_field_dressing, "Field Dressing"],
		"health": [health_label, GameManager.player_health, "Health", GameManager.player_max_health],
		"stamina": [stamina_label, GameManager.player_stamina, "Stamina", GameManager.player_max_stamina],
		"mana": [mana_label, GameManager.player_mana, "Mana", GameManager.player_max_mana]
	}
	for stat in stats:
		var label = stats[stat][0]
		var value = stats[stat][1]
		var stat_name = stats[stat][2]
		var max_value = stats[stat][3] if stats[stat].size() > 3 else null
		var bonus = _get_stat_bonuses(stat)
		var color = "[color=lightblue]" if bonus > 0 else ""
		var text = stat_name + ": " + str(value)
		if max_value != null:
			text += " / " + str(max_value)
		if bonus > 0:
			text = color + text + "[/color]"
		label.text = text
		if prev_stats.has(stat) and prev_stats[stat] != value:
			if value < prev_stats[stat]:
				_flash_label(label, "red")
			elif value > prev_stats[stat]:
				_flash_label(label, "green")
	level_label.text = "Level: " + str(GameManager.player_level)
	xp_label.text = "Experience: " + str(GameManager.player_xp) + "/100"
	var _follow = _is_feed_at_bottom()
	feed_text.text = "\n".join(GameManager.action_log)
	if _follow:
		call_deferred("_scroll_feed_to_bottom")
	if location_vbox:
		for child in location_vbox.get_children():
			child.queue_free()
		for loc in GameManager.discovered_locations:
			var loc_label = RichTextLabel.new()
			loc_label.bbcode_enabled = true
			loc_label.text = loc.get_display_text()
			loc_label.fit_content = true
			loc_label.scroll_active = false
			loc_label.selection_enabled = true
			loc_label.gui_input.connect(_on_location_gui_input.bind(loc))
			location_vbox.add_child(loc_label)
	if current_selected_location:
		location_desc.text = current_selected_location.description
	else:
		location_desc.text = "No location selected."
	if GameManager.current_action:
		action_display.text = GameManager.current_action_type + "..."
	else:
		action_display.text = "No action"
	if equipment_vbox:
		for child in equipment_vbox.get_children():
			var slot = child.name
			if EquipmentManager.equipped.has(slot):
				child.text = slot + ": " + EquipmentManager.equipped[slot].get_display_text()
			else:
				child.text = slot + ":"
	if quest_vbox:
		for child in quest_vbox.get_children():
			child.queue_free()
		var quest_title = RichTextLabel.new()
		quest_title.text = "- Active Quests -"
		quest_vbox.add_child(quest_title)
		for quest in GameManager.active_quests:
			var quest_label = RichTextLabel.new()
			quest_label.bbcode_enabled = true
			quest_label.text = quest.get_display_text()
			quest_label.fit_content = true
			quest_label.scroll_active = false
			quest_label.selection_enabled = true
			quest_label.mouse_entered.connect(_show_tooltip.bind(quest))
			quest_label.mouse_exited.connect(_hide_tooltip)
			quest_vbox.add_child(quest_label)
	else:
		print("Error: quest_vbox is null")
	_update_prev_stats()

func _on_item_gui_input(event: InputEvent, entry: Dictionary, inventory_type: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		current_selected_item = entry
		current_selected_location = null
		context_menu.clear()
		var item = entry["item"]
		if item is Location:
			context_menu.add_item("Add Map", 0)
		elif item is Animal:
			context_menu.add_item("Skin and Dress", 3)
		elif item is Fish:
			context_menu.add_item("Fillet Fish", 4)
		elif item is Potion:
			context_menu.add_item("Use Potion", 5)
		elif item is QuestNote:
			context_menu.add_item("Use Note", 19)
		elif item is EquipmentItem:
			context_menu.add_item("Equip", 11)
		elif item is Bag:
			context_menu.add_item("Equip Bag", 15)
		if entry["count"] == 1:
			context_menu.add_item("Sell", 6)
		else:
			context_menu.add_item("Sell One", 7)
			context_menu.add_item("Sell All", 8)
		if current_selected_location and current_selected_location.has_camp:
			if inventory_type == "player":
				context_menu.add_item("Store in Camp", 9)
			elif inventory_type == "camp":
				context_menu.add_item("Take from Camp", 10)
		context_menu.reset_size()
		context_menu.popup()
		context_menu.position = get_global_mouse_position()

func _on_location_gui_input(event: InputEvent, loc: Location):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			current_selected_location = loc
			update_ui()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			current_selected_item = {}
			current_selected_location = loc
			context_menu.clear()
			context_menu.add_item("Explore", 0)
			if loc.animal_list.size() > 0:
				context_menu.add_item("Hunt", 1)
			if "River" in loc.features or "Lake" in loc.features or "Sea" in loc.features:
				context_menu.add_item("Fish", 2)
			context_menu.add_item("Gather Water", 18)
			if loc.plant_list.size() > 0:
				context_menu.add_item("Harvest", 17)
			if not loc.has_camp:
				context_menu.add_item("Build Camp", 3)
			if loc.bonuses.has("quest"):
				context_menu.add_item("Quest", 20)
			if loc.identifier == "[V]":
				if loc.shops.has("Blacksmith"):
					context_menu.add_item("Visit Blacksmith", 21)
				if loc.shops.has("Forge"):
					context_menu.add_item("Visit Forge", 22)
				if loc.shops.has("Leatherworker"):
					context_menu.add_item("Visit Leatherworker", 23)
				if loc.shops.has("Workshop"):
					context_menu.add_item("Visit Workshop", 24)
				if loc.shops.has("Alchemist"):
					context_menu.add_item("Visit Alchemist", 25)
				if loc.shops.has("Quests"):
					context_menu.add_item("Visit Quests", 26)
				if loc.shops.has("Jeweler"):
					context_menu.add_item("Visit Jeweler", 27)
			if "Cave" in loc.features:
				context_menu.add_item("Enter Cave", 4)
			if "Dungeon" in loc.features:
				context_menu.add_item("Enter Dungeon", 5)
			if "Trial" in loc.features:
				context_menu.add_item("Enter Trial", 6)
			context_menu.reset_size()
			context_menu.popup()
			context_menu.position = get_global_mouse_position()

func _on_equipment_gui_input(event: InputEvent, slot: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if EquipmentManager.equipped.has(slot):
			current_selected_slot = slot
			context_menu.clear()
			context_menu.add_item("Unequip", 12)
			if EquipmentManager.equipped[slot].durability < EquipmentManager.equipped[slot].max_durability:
				context_menu.add_item("Repair", 13)
			if EquipmentManager.equipped[slot].socketed.size() > 0:
				context_menu.add_item("Remove Socket", 14)
			context_menu.reset_size()
			context_menu.popup()
			context_menu.position = get_global_mouse_position()

func _on_backpack_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if GameManager.equipped_bag:
			context_menu.clear()
			context_menu.add_item("Unequip Bag", 16)
			context_menu.reset_size()
			context_menu.popup()
			context_menu.position = get_global_mouse_position()

func _on_buy_pressed():
	var shop = ShopPopupClass.new()
	if shop.has_method("configure"):
		shop.configure("General", null)
	shop.popup_centered()
	shop.popup_centered()

func _on_sell_pressed():
	if current_selected_item.size() > 0:
		current_confirm_type = "sell"
		current_confirm_item = current_selected_item
		current_confirm_count = 1
		var _nm = current_confirm_item["item"].name
		var _tot = current_confirm_item["item"].value * current_confirm_count
		confirm_dialog.dialog_text = "Sell '%s' for %d gold?" % [_nm, _tot]
		confirm_dialog.popup_centered()


func _on_confirm_dialog_confirmed():
	if current_confirm_type == "sell":
		if GameManager.remove_item(current_confirm_item, false, current_confirm_count):
			GameManager.gold += current_confirm_item["item"].value * current_confirm_count
			GameManager.log_action("[color=#606060]Sold " + str(current_confirm_count) + "x " + current_confirm_item["item"].name + " for " + str(current_confirm_item["item"].value * current_confirm_count) + " gold.[/color]")
	current_confirm_item = {}
	current_confirm_count = 0
	current_confirm_type = ""
	update_ui()

func _on_confirm_dialog_canceled():
	current_confirm_item = {}
	current_confirm_count = 0
	current_confirm_type = ""

func _on_action_timer_timeout():
	if GameManager:
		GameManager.current_action = false
		action_display.text = "No action"
		timer_bar.value = 0
		update_ui()
func _on_ContextMenu_id_pressed(id: int) -> void:
	match id:
		0: # Add Map / Explore
			if current_selected_item.size() > 0 and current_selected_item["item"] is Location:
				GameManager.add_location(current_selected_item["item"])
				GameManager.remove_item(current_selected_item, false, 1)
			elif current_selected_location:
				GameManager.start_action(current_selected_location, "Explore")
				action_duration = GameManager.action_duration
		1: # Hunt
			if current_selected_location:
				GameManager.start_action(current_selected_location, "Hunt")
				action_duration = GameManager.action_duration
		2: # Fish
			if current_selected_location:
				GameManager.start_action(current_selected_location, "Fish")
				action_duration = GameManager.action_duration
		3: # Skin and Dress (item) / Build Camp (location)
			if current_selected_item.size() > 0 and current_selected_item["item"] is Animal:
				GameManager.start_action(null, "Skin", current_selected_item)
				action_duration = GameManager.action_duration
			elif current_selected_location and not current_selected_location.has_camp:
				GameManager.start_action(current_selected_location, "Build Camp")
				action_duration = GameManager.action_duration
		4: # Fillet Fish (item) / Enter Cave (location)
			if current_selected_item.size() > 0 and current_selected_item["item"] is Fish:
				GameManager.start_action(null, "Fillet", current_selected_item)
				action_duration = GameManager.action_duration
			elif current_selected_location:
				GameManager.start_action(current_selected_location, "Cave")
				action_duration = GameManager.action_duration
		5: # Use Potion (item) / Enter Dungeon (location)
			if current_selected_item.size() > 0 and current_selected_item["item"] is Potion:
				GameManager.use_potion(current_selected_item["item"])
				GameManager.remove_item(current_selected_item, false, 1)
			elif current_selected_location:
				GameManager.start_action(current_selected_location, "Dungeon")
				action_duration = GameManager.action_duration
		6: # Sell (item) / Enter Trial (location)
			if current_selected_location and "Trial" in current_selected_location.features:
				GameManager.start_action(current_selected_location, "Trial")
				action_duration = GameManager.action_duration
			elif current_selected_item.size() > 0:
				current_confirm_type = "sell"
				current_confirm_item = current_selected_item
				current_confirm_count = 1
				var _nm = current_confirm_item["item"].name
				var _tot = current_confirm_item["item"].value * current_confirm_count
				confirm_dialog.dialog_text = "Sell '%s' for %d gold?" % [_nm, _tot]
				confirm_dialog.popup_centered()
		7: # Sell One
			if current_selected_item.size() > 0:
				current_confirm_type = "sell"
				current_confirm_item = current_selected_item
				current_confirm_count = 1
				var _nm2 = current_confirm_item["item"].name
				var _tot2 = current_confirm_item["item"].value * current_confirm_count
				confirm_dialog.dialog_text = "Sell '%s' for %d gold?" % [_nm2, _tot2]
				confirm_dialog.popup_centered()
		8: # Sell All
			if current_selected_item.size() > 0:
				current_confirm_type = "sell"
				current_confirm_item = current_selected_item
				current_confirm_count = current_selected_item["count"]
				var _nm3 = current_confirm_item["item"].name
				var _tot3 = current_confirm_item["item"].value * current_confirm_count
				confirm_dialog.dialog_text = "Sell %dx '%s' for %d gold?" % [current_confirm_count, _nm3, _tot3]
				confirm_dialog.popup_centered()
		9: # Store in Camp
			if current_selected_item.size() > 0 and current_selected_location and current_selected_location.has_camp:
				GameManager.move_to_camp(current_selected_item)
		10: # Take from Camp
			if current_selected_item.size() > 0 and current_selected_location and current_selected_location.has_camp:
				GameManager.move_from_camp(current_selected_item)
		11: # Equip (equipment item)
			if current_selected_item.size() > 0 and current_selected_item["item"] is EquipmentItem:
				EquipmentManager.equip(current_selected_item["item"])
				GameManager.remove_item(current_selected_item, false, 1)
		12: # Unequip (slot)
			if current_selected_slot != "":
				EquipmentManager.unequip(current_selected_slot)
		13: # Repair (slot)
			if current_selected_slot != "" and EquipmentManager.equipped.has(current_selected_slot):
				GameManager.repair_item(current_selected_slot)
		14: # Remove Socket (equipped item in slot)
			if current_selected_slot != "" and EquipmentManager.equipped.has(current_selected_slot):
				EquipmentManager.remove_socket(EquipmentManager.equipped[current_selected_slot])
		15: # Equip Bag
			if current_selected_item.size() > 0 and current_selected_item["item"] is Bag:
				GameManager.equip_bag(current_selected_item["item"])
				GameManager.remove_item(current_selected_item, false, 1)
		16: # Unequip Bag
			if GameManager.equipped_bag:
				GameManager.unequip_bag()
		17: # Harvest
			if current_selected_location:
				GameManager.start_action(current_selected_location, "Harvest")
				action_duration = GameManager.action_duration
		18: # Gather Water
			if current_selected_location:
				GameManager.start_action(current_selected_location, "Gather Water")
				action_duration = GameManager.action_duration
		19: # Use Note
			if current_selected_item.size() > 0 and current_selected_item["item"] is QuestNote:
				GameManager.use_note(current_selected_item["item"])
				GameManager.remove_item(current_selected_item, false, 1)
		20: # Quest browser (from location)
			if current_selected_location and current_selected_location.bonuses.has("quest"):
				GameManager.start_action(current_selected_location, "Quest")
				action_duration = GameManager.action_duration
		21: # Visit Blacksmith
			if current_selected_location and current_selected_location.shops.has("Blacksmith"):
				var shop = ShopPopupClass.new()
				if shop.has_method("configure"):
					shop.configure("Blacksmith", current_selected_location)
				self.add_child(shop)
				shop.popup_centered()
		22: # Visit Forge
			if current_selected_location and current_selected_location.shops.has("Forge"):
				var shop2 = ShopPopupClass.new()
				if shop2.has_method("configure"):
					shop2.configure("Forge", current_selected_location)
				self.add_child(shop2)
				shop2.popup_centered()
		23: # Visit Leatherworker
			if current_selected_location and current_selected_location.shops.has("Leatherworker"):
				var shop3 = ShopPopupClass.new()
				if shop3.has_method("configure"):
					shop3.configure("Leatherworker", current_selected_location)
				self.add_child(shop3)
				shop3.popup_centered()
		24: # Visit Workshop
			if current_selected_location and current_selected_location.shops.has("Workshop"):
				var shop4 = ShopPopupClass.new()
				if shop4.has_method("configure"):
					shop4.configure("Workshop", current_selected_location)
				self.add_child(shop4)
				shop4.popup_centered()
		25: # Visit Alchemist
			if current_selected_location and current_selected_location.shops.has("Alchemist"):
				var shop5 = ShopPopupClass.new()
				if shop5.has_method("configure"):
					shop5.configure("Alchemist", current_selected_location)
				self.add_child(shop5)
				shop5.popup_centered()
		26: # Visit Quests
			if current_selected_location and current_selected_location.shops.has("Quests"):
				var shop6 = ShopPopupClass.new()
				if shop6.has_method("configure"):
					shop6.configure("Quests", current_selected_location)
				self.add_child(shop6)
				shop6.popup_centered()
		27: # Visit Jeweler
			if current_selected_location and current_selected_location.shops.has("Jeweler"):
				var shop7 = ShopPopupClass.new()
				if shop7.has_method("configure"):
					shop7.configure("Jeweler", current_selected_location)
				self.add_child(shop7)
				shop7.popup_centered()
	update_ui()

func _show_stat_tooltip(stat: String):
	tooltip_label.text = "[b]" + stat.capitalize() + "[/b]\nBonus: +" + str(_get_stat_bonuses(stat))
	tooltip_popup.position = Vector2i(get_global_mouse_position() + Vector2(10, 10))
	tooltip_popup.popup()

func _show_tooltip(item: Item) -> void:
	var desc_text: String = item.description
	if item is EquipmentItem:
		desc_text = (item as EquipmentItem).get_description()
	tooltip_label.text = item.get_display_text() + "\n" + desc_text
	tooltip_popup.position = Vector2i(get_global_mouse_position() + Vector2(10, 10))
	tooltip_popup.popup()

func _hide_tooltip():
	tooltip_popup.hide()

func _tune_stat_labels_for_scroll():
	var vbox = get_node("CharacterPanel/CharacterSubPanel/ScrollContainer/CharacterVBox")
	for c in vbox.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_PASS

func _is_feed_at_bottom():
	if not is_instance_valid(feed_scroll):
		return true
	var vbar = feed_scroll.get_v_scroll_bar()
	if vbar == null:
		return true
	return vbar.value + vbar.page >= vbar.max_value - 2.0

func _scroll_feed_to_bottom():
	if not is_instance_valid(feed_scroll):
		return
	var vbar = feed_scroll.get_v_scroll_bar()
	if vbar != null:
		vbar.value = vbar.max_value

func _bb_item_name(item) -> String:
	if item and item.has_method("get_display_text"):
		return item.get_display_text()
	return str(item.name) if item and "name" in item else ""
