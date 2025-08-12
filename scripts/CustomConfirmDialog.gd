# CustomConfirmDialog.gd
extends ConfirmationDialog
class_name CustomConfirmDialog

var rich_label: RichTextLabel

func _ready() -> void:
	var original_label = get_label()
	rich_label = RichTextLabel.new()
	rich_label.name = original_label.name
	rich_label.bbcode_enabled = true
	rich_label.fit_content = true
	rich_label.scroll_active = true
	rich_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich_label.custom_minimum_size = Vector2(300, 0)
	rich_label.text = original_label.text
	var parent = original_label.get_parent()
	parent.add_child(rich_label)
	parent.remove_child(original_label)
	original_label.queue_free()

func set_dialog_text(value: String) -> void:
	rich_label.text = value

func get_dialog_text() -> String:
	return rich_label.text
