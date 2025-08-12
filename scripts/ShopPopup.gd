class_name ShopPopup
extends PopupPanel
var location_ref = null
func configure(p_title: String = "", p_loc = null) -> void:
	title = p_title
	location_ref = p_loc


@export var shop_type: String = "General"

var _confirm_action: Callable = func(): pass

func _ready() -> void:
	title = shop_type + " Shop"
	min_size = Vector2(420, 320)
	# Build simple layout
	var root := VBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	var header := HBoxContainer.new()
	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): queue_free())
	header.add_child(close_btn)
	root.add_child(header)

	var info := Label.new()
	info.text = "Browse and sell items."
	root.add_child(info)

	# Confirm dialog
	var dlg := AcceptDialog.new()
	dlg.name = "ConfirmDialog"
	dlg.title = "Confirm"
	add_child(dlg)
	dlg.confirmed.connect(_on_confirmed)

func _on_confirmed() -> void:
	if _confirm_action.is_valid():
		_confirm_action.call()
		_confirm_action = func(): pass

func confirm_sell(item_name: String, price: int, on_yes: Callable) -> void:
	var dlg := get_node("ConfirmDialog") as AcceptDialog
	dlg.get_ok_button().text = "Sell '%s' for %d gold?"
	dlg.dialog_text = "Sell '%s' for %d gold?" % [item_name, price]
	_confirm_action = on_yes
	dlg.popup_centered(Vector2(320, 120))

# Optional helper to be called by external UI:
func sell_entry(entry: Dictionary) -> void:
	if not entry.has("item") or not GameManager:
		return
	var item = entry["item"]
	var item_name: String = (item.name if "name" in item else "Item")
	var price := int(item.value if "value" in item else 1)
	confirm_sell(item_name, price, func():
		GameManager.gold += price
		GameManager.remove_entry(entry)
		if GameManager:
			GameManager.log_action("[color=#606060]Sold %s for %d gold.[/color]" % [item_name, price])
		)

func _format_sell_confirm(item, price:int) -> String:
	var nm := str(item.name) if item and "name" in item else str(item)
	return "Sell '%s' for %d gold?" % [nm, price]
