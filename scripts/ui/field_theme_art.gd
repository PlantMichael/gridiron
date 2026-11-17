class_name FieldThemeArt
extends RefCounted

## Yard-anchored venue art. Scenery never enters the simulation or its RNG.
const STYLES := {
	"practice":{"name":"Home Practice Ground","ground":Color("293e2d"),"field":Color("304c35"),"alt":Color("344f38"),"paint":Color("c0c4a8"),"grass":true},
	"stadium":{"name":"California • Superb Stadium","ground":Color("303a36"),"field":Color("304c39"),"alt":Color("36523e"),"paint":Color("b9c3af"),"grass":true},
	"detroit":{"name":"Detroit • Pro Stadium","ground":Color("303b40"),"field":Color("354b58"),"alt":Color("3b5260"),"paint":Color("b6c7cb"),"grass":true},
	"beach":{"name":"Miami • Alligator Beach","ground":Color("80765d"),"field":Color("827a61"),"alt":Color("827a61"),"paint":Color("d0cbb1"),"grass":false},
	"parking":{"name":"Philadelphia • Toilet Bowl Lot","ground":Color("414448"),"field":Color("494c4d"),"alt":Color("494c4d"),"paint":Color("c8c6b6"),"grass":false},
	"park":{"name":"New Jersey • Leach Park","ground":Color("344635"),"field":Color("40533c"),"alt":Color("43573e"),"paint":Color("b6bda2"),"grass":true},
	"olympic":{"name":"Salt Lake City • Olympic Grounds","ground":Color("344139"),"field":Color("365044"),"alt":Color("3b5549"),"paint":Color("c0c6b4"),"grass":true},
}

static func style(id: String) -> Dictionary:
	return STYLES.get(id,STYLES.practice)

static func _p(field, x: float, y: float) -> Vector2:
	return field.to_px(Vector2(x,y))

static func _box(field, x: float, y: float, length: float, width: float, color: Color) -> void:
	var a := _p(field,x+length,y)
	var b := _p(field,x,y+width)
	field.draw_rect(Rect2(a,b-a),color)

static func _round_box(field, x: float, y: float, length: float, width: float, color: Color, radius: float, outline: bool=false) -> void:
	var a := _p(field,x+length,y)
	var b := _p(field,x,y+width)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT if outline else color
	sb.set_corner_radius_all(int(radius*float(field.get("_scale"))))
	if outline:
		sb.set_border_width_all(1)
		sb.border_color = color
	field.draw_style_box(sb,Rect2(a,b-a))

static func draw_base(field, theme: String) -> void:
	if theme != "olympic":
		return
	_round_box(field,-6,-10,132,73.33,Color("714e43"),10)
	for lane in 6:
		var inset := float(lane)*1.1
		_round_box(field,-6+inset,-10+inset,132-inset*2,73.33-inset*2,Color("b39a85"),10-inset*0.5,true)
	_round_box(field,1,-2,118,57.33,Color("3d5040"),5)

static func draw_scenery(field, theme: String, visible: Vector2i) -> void:
	var scale: float = field.get("_scale")
	for side in 2:
		var sign := -1.0 if side == 0 else 1.0
		var edge := 0.0 if side == 0 else 53.33
		if theme in ["stadium","detroit","olympic"]:
			for tier in 4:
				var depth := 11.0+float(tier)*2.2
				var y := edge+sign*depth
				_box(field,4,y-1.0,112,1.8,Color("454f50"))
				for x in range(maxi(6,visible.x-3),mini(116,visible.y+4),3):
					var seat_color := Color("62717a") if theme == "detroit" else Color("6f6c58") if theme == "stadium" else Color("65766f")
					_box(field,float(x),y-0.65,1.7,1.3,seat_color)
					if (x+tier)%5 != 0:
						_spectator(field,_p(field,float(x)+0.8,y),scale,x+tier)
			field.draw_line(_p(field,4,edge+sign*10.2),_p(field,116,edge+sign*10.2),Color("9caa9b"),maxf(1,scale*0.1),true)
			for x in [12.0,60.0,108.0]:
				_light(field,_p(field,x,edge+sign*19),scale)
		elif theme in ["practice","park"]:
			var depth := 13.0 if theme == "practice" else 11.8
			if theme == "practice":
				var y := edge+sign*11.1
				field.draw_line(_p(field,2,y),_p(field,118,y),Color("6d7a68"),maxf(1.0,scale*0.12),true)
				for x in range(2,119,4):
					var at := _p(field,float(x),y)
					field.draw_line(at,at+Vector2(0,-scale*1.5),Color("879080"),maxf(1.0,scale*0.08),true)
			else:
				var trail := PackedVector2Array()
				for x in range(0,121,3):
					trail.append(_p(field,float(x),edge+sign*(13.5+sin(float(x)*0.07)*1.3)))
				field.draw_polyline(trail,Color("6b6751"),scale*1.4,true)
			for x in range(4,120,9):
				if x < visible.x-8 or x > visible.y+10:
					continue
				_tree(field,_p(field,float(x),edge+sign*(depth+float(x%3))),scale,theme=="park")
			if theme == "practice":
				_box(field,55,edge+sign*18,10,5,Color("64634f"))
				_box(field,55,edge+sign*18,1,5,Color("88816b"))
			else:
				for x in [25.0,70.0,103.0]:
					_picnic(field,_p(field,x,edge+sign*17),scale)
		elif theme == "beach":
			var water_y := -35.0 if side==0 else 64.5
			_box(field,-10,water_y,140,24,Color("385d64"))
			for wave in 4:
				var line := PackedVector2Array()
				for x in range(-5,126,2):
					var y := edge+sign*(11.8+float(wave)*2.5+sin(float(x)*0.15+float(wave))*0.6)
					line.append(_p(field,float(x),y))
				field.draw_polyline(line,Color("819795"),maxf(1,scale*0.12),true)
			for x in range(8,118,18):
				if x >= visible.x-8 and x <= visible.y+8:
					_palm(field,_p(field,float(x),edge+sign*12.5),scale)
			for x in [28.0,64.0,100.0]:
				_umbrella(field,_p(field,x,edge+sign*10.8),scale)
		elif theme == "parking":
			for x in range(3,120,12):
				var y := edge+sign*15.0
				_box(field,float(x),y-3,0.13,6,Color("93968b"))
				if x >= visible.x-5 and x <= visible.y+6:
					_car(field,_p(field,float(x)+5,y),scale,x==63)
			field.draw_line(_p(field,0,edge+sign*11),_p(field,120,edge+sign*11),Color("827c61"),maxf(1,scale*0.12),true)
	if theme in ["stadium","detroit","olympic"]:
		for end in [-9.0,127.0]:
			for tier in 3:
				var x: float = float(end)+float(tier)*(-2.1 if end<0 else 2.1)
				_box(field,x,-17,1.8,87.33,Color("465451"))
				for lat in range(-15,70,3):
					_box(field,x,float(lat),1.6,1.5,Color("687467"))
					_spectator(field,_p(field,x+0.8,float(lat)+0.75),scale,lat+tier)
		var board := _p(field,130,26.665)
		field.draw_rect(Rect2(board-Vector2(scale*15,scale*2),Vector2(scale*30,scale*4)),Color("152826"))
		var score := "%02d   :   %02d" % [field.sim.score_us,field.sim.score_them]
		var font_size := maxi(12,int(scale*1.6))
		var width := UIKit.FONT_BLOCK.get_string_size(score,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		field.draw_string(UIKit.FONT_BLOCK,board+Vector2(-width*0.5,scale*0.65),score,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("c2bb8d"))
	# Venue material detail belongs to world yards, not the viewport.
	if theme == "parking":
		for i in 32:
			var x := float((i*19)%120)
			if x < visible.x-2 or x > visible.y+2:
				continue
			var y := float((i*17)%53)
			field.draw_polyline(PackedVector2Array([_p(field,x,y),_p(field,x+1.8,y+0.5),_p(field,x+3,y+0.1)]),Color("363c3d"),maxf(1,scale*0.08),true)
	elif theme == "beach":
		for i in 75:
			var x := float((i*29)%120)
			if x >= visible.x and x <= visible.y:
				field.draw_arc(_p(field,x,float((i*23)%53)),scale*0.5,0.2,2.5,6,Color("968c70"),1,true)
	if theme == "olympic" and visible.x < 65 and visible.y > 55:
		var colors := [Color("5b7c93"),Color("8d815b"),Color("303e3b"),Color("69836f"),Color("9c6e65")]
		for i in 5:
			var center := _p(field,60+(1.4 if i>2 else 0),22+float(i%3)*4+(2 if i>2 else 0))
			field.draw_arc(center,scale*2.1,0,TAU,32,Color(colors[i],0.55),maxf(2,scale*0.25),true)
	if theme in ["stadium","detroit","olympic"]:
		for x in [24.0,92.0]:
			for y in [-10.0,63.33]:
				_board(field,_p(field,x,y),scale,style(theme).name)
	if theme == "parking" and field.sim.police_active():
		var at := _p(field,68,-15)
		field.draw_circle(at+Vector2(-scale*0.4,0),scale*0.3,Color("a77872"))
		field.draw_circle(at+Vector2(scale*0.4,0),scale*0.3,Color("7895ae"))

static func _tree(field, at: Vector2, scale: float, park: bool) -> void:
	field.draw_circle(at+Vector2(scale*0.7,scale*0.3),scale*2.3,Color(0.03,0.08,0.05,0.3))
	field.draw_line(at,at+Vector2(0,-scale*2.1),Color("5b4b34"),scale*0.4,true)
	var crown := at+Vector2(0,-scale*2.3)
	field.draw_circle(crown,scale*2.4,Color("213e2e"))
	for i in 5:
		var p := crown+Vector2(cos(i*TAU/5.0),sin(i*TAU/5.0))*scale*1.25
		field.draw_circle(p,scale*1.5,Color("496044") if park else Color("3f583d"))
	field.draw_circle(crown+Vector2(-scale*0.4,-scale*0.5),scale*1.5,Color("5a704b") if park else Color("4d6544"))

static func _palm(field, at: Vector2, scale: float) -> void:
	var top := at+Vector2(scale*0.7,-scale*3.5)
	field.draw_line(at,top,Color("6e5d3d"),scale*0.4,true)
	for i in 7:
		var direction := Vector2(cos(float(i)*TAU/7.0),sin(float(i)*TAU/7.0)*0.5)
		field.draw_colored_polygon(PackedVector2Array([top,top+direction*scale*3+Vector2(0,scale*0.8),top+direction.rotated(0.25)*scale*2]),Color("456047"))

static func _umbrella(field, at: Vector2, scale: float) -> void:
	field.draw_circle(at+Vector2(scale*0.4,scale*0.4),scale*1.5,Color(0,0,0,0.16))
	var colors := [Color("a5936b"),Color("7c6d58")]
	for i in 8:
		var a := float(i)*TAU/8
		var b := float(i+1)*TAU/8
		field.draw_colored_polygon(PackedVector2Array([at,at+Vector2(cos(a),sin(a))*scale*1.4,at+Vector2(cos(b),sin(b))*scale*1.4]),colors[i%2])
	field.draw_circle(at,scale*0.1,Color("4e5140"))

static func _light(field, at: Vector2, scale: float) -> void:
	var top := at-Vector2(0,scale*5)
	field.draw_line(at,top,Color("77817d"),maxf(2,scale*0.15),true)
	field.draw_rect(Rect2(top-Vector2(scale*1.5,scale*0.5),Vector2(scale*3,scale)),Color("4b5757"))
	for i in 4:
		field.draw_circle(top+Vector2((float(i)-1.5)*scale*0.65,0),scale*0.22,Color("b6b9a1"))

static func _picnic(field, at: Vector2, scale: float) -> void:
	field.draw_rect(Rect2(at-Vector2(scale*1.5,scale*0.7),Vector2(scale*3,scale*1.4)),Color("77664a"))
	for direction in [-1,1]:
		field.draw_line(at+Vector2(-scale*1.8,direction*scale),at+Vector2(scale*1.8,direction*scale),Color("9a8661"),scale*0.3,true)

static func _car(field, at: Vector2, scale: float, police: bool) -> void:
	var color := Color("444f59") if not police else Color("a3a59a")
	field.draw_rect(Rect2(at-Vector2(scale*1.0,scale*2.1),Vector2(scale*2.0,scale*4.2)),Color("242f32"))
	field.draw_rect(Rect2(at-Vector2(scale*0.9,scale*2),Vector2(scale*1.8,scale*4)),color)
	field.draw_rect(Rect2(at-Vector2(scale*0.7,scale),Vector2(scale*1.4,scale*2)),Color("65787c"))
	for side in [-1,1]:
		for end in [-1,1]:
			field.draw_rect(Rect2(at+Vector2(side*scale*0.9-scale*0.12,end*scale*1.3-scale*0.35),Vector2(scale*0.24,scale*0.7)),Color("202929"))
		field.draw_circle(at+Vector2(side*scale*0.6,-scale*1.8),scale*0.16,Color("c5bea0"))
		field.draw_circle(at+Vector2(side*scale*0.6,scale*1.8),scale*0.13,Color("855b50"))
	if police:
		field.draw_line(at-Vector2(scale*0.65,0),at+Vector2(scale*0.65,0),Color("4b5f75"),scale*0.3,true)

static func _board(field, at: Vector2, scale: float, text: String) -> void:
	var r := Rect2(at-Vector2(scale*5,scale*0.8),Vector2(scale*10,scale*1.6))
	field.draw_rect(r,Color("263b39"))
	var size := maxi(8,int(scale*0.7))
	field.draw_string(UIKit.FONT_BLOCK,r.position+Vector2(scale*0.25,scale),text,HORIZONTAL_ALIGNMENT_LEFT,scale*9.5,size,Color("a9b4a1"))


static func _spectator(field, at: Vector2, scale: float, index: int) -> void:
	var coat := [Color("747c79"),Color("5c6f76"),Color("686248"),Color("4f6252")]
	field.draw_circle(at,scale*0.42,coat[posmod(index,4)])
	field.draw_circle(at-Vector2(0,scale*0.3),scale*0.22,Color("aa967c") if index%3 else Color("816b52"))
