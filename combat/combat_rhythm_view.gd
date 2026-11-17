extends RefCounted
## Open playfields beside the spotlit actor; no minigame card or dashboard.
const Style = preload("res://rhythm/rhythm_theme.gd")
const Strum = preload("res://rhythm/strum_visuals.gd")
const Circles = preload("res://rhythm/circle_visuals.gd")
const COLORS := [Color("88dbd3"), Color("abc7ff"), Color("d3b0ec"), Color("f5cf85")]

static func text(view: Control, value: String, point: Vector2, px: int = 20, color: Color = Style.INK) -> void:
	view.draw_string(view.font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

static func centered(view: Control, value: String, bounds: Rect2, px: int, color: Color = Style.INK) -> void:
	view.draw_string(view.font, bounds.position + Vector2(0, bounds.size.y * 0.5 + px * 0.35), value, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, px, color)

static func draw(view: Control) -> void:
	if not view.font:
		return
	view.draw_rect(view.dimmer_rect(), Color(0, 0, 0, view.dim_opacity * view.presentation_weight))
	if not view.gameplay_visible():
		return
	var zoom := minf(view.size.x / 1200.0, view.size.y / 800.0)
	view.draw_set_transform((view.size - Vector2(1200, 800) * zoom) * 0.5, 0, Vector2.ONE * zoom)
	if view.instrument == "piano":
		piano_board(view)
	elif view.instrument == "guitar":
		guitar_board(view)
	else:
		if view.preparation_left <= 0:
			Circles.draw(view, view.session.notes, view.time, Circles.COMBAT_AREA, view.font)
	if view.preparation_left <= 0 and view.feedback != "READY":
		centered(view, view.feedback.capitalize(), Rect2(110, 650, 640, 42), 26, Style.GOLD)
	view.draw_set_transform(Vector2.ZERO)

static func piano_board(view: Control) -> void:
	const TOP := 190.0
	const HIT := 550.0
	for lane in range(4):
		var x := 135.0 + lane * 145
		var pressed: bool = (int(view.held) & (1 << lane)) != 0
		view.draw_rect(Rect2(x, TOP, 130, 360), Color(COLORS[lane], 0.14 if pressed else 0.045))
		view.draw_line(Vector2(x + 65, TOP), Vector2(x + 65, HIT), Color(COLORS[lane], 0.13), 1)
		view.draw_rect(Rect2(x, HIT + 20, 130, 48), Color(COLORS[lane], 0.65 if pressed else 0.14))
		view.draw_line(Vector2(x, HIT + 20), Vector2(x + 130, HIT + 20), COLORS[lane], 2)
		centered(view, view.shell.key_name("piano_%d" % (lane + 1)), Rect2(x, HIT + 20, 130, 48), 25)
	if view.preparation_left <= 0:
		for note in view.session.notes:
			if note.state == "done":
				continue
			var lane := 0
			while (1 << lane) != int(note.mask):
				lane += 1
			var y: float = HIT - (float(note.time) - view.time) / 0.85 * (HIT - TOP)
			var tail: float = HIT - (float(note.time) + float(note.duration) - view.time) / 0.85 * (HIT - TOP)
			if note.state == "holding":
				y = HIT
			if y < TOP + 10 or tail > HIT + 22:
				continue
			var x := 200.0 + lane * 145
			if note.duration > 0:
				view.draw_line(Vector2(x, maxf(TOP, tail)), Vector2(x, y), Color(COLORS[lane], 0.65), 22)
			view.draw_rect(Rect2(x - 48, y - 9, 96, 18), COLORS[lane])
	view.draw_line(Vector2(125, HIT), Vector2(715, HIT), Style.INK, 3)

static func guitar_board(view: Control) -> void:
	const HIT_X := 180.0
	const CENTER_Y := 350.0
	for y in [290, 314, 338, 362, 386, 410]:
		view.draw_line(Vector2(130, y), Vector2(735, y), Color(0.85, 0.73, 0.5, 0.36), 2)
	view.draw_line(Vector2(HIT_X, 255), Vector2(HIT_X, 450), Style.INK, 3)
	if view.preparation_left <= 0:
		for note in view.session.notes:
			if note.state == "done":
				continue
			var x: float = HIT_X + (float(note.time) - view.time) / 1.15 * 530
			if x < HIT_X - 30 or x > 735:
				continue
			view.draw_circle(Vector2(x, CENTER_Y), 31, Style.GOLD)
			Strum.arrow(view, Vector2(x, CENTER_Y), int(note.direction), 47, Color("152031"))
	for lane in range(3):
		var bounds := Rect2(135 + lane * 195, 510, 180, 76)
		Strum.fret(view, bounds, (int(view.chord_mask) & (1 << lane)) != 0, (int(view.held) & (1 << lane)) != 0)
		centered(view, view.shell.key_name("guitar_%d" % (lane + 1)), bounds, 27)
	Strum.arrow(view, Vector2(310, 618), 1, 25, Style.GOLD)
	text(view, view.shell.key_name("strum_down"), Vector2(333, 625), 17, Style.MUTED)
	Strum.arrow(view, Vector2(505, 618), -1, 25, Style.GOLD)
	text(view, view.shell.key_name("strum_up"), Vector2(528, 625), 17, Style.MUTED)
