extends Control

## Title navigation shares the broadcast menu rows used during a run.

func _ready() -> void:
	UIKit.background(self, true)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)

	var ball := CenterContainer.new()
	ball.add_child(_football())
	v.add_child(ball)

	# Varsity lettering: gold, a thick dark outline, and a drop shadow.
	var t := UIKit.label("GRIDIRON", 96, UIKit.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", _spaced(6))
	t.add_theme_constant_override("outline_size", 14)
	t.add_theme_color_override("font_outline_color", Color("1a1206"))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 8)
	t.add_theme_constant_override("shadow_outline_size", 14)
	v.add_child(t)


	v.add_child(UIKit.vsep(12))
	if LoadingScreen.active:
		LoadingScreen.update_progress(1.0, "Ready")
		LoadingScreen.finish_after_frame()

	var panel := UIKit.menu_panel()
	panel.custom_minimum_size.x = 360
	v.add_child(panel)
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 4)
	panel.add_child(options)
	var play := UIKit.menu_item("PLAY", true)
	play.pressed.connect(_on_new_run)
	options.add_child(play)

	var dev := UIKit.menu_item("DEV MODE")
	dev.pressed.connect(_on_dev_mode)
	options.add_child(dev)

	var book := UIKit.menu_item("PLAYER BOOK")
	book.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/player_book.tscn"))
	options.add_child(book)
	options.add_child(UIMotion.option_button())

	# A browser tab can't be quit from inside the page, so the web build
	# leaves it off.
	if not OS.has_feature("web"):
		var quit := UIKit.menu_item("QUIT")
		quit.pressed.connect(func(): get_tree().quit())
		options.add_child(quit)

	v.add_child(UIKit.vsep(36))


## The block font with extra space between letters, like painted lettering.
func _spaced(px: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = UIKit.FONT_BLOCK
	f.spacing_glyph = px
	return f


## A football, laces up, drawn over the title.
func _football() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(120, 64)
	c.draw.connect(func():
		var mid := c.size * 0.5
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * float(i) / 48.0
			# A prolate spheroid's outline: fuller in the middle, pointed at the ends.
			var x := cos(a) * 56.0
			var y := sin(a) * 28.0 * (1.0 - 0.15 * absf(cos(a)))
			pts.append(mid + Vector2(x, y))
		c.draw_colored_polygon(pts, Color("7a3f1d"))
		c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color("1a1206"), 4.0, true)
		# The white stripes near each tip, and the laces.
		for side in [-1.0, 1.0]:
			c.draw_line(mid + Vector2(side * 38.0, -20.0), mid + Vector2(side * 38.0, 20.0), Color("f4efe4"), 4.0, true)
		c.draw_line(mid + Vector2(-16, -2), mid + Vector2(16, -2), Color("f4efe4"), 3.0, true)
		for i in 5:
			var x := -12.0 + 6.0 * float(i)
			c.draw_line(mid + Vector2(x, -8), mid + Vector2(x, 4), Color("f4efe4"), 2.5, true))
	return c


func _on_new_run() -> void:
	get_tree().change_scene_to_file("res://scenes/qb_select.tscn")


## Endless scrimmage with everything unlocked, skipping the QB pick and hub
## entirely - straight into the field for tuning and ability testing.
func _on_dev_mode() -> void:
	GameState.start_dev_mode()
	LoadingScreen.go_to("res://scenes/match.tscn")
