extends RefCounted
## A restrained battle menu: serif names, compact command list, and a party ledger.
const BODY = preload("res://ui/clear_font.tres")
const DISPLAY = preload("res://ui/display_font.tres")
const INK := Color("eee7d7")
const MUTED := Color("aaa595")
const BRASS := Color("c5ae7b")
const LINE := Color("5c5646")
const HEALTH := Color("9ba982")
const MAGIC := Color("96a6bb")

static func text(b: Control, value: String, at: Vector2, px: int = 16, color: Color = INK, display: bool = false) -> void:
	b.hud.draw_string(DISPLAY if display else BODY, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

static func right(b: Control, value: String, at: Vector2, width: float, px: int = 16, color: Color = INK) -> void:
	b.hud.draw_string(BODY, at, value, HORIZONTAL_ALIGNMENT_RIGHT, width, px, color)

static func line(b: Control, a: Vector2, z: Vector2, color: Color = LINE) -> void:
	b.hud.draw_line(a, z, color, 1)

static func bar(b: Control, area: Rect2, ratio: float, color: Color) -> void:
	b.hud.draw_rect(area, Color("38392f"))
	b.hud.draw_rect(Rect2(area.position, Vector2(area.size.x * clampf(ratio, 0, 1), area.size.y)), color)

static func diamond(b: Control, at: Vector2, radius: float, color: Color) -> void:
	b.hud.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0), at + Vector2(0, radius), at + Vector2(-radius, 0)]), color)

static func draw(b: Control) -> void:
	var c: Control = b.hud
	c.draw_rect(Rect2(0, 0, 1200, 75), Color(0.065, 0.065, 0.055, 0.87))
	text(b, "The Hollow Passage", Vector2(35, 40), 28, INK, true)
	text(b, "Woodland Sentinel", Vector2(37, 61), 13, MUTED)
	text(b, "Round %d" % b.battle.round_number, Vector2(716, 41), 21, BRASS, true)
	line(b, Vector2(35, 74), Vector2(1165, 74), Color(0.77, 0.68, 0.48, 0.4))
	# Enemy identity stays small enough to leave the painted stage visible.
	c.draw_rect(Rect2(28, 110, 318, 122), Color(0.065, 0.065, 0.055, 0.84))
	line(b, Vector2(28, 111), Vector2(346, 111), BRASS)
	text(b, "The Hollow Warden", Vector2(43, 145), 24, INK, true)
	text(b, "Sentinel", Vector2(44, 168), 13, MUTED)
	right(b, "%d / %d" % [b.battle.enemy.hp, b.battle.enemy.max_hp], Vector2(196, 168), 134, 14)
	bar(b, Rect2(44, 181, 286, 5), b.enemy_hp / b.battle.enemy.max_hp, Color("a66f58"))
	var statuses: PackedStringArray = []
	if b.battle.enemy.exposed_turns > 0:
		statuses.append("Exposed")
	if b.battle.enemy.burn_turns > 0:
		statuses.append("Burn %d" % b.battle.enemy.burn)
	if b.battle.enemy.stagger_turns > 0:
		statuses.append("Staggered")
	if b.battle.enemy.slow > 0:
		statuses.append("Slow −%d" % b.battle.enemy.slow)
	text(b, " · ".join(statuses) if not statuses.is_empty() else "", Vector2(44, 211), 14, BRASS)
	var intent: Dictionary = b.battle.intent()
	c.draw_string_outline(DISPLAY, Vector2(40, 258), str(intent.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 3, Color("191a17"))
	text(b, str(intent.name), Vector2(40, 258), 20, INK, true)
	text(b, "Party-wide" if intent.target < 0 else "Aimed at " + str(b.battle.party[int(intent.target)].name), Vector2(41, 279), 13, MUTED)
	if b.battle.turn_cursor < b.battle.party.size() and b.battle.outcome.is_empty():
		c.draw_set_transform(b.heroes[b.battle.turn_cursor].ground, 0, Vector2(1, 0.27))
		c.draw_arc(Vector2.ZERO, 49, 0, TAU, 64, Color(0.77, 0.68, 0.48, 0.65), 2)
		c.draw_set_transform(Vector2.ZERO)
	# One continuous lower menu, instead of three boxed status dashboards.
	c.draw_rect(Rect2(0, 532, 1200, 268), Color("191a17"))
	line(b, Vector2(28, 533), Vector2(1172, 533), BRASS)
	line(b, Vector2(352, 553), Vector2(352, 748))
	var actor: int = mini(b.battle.turn_cursor, b.battle.party.size() - 1)
	var heading: String = "Choose an ally" if b.phase == "target" else str(b.battle.party[actor].name)
	text(b, heading, Vector2(47, 574), 27, INK, true)
	if b.phase not in ["select", "target"]:
		text(b, "Performing" if b.phase == "rhythm" else "Resolving", Vector2(52, 615), 14, MUTED)
		c.draw_multiline_string(DISPLAY, Vector2(51, 648), b.banner, HORIZONTAL_ALIGNMENT_LEFT, 268, 22, 3, INK)
	for index in range(b.battle.party.size()):
		hero(b, index)
	line(b, Vector2(28, 758), Vector2(1172, 758))
	text(b, b.shell.key_name("back") + "  Back" if b.phase == "target" else "Esc  Menu", Vector2(45, 784), 14, MUTED)
	var detail: String = b.description if b.phase in ["select", "target"] else b.battle.last_event
	c.draw_multiline_string(BODY, Vector2(382, 774), detail, HORIZONTAL_ALIGNMENT_LEFT, 777, 14, 2, MUTED)
	if b.phase in ["resolve", "enemy"]:
		c.draw_rect(Rect2(402, 482, 396, 38), Color(0.065, 0.065, 0.055, 0.9))
		c.draw_string(DISPLAY, Vector2(412, 509), b.banner, HORIZONTAL_ALIGNMENT_CENTER, 376, 22, INK)
	for popup in b.popups:
		var color: Color = popup.color
		color.a = minf(1, popup.life * 2)
		var px := 31 if str(popup.text).is_valid_int() else 16
		var width := BODY.get_string_size(popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var at: Vector2 = popup.position - Vector2(width * 0.5, 0)
		c.draw_string_outline(BODY, at, popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4, Color("161710"))
		text(b, popup.text, at, px, color)
	if b.phase in ["victory", "defeat"]:
		outcome(b)

static func hero(b: Control, index: int) -> void:
	var h: Dictionary = b.battle.party[index]
	var x := 382.0 + index * 258
	var selected: bool = b.battle.turn_cursor == index and b.battle.outcome.is_empty()
	if index > 0:
		line(b, Vector2(x - 14, 575), Vector2(x - 14, 739), Color("3b3b31"))
	var portrait: TextureRect = b.hud.get_node("Portrait%d" % index)
	portrait.modulate = Color("777569") if h.hp <= 0 else Color.WHITE
	text(b, h.name, Vector2(x + 76, 605), 25, BRASS if selected else INK, true)
	text(b, h.instrument.capitalize(), Vector2(x + 77, 627), 14, MUTED)
	if selected:
		diamond(b, Vector2(x + 80, 650), 3, BRASS)
	text(b, "HP", Vector2(x + 5, 674), 12, MUTED)
	bar(b, Rect2(x + 32, 665, 119, 4), b.hero_hp[index] / h.max_hp, HEALTH if h.hp > 0 else Color("94675d"))
	right(b, "%d/%d" % [h.hp, h.max_hp], Vector2(x + 159, 674), 77, 15)
	text(b, "MP", Vector2(x + 5, 699), 12, MUTED)
	bar(b, Rect2(x + 32, 690, 119, 3), float(h.mp) / h.max_mp, MAGIC)
	right(b, "%d/%d" % [h.mp, h.max_mp], Vector2(x + 159, 699), 77, 15, MAGIC)
	var effects: PackedStringArray = []
	if h.hp <= 0:
		effects.append("Fallen")
	elif h.guard:
		effects.append("Guard %d%%" % roundi(h.guard_strength * 100))
	if h.shield > 0:
		effects.append("Shield %d" % h.shield)
	if h.haste > 0:
		effects.append("Haste +%d" % h.haste)
	if h.slow > 0:
		effects.append("Slow −%d" % h.slow)
	if b.phase != "target":
		var status_text := " · ".join(effects)
		var status_size := 12
		while status_size > 10 and BODY.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, status_size).x > 232:
			status_size -= 1
		text(b, status_text, Vector2(x + 5, 722), status_size, BRASS)
		var queued: Dictionary = b.battle.queued_for(index)
		if not queued.is_empty():
			text(b, b.battle.action_for(index, queued.action_id).name, Vector2(x + 5, 744), 15, MUTED)

static func outcome(b: Control) -> void:
	b.hud.draw_rect(Rect2(0, 76, 1200, 456), Color(0.035, 0.035, 0.03, 0.68))
	b.hud.draw_rect(Rect2(330, 170, 540, 318), Color("191a17"))
	line(b, Vector2(350, 187), Vector2(850, 187), BRASS)
	line(b, Vector2(350, 471), Vector2(850, 471), BRASS)
	text(b, "Victory" if b.phase == "victory" else "Defeat", Vector2(383, 268), 48, INK, true)
	var average := 0.0
	for score in b.resonance:
		average += score
	average /= maxf(1, b.resonance.size())
	text(b, "%d %s · %d%% accuracy" % [b.battle.round_number, "round" if b.battle.round_number == 1 else "rounds", roundi(average * 100)], Vector2(386, 311), 18, BRASS)
	b.hud.draw_multiline_string(BODY, Vector2(386, 351), "The forest falls quiet. The passage is open." if b.phase == "victory" else "The party falls. Regroup and try again.", HORIZONTAL_ALIGNMENT_LEFT, 423, 17, 2, MUTED)
