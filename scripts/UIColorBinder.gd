extends Node
class_name UIColorBinder
const QualityColors = preload("res://scripts/QualityColors.gd")

## Utility to color a RichTextLabel or Label based on a quality string.
static func apply_bbcode_text(label: Node, text: String, quality: String) -> void:
	if label is RichTextLabel:
		label.bbcode_enabled = true
		label.text = QualityColors.bb_name(text, quality)
	elif label is Label:
		label.text = text
		label.add_theme_color_override("font_color", Color(QualityColors.hex_for(quality)))
