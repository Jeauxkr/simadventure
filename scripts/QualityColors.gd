extends Resource
class_name QualityColors

## Returns a hex color string (e.g. "#ffd700") for a quality name.
static func hex_for(quality: String) -> String:
	var q := quality.strip_edges()
	# Normalize common spellings
	q = q.to_lower()
	match q:
		"common":
			return "#808080" # Gray
		"uncommon":
			return "#ffffff" # White
		"rare":
			return "#3da5ff" # Blue
		"unique":
			return "#b36bff" # Purple
		"legendary":
			return "#ffd700" # Gold
		"ancient":
			return "#ff3b3b" # Red
		_:
			return "#ffffff" # default

## Convenience: wraps a name in BBCode color tags based on the quality.
static func bb_name(name: String, quality: String) -> String:
	return "[color=%s]%s[/color]" % [hex_for(quality), name]
