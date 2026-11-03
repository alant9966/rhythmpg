extends SceneTree
const Shell = preload("res://global/game_shell.gd")
var shell: Shell
## Exercise the actual audio clock and end-of-phrase flow (~34 seconds).
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	shell = root.get_node("GameShell")
	var lab = load("res://scenes/rhythm_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	var failures := 0
	for mode in ["piano", "guitar"]:
		lab.start_performance(mode)
		await create_timer(0.4).timeout
		lab._toggle_pause()
		var paused_time: float = lab.song_time
		await create_timer(0.2).timeout
		if not is_equal_approx(lab.song_time, paused_time):
			push_error(mode + " clock advanced while paused")
			failures += 1
		shell.resume_game(false)
		await create_timer(18.0).timeout
		if lab.running or lab.results.is_empty():
			push_error(mode + " did not finish from real audio playback")
			failures += 1
		elif lab.results.missed != lab.session.notes.size():
			push_error(mode + " did not account for all missed notes")
			failures += 1
		else:
			print(mode + " real-time audio, pause, and completion passed")
	lab._reset()
	lab.queue_free()
	await create_timer(0.1).timeout
	quit(1 if failures else 0)
