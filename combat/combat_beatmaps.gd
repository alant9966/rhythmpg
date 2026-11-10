extends RefCounted
## One bar at 120 BPM. Guitar downbeats strum down; offbeats strum up.
const BEAT := 0.5
const LEAD := 0.65
const GUITAR := [
	{"name": "Island strum", "beats": [0, 1, 1.5, 2.5, 3, 3.5], "directions": [1, 1, -1, -1, 1, -1]},
	{"name": "Steady downstrokes", "beats": [0, 1, 2, 3], "directions": [1, 1, 1, 1]},
	{"name": "Alternating eighths", "beats": [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5], "directions": [1, -1, 1, -1, 1, -1, 1, -1]},
	{"name": "Folk strum", "beats": [0, 1, 1.5, 2, 3, 3.5], "directions": [1, 1, -1, 1, 1, -1]},
	{"name": "Offbeat lift", "beats": [0, 1.5, 2, 2.5, 3.5], "directions": [1, -1, 1, -1, -1]},
	{"name": "Backbeat strum", "beats": [0, 1, 1.5, 3, 3.5], "directions": [1, 1, -1, 1, -1]},
]
# Entries: beat, lane, hold seconds. Holds finish before the bar ends.
const PIANO := [
	{"name": "Rising phrase", "notes": [[0, 0, 0], [0.5, 1, 0], [1, 2, 0], [1.5, 3, 0], [2, 0, 0], [2, 2, 0], [3, 1, 0.35], [3, 3, 0.35]]},
	{"name": "Falling phrase", "notes": [[0, 3, 0], [0.5, 2, 0], [1, 1, 0], [1.5, 0, 0], [2, 1, 0], [2, 3, 0], [3, 0, 0.35], [3, 2, 0.35]]},
	{"name": "Chord pulse", "notes": [[0, 0, 0], [0, 2, 0], [1, 1, 0], [1, 3, 0], [2, 0, 0], [2, 3, 0], [3, 1, 0.35], [3, 2, 0.35]]},
	{"name": "Broken arpeggio", "notes": [[0, 0, 0], [0.5, 2, 0], [1, 1, 0], [1.5, 3, 0], [2, 2, 0], [2.5, 1, 0], [3, 0, 0], [3.5, 3, 0]]},
	{"name": "Syncopated answer", "notes": [[0, 1, 0], [0.5, 2, 0], [1.5, 0, 0], [2, 3, 0], [2.5, 2, 0], [3, 0, 0.35], [3, 2, 0.35]]},
	{"name": "Echo phrase", "notes": [[0, 0, 0], [0.5, 0, 0], [1, 3, 0], [1.5, 3, 0], [2, 1, 0], [2, 2, 0], [3, 0, 0.35], [3, 3, 0.35]]},
]
const TIMPANI := [
	{"name": "Crescent", "beats": [0.0, 0.75, 1.5, 2.25, 3.0, 3.5], "points": [Vector2(0.15, 0.4), Vector2(0.32, 0.22), Vector2(0.53, 0.28), Vector2(0.76, 0.46), Vector2(0.66, 0.75), Vector2(0.4, 0.7)]},
	{"name": "Zigzag", "beats": [0.0, 0.5, 1.25, 2.0, 2.75, 3.5], "points": [Vector2(0.18, 0.27), Vector2(0.35, 0.72), Vector2(0.5, 0.27), Vector2(0.68, 0.72), Vector2(0.83, 0.3), Vector2(0.65, 0.3)]},
	{"name": "Drum triangle", "beats": [0.0, 0.5, 1.0, 2.0, 2.5, 3.0], "points": [Vector2(0.25, 0.68), Vector2(0.5, 0.25), Vector2(0.75, 0.68), Vector2(0.25, 0.68), Vector2(0.5, 0.25), Vector2(0.75, 0.68)]},
	{"name": "Orbit", "beats": [0.0, 0.75, 1.5, 2.0, 2.75, 3.5], "points": [Vector2(0.2, 0.5), Vector2(0.34, 0.23), Vector2(0.66, 0.23), Vector2(0.8, 0.5), Vector2(0.66, 0.77), Vector2(0.4, 0.77)]},
	{"name": "Crossing beat", "beats": [0.0, 0.5, 1.5, 2.0, 2.5, 3.5], "points": [Vector2(0.2, 0.25), Vector2(0.44, 0.5), Vector2(0.75, 0.72), Vector2(0.75, 0.25), Vector2(0.48, 0.5), Vector2(0.22, 0.72)]},
	{"name": "Rolling wave", "beats": [0.0, 0.75, 1.25, 2.0, 3.0, 3.5], "points": [Vector2(0.15, 0.5), Vector2(0.3, 0.3), Vector2(0.46, 0.6), Vector2(0.62, 0.35), Vector2(0.8, 0.65), Vector2(0.82, 0.3)]},
]

static func count(mode: String) -> int:
	return TIMPANI.size() if mode == "timpani" else (GUITAR.size() if mode == "guitar" else PIANO.size())

static func pattern_name(mode: String, variation: int) -> String:
	return (TIMPANI if mode == "timpani" else (GUITAR if mode == "guitar" else PIANO))[posmod(variation, count(mode))].name

static func chart(mode: String, mask: int, variation: int) -> Array[Dictionary]:
	var notes: Array[Dictionary] = []
	variation = posmod(variation, count(mode))
	if mode == "timpani":
		var pattern: Dictionary = TIMPANI[variation]
		for i in range(pattern.beats.size()):
			notes.append({"time": LEAD + float(pattern.beats[i]) * BEAT, "mask": 1, "duration": 0.0,
				"direction": 0, "position": pattern.points[i]})
	elif mode == "guitar":
		var pattern: Dictionary = GUITAR[variation]
		for i in range(pattern.beats.size()):
			notes.append({"time": LEAD + float(pattern.beats[i]) * BEAT, "mask": mask,
				"duration": 0.0, "direction": int(pattern.directions[i])})
	else:
		for item in PIANO[variation].notes:
			notes.append({"time": LEAD + float(item[0]) * BEAT, "mask": 1 << int(item[1]),
				"duration": float(item[2]), "direction": 0})
	return notes
