extends Node
class_name ShopManager

func display_blacksmith(_loc) -> void:
	_open("Blacksmith")

func display_leatherworker(_loc) -> void:
	_open("Leatherworker")

func display_quests(_loc) -> void:
	_open("Quests")

func _open(kind: String) -> void:
	var popup := ShopPopup.new()
	popup.shop_type = kind
	get_node("/root/MainUi").add_child(popup)
	popup.popup_centered()
