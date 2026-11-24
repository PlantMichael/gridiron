class_name MatchIntro
extends Control

## A scene-owned broadcast bumper. Simulation stays gated by match.loading;
## a skip consumes its input and completes the same cleanup as the timeline.
signal completed
var done := false
var _field: Control
var _home: PanelContainer
var _away: PanelContainer
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
	var height := clampf(size.y * 0.22, 168.0, 180.0)
	var y := size.y * 0.47 - height * 0.5
	var rebound := 38.0 * _recoil
	var home_x := lerpf(-width - 48.0, size.x * 0.5 - width, _home_approach) - rebound * 1.35
	var away_x := lerpf(size.x + 48.0, size.x * 0.5, _approach) + rebound
	_home.position = Vector2(lerpf(home_x, -width - 80.0, _departure), y)
	_away.position = Vector2(lerpf(away_x, size.x + 80.0, _departure), y)
	for plate in [_home, _away]:
		plate.size = Vector2(width, height)
		plate.pivot_offset = plate.size * 0.5
		var name_label := plate.find_child("TeamName", true, false) as Label
		var font_size := int(clampf(width * 0.105, 24.0, 50.0))
		if name_label.get_theme_font_size("font_size") != font_size:
			name_label.add_theme_font_size_override("font_size", font_size)
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


func _plate(team: String, side: String, color: Color) -> PanelContainer:
	var plate := PanelContainer.new()
	var style := UIKit.stylebox(UIKit.PANEL, 4, 3, color)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 14
	plate.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	plate.add_child(column)
	var tag := UIKit.label(side, 14, color.lightened(0.2))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tag)
	var name_label := UIKit.label(team.to_upper(), 50, UIKit.TEXT)
	name_label.name = "TeamName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name_label)
	return plate
