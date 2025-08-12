# Camp.gd
extends Node
class_name Camp

static func reduce_duration(duration: float, loc: Location) -> float:
	return duration * (0.9 if loc.has_camp else 1.0)
