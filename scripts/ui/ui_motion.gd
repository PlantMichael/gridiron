class_name UIMotion
extends Node

## Presentation only: never delays an action or changes a control's layout rect.
## Each effect belongs to its control, so rebuilding a menu cancels its tween.
static var reduced := false
var _target: Control
var _tween: Tween
var _button: Button
var _color := Color.WHITE
var _scale := Vector2.ONE


static func set_reduced(value: bool, tree: SceneTree) -> void:
	reduced = value
	if reduced:
		tree.call_group("ui_motion", "settle")


static func wire_button(button: Button) -> void:
	var effect := UIMotion.new()
	effect._button = button
	effect._target = button
	button.add_child(effect)


static func reveal(control: Control, delay: float = 0.0, lift: bool = true) -> void:
	var effect := control.get_node_or_null("RevealMotion") as UIMotion
	if effect == null:
		effect = UIMotion.new()
		effect.name = "RevealMotion"
		effect._target = control
		control.add_child(effect)
	effect._reveal(delay, lift)


static func enter_screen(root: Control) -> void:
	# Match preparation owns its reveal, after all field textures are ready.
	if root.scene_file_path == "res://scenes/match.tscn":
		return
	var order := 0
	for child in root.get_children():
		if child is Control and not child is ColorRect and child.visible:
			reveal(child, minf(order * 0.04, 0.12))
			order += 1


static func option_button() -> Button:
	var button := UIKit.menu_item("REDUCED MOTION")
	button.toggle_mode = true
	button.button_pressed = reduced
	button.tooltip_text = "Skip menu reveals and animated feedback. Applies for this session."
	button.toggled.connect(func(on: bool): set_reduced(on, button.get_tree()))
	button.visibility_changed.connect(func(): button.set_pressed_no_signal(reduced))
	return button


func _ready() -> void:
	# Pause-menu effects must finish while gameplay is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("ui_motion")
	_color = _target.modulate
	_scale = _target.scale
	if _button == null:
		_target.resized.connect(func(): _target.pivot_offset = _target.size * 0.5)
	if _button != null:
		_button.mouse_entered.connect(_feedback)
		_button.mouse_exited.connect(_feedback)
		_button.focus_entered.connect(_feedback)
		_button.focus_exited.connect(_feedback)
		_button.button_down.connect(func(): _feedback(true))
		_button.button_up.connect(_feedback)
		_button.visibility_changed.connect(settle)


func settle() -> void:
	if _tween != null:
		_tween.kill()
	_target.modulate = _color
	_target.scale = _scale
	if _button != null:
		_button.self_modulate = Color.WHITE


func _reveal(delay: float, lift: bool) -> void:
	settle()
	if reduced:
		return
	_target.modulate = Color(_color, 0.0)
	_target.pivot_offset = _target.size * 0.5
	if lift:
		_target.scale = _scale * 0.97
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_interval(delay)
	_tween.tween_property(_target, "modulate", _color, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_target, "scale", _scale, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _feedback(down: bool = false) -> void:
	if _tween != null:
		_tween.kill()
	var tint := Color.WHITE
	if not reduced and not _button.disabled:
		if down:
			tint = Color(0.80, 0.80, 0.80)
		elif _button.is_hovered() or _button.has_focus():
			tint = Color(1.12, 1.12, 1.12)
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_property(_button, "self_modulate", tint, 0.08 if down else 0.14)
