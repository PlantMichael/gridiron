extends Node

## Real-tree pause regression: input, live simulation, countdowns and exit.
## godot --headless --path . res://tools/pause_check.tscn
var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Keep the harness alive while the real game changes current_scene.
	get_tree().current_scene = null
	_run.call_deferred()


func _run() -> void:
	get_tree().root.size = Vector2i(1440, 900)
	await _screen("main_menu")
	await _escape()
	_check(not get_tree().paused and not PauseMenu.visible, "title screen ignores pause")
	GameState.new_run(99001)
	await _screen("hub")
	await _escape()
	_check(get_tree().paused and PauseMenu.visible, "Esc pauses the map")
	_check(get_viewport().gui_get_focus_owner().text == "RESUME", "resume receives keyboard focus")
	_press("MAIN MENU")
	_check(get_tree().paused and _visible_button("BACK") != null, "leaving requires confirmation")
	await _escape()
	_check(get_tree().paused and _visible_button("RESUME") != null, "Esc cancels leaving without unpausing")
	_press("RESUME")
	_check(not get_tree().paused, "resume button unpauses")

	await _screen("match")
	var match_screen := get_tree().current_scene
	var sim: MatchSim = match_screen.sim
	var field: Control = match_screen.field
	await _right_mouse(field, true)
	_check(field.get("_dragging"), "right mouse starts camera drag")
	await _escape()
	await _right_mouse(field, false)
	await _escape()
	var camera_before := Vector2(field.get("_cam_x"), field.get("_cam_y"))
	var motion := InputEventMouseMotion.new()
	motion.position = field.get_global_rect().get_center()
	motion.global_position = motion.position
	motion.relative = Vector2(10, 10)
	Input.parse_input_event(motion)
	await get_tree().process_frame
	_check(Vector2(field.get("_cam_x"), field.get("_cam_y")) == camera_before,
		"releasing camera drag during pause does not pan after resume")
	match_screen.call("_on_snap")
	await get_tree().create_timer(0.1).timeout
	_check(sim.phase == MatchSim.Phase.LIVE, "real match has a live play")
	_press("MENU  ≡")
	await _click(_visible_button("2x"))
	_check(match_screen.speed == 2.0 and get_tree().paused, "speed setting changes without resuming")
	var locked: bool = field.camera_locked
	await _click(_visible_button("CAMERA    FOLLOW BALL" if locked else "CAMERA    FREE"))
	_check(field.camera_locked != locked and get_tree().paused, "camera setting changes without resuming")
	for step in 14:
		await _key(KEY_TAB)
		_check(PauseMenu._actions.is_ancestor_of(get_viewport().gui_get_focus_owner()), "Tab stays in the open menu")
	var time_before := sim.time
	var ball_before := sim.ball_pos
	await get_tree().create_timer(0.15).timeout
	_check(sim.time == time_before and sim.ball_pos == ball_before, "pause freezes the live play")
	await _escape()
	await get_tree().create_timer(0.1).timeout
	_check(sim.time > time_before, "Esc resumes the same play")

	await _click(_visible_button("MENU  ≡"))
	_check(_visible_button("2x").button_pressed, "reopened menu reads scene speed")
	await _click(_visible_button("TEAM STATS"))
	_check(not get_tree().paused and match_screen.side_panel.visible, "Team Stats resumes into the existing stats panel")
	match_screen._dismiss_overlays()

	# The real result-card and end-of-match counters must also stay frozen.
	sim.phase = MatchSim.Phase.DEAD
	match_screen.set("_auto_left", 3.0)
	PauseMenu.open()
	await get_tree().create_timer(0.1).timeout
	_check(match_screen.get("_auto_left") == 3.0, "result countdown stops")
	PauseMenu.resume()
	match_screen.set("_match_ended", true)
	match_screen.set("_end_countdown", 4.0)
	PauseMenu.open()
	await get_tree().create_timer(0.1).timeout
	_check(match_screen.get("_end_countdown") == 4.0, "match-end countdown stops")
	_press("MAIN MENU")
	_press("LEAVE RUN")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not get_tree().paused and not PauseMenu.visible, "exit clears pause")
	_check(get_tree().current_scene.scene_file_path.ends_with("main_menu.tscn"), "confirmed exit reaches title")
	_check(not GameState.run_active, "confirmed exit ends the run")
	GameState.new_run(99002)
	await _screen("shop")
	await _escape()
	_check(get_tree().paused, "pause works after leaving and starting another run")
	await _escape()
	_check(not get_tree().paused, "second run resumes")
	# The same launcher survives both ordinary and backdrop-meta rebuilds.
	for id in ["qb_select", "hub", "lineup", "shop", "playbook", "practice", "mystery", "laboratory", "ritual_site", "player_book", "post_match"]:
		await _screen(id)
		await _click(_visible_button("MENU  ≡"))
		_check(PauseMenu.visible and get_tree().paused, id + " launcher receives pointer input")
		_check(_visible_button("2x") == null, id + " has no stale match settings")
		await _click(_visible_button("RESUME"))
		if id in ["lineup", "shop", "player_book", "laboratory", "ritual_site"]:
			var page := get_tree().current_scene
			page.call("_rebuild" if page.has_method("_rebuild") else "_build")
			for frame in 4:
				await get_tree().process_frame
			await _click(_visible_button("MENU  ≡"))
			_check(PauseMenu.visible, id + " launcher works after rebuilding")
			PauseMenu.resume()
	GameState.start_dev_mode()
	await _screen("match")
	await _click(_visible_button("MENU  ≡"))
	await _click(_visible_button("LINEUP"))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not get_tree().paused and get_tree().current_scene.scene_file_path.ends_with("lineup.tscn"), "Dev lineup navigation clears pause")
	_check(GameState.run_active and GameState.dev_mode, "Dev lineup preserves the run")
	print("PAUSE CHECK: %s" % ("ALL CHECKS PASSED" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(1 if failures else 0)


func _screen(id: String) -> void:
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % id)
	await get_tree().process_frame
	await get_tree().process_frame
	if id == "match" and get_tree().current_scene.loading:
		await get_tree().current_scene.ready_to_play


func _escape() -> void:
	await _key(KEY_ESCAPE)


func _key(code: Key) -> void:
	await get_tree().process_frame
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await get_tree().process_frame


func _right_mouse(field: Control, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	event.position = field.get_global_rect().get_center()
	event.global_position = event.position
	Input.parse_input_event(event)
	await get_tree().process_frame


func _visible_button(text: String) -> Button:
	for node in get_tree().root.find_children("*", "Button", true, false):
		if node.text == text and node.is_visible_in_tree():
			return node
	return null


func _press(text: String) -> void:
	var button := _visible_button(text)
	_check(button != null, "%s button available" % text)
	if button != null:
		button.pressed.emit()


func _check(ok: bool, text: String) -> void:
	print("[%s] %s" % ["ok" if ok else "FAIL", text])
	if not ok:
		failures += 1


func _click(button: Button) -> void:
	_check(button != null, "pointer target available")
	if button == null:
		return
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		Input.parse_input_event(event)
		await get_tree().process_frame
