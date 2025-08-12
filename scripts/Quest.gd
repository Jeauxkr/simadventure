extends Resource
class_name Quest

var name: String = ""
var description: String = ""
var objectives: Array[Dictionary] = []
var rewards: Dictionary = {}
var location: Location = null
var status: String = "active"

func _init(p_name: String, p_desc: String, p_obj: Array[Dictionary], p_rewards: Dictionary, p_loc: Location = null):
	name = p_name
	description = p_desc
	objectives = p_obj
	rewards = p_rewards
	location = p_loc

##
# Return a string suitable for display in the UI.
#
# This method summarises the quest name, description, each objective's
# current progress and the rewards offered.  It is used by
# `MainUI.update_ui()` when populating the active quest list.  Without this
# method the UI will attempt to call `get_display_text()` on a Quest
# instance and raise an error.
func get_display_text() -> String:
	var lines: Array[String] = []
	# Title
	lines.append("[b]" + name + "[/b]")
	# Description
	lines.append(description)
	# Objectives
	for obj in objectives:
		var target: String = obj.get("target", "")
		var type_name: String = obj.get("type", "").capitalize()
		var count: int = obj.get("count", 0)
		var current: int = obj.get("current", 0)
		var line: String = type_name
		if target != "":
			line += " " + target
		line += ": " + str(current) + "/" + str(count)
		lines.append(line)
	# Rewards
	if rewards.size() > 0:
		var reward_parts: Array[String] = []
		if rewards.has("gold"):
			reward_parts.append(str(rewards["gold"]) + " gold")
		if rewards.has("xp"):
			reward_parts.append(str(rewards["xp"]) + " XP")
		if rewards.has("items"):
			# Display the names of item rewards
			var item_names: Array[String] = []
			for reward_item in rewards["items"]:
				if reward_item is Item:
					item_names.append(reward_item.name)
				else:
					item_names.append(str(reward_item))
			reward_parts.append(", ".join(item_names))
		lines.append("Rewards: " + ", ".join(reward_parts))
	# Status
	if status != "active":
		lines.append("Status: " + status.capitalize())
	return "\n".join(lines)
