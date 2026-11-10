extends RefCounted
const APPROACH := 0.9
const RADIUS := 40.0
const COMBAT_AREA := Rect2(350, 254, 750, 346)
const PRACTICE_AREA := Rect2(298, 250, 632, 400)

static func logical_point(local: Vector2, size: Vector2) -> Vector2:
	var zoom := minf(size.x / 1200.0, size.y / 800.0)
	return (local - (size - Vector2(1200, 800) * zoom) * 0.5) / zoom

static func draw(canvas: CanvasItem, notes: Array[Dictionary], time: float, area: Rect2, font: Font) -> void:
	var first := -1
	var visible: Array[int] = []
	for i in range(notes.size()):
		if notes[i].state == "pending":
			if first < 0:
				first = i
			if notes[i].time - time <= APPROACH and time <= notes[i].time + 0.14:
				visible.append(i)
	for i in range(visible.size() - 1):
		var a: Vector2 = area.position + notes[visible[i]].position * area.size
		var b: Vector2 = area.position + notes[visible[i + 1]].position * area.size
		canvas.draw_line(a, b, Color(0.65, 0.78, 0.8, 0.23), 2, true)
	# Draw the earliest target last so it stays clickable/legible on returning patterns.
	for index in range(visible.size() - 1, -1, -1):
		var i: int = visible[index]
		var note: Dictionary = notes[i]
		var center: Vector2 = area.position + note.position * area.size
		var remaining: float = clampf((note.time - time) / APPROACH, 0, 1)
		var current := i == first
		var color := Color("f2c675") if current else Color("83d4c4")
		canvas.draw_circle(center, RADIUS, Color("334c53") if not current else Color("65543a"))
		canvas.draw_arc(center, RADIUS, 0, TAU, 80, color, 3, true)
		canvas.draw_arc(center, RADIUS + 64 * remaining, 0, TAU, 80, Color(color, 0.75), 3, true)
		canvas.draw_string(font, center + Vector2(-RADIUS, 9), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2, 28, Color("eef0e9"))
