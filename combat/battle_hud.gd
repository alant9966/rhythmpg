extends Control
## A separate editor-owned canvas lets the HUD fade independently of the world.
func _draw() -> void:
	get_parent().draw_hud()
