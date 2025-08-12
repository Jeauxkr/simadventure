extends Item
class_name DropItem
func _init(p_name: String = "Drop Item"):
	super._init(p_name, "Generic drop item", 10, 99)


func get_display_text() -> String:
	return name
