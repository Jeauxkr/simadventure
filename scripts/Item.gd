extends Resource

class_name Item

@export var name: String = "Item"
@export var stack_max: int = 99
@export var description: String = ""
@export var value: int = 0

func _init(p_name: String = "Item", p_desc: String = "", p_value: int = 0, p_stack: int = 99):
	name = p_name
	description = p_desc
	value = p_value
	stack_max = p_stack

func get_display_text() -> String:
	return "[b]" + name + "[/b]"
