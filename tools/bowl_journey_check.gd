extends Node
## Journey, route effects and the actual QB→match→USA→road-match handoff.
var failures := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()
func _run() -> void:
	get_tree().root.size=Vector2i(1440,900)
	_routes()
	_modifiers()
	_weather()
	_vegas()
	_police()
	await _ui_flow()
	print("BOWL JOURNEY CHECK: ","ALL CHECKS PASSED" if failures==0 else "%d FAILURES" % failures)
	get_tree().quit(0 if failures==0 else 1)
func _check(ok: bool, text: String) -> void:
	print("[ok] " if ok else "[FAIL] ",text)
	if not ok:
		failures+=1
func _routes() -> void:
	for city in Generator.TEAM_CITIES:
		_check(BowlDB.home_city(city+" "+Generator.TEAM_MASCOTS[0])==city,"home origin "+city)
	for id in BowlDB.all_ids():
		GameState.new_run(17001,0)
		_check(not GameState.choose_destination(id),"destination blocked before opener")
		GameState.select_match(0,0)
		GameState.finish_match(false)
		var money := GameState.bucks
		var roster := GameState.roster.duplicate()
		_check(GameState.needs_bowl_choice() and GameState.reachable().is_empty(),"opener loss leads to destination choice")
		_check(GameState.choose_destination(id),"choose "+id)
		_check(GameState.losses==1 and GameState.bucks==money and GameState.roster==roster and GameState.current_node().result=="L","choosing preserves progress")
		var rng_before := GameState.rng.state
		_check(not GameState.choose_destination(id) and not GameState.choose_destination("missing") and GameState.rng.state==rng_before,"duplicate/invalid selection is inert")
		for r in range(1,GameState.BOWL_ROW+1):
			_check(GameState.run_map[r].size()<=2,"compact route row %d" % r)
			var choices := GameState.reachable()
			_check(not choices.is_empty(),"unlocked continuation at row%d" % r)
			if choices.is_empty():
				break
			var at := choices[0]
			var node := GameState.map_node(at.x,at.y)
			if GameState.is_match_stop(node.type):
				GameState.select_match(at.x,at.y)
				_check(GameState.current_field_theme()==BowlDB.route(id).theme,"selected route owns match field")
				if r==GameState.BOWL_ROW:
					_check(GameState.is_bowl_match() and GameState.current_opponent().bowl_id==id and GameState.match_win_bonus()==BowlDB.win_bonus(id),"only selected bowl supplies final identity/payout")
				GameState.finish_match(true)
			else:
				GameState.enter_stop(at.x,at.y)
		_check(GameState.run_complete and GameState.bowl_won and GameState.matches_played==5,"five-match route completes "+id)
		MetaState.award_mark(0,id)
	var old_marks := MetaState.marks.duplicate(true)
	MetaState.marks.clear()
	MetaState._load()
	_check(MetaState.marks==old_marks and MetaState.has_mark(0,"gleech_bowl"),"all stable bowl completion ids survive actual save/reload")
	GameState.new_run(17002)
	GameState.select_match(0,0)
	GameState.finish_match(false,true)
	_check(GameState.needs_bowl_choice() and GameState.losses==0,"tied opener still permits choice")
	GameState.choose_destination("toilet_bowl")
	GameState.losses=2
	GameState.enter_stop(1,0)
	GameState.select_match(2,0)
	GameState.finish_match(false)
	_check(not GameState.run_active,"third loss still ends the season")
	for id in BowlDB.all_ids():
		var pool := DriveEventDB.pool_for_bowl(id)
		for event in DriveEventDB.GENERIC:
			_check(pool.has(event),"route retains generic event "+event)
		for event in BowlDB.route(id).events:
			_check(pool.has(event),"route includes "+event)
		for i in 8:
			var weather := WeatherDB.roll_for_bowl(GameState.rng,id)
			_check(weather==WeatherDB.CLEAR or BowlDB.route(id).weather.has(weather),"route forecast stays eligible")
func _make(event: String="", weather: String=WeatherDB.CLEAR) -> MatchSim:
	GameState.new_run(17011)
	for p in GameState.roster:
		p.ability_id=""
		p.items.clear()
		for key in PlayerData.STAT_KEYS:
			p.set(key,8)
	var defenders := Generator.make_defense(GameState.rng,8.0,0)
	for p in defenders:
		p.ability_id=""
		p.aura_id=""
		for key in PlayerData.STAT_KEYS:
			p.set(key,8)
	var s := MatchSim.new()
	s.setup(GameState.starters(),defenders,8.0,"Test",4,7711)
	s.set_kicker(GameState.kicker())
	s.set_weather(weather)
	s.start_match()
	s.set_drive_event(event)
	s.set_drawn_call({})
	return s
func _modifiers() -> void:
	var s := _make(DriveEventDB.PULSE)
	s.score_them=7
	s.set_drawn_call({})
	s.snap()
	_check(s.offense_slot("C").stat("strength")==9 and s.defense[0].stat("strength")==8 and s._kicker_stat("strength")==9,"Pulse boosts losing offense and actual kicker")
	s.phase=MatchSim.Phase.PRESNAP
	s.score_us=14
	s.set_drawn_call({})
	s.snap()
	_check(s.defense[0].stat("strength")==9 and s.offense_slot("C").stat("strength")==8,"Pulse follows losing defense")
	s.phase=MatchSim.Phase.PRESNAP
	s.score_them=14
	s.set_drawn_call({})
	s.snap()
	_check(s.defense[0].stat("strength")==8 and s.offense_slot("C").stat("strength")==8,"tied Pulse gives no boost")
	s.phase=MatchSim.Phase.PRESNAP
	s.set_drawn_call({})
	s.set_drive_event(DriveEventDB.AD_BREAK)
	for i in 3:
		s.set_drawn_call({})
	_check(s.offense_slot("C").stat("stamina")==7 and s.defense[0].stat("intelligence")==7 and s._kicker_stat("dexterity")==7,"Ad Break applies once to both teams and actual kicker")
	_check(s.offense_slot("C").data.stamina==8,"drive effects do not change player cards")
	s.begin_drive()
	s.set_drawn_call({})
	_check(s.offense_slot("C").stat("stamina")==8,"next drive removes Ad Break")
	for fixture in [[DriveEventDB.AD_BREAK,1,1],[DriveEventDB.PULSE,15,15]]:
		var capped := _make(fixture[0])
		capped.score_them=7
		capped.offense_slot("C").data.strength=fixture[1]
		capped.kicker_sp.data.strength=fixture[1]
		capped.set_drawn_call({})
		capped.snap()
		_check(capped.offense_slot("C").stat("strength")==fixture[2] and capped._kicker_stat("strength")==fixture[2],"route effects respect normal stat caps")
func _weather() -> void:
	var hot := _make("",WeatherDB.HEAT)
	hot.offense_slot("F0").data.ability_id="weatherproof"
	hot.set_drawn_call({})
	hot.snap()
	_check(hot.offense_slot("C").stat("stamina")==6 and hot.defense[0].stat("stamina")==6 and hot.offense_slot("F0").stat("stamina")==8,"Heat respects stamina and Weatherproof")
	var storm := _make("",WeatherDB.HURRICANE)
	var clear := _make()
	for s in [storm,clear]:
		s.offense_slot("F0").data.ability_id="weatherproof"
		s.set_drawn_call({})
		s.snap()
	storm.step(0.02)
	clear.step(0.02)
	_check(storm.offense_slot("F0").pos.is_equal_approx(clear.offense_slot("F0").pos),"Weatherproof receives no added Hurricane displacement")
	_check(storm.offense_slot("F4").pos.distance_to(clear.offense_slot("F4").pos)>0.001,"ordinary player is displaced by Hurricane")
	_check(storm.ball_pos.is_equal_approx(storm.carrier.pos),"gusted carrier keeps the ball attached")
	storm.offense_slot("F4").pos.y=MatchSim.FIELD_W-0.301
	storm.step(0.02)
	_check(storm.offense_slot("F4").pos.y<=MatchSim.FIELD_W-0.3,"gusts respect playable boundaries")
func _vegas() -> void:
	for defense_recovers in [false,true]:
		var s := _make(DriveEventDB.VEGAS)
		s.set_planned_action("scramble")
		s.snap()
		for d in s.defense:
			d.pos=Vector2(109,49)
			d.stunned=100
		var runner := s.carrier
		for i in 500:
			s.step(1.0/120.0)
			if s.vegas_loose_left>0 or s.phase!=MatchSim.Phase.LIVE:
				break
		_check(s.vegas_loose_left>0 and s._vegas_yards>=10 and s._vegas_yards<10.2 and not runner.has_ball,"Vegas drops after ten carried yards in actual live movement")
		var drop := s.ball_pos
		for p in s.offense+s.defense:
			if p!=runner:
				p.pos=drop+Vector2(25,0)
				p.stunned=0
		var recoverer: SimPlayer = s.defense[0] if defense_recovers else s.offense_slot("C")
		recoverer.pos=drop+Vector2(0.2,0)
		for i in 80:
			s.step(1.0/120.0)
			if s.phase!=MatchSim.Phase.LIVE:
				break
		_check(s.phase==MatchSim.Phase.DEAD and bool(s.result.get("fumble",false)) and bool(s.result.turnover)==defense_recovers,"nearest team recovers loose ball with correct possession outcome")
		_check(is_equal_approx(float(s.stat_line_for(runner.data).get("rush_yards",0)),float(s.result.yards)),"fumble retains carrier yardage credit")
		var los := s.los
		var yards: float = s.result.yards
		s.advance()
		_check((s.phase==MatchSim.Phase.DRIVE_OVER) if defense_recovers else (s.phase==MatchSim.Phase.PRESNAP and is_equal_approx(s.los,los+yards)),"recovery advances the existing down/drive boundary")
		s.set_drawn_call({})
		_check(not s._vegas_fired and s.vegas_loose_left==0,"next call clears all fumble state")
	var pass_sim := _make(DriveEventDB.VEGAS)
	var receiver := pass_sim.offense_slot("F0")
	receiver.data.ability_id="cant_miss"
	pass_sim.offense_slot("QB").data.ability_id="twohands_aim"
	pass_sim.set_drawn_call({})
	pass_sim.snap()
	for d in pass_sim.defense:
		d.pos=Vector2(109,49)
		d.stunned=100
	receiver.pos=Vector2(pass_sim.los+25,10)
	receiver.route=[receiver.pos]
	receiver.route_idx=0
	receiver.vel=Vector2.ZERO
	pass_sim._throw(pass_sim.carrier,receiver)
	for i in 400:
		pass_sim.step(1.0/120.0)
		if pass_sim.carrier==receiver or pass_sim.phase!=MatchSim.Phase.LIVE:
			break
	_check(pass_sim.carrier==receiver and not pass_sim._vegas_fired and pass_sim._vegas_yards<1,"air yards and pre-catch route distance do not trigger Vegas")
func _police() -> void:
	var s := _make(DriveEventDB.POLICE)
	for drive in 3:
		if drive>0:
			s.begin_drive()
			s.set_drive_event(DriveEventDB.POLICE)
			s.set_drawn_call({})
		s.snap()
		s.time=2.19
		s.step(0.02)
		_check(s.police_uses==mini(drive+1,2),"police cap on drive%d" % drive)
		if drive<2:
			_check(s.defense[0].stunned>0 and s.phase==MatchSim.Phase.LIVE and s.down==1,"investigation distracts defense without cancelling play/down")
			s.set_drawn_call({})
			s.snap()
			s.time=2.19
			s.step(0.02)
			_check(s.police_uses==drive+1,"another snap cannot repeat investigation in same drive")
	s.configure_drive_events(10,"toilet_bowl")
	var exhausted := true
	for i in 30:
		s.begin_drive()
		exhausted = exhausted and s.drive_event!=DriveEventDB.POLICE
	_check(exhausted,"automatic rolls exclude police after the match cap")
	var kick := _make(DriveEventDB.POLICE)
	kick.set_kick_mode(true)
	kick.snap()
	kick.time=2.3
	kick.step(0.02)
	_check(kick.police_uses==0,"police does not interrupt a kick")
func _ui_flow() -> void:
	await _screen("qb_select")
	await _click(_button("SELECT"))
	await _ready_match()
	var opening := get_tree().current_scene
	_check(opening.scene_file_path.ends_with("match.tscn") and opening.sim.field_theme=="practice" and GameState.target_row==0,"actual QB selection loads practice opener")
	opening.sim.score_us=7
	opening.sim.score_them=0
	opening._begin_match_end()
	var completed := GameState.matches_played
	opening._begin_match_end()
	_check(GameState.matches_played==completed,"end-of-match handoff banks result once")
	opening._leave_match()
	await get_tree().process_frame
	await get_tree().process_frame
	var destination: Button = get_tree().current_scene.find_child("Destination_alligator_bowl",true,false)
	_check(destination!=null,"actual hub presents bowl choices after opener")
	if destination!=null:
		destination.grab_focus()
		await _key(KEY_ENTER)
	for i in 4:
		await get_tree().process_frame
	_check(GameState.chosen_bowl=="alligator_bowl","keyboard activates native destination control")
	var hub := get_tree().current_scene
	await _click(hub.find_child("Stop_1_0",true,false))
	await _click(_button("GO THERE"))
	await get_tree().process_frame
	await _screen("hub")
	hub=get_tree().current_scene
	await _click(hub.find_child("Stop_2_0",true,false))
	await _click(_button("KICKOFF"))
	await _ready_match()
	var road := get_tree().current_scene
	_check(road.sim.field_theme=="beach" and road.sim._drive_event_pool.has(DriveEventDB.AD_BREAK) and road.sim._drive_event_pool.has(DriveEventDB.OIL),"route kickoff loads real themed field with mixed event pool")
	_check(road.field.sidelines.warm_resources(road.sim),"new venue preserves warmed NPC resources")
func _screen(id: String) -> void:
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % id)
	for i in 6:
		await get_tree().process_frame
func _ready_match() -> void:
	for i in 600:
		if get_tree().current_scene!=null and get_tree().current_scene.scene_file_path.ends_with("match.tscn") and not LoadingScreen.active:
			return
		await get_tree().process_frame
	_check(false,"match readiness deadline")
func _button(text: String) -> Button:
	for b in get_tree().root.find_children("*","Button",true,false):
		if b.is_visible_in_tree() and b.text.strip_edges()==text:
			return b
	return null
func _click(b: Button) -> void:
	_check(b!=null,"pointer target exists")
	if b==null:
		return
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=b.get_global_rect().get_center()
		event.global_position=event.position
		Input.parse_input_event(event)
		for i in 4:
			await get_tree().process_frame
func _key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code
		event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
