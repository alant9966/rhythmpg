extends RefCounted
## Shared, font-independent strum arrows and full-area chord highlighting.
const GOLD := Color("f2c675")

static func fret(canvas: CanvasItem, bounds: Rect2, required: bool, held: bool) -> void:
	var fill := Color("4d4434") if required else Color("1c293a")
	var edge := GOLD if required else Color("34445b")
	if held:
		fill = Color("386d64") if required else Color("713f43")
		if not required:
			edge = Color("f29b93")
	canvas.draw_rect(bounds, fill)
	canvas.draw_rect(bounds, edge, false, 3.0 if required else 1.0)

static func arrow(canvas: CanvasItem, center: Vector2, direction: int, height: float, color: Color) -> void:
	var points := PackedVector2Array()
	for point in [Vector2(-0.12, -0.5), Vector2(0.12, -0.5), Vector2(0.12, 0.05),
		Vector2(0.36, 0.05), Vector2(0, 0.5), Vector2(-0.36, 0.05), Vector2(-0.12, 0.05)]:
		points.append(center + Vector2(point.x, point.y * direction) * height)
	canvas.draw_colored_polygon(points, color)

static func pattern(canvas: CanvasItem, origin: Vector2, spacing: float, height: float) -> void:
	var directions := [1, 1, -1, -1, 1, -1]
	for i in range(directions.size()):
		arrow(canvas, origin + Vector2(i * spacing, 0), directions[i], height, GOLD)
