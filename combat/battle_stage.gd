extends Node2D
## Scenery is authored in combat.tscn. This clock also follows global pause.
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
