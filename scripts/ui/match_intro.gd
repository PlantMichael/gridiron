class_name MatchIntro
extends Control

## A scene-owned broadcast bumper. Simulation stays gated by match.loading;
## a skip consumes its input and completes the same cleanup as the timeline.
signal completed
var done := false
var _field: Control
var _home: TeamBanner
var _away: TeamBanner
var _versus: Label
var _caption: Label
var _hint: Label
var _veil: ColorRect
var _motion: Tween
var _home_approach := 0.0
var _approach := 0.0
var _recoil := 0.0
var _departure := 0.0
var _impact := 0.0


class TeamBanner extends Control:
	var team_color: Color
	var visitor: bool
	var _name_label: Label
	var _side_label: Label
	var _text: VBoxContainer

	func _init(team: String, side: String, color: Color) -> void:
		team_color = color
		visitor = side == "VISITOR"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_side_label = UIKit.label("VISITOR" if visitor else "YOUR TEAM", 14, UIKit.ACCENT)
		_name_label = UIKit.outlined(UIKit.label(team.to_upper(), 44, UIKit.TEXT), 3)
		_name_label.name = "TeamName"
		_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_name_label.max_lines_visible = 2
		_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_text = VBoxContainer.new()
		_text.alignment = BoxContainer.ALIGNMENT_CENTER
		_text.add_theme_constant_override("separation", 2)
		_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_text)
		for label in [_side_label, _name_label]:
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if visitor else HORIZONTAL_ALIGNMENT_LEFT
			_text.add_child(label)
		resized.connect(_fit_text)

	func _fit_text() -> void:
		var helmet_width := 200.0 * size.y / 220.0
		var text_width := maxf(50.0, size.x - helmet_width - 34.0)
		var x := helmet_width + 8.0 if visitor else 26.0
		var font := _name_label.get_theme_font("font")
		var font_size := int(clampf(size.x * 0.086, 22.0, 44.0))
		while font_size > 22 and font.get_multiline_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size).y > minf(size.y * 0.48, font.get_height(font_size) * 2.05):
			font_size -= 1
		_name_label.add_theme_font_size_override("font_size", font_size)
		_text.position = Vector2(x, size.y * 0.26)
		_text.size = Vector2(text_width, size.y * 0.59)
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var w := size.x
		# Cut fabric tails and a tapered leading edge, rather than a panel rim.
		var pennant := PackedVector2Array([Vector2(0, h * 0.20), Vector2(w, h * 0.26),
			Vector2(w, h * 0.82), Vector2(0, h * 0.92), Vector2(24, h * 0.56)])
		if visitor:
			for i in pennant.size():
				pennant[i].x = w - pennant[i].x
		draw_colored_polygon(pennant, team_color.darkened(0.68))
		draw_polyline(pennant + PackedVector2Array([pennant[0]]), UIKit.BG, 8.0, true)
		var start := Vector2(28, h * 0.24)
		var end := Vector2(w - 28, h * 0.29)
		if visitor:
			start.x = w - start.x
			end.x = w - end.x
		draw_line(start, end, team_color, 7.0, true)
		draw_dashed_line(start + Vector2(0, 10), end + Vector2(0, 10), Color(UIKit.CHALK, 0.20), 1.0, 6.0, true)
		draw_dashed_line(Vector2(28, h * 0.85), Vector2(w - 28, h * 0.80), Color(UIKit.CHALK, 0.20), 1.0, 6.0, true)
		# Mirror only the helmet so both face the collision; lettering stays upright.
		var s := h / 220.0
		var origin := Vector2(200.0 * s if visitor else w - 200.0 * s, h * 0.08)
		draw_set_transform(origin, 0.0, Vector2(-s if visitor else s, s))
		var shell := PackedVector2Array()
		for i in 17:
			var angle := PI + PI * float(i) / 16.0
			shell.append(Vector2(94, 94) + Vector2(cos(angle) * 78, sin(angle) * 78))
		shell.append_array(PackedVector2Array([Vector2(163, 118), Vector2(126, 155), Vector2(57, 153), Vector2(22, 126)]))
		draw_colored_polygon(shell, team_color)
		draw_polyline(shell + PackedVector2Array([shell[0]]), UIKit.BG, 9.0, true)
		# Painted crown stripes, dark face opening and padded ear hole.
		draw_polyline(PackedVector2Array([Vector2(75, 19), Vector2(83, 45), Vector2(88, 77)]), UIKit.CHALK, 12.0, true)
		draw_polyline(PackedVector2Array([Vector2(58, 25), Vector2(65, 49), Vector2(69, 71)]), Color(UIKit.CHALK, 0.55), 4.0, true)
		var opening := PackedVector2Array([Vector2(140, 72), Vector2(169, 90), Vector2(160, 120), Vector2(130, 139), Vector2(119, 116)])
		draw_colored_polygon(opening, UIKit.BG)
		draw_circle(Vector2(75, 111), 17.0, team_color.darkened(0.35))
		draw_arc(Vector2(75, 111), 17, 0, TAU, 24, UIKit.BG, 4.0, true)
		draw_circle(Vector2(75, 111), 6.0, UIKit.BG)
		# Heavy cage reaches the exact leading edge of the banner at impact.
		var cage := PackedVector2Array([Vector2(143, 87), Vector2(195, 103), Vector2(195, 139), Vector2(137, 150), Vector2(126, 130)])
		draw_polyline(cage, UIKit.BG, 14.0, true)
		draw_polyline(cage, UIKit.CHALK.darkened(0.18), 6.0, true)
		for bar in [PackedVector2Array([Vector2(141, 111), Vector2(195, 115)]),
				PackedVector2Array([Vector2(173, 99), Vector2(172, 143)])]:
			draw_polyline(bar, UIKit.BG, 11.0, true)
			draw_polyline(bar, UIKit.CHALK.darkened(0.18), 4.0, true)
		draw_circle(Vector2(126, 144), 7.0, UIKit.CHALK.darkened(0.25))
		draw_set_transform(Vector2.ZERO)


func _init(home: String = "", away: String = "", away_color: Color = UIKit.ACCENT) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	_veil = ColorRect.new()
	_veil.color = Color(UIKit.BG, 0.88)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	_home = _plate(home, "HOME", JerseyDB.score_color(JerseyDB.BLUE))
	_away = _plate(away, "VISITOR", away_color)
	add_child(_home)
	add_child(_away)
	_versus = UIKit.outlined(UIKit.label("VS", 52, UIKit.ACCENT))
	_versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_versus.modulate.a = 0.0
	add_child(_versus)
	_caption = UIKit.label("GRIDIRON  /  MATCH DAY", 20, UIKit.MUTED)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_caption)
	_hint = UIKit.label("ENTER / SPACE / CLICK TO SKIP", 14, UIKit.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)


func _ready() -> void:
	add_to_group("ui_motion")
	_layout()


func play(field: Control) -> void:
	_field = field
	if UIMotion.reduced:
		settle()
		return
	_field.intro_zoom = 0.68
	_motion = create_tween().set_ignore_time_scale(true)
	_motion.tween_property(self, "_home_approach", 1.0, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_interval(0.16)
	_motion.tween_property(self, "_approach", 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_motion.tween_callback(func(): _impact = 1.0)
	_motion.tween_property(self, "_recoil", 1.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion.parallel().tween_property(self, "_impact", 0.0, 0.28)
	_motion.parallel().tween_property(_versus, "modulate:a", 1.0, 0.10)
	_motion.tween_property(self, "_recoil", 0.45, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_interval(0.32)
	_motion.tween_property(self, "_departure", 1.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion.parallel().tween_property(_versus, "modulate:a", 0.0, 0.18)
	_motion.tween_property(_field, "intro_zoom", 1.0, 0.60).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_motion.parallel().tween_property(_veil, "modulate:a", 0.0, 0.60)
	_motion.tween_callback(settle)
	await completed


func settle() -> void:
	if done:
		return
	done = true
	if _motion != null:
		_motion.kill()
	if is_instance_valid(_field):
		_field.intro_zoom = 1.0
	hide()
	completed.emit()


func _input(event: InputEvent) -> void:
	if done:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		settle()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		settle()
	# Consume even the skip press; it must never also snap, pan or draw a route.
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_layout()
	queue_redraw()


func _layout() -> void:
	var width := minf(500.0, size.x * 0.42)
	var height := clampf(size.y * 0.26, 204.0, 236.0)
	var y := size.y * 0.47 - height * 0.5
	var rebound := 38.0 * _recoil
	var home_x := lerpf(-width - 48.0, size.x * 0.5 - width, _home_approach) - rebound * 1.35
	var away_x := lerpf(size.x + 48.0, size.x * 0.5, _approach) + rebound
	_home.position = Vector2(lerpf(home_x, -width - 80.0, _departure), y)
	_away.position = Vector2(lerpf(away_x, size.x + 80.0, _departure), y)
	for plate in [_home, _away]:
		plate.size = Vector2(width, height)
		plate.pivot_offset = plate.size * 0.5
	_home.rotation = -0.025 * _recoil * (1.0 - _departure)
	_away.rotation = 0.025 * _recoil * (1.0 - _departure)
	_versus.position = Vector2(size.x * 0.5 - 60.0, y + height * 0.5 - 42.0)
	_versus.size = Vector2(120, 84)
	_caption.position = Vector2(0, y - 68.0)
	_caption.size.x = size.x
	_hint.position = Vector2(0, y + height + 50.0)
	_hint.size.x = size.x
	_caption.modulate.a = 1.0 - _departure
	_hint.modulate.a = 1.0 - _departure


func _draw() -> void:
	if _impact <= 0.0:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.47)
	for i in 8:
		var direction := Vector2.from_angle(float(i) * TAU / 8.0)
		draw_line(center + direction * 54.0, center + direction * (82.0 + (1.0 - _impact) * 42.0),
			Color(UIKit.ACCENT, _impact), 3.0, true)


func _plate(team: String, side: String, color: Color) -> TeamBanner:
	return TeamBanner.new(team, side, color)
