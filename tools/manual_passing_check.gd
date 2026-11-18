extends Node

## Real simulation commands plus native match inputs. Isolate APPDATA when running.
var failures := 0
var screen: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

func _check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		push_error(why)

func _sim(special: String = "", seed: int = 7711) -> MatchSim:
	GameState.new_run(18011)
	var roster := GameState.starters()
	for p in roster:
		p.ability_id = ""
		p.items.clear()
		for stat in ["strength", "agility", "dexterity", "intelligence", "stamina"]:
			p.set(stat, 8)
	if special in ["clones", "overflow"]:
		for i in range(6, 11):
			roster[i] = OddityPlayerDB.make_named(GameState.rng, "Mickey Mitosis")
		if special == "overflow":
			roster[2] = OddityPlayerDB.make_named(GameState.rng, "Ricky Dooper IV")
	elif special == "blocker":
		for p in ShopPlayerDB.all_players(GameState.rng):
			if p.pname == "Manuel Fern":
				roster[6] = p
	var defense := Generator.make_defense(GameState.rng, 8.0, 0)
	for p in defense:
		p.ability_id = ""
		p.aura_id = ""
	var sim := MatchSim.new()
	sim.setup(roster, defense, 8.0, "Test", 4, seed)
	sim.set_drawn_call({})
	sim.auto_passing = false
	sim.snap()
	# Controlled coverage leaves the passing window open; normal throw/flight stays real.
	for d in sim.defense:
		d.pos = Vector2(109, 49)
		d.stunned = 100
	return sim

func _inert(sim: MatchSim, target: SimPlayer, why: String) -> void:
	var before := sim.rng.state
	var flight := sim.ball_in_air
	_check(not sim.request_pass(target) and sim.rng.state == before and sim.ball_in_air == flight, why)

func _run() -> void:
	var sim := _sim()
	for i in 480:
		sim.step(1.0 / 120.0)
	_check(sim.manual_pass_available() and is_equal_approx(sim.time, 4.0), "Manual waits for chosen timing")
	var target := sim.offense_slot("F4")
	target.pos = sim.carrier.pos + Vector2(12, 8)
	target.vel = Vector2.ZERO
	var outsider := SimPlayer.new()
	_inert(sim, outsider, "foreign target is inert")
	target.start_delay = sim.time + 1
	_inert(sim, target, "delayed receiver is inert")
	target.start_delay = 0
	target.melted = true
	_inert(sim, target, "melted receiver is inert")
	target.melted = false
	var near := target.pos
	target.pos = sim.carrier.pos + Vector2(49, 0)
	_inert(sim, target, "out-of-range request is inert")
	target.pos = near
	sim.planned_action = "scramble"
	_inert(sim, target, "planned ground action cannot become a pass")
	sim.planned_action = ""
	sim.carrier.has_ball = false
	_inert(sim, target, "lost possession cannot throw")
	sim.carrier.has_ball = true
	_check(sim.request_pass(target) and sim.thrown_to == target and sim.ball_in_air, "chosen receiver enters existing flight")
	_inert(sim, sim.offense_slot("F0"), "second pass cannot consume RNG")
	for i in 600:
		sim.step(1.0 / 120.0)
		if not sim.ball_in_air:
			break
	_check(not sim.ball_in_air, "manual pass resolves through normal flight")
	_inert(sim, target, "resolved pass cannot be thrown again")
	for i in 3600:
		if sim.phase != MatchSim.Phase.LIVE:
			break
		sim.step(1.0 / 120.0)
	_check(sim.phase == MatchSim.Phase.DEAD and int(sim.stat_line_for(sim.offense_slot("QB").data).get("pass_att", 0)) == 1,
		"normal whistle credits exactly one manual pass attempt")
	sim.advance()
	_check(sim.phase == MatchSim.Phase.PRESNAP and sim.down == 2, "incomplete manual pass advances the down normally")
	var complete := _sim("", 7712)
	for i in 480:
		complete.step(1.0 / 120.0)
	var catcher := complete.offense_slot("F4")
	catcher.pos = complete.carrier.pos + Vector2(12, 8)
	catcher.vel = Vector2.ZERO
	_check(complete.request_pass(catcher), "completion fixture uses the manual command")
	for i in 600:
		complete.step(1.0 / 120.0)
		if not complete.ball_in_air:
			break
	_check(complete.carrier == catcher and catcher.has_ball, "manual flight reaches chosen receiver's possession")
	_inert(complete, complete.offense_slot("F0"), "receiver carrying a catch cannot throw a second pass")
	for i in 3600:
		if complete.phase != MatchSim.Phase.LIVE:
			break
		complete.step(1.0 / 120.0)
	var passing := complete.stat_line_for(complete.offense_slot("QB").data)
	var receiving := complete.stat_line_for(catcher.data)
	_check(int(passing.get("pass_comp", 0)) == 1 and int(receiving.get("rec", 0)) == 1,
		"successful manual play credits one completion and reception")
	_check(bool(complete.result.get("td", false)) and int(passing.get("pass_td", 0)) == 1,
		"manual catch and run retains normal touchdown credit")
	complete.advance()
	_check(complete.phase == MatchSim.Phase.DRIVE_OVER and complete.score_us > 0,
		"completed manual play advances through the normal scoring boundary")
	var auto := _sim()
	auto.auto_passing = true
	for i in 720:
		auto.step(1.0 / 120.0)
		if auto.ball_in_air or auto.phase != MatchSim.Phase.LIVE:
			break
	_check(auto.ball_in_air, "Auto still chooses its own receiver and timing")
	_inert(auto, auto.offense_slot("F0"), "manual command cannot override Auto")
	var blocked := _sim("blocker")
	var blocker := blocked.offense_slot("F0")
	_check(blocker.data.pname == "Manuel Fern" and blocker.role == SimPlayer.Role.BLOCK, "real Enforcer fixture blocks")
	_inert(blocked, blocker, "dedicated blocking flex cannot receive")
	var clones := _sim("clones")
	var targets := clones.passing_targets()
	_check(targets.size() == 10, "five Mitosis originals produce five distinct extra targets")
	if targets.size() == 10:
		for i in 5:
			_check(targets[i] == clones.offense_slot("F%d" % i), "original numbering stays stable")
		var twin := targets[9]
		_check(twin.clone_of != null and twin.data == twin.clone_of.data, "twin is actual shared-data producer")
		_inert(clones, twin, "twin cannot receive during snap delay")
		for i in 144:
			clones.step(1.0 / 120.0)
		_check(clones.passing_targets() == targets and clones.can_manual_pass(twin), "delay expiry retains numbering and enables twin")
		_check(clones.request_pass(twin) and clones.thrown_to == twin, "passing selects exact twin instance")

	get_tree().root.size = Vector2i(1440, 900)
	await _match()
	_check(not screen.sim.auto_passing and screen.bar_host.find_child("Priority_F0", true, false) == null, "Manual default hides priority controls")
	await get_tree().process_frame
	for i in 5:
		var player: SimPlayer = screen.sim.offense_slot("F%d" % i)
		var marker: Button = screen.field.get("_pass_controls")[player].get_node("Throw")
		_check(marker.text == str(i + 1) and marker.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and marker.focus_mode == Control.FOCUS_NONE, "pre-snap number identifies receiver without intercepting chalk input")
	await _key(KEY_1)
	_check(screen.sim.phase == MatchSim.Phase.PRESNAP and not screen.sim.ball_in_air, "pre-snap number keys cannot throw or snap")
	var field: Control = screen.field
	field.set_process(false) # Stable geometry for the native drawing gesture.
	var start: Vector2 = field.to_px(screen.sim.offense_slot("F0").pos)
	var press := InputEventMouseButton.new()
	press.position = start
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = start + Vector2(0, -90)
	motion.relative = Vector2(0, -90)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await get_tree().process_frame
	press = InputEventMouseButton.new()
	press.position = motion.position
	press.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(press)
	await get_tree().process_frame
	_check(GameState.has_route("F0"), "native chalk gesture still stores a route with numbered previews visible")
	field.set_process(true)
	screen.sim.toggle_priority_target("F0")
	var before: int = screen.sim.rng.state
	screen._set_auto_passing(true)
	_check(screen.sim.auto_passing and GameState.auto_passing and screen.sim.rng.state == before, "mode choice retains run state without reroll")
	_check(screen.bar_host.find_child("Priority_F0", true, false) != null, "Auto restores target controls")
	screen._set_auto_passing(false)
	_check(screen.sim.is_priority_target("F0"), "Manual preserves Auto preferences")
	# Effective state persists across actual match construction, then switch back for inputs.
	screen._set_auto_passing(true)
	get_tree().change_scene_to_file("res://scenes/match.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	screen = get_tree().current_scene
	if screen.loading:
		await screen.ready_to_play
	screen.speed = 0.0
	_check(screen.sim.auto_passing, "next match inherits this run's Auto choice")
	screen._set_auto_passing(false)
	await _key(KEY_ENTER)
	_check(screen.sim.phase == MatchSim.Phase.LIVE, "Enter still snaps")
	var live_marker: Button = screen.field.get("_pass_controls")[screen.sim.offense_slot("F0")].get_node("Throw")
	_check(live_marker.text == "1" and live_marker.mouse_filter == Control.MOUSE_FILTER_STOP
		and live_marker.focus_mode == Control.FOCUS_ALL, "receiver keeps its number and gains throw input at the snap")
	await _key(KEY_1, true)
	await _key(KEY_1, false, true)
	_check(not screen.sim.ball_in_air, "echo and modified numeric inputs do not throw")
	PauseMenu.open()
	await _key(KEY_1)
	_check(not screen.sim.ball_in_air, "pause blocks numeric throw")
	PauseMenu.resume()
	screen.side_panel.show()
	await _key(KEY_1)
	_check(not screen.sim.ball_in_air, "open panel blocks numeric throw")
	screen.side_panel.hide()
	await get_tree().process_frame
	await _key(KEY_KP_3)
	_check(screen.sim.ball_in_air and screen.sim.thrown_to == screen.sim.offense_slot("F2"), "keypad chooses exact receiver")
	_check(screen.field.get("_pass_controls").is_empty(), "receiver controls leave after throw")

	await _match()
	await _key(KEY_ENTER)
	var receiver: SimPlayer = screen.sim.offense_slot("F0")
	screen.sim._gain_stat(receiver, "dexterity", 2)
	await get_tree().process_frame
	var host: Control = screen.field.get("_pass_controls")[receiver]
	_check(host.get_node("Dex").text == "DEX %d" % receiver.stat("dexterity"), "DEX follows effective mid-play gains")
	# Freeze the moving camera only for this geometric hit-area check; GUI input stays native.
	screen.field.set_process(false)
	var button: Button = host.get_node("Throw")
	await _click(button.get_global_rect().position + Vector2(1, 1))
	_check(not screen.sim.ball_in_air, "outside circular face does not throw")
	await _click(button.get_global_rect().get_center())
	_check(screen.sim.ball_in_air and screen.sim.thrown_to == receiver, "native circle click throws to chosen instance")

	# Use the real snap producers for a ten-receiver key and an overflow focus target.
	await _match()
	screen.sim = _sim("overflow", 7712)
	screen.field.sim = screen.sim
	screen._refresh_bar()
	await get_tree().process_frame
	var extras: Array[SimPlayer] = screen.sim.passing_targets()
	_check(extras.size() == 11, "rogue lineman plus five Mitosis splits expose eleven targets")
	if extras.size() == 11:
		for i in 144:
			screen.sim.step(1.0 / 120.0)
		await get_tree().process_frame
		await _key(KEY_0)
		_check(screen.sim.thrown_to == extras[9], "zero throws to tenth receiver")
	await _match()
	screen.sim = _sim("overflow", 7712)
	screen.field.sim = screen.sim
	screen._refresh_bar()
	for i in 144:
		screen.sim.step(1.0 / 120.0)
	await get_tree().process_frame
	extras = screen.sim.passing_targets()
	if extras.size() == 11:
		var extra_host: Control = screen.field.get("_pass_controls")[extras[10]]
		extra_host.get_node("Throw").grab_focus()
		await _key(KEY_SPACE)
		_check(screen.sim.thrown_to == extras[10], "receiver beyond numeric hotkeys uses native focus and Space")

	await _match()
	await _key(KEY_ENTER)
	await _key(KEY_5)
	_check(screen.sim.thrown_to == screen.sim.offense_slot("F4"), "top-row key chooses fifth receiver")
	GameState.auto_passing = true
	GameState.new_run(91)
	_check(not GameState.auto_passing, "new run resets to Manual")
	print("MANUAL PASSING CHECK: %s" % ("ALL CHECKS PASSED" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(1 if failures else 0)

func _match() -> void:
	GameState.new_run(99003)
	get_tree().change_scene_to_file("res://scenes/match.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	screen = get_tree().current_scene
	if screen.loading:
		await screen.ready_to_play
	screen.speed = 0.0 # Freeze sim time while real UI/field input owners keep processing.

func _key(code: Key, echo: bool = false, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	event.shift_pressed = shift
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame

func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame
