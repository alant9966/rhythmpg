extends RefCounted
## Large performance overlay. Judgment and audio remain in combat_rhythm.gd.
const Style = preload("res://rhythm/rhythm_theme.gd")
const Strum = preload("res://rhythm/strum_visuals.gd")
const Circles = preload("res://rhythm/circle_visuals.gd")
const COLORS := [Color("88dbd3"), Color("abc7ff"), Color("d3b0ec"), Color("f5cf85")]

static func text(view: Control, value: String, point: Vector2, px: int = 20, color: Color = Style.INK) -> void:
	view.draw_string(view.font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

static func centered(view: Control, value: String, bounds: Rect2, px: int, color: Color = Style.INK) -> void:
	var fitted := px
	while fitted > 12 and view.font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > bounds.size.x - 12:
		fitted -= 1
	view.draw_string(view.font, bounds.position + Vector2(0, bounds.size.y * 0.5 + fitted * 0.35), value, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, fitted, color)

static func draw(view: Control) -> void:
	if not view.font:
		return
	view.draw_rect(Rect2(Vector2.ZERO, view.size), Color(0.015, 0.025, 0.035, 0.78))
	var zoom := minf(view.size.x / 1200.0, view.size.y / 800.0)
	view.draw_set_transform((view.size - Vector2(1200, 800) * zoom) * 0.5, 0, Vector2.ONE * zoom)
	view.draw_style_box(Style.panel(Color(0.065, 0.105, 0.13, 0.94), Style.GOLD), Rect2(32, 28, 1136, 744))
	var piano: bool = view.instrument == "piano"
	var timpani: bool = view.instrument == "timpani"
	text(view, "P E R F O R M A N C E   /   " + ("C I R C L E S T R I K E" if timpani else ("C H O R D F A L L" if piano else "S T R U M L I N E")), Vector2(64, 70), 16, Style.GOLD)
	text(view, view.title, Vector2(64, 125), 38)
	text(view, "TIMPANI / MARO" if timpani else ("PIANO / LYRA" if piano else "GUITAR / ROWAN"), Vector2(876, 78), 19, Style.GOLD)
	text(view, "120 BPM  ·  ONE PHRASE", Vector2(876, 113), 16, Style.MUTED)
	text(view, view.pattern_name, Vector2(876, 138), 14, Style.MUTED)
	text(view, "PERFECT: " + view.bonus_hint, Vector2(64, 141), 13, Style.GOLD)
	view.draw_line(Vector2(64, 148), Vector2(1136, 148), Color("52615f"), 1)
	view.draw_style_box(Style.panel(Color("152530")), Rect2(64, 174, 236, 488))
	view.draw_style_box(Style.panel(Color("101d28")), Rect2(316, 174, 820, 488))
	text(view, "ACCURACY", Vector2(84, 210), 14, Style.MUTED)
	var accuracy: float = view.session.accuracy()
	text(view, "%d%%" % (100 if accuracy == 1.0 else mini(99, roundi(accuracy * 100))), Vector2(84, 263), 44, Style.TEAL)
	text(view, "COMBO  %02d" % view.session.combo, Vector2(84, 301), 20)
	text(view, "AIM + CLICK" if timpani else ("PLAY KEYS" if piano else "HOLD CHORD"), Vector2(84, 351), 15, Style.GOLD)
	if timpani:
		centered(view, "LEFT MOUSE", Rect2(75, 361, 210, 44), 25, Style.TEAL)
		view.draw_multiline_string(view.font, Vector2(84, 437), "Click circles in order.\nWait for the ring to\nreach the circle edge.", HORIZONTAL_ALIGNMENT_LEFT, 195, 18, 6, Style.MUTED)
		centered(view, "CLICK THE NEXT NUMBER WHEN ITS RINGS MEET", Rect2(341, 191, 770, 38), 18, Style.MUTED)
		if view.preparation_left <= 0:
			Circles.draw(view, view.session.notes, view.time, Circles.COMBAT_AREA, view.font)
	elif piano:
		centered(view, " / ".join(view.shell.lane_names("piano")), Rect2(75, 361, 210, 44), 25, Style.TEAL)
		view.draw_multiline_string(view.font, Vector2(84, 437), "Tap at the white line.\nPlay chords together.\nHold the long notes.", HORIZONTAL_ALIGNMENT_LEFT, 195, 18, 5, Style.MUTED)
		piano_board(view)
	else:
		var names: PackedStringArray = []
		for lane in range(3):
			if int(view.chord_mask) & (1 << lane):
				names.append(view.shell.key_name("guitar_%d" % (lane + 1)))
		centered(view, " + ".join(names), Rect2(75, 358, 210, 48), 28, Style.GOLD)
		for lane in range(3):
			var bounds := Rect2(80 + lane * 68, 421, 61, 89)
			Strum.fret(view, bounds, (int(view.chord_mask) & (1 << lane)) != 0, (int(view.held) & (1 << lane)) != 0)
			centered(view, view.shell.key_name("guitar_%d" % (lane + 1)), bounds, 25)
		text(view, "Keep this shape held.", Vector2(84, 546), 17, Style.MUTED)
		Strum.pattern(view, Vector2(92, 589), minf(35, 175.0 / maxf(1, view.pattern_directions.size() - 1)), 27, view.pattern_directions)
		guitar_board(view)
	centered(view, "READY" if view.preparation_left > 0 else view.feedback, Rect2(320, 665, 810, 42), 29, Style.GOLD)
	view.draw_rect(Rect2(64, 718, 1072, 4), Color("34465e"))
	view.draw_rect(Rect2(64, 718, 1072 * clampf(view.time / view.END, 0, 1), 4), Style.TEAL)
	text(view, "ESC  /  PAUSE MENU", Vector2(64, 751), 15, Style.MUTED)
	text(view, view.shell.key_name("back") + "  /  RESOLVE AT 0%", Vector2(794, 751), 15, Style.MUTED)
	if view.preparation_left > 0 and not timpani:
		view.draw_style_box(Style.panel(Color(0.06, 0.09, 0.12, 0.95), Style.GOLD), Rect2(510, 276, 432, 222))
		centered(view, "GET READY", Rect2(530, 302, 392, 42), 26, Style.GOLD)
		centered(view, "%d" % ceili(view.preparation_left), Rect2(530, 355, 392, 78), 64, Style.TEAL)
		centered(view, "Set your hands on the highlighted keys", Rect2(530, 447, 392, 28), 17, Style.MUTED)
	view.draw_set_transform(Vector2.ZERO)

static func piano_board(view: Control) -> void:
	const TOP := 207.0
	const HIT := 567.0
	for lane in range(4):
		var x := 359.0 + lane * 183
		view.draw_rect(Rect2(x, TOP, 171, 372), Color("223240"))
		view.draw_line(Vector2(x + 85.5, TOP), Vector2(x + 85.5, HIT), Color("34465e"), 1)
		var pressed: bool = (int(view.held) & (1 << lane)) != 0
		view.draw_style_box(Style.panel(COLORS[lane] if pressed else Color("dce3ed")), Rect2(x, 587, 171, 49))
		centered(view, view.shell.key_name("piano_%d" % (lane + 1)), Rect2(x, 587, 171, 49), 27, Color("101d28"))
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
			var x := 444.5 + lane * 183
			if note.duration > 0:
				view.draw_line(Vector2(x, maxf(TOP, tail)), Vector2(x, y), Color(COLORS[lane], 0.5), 25)
			view.draw_style_box(Style.panel(COLORS[lane], COLORS[lane]), Rect2(x - 66, y - 10, 132, 20))
	view.draw_line(Vector2(344, HIT), Vector2(1110, HIT), Style.INK, 4)
	text(view, "HIT", Vector2(331, HIT - 16), 13, Style.MUTED)

static func guitar_board(view: Control) -> void:
	centered(view, "STRUM WHEN THE ARROW REACHES THE WHITE LINE", Rect2(341, 207, 770, 40), 19, Style.MUTED)
	const HIT_X := 414.0
	const CENTER_Y := 391.0
	for y in [343, 367, 391, 415, 439, 463]:
		view.draw_line(Vector2(354, y), Vector2(1095, y), Color("806a4e"), 2)
	view.draw_line(Vector2(HIT_X, 292), Vector2(HIT_X, 499), Style.INK, 4)
	centered(view, "HIT", Rect2(HIT_X - 45, 514, 90, 34), 18)
	if view.preparation_left <= 0:
		for note in view.session.notes:
			if note.state == "done":
				continue
			var x: float = HIT_X + (float(note.time) - view.time) / 1.15 * 660
			if x < HIT_X - 30 or x > 1065:
				continue
			view.draw_circle(Vector2(x, CENTER_Y), 34, Style.GOLD)
			Strum.arrow(view, Vector2(x, CENTER_Y), int(note.direction), 49, Color("152031"))
	Strum.arrow(view, Vector2(564, 592), 1, 31, Style.GOLD)
	text(view, view.shell.key_name("strum_down") + "  /  DOWN", Vector2(591, 599), 20)
	Strum.arrow(view, Vector2(865, 592), -1, 31, Style.GOLD)
	text(view, view.shell.key_name("strum_up") + "  /  UP", Vector2(892, 599), 20)
