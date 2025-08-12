# CraftPopup.gd
extends Window
class_name CraftPopup

func _init():
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	var popup_title = Label.new()
	popup_title.text = "Crafting"
	vbox.add_child(popup_title)
	
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(queue_free)
	vbox.add_child(close_button)
