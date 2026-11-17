extends CanvasLayer

## Shared gameplay menu. The tree stays paused until Resume or navigation.
signal opening
const MAIN_MENU := "res://scenes/main_menu.tscn"
var _shade: ColorRect
var _actions: VBoxContainer
var _match_actions: VBoxContainer
var _confirm: VBoxContainer
var _resume_button: Button
var _cancel_button: Button
var _main_button: Button
var _previous_focus: Control
var _quit_game := false
var _hint: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build()
	hide()

func _input(event: InputEvent) -> void:
	if LoadingScreen.active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if visible:
			if _confirm.visible:
				_show_actions()
			else:
				resume()
		else:
			open()
		if visible or get_tree().current_scene != null and get_tree().current_scene.scene_file_path != MAIN_MENU:
			get_viewport().set_input_as_handled()

func open() -> void:
	var scene := get_tree().current_scene
	if LoadingScreen.active or visible or scene == null or scene.scene_file_path == MAIN_MENU:
		return
	_previous_focus = get_viewport().gui_get_focus_owner()
	_build_match_actions(scene)
	opening.emit()
	get_tree().paused = true
	show()
	_show_actions()

func resume() -> void:
	hide()
	get_tree().paused = false
	_clear_match_actions()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	else:
		_resume_button.release_focus()
	_previous_focus = null

func _build() -> void:
	_shade = ColorRect.new()
	_shade.theme = UIKit.menu_theme()
	_shade.color = Color(UIKit.BG, 0.88)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.add_child(center)
	var panel := UIKit.menu_panel()
	panel.custom_minimum_size.x = 408
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(UIKit.label("GRIDIRON  /  MENU", 26, UIKit.TEXT))
	_hint = UIKit.label("", 14, UIKit.MUTED)
	column.add_child(_hint)
	column.add_child(UIKit.rule())
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 4)
	column.add_child(_actions)
	_resume_button = _button("RESUME", resume, true)
	_actions.add_child(_resume_button)
	_match_actions = VBoxContainer.new()
	_match_actions.add_theme_constant_override("separation", 4)
	_actions.add_child(_match_actions)
	_main_button = _button("MAIN MENU", _ask_leave)
	_actions.add_child(_main_button)
	if not OS.has_feature("web"):
		_actions.add_child(_button("QUIT GAME", func(): _ask_leave(true)))
	_confirm = VBoxContainer.new()
	_confirm.add_theme_constant_override("separation", 8)
	column.add_child(_confirm)
	var warning := UIKit.label("Leaving ends this run.\nOnly bowl completion marks are saved.", 18, UIKit.TEXT)
	_confirm.add_child(warning)
	_cancel_button = _button("BACK", _show_actions, true)
	_confirm.add_child(_cancel_button)
	_confirm.add_child(_button("LEAVE RUN", _leave))
	_trap_focus(_confirm)

func _button(text: String, action: Callable, primary: bool = false) -> Button:
	var b := UIKit.menu_item(text, primary)
	b.pressed.connect(action)
	return b

func _clear_match_actions() -> void:
	for c in _match_actions.get_children():
		_match_actions.remove_child(c)
		c.queue_free()

func _build_match_actions(scene: Node) -> void:
	_clear_match_actions()
	_main_button.text = "EXIT DEV MODE" if GameState.dev_mode else "MAIN MENU"
	if scene.scene_file_path != "res://scenes/match.tscn":
		_trap_focus(_actions)
		return
	_match_actions.add_child(UIKit.vsep(6))
	_match_actions.add_child(UIKit.label("GAME SPEED", 12, UIKit.MUTED))
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 0)
	_match_actions.add_child(speeds)
	var group := ButtonGroup.new()
	for value in [0.5, 1.0, 2.0, 4.0]:
		var b := UIKit.button("%sx" % ("0.5" if value == 0.5 else str(int(value))), 18)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = is_equal_approx(scene.speed, value)
		b.custom_minimum_size.y = 40
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): scene.speed = value)
		speeds.add_child(b)
	_match_actions.add_child(UIKit.vsep(6))
	var camera := _button(_camera_text(scene), func():
		scene.field.toggle_camera_lock()
		_update_camera_text(scene))
	camera.name = "CameraSetting"
	_match_actions.add_child(camera)
	_match_actions.add_child(_button("TEAM STATS", func():
		resume()
		scene._open_team_stats()))
	if GameState.dev_mode:
		_match_actions.add_child(_button("LINEUP", func():
			resume()
			get_tree().change_scene_to_file("res://scenes/lineup.tscn")))
	_match_actions.add_child(UIKit.rule())
	_trap_focus(_actions)

func _camera_text(scene: Node) -> String:
	return "CAMERA    FOLLOW BALL" if scene.field.camera_locked else "CAMERA    FREE"

func _update_camera_text(scene: Node) -> void:
	_match_actions.get_node("CameraSetting").text = _camera_text(scene)

func _buttons(group: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	for c in group.get_children():
		if c is Button:
			buttons.append(c)
		else:
			buttons.append_array(_buttons(c))
	return buttons

func _trap_focus(group: Node) -> void:
	var buttons := _buttons(group)
	for i in buttons.size():
		var b := buttons[i]
		b.focus_neighbor_top = b.get_path_to(buttons[posmod(i - 1, buttons.size())])
		b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 1) % buttons.size()])
		b.focus_previous = b.focus_neighbor_top
		b.focus_next = b.focus_neighbor_bottom
		b.focus_neighbor_left = b.focus_neighbor_top
		b.focus_neighbor_right = b.focus_neighbor_bottom

func _show_actions() -> void:
	_hint.text = "GAME PAUSED  /  ESC TO RESUME"
	_confirm.hide()
	_actions.show()
	_resume_button.grab_focus()

func _ask_leave(quit_game: bool = false) -> void:
	_hint.text = "LEAVE RUN  /  ESC TO GO BACK"
	_quit_game = quit_game
	_actions.hide()
	_confirm.show()
	_cancel_button.grab_focus()

func _leave() -> void:
	if _quit_game:
		get_tree().quit()
		return
	var error := get_tree().change_scene_to_file(MAIN_MENU)
	if error == OK:
		GameState.run_active = false
		_previous_focus = null
		resume()
	else:
		push_error("PauseMenu: could not return to main menu (%s)" % error)
