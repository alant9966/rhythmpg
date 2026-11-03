extends Node2D
var background: Texture2D = preload("res://assets/backgrounds/1280x720/forest_clearing.png")
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	# The painted ground recedes toward the stream; actors use matching depth scales.
	draw_texture_rect(background, Rect2(0, -42, 1200, 675), false, Color("d8e1d3"))
	draw_rect(Rect2(0, 0, 1200, 555), Color(0.02, 0.07, 0.10, 0.12))
	# Soft shafts of light and moving motes live behind the combatants.
	draw_colored_polygon(PackedVector2Array([Vector2(710, 0), Vector2(768, 0), Vector2(920, 510), Vector2(773, 510)]), Color(0.9, 1, 0.8, 0.035))
	for i in range(24):
		var x := fmod(i * 89.0 + elapsed * (4 + i % 3), 1200)
		var y := 130 + fmod(i * 47.0 - elapsed * 9, 360)
		draw_circle(Vector2(x, y), 1.5 if i % 3 else 2.5, Color(0.95, 0.92, 0.65, 0.22 + sin(elapsed + i) * 0.12))
