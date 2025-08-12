extends Item
class_name QuestNote

var quest: Quest
var is_completion: bool = false

func _init(p_quest: Quest, p_is_completion: bool = false):
	super._init(p_quest.name + " Note", "Note for quest: " + p_quest.description, 0, 1)
	quest = p_quest
	is_completion = p_is_completion

func get_display_text() -> String:
	var text = "[b]" + name + "[/b]"
	if is_completion:
		text += " [Completion]"
	return text
