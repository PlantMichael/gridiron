extends Node

## Real drive, movement, modifier and match-screen boundaries.
## godot --headless --path . res://tools/drive_event_check.tscn
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_extra_defender()
	_rolls()
	_oil()
	_aura()
	_bottles()
	await _screen_flow()
	print("DRIVE EVENT CHECK: %s" % ("ALL CHECKS PASSED" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _make(depth: int = -1) -> MatchSim:
	GameState.new_run(91031)
	for p in GameState.roster:
		p.ability_id = ""
		for key in PlayerData.STAT_KEYS:
			p.set(key, 8)
	var s := MatchSim.new()
	s.setup(GameState.starters(), Generator.make_defense(GameState.rng, 5.0), 5.0, "Test defense", 4, 2981)
	s.set_kicker(GameState.kicker())
	if depth >= 0:
		s.configure_drive_events(depth)
	s.start_match()
	s.set_drawn_call({})
	return s


func _extra_defender() -> void:
	var s := _make()
	var original := s.defense.map(func(d): return d.data)
	s.set_drive_event(DriveEventDB.EXTRA_DEFENDER)
	s.set_drawn_call({})
	_check(s.defense.size() == 12 and s.defense.back().role == SimPlayer.Role.ZONE,
		"extra linebacker takes real shallow-zone assignment")
	var d: SimPlayer = s.defense.back()
	var at := d.pos
	s.snap()
	s.step(1.0 / 60.0)
	_check(d.pos != at, "extra defender participates in live movement")
	s.set_drawn_call({}, false)
	_check(s.defense.size() == 12 and s.defense.map(func(p): return p.data).slice(0, 11) == original,
		"route redraw retains exactly one extra and original base defense")
	s.regenerate_defense(GameState.rng, 6.0)
	_check(s.defense.size() == 12 and s.defense.back().stat("strength") >= 1,
		"Dev regeneration keeps one aligned effective extra defender")
	s.set_kick_mode(true)
	_check(s.defense.size() == 12, "kick unit does not duplicate extra defender")
	s.set_kick_mode(false)
	s.set_drawn_call({})
	var removed: SimPlayer = s.defense.back()
	var ref: WeakRef = weakref(removed)
	s.offense[0].mark = removed
	s.offense[0].synergy["block_target"] = removed
	removed.mark = s.offense[0]
	s.chains.append([removed, s.defense[0], 3.0])
	s.shots.append({"from": s.offense[0], "to": removed})
	s.tackler = removed
	removed = null
	s.begin_drive() # event-disabled standalone sim selects None
	_check(s.defense.size() == 11 and ref.get_ref() == null and s.offense[0].mark == null,
		"next drive removes extra and releases ability/block/visual references")


func _rolls() -> void:
	var low := _make(0)
	var high := _make(7)
	var first_count := 0
	var late_count := 0
	var appeared := {}
	for seed_value in range(1, 201):
		low.rng.seed = seed_value
		high.rng.seed = seed_value
		low.begin_drive()
		high.begin_drive()
		first_count += int(low.drive_event != DriveEventDB.NONE)
		late_count += int(high.drive_event != DriveEventDB.NONE)
		appeared[high.drive_event] = true
	_check(first_count > 0 and first_count < late_count and late_count < 200 and appeared.size() == 5,
		"every drive can roll None or all four events, with higher frequency deeper in run")
	var a := _make(3)
	var b := _make(3)
	for i in 8:
		a.begin_drive()
		b.begin_drive()
		_check(a.drive_event == b.drive_event and a.oil_spills == b.oil_spills,
			"seeded drive sequence reproducible %d" % i)
	var event := a.drive_event
	var oil := a.oil_spills.duplicate(true)
	for i in 3:
		a.set_drawn_call({}, false)
	a.resync_offense(GameState.starters())
	a.set_drawn_call({})
	_check(a.drive_event == event and a.oil_spills == oil, "redraw/substitution does not reroll event")
	a.start_overtime()
	var before := a.drive_num
	a.begin_drive()
	_check(a.drive_num == before + 1 and a.in_overtime and DriveEventDB.ALL.has(a.drive_event),
		"overtime enters the same event lifecycle")


func _oil() -> void:
	var s := _make()
	s.set_drive_event(DriveEventDB.OIL)
	s.set_drawn_call({})
	var patch: Dictionary = s.oil_spills[0]
	var o := s.offense_slot("F0")
	var d := s.defense[7]
	o.pos = patch["pos"]
	d.pos = patch["pos"]
	s._update_terrain()
	var outside := o.max_speed()
	_check(o.speed() < outside and is_equal_approx(o.terrain_mult, d.terrain_mult),
		"oil slows actual speed equally for offense and defense")
	o.vel = Vector2.ZERO
	var at := o.pos
	o.move_toward_point(at + Vector2(10, 0), 0.1)
	var slowed_distance := o.pos.distance_to(at)
	o.pos = at
	o.vel = Vector2.ZERO
	o.terrain_mult = 1.0
	o.move_toward_point(at + Vector2(10, 0), 0.1)
	_check(o.pos.distance_to(at) > slowed_distance, "oil reduces real movement distance")
	o.pos = patch["pos"]
	# Use the real weather-immune producer rather than assume an ability ID.
	for p in ShopPlayerDB.all_players(GameState.rng):
		if AbilityDB.weather_immune(p.ability_id):
			o.data.ability_id = p.ability_id
			break
	_check(AbilityDB.weather_immune(o.ability()), "weather immunity fixture comes from real player data")
	s.puddles = [{"pos": patch["pos"], "r": 5.0, "stretch": 1.0}]
	s._update_terrain()
	_check(is_equal_approx(o.terrain_mult, 0.65) and is_equal_approx(d.terrain_mult, 0.6),
		"weather immunity still slips on oil; rain/oil use stronger slowdown")
	s.begin_drive()
	_check(s.oil_spills.is_empty() and is_equal_approx(o.terrain_mult, 1.0), "next drive clears oil and stale terrain multiplier")


func _aura() -> void:
	var s := _make()
	var p := s.offense_slot("F0").data
	var before := p.agility
	s.add_match_bonus(p, "agility", 2)
	s.set_drive_event(DriveEventDB.AURA)
	s.set_drawn_call({})
	_check(s.offense_slot("F0").stat("agility") == before + 3 and p.agility == before,
		"Aura adds effective team bonus alongside retained map bonus without changing base data")
	var base := s.offense_slot("C").data
	base.strength = 15
	s.set_drawn_call({})
	_check(s.offense_slot("C").stat("strength") == 15, "Aura honors normal stat cap")
	var fresh := Generator.make_player(GameState.rng, PlayerData.Pos.WR, 5.0)
	fresh.ability_id = ""
	var starters := GameState.starters()
	starters[GameState.SLOT_ORDER.find("F0")] = fresh
	s.resync_offense(starters)
	s.set_drawn_call({})
	_check(s.offense_slot("F0").stat("dexterity") == fresh.dexterity + 1,
		"substitute receives Aura for remainder of drive")
	var range_with_aura := s.kick_range()
	s.set_drive_event(DriveEventDB.NONE)
	s.set_drawn_call({})
	_check(s.offense_slot("F0").stat("dexterity") == fresh.dexterity and range_with_aura > s.kick_range(),
		"Aura expires for substitute and actual kicker strength calculation")
	_check(s.match_bonus_for(p).get("agility") == 2 and s.match_bonuses.size() == 1,
		"Aura does not erase or accumulate map-event match bonuses")


func _bottles() -> void:
	var s := _make()
	s.set_drive_event(DriveEventDB.BOTTLES)
	s.set_drawn_call({})
	s.snap()
	# Drive the canonical event owner on its real simulation clock. Movement
	# is proved separately; controlled locations isolate impact vs escape.
	s.time = 0.74
	s.step(0.01)
	_check(s.bottles.size() == 1 and not s.bottles[0]["impacted"], "bottle warns before any impact")
	var target: Vector2 = s.bottles[0]["pos"]
	var hit := s.offense_slot("F0")
	var escaped := s.defense[0]
	hit.pos = target
	escaped.pos = target + Vector2(3, 0)
	s.time += 1.0
	s._step_drive_event()
	_check(hit.stunned == 0.0, "fixed marker gives at least one second to escape")
	s.time += 0.25
	s._step_drive_event()
	_check(hit.stunned > 0.0 and escaped.stunned == 0.0 and hit.pending_events.has("BOTTLE!"),
		"impact stuns players inside marked zone while escape avoids it")
	hit.stunned = 0.0
	s._step_drive_event()
	_check(hit.stunned == 0.0, "one bottle cannot apply impact twice")
	for second in [4.0, 7.0, 10.0, 13.0]:
		s.time = second
		s._step_drive_event()
	_check(s._bottles_thrown == 3, "bottle event caps throws per play")
	s.set_drawn_call({})
	_check(s.bottles.is_empty() and s._bottles_thrown == 0 and s.drive_event == DriveEventDB.BOTTLES,
		"next play clears bottle state but retains drive event")
	s.set_kick_mode(true)
	s.snap()
	s.step(0.1)
	_check(s.bottles.is_empty(), "no bottles are launched during kicks")
	s.begin_drive()
	_check(s.bottles.is_empty() and s.drive_event == DriveEventDB.NONE, "next drive clears bottle event")


func _screen_flow() -> void:
	GameState.new_run(91032)
	GameState.matches_played = 3
	var ui: Node = load("res://scenes/match.tscn").instantiate()
	add_child(ui)
	await ui.ready_to_play
	var s: MatchSim = ui.sim
	_check(s._drive_events_enabled and s.drive_event_depth == 3, "actual match enables events at completed-match depth before opening drive")
	var map_player := s.offense_slot("F0").data
	s.add_match_bonus(map_player, "strength", 2)
	var bonuses := s.match_bonuses.duplicate(true)
	# Use real score/award/end owners; UI processes the dead result's bucks.
	s.set_drive_event(DriveEventDB.NONE)
	s.set_drawn_call({})
	ui._on_snap()
	s.carrier = s.offense_slot("F0")
	s.carrier.has_ball = true
	s.carrier.pos.x = MatchSim.GOAL_LINE + 0.1
	ui._process(1.0 / 120.0)
	var earned: int = ui.bucks_earned
	ui._on_continue()
	await get_tree().process_frame
	_check(s.score_us == 7 and earned > 0 and s.match_bonuses == bonuses,
		"touchdown retains points/bucks and creates no stat reward")
	var next: Button
	for b in ui.find_children("*", "Button", true, false):
		if b.text == "NEXT DRIVE" and b.is_visible_in_tree():
			next = b
	_check(next != null, "touchdown leads straight to usable Next Drive action")
	if next != null:
		next.pressed.emit()
		await get_tree().process_frame
		_check(s.drive_num == 2 and s.phase == MatchSim.Phase.PRESNAP, "Next Drive enters once without reward picker")
	s.set_drive_event(DriveEventDB.BOTTLES)
	ui._apply_call(true)
	ui._on_snap()
	var time_before := s.time
	PauseMenu.open()
	await get_tree().create_timer(0.1, true).timeout
	_check(s.time == time_before and s.bottles.is_empty(), "pause freezes real event clock and warning schedule")
	PauseMenu.resume()
	ui._apply_call(true)
	GameState.dev_mode = true
	ui._refresh_bar()
	await get_tree().process_frame
	var picker: OptionButton = ui._event_picker
	picker.show_popup()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await get_tree().process_frame
	_check(s.phase == MatchSim.Phase.PRESNAP, "Enter in Dev event popup does not snap the play")
	picker.get_popup().hide()
	s.set_drive_event(DriveEventDB.AURA)
	ui._apply_call(true)
	s.set_kick_mode(true)
	ui._refresh_bar()
	for i in 4:
		await get_tree().process_frame
	_check(ui.field.bottom_inset < ui.size.y - ui.TOP_BAR_H - 100,
		"wrapped kick notice leaves a usable field viewport after layout settles")
	ui.queue_free()
	await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("DRIVE EVENT: " + message)
	else:
		print("  PASS: " + message)
