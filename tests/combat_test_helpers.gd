extends RefCounted
const Rhythm = preload("res://combat/combat_rhythm.gd")
const Circles = preload("res://rhythm/circle_visuals.gd")

static func prepare(rhythm: Node) -> void:
	# Fast-forward only the visual intro when testing input/scoring directly.
	var battle = rhythm.get_parent()
	if battle.has_method("draw_hud") and not rhythm.gameplay_revealed:
		battle.focus_tween.custom_step(battle.rhythm_focus_in_seconds + battle.rhythm_hud_fade_seconds + 0.1)

static func perfect(rhythm: Node) -> void:
	prepare(rhythm)
	rhythm.preparation_left = 0
	for note in rhythm.session.notes:
		if rhythm.instrument == "timpani":
			rhythm.session.click(note.time, Circles.COMBAT_AREA.position + note.position * Circles.COMBAT_AREA.size, Circles.COMBAT_AREA)
		else:
			var lane := 0
			while rhythm.instrument == "piano" and (1 << lane) != int(note.mask):
				lane += 1
			rhythm.session.press(note.time, lane, note.mask, note.direction)
	rhythm.time = Rhythm.END
	rhythm.held = 15
	rhythm._process(0)

static func finish_round(scene: Node, accuracy: float = 1.0) -> bool:
	for tick in range(650):
		if scene.phase in ["select", "victory", "defeat"]:
			return true
		if scene.phase == "rhythm" and scene.rhythm.active:
			if accuracy == 1.0:
				perfect(scene.rhythm)
			else:
				scene.rhythm.resolve_now()
		await scene.get_tree().create_timer(0.02).timeout
	return false

static func settle(tree: SceneTree) -> void:
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
