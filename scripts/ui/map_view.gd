extends Control

## USA destination picker, home-city journey and compact itinerary.
## Native stop controls emit selections; the hub owns navigation.

signal stop_clicked(row: int, col: int)

const NODE_R := 22.0
const BOWL_R := 27.0
const PAD_X := 44.0
const PAD_Y := 32.0

## Per stop type: ring color (for the dark detail panel - see hub.gd), the
## darker ink it's drawn in on the paper map, and the short label inside the
## circle.
const INK := {
	"match": Color("23262b"), "elite": Color("c8372d"), "shop": Color("9a6b00"),
	"ritual": Color("7b2fb0"), "lab": Color("1f8a3a"), "practice": Color("2e7d32"),
	"mystery": Color("1f5fa8"), "bowl": Color("9a6b00"),
}
const STYLE := {
	"match": {"color": Color("dce8e2"), "text": "VS"},
	"elite": {"color": Color("e8613c"), "text": "ELITE"},
	"shop": {"color": Color("f2c14e"), "text": "$"},
	"ritual": {"color": Color("b060e0"), "text": "RIT"},
	"lab": {"color": Color("39ff5a"), "text": "LAB"},
	"practice": {"color": Color("6ec46e"), "text": "+"},
	"mystery": {"color": Color("5aa9e6"), "text": "?"},
	"bowl": {"color": Color("f2c14e"), "text": ""},
}

## One map owner: destination picker, geographic journey and compact itinerary.
signal destination_chosen(id: String)
var selected := Vector2i(-1,-1):
	set(value):
		selected = value
		queue_redraw()
var _buttons: Array[Button] = []
var _clock := 0.0
const OUTLINE := [Vector2(0.04,0.16),Vector2(0.10,0.06),Vector2(0.32,0.09),Vector2(0.50,0.09),Vector2(0.57,0.13),Vector2(0.68,0.13),Vector2(0.73,0.20),Vector2(0.79,0.19),Vector2(0.84,0.10),Vector2(0.89,0.07),Vector2(0.92,0.13),Vector2(0.88,0.26),Vector2(0.93,0.29),Vector2(0.88,0.44),Vector2(0.82,0.53),Vector2(0.78,0.61),Vector2(0.77,0.72),Vector2(0.84,0.86),Vector2(0.82,0.95),Vector2(0.78,0.88),Vector2(0.72,0.73),Vector2(0.62,0.74),Vector2(0.57,0.82),Vector2(0.49,0.78),Vector2(0.43,0.72),Vector2(0.34,0.70),Vector2(0.31,0.65),Vector2(0.19,0.70),Vector2(0.12,0.67),Vector2(0.08,0.53),Vector2(0.05,0.42)]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout_buttons)
	if GameState.needs_bowl_choice():
		for id in BowlDB.ROUTES:
			var info := BowlDB.route(id)
			var b := UIKit.button("%s\n%s" % [BowlDB.bowl_name(id),info.location],16)
			b.name = "Destination_"+String(id)
			b.set_meta("destination",id)
			b.tooltip_text = "%s • %s\nRoute events: %s\nSelect this destination for the rest of this run." % [BowlDB.bowl_name(id),info.location,", ".join(info.events+info.weather)]
			b.accessibility_name = "%s — %s" % [BowlDB.bowl_name(id),info.location]
			b.pressed.connect(func(): destination_chosen.emit(id))
			add_child(b)
			_buttons.append(b)
	else:
		for r in GameState.run_map.size():
			for c in (GameState.run_map[r] as Array).size():
				var node := GameState.map_node(r,c)
				var t := String(node.type)
				var b := UIKit.button(String(STYLE[t].text),12)
				b.name = "Stop_%d_%d" % [r,c]
				b.set_meta("stop",Vector2i(r,c))
				b.tooltip_text = BowlDB.bowl_name(GameState.chosen_bowl) if t == "bowl" else ("%s%s" % [t.to_upper()," — challenge locked" if GameState.stop_locked(r,c) else ""])
				b.accessibility_name = b.tooltip_text
				var here := r == GameState.map_row and c == GameState.map_col
				b.disabled = not (GameState.can_go_to(r,c) or GameState.stop_locked(r,c) or (here and t=="shop"))
				if t == "bowl":
					b.icon = BowlDB.logo(GameState.chosen_bowl)
					b.expand_icon = true
					b.add_theme_constant_override("icon_max_width",32)
				var style := UIKit.stylebox(UIKit.PANEL_HI,22,2,UIKit.ACCENT if GameState.can_go_to(r,c) else UIKit.LINE)
				style.content_margin_left = 2
				style.content_margin_right = 2
				b.add_theme_stylebox_override("normal",style)
				b.add_theme_stylebox_override("disabled",UIKit.stylebox(UIKit.PANEL,22,1,UIKit.LINE))
				b.pressed.connect(func(): stop_clicked.emit(r,c))
				add_child(b)
				_buttons.append(b)
	_layout_buttons()

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _country_rect() -> Rect2:
	var h := maxf(100.0,size.y-(70.0 if GameState.needs_bowl_choice() else 190.0))
	var w := minf(size.x*0.60,h*2.05)
	return Rect2(Vector2((size.x-w)*0.5,24),Vector2(w,h))

func _geo(point: Vector2) -> Vector2:
	var rect := _country_rect()
	return rect.position+point*rect.size

func stop_pos(row: int, col: int) -> Vector2:
	var node := GameState.map_node(row,col)
	var fraction := float(row)/float(maxi(GameState.run_map.size()-1,1))
	return Vector2(44.0+(size.x-88.0)*fraction,size.y-80.0+(float(node.get("y",0.5))-0.5)*105.0)

func _layout_buttons() -> void:
	for b in _buttons:
		if b.has_meta("destination"):
			var id: String = b.get_meta("destination")
			var positions := {"superbowl":Vector2(12,size.y*0.52),"olympic_bowl":Vector2(12,size.y*0.15),"pro_bowl":Vector2(size.x*0.47,2),"gleech_bowl":Vector2(size.x-202,size.y*0.14),"toilet_bowl":Vector2(size.x-202,size.y*0.43),"alligator_bowl":Vector2(size.x-202,size.y*0.73)}
			b.position = positions[id]
			b.size = Vector2(190,56)
		else:
			var at: Vector2i = b.get_meta("stop")
			b.position = stop_pos(at.x,at.y)-Vector2(22,22)
			b.size = Vector2(44,44)
	queue_redraw()

func _draw() -> void:
	if GameState.run_map.is_empty():
		return
	var land := PackedVector2Array()
	for point in OUTLINE:
		land.append(_geo(point))
	draw_colored_polygon(land,Color("6c785e"))
	land.append(land[0])
	draw_polyline(land,Color("aab48a"),2.0,true)
	var alaska := PackedVector2Array()
	for point in [Vector2(0.04,0.82),Vector2(0.14,0.80),Vector2(0.19,0.88),Vector2(0.15,0.95),Vector2(0.07,0.96),Vector2(0.02,0.92)]:
		alaska.append(_geo(point))
	draw_colored_polygon(alaska,Color("6c785e"))
	_text(_geo(Vector2(0.04,1.02)),"ALASKA",11,UIKit.MUTED)
	# A few sketched mountain ranges make the overview feel like a travel map.
	for i in 7:
		var at := _geo(Vector2(0.22+float(i%2)*0.06,0.20+float(i)*0.055))
		draw_polyline(PackedVector2Array([at+Vector2(-6,4),at+Vector2(0,-5),at+Vector2(6,4)]),Color("4d624e"),1.5,true)
	# Lakes and regional sketch lines keep the country recognizable at a glance.
	for lake in [Vector2(0.64,0.20),Vector2(0.68,0.24),Vector2(0.73,0.27),Vector2(0.77,0.27)]:
		draw_circle(_geo(lake),maxf(3,_country_rect().size.x*0.012),Color("455e60"))
	for i in 4:
		var a := _geo(Vector2(0.38,0.25+float(i)*0.08))
		var b := _geo(Vector2(0.57,0.27+float(i)*0.08))
		draw_line(a,b,Color("7f876c"),1,true)
	var home := _geo(BowlDB.home_point(GameState.team_name))
	draw_circle(home,5,UIKit.ACCENT)
	_text(home+Vector2(8,18),BowlDB.home_city(GameState.team_name),13,UIKit.TEXT)
	if GameState.needs_bowl_choice():
		for b in _buttons:
			var info := BowlDB.route(String(b.get_meta("destination")))
			var point := _geo(info.point)
			draw_line(point,b.position+b.size*0.5,Color(UIKit.ACCENT,0.48),1.5,true)
			draw_circle(point,5,UIKit.ACCENT)
		_text(Vector2(14,20),"CHOOSE YOUR BOWL",20,UIKit.TEXT)
		_text(Vector2(14,size.y-8),"Six destinations. One road to the final.",14,UIKit.MUTED)
		return
	if not GameState.chosen_bowl.is_empty():
		var destination := _geo(BowlDB.route(GameState.chosen_bowl).point)
		var route := PackedVector2Array()
		var bend := Vector2(0,-maxf(24.0,home.distance_to(destination)*0.2))
		for i in 41:
			var t := float(i)/40.0
			route.append(home.lerp(destination,t)+bend*sin(t*PI))
		var shown := maxi(2,int(clampf(_clock/0.75,0,1)*route.size()))
		draw_polyline(route.slice(0,shown),UIKit.ACCENT,3.0,true)
		draw_circle(destination,6,UIKit.ACCENT)
		_text(destination+Vector2(8,-10),String(BowlDB.route(GameState.chosen_bowl).location),14,UIKit.TEXT)
		_text(Vector2(14,20),"ROAD TO "+BowlDB.bowl_name(GameState.chosen_bowl).to_upper(),20,UIKit.TEXT)
	else:
		_text(Vector2(14,20),"HOME FIELD OPENER",20,UIKit.TEXT)
	_text(Vector2(14,size.y-145),"YOUR ITINERARY  /  choose a connected stop",13,UIKit.MUTED)
	for r in GameState.run_map.size():
		for c in (GameState.run_map[r] as Array).size():
			var node := GameState.map_node(r,c)
			for next in node.get("next",[]):
				var target := GameState.map_node(r+1,int(next))
				var used := bool(node.done) and bool(target.done)
				draw_line(stop_pos(r,c),stop_pos(r+1,int(next)),Color(UIKit.ACCENT,0.9 if used else 0.3),3 if used else 2,true)
			var point := stop_pos(r,c)
			if GameState.can_go_to(r,c):
				draw_arc(point,27+sin(_clock*4.0)*2,0,TAU,32,Color(UIKit.ACCENT,0.35),2,true)
			if Vector2i(r,c)==selected:
				draw_arc(point,26,0,TAU,32,UIKit.ACCENT,2,true)
			if bool(node.done):
				_text(point+Vector2(-4,40),String(node.get("result","✓")),13,UIKit.GOOD)

func _text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(UIKit.FONT_BLOCK,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
