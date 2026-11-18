class_name SidelineBatch
extends RefCounted

## A private drawing target for SidelineCrowd's existing actor poses. Quads
## retain painter order, but share one texture and one world-space mesh.
const ATLAS_WIDTH := 4096
const GUTTER := 32
const POSE_INTERVAL := 1.0 / 30.0
const ACTOR_MARGIN := 3.0
const CAMERA_MARGIN := 2.0

var _images: Dictionary = {}
var _regions: Dictionary = {}
var _texture: CanvasTexture
var _mesh: ArrayMesh
var _covered := Rect2()
var _last_size := Vector2.ZERO
var _sample_time := -INF
var _scale := 1.0
var _origin := Vector2.ZERO
var _transform := Transform2D.IDENTITY
var _atlas_size := Vector2.ONE
var _vertices := PackedVector2Array()
var _uvs := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()


func prepare(sprites: Array) -> bool:
	if _images.is_empty():
		var circle := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var alpha := clampf(31.5 - Vector2(x - 31.5, y - 31.5).length(), 0.0, 1.0)
				circle.set_pixel(x, y, Color(1, 1, 1, alpha))
		var white := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		white.fill(Color.WHITE)
		_images["shadow"] = circle
		_images["white"] = white
	for sprite: Texture2D in sprites:
		if _images.has(sprite):
			continue
		var image := sprite.get_image()
		if image == null or image.is_empty():
			return false
		image.convert(Image.FORMAT_RGBA8)
		_images[sprite] = image
	var regions := {}
	var x := GUTTER
	var y := GUTTER
	var row := 0
	for key in _images:
		var image: Image = _images[key]
		if x + image.get_width() + GUTTER > ATLAS_WIDTH:
			x = GUTTER
			y += row + GUTTER * 2
			row = 0
		regions[key] = Rect2i(x, y, image.get_width(), image.get_height())
		x += image.get_width() + GUTTER * 2
		row = maxi(row, image.get_height())
	var height := y + row + GUTTER
	if height > ATLAS_WIDTH:
		push_error("Sideline sprite atlas exceeds its supported size")
		return false
	var atlas := Image.create(ATLAS_WIDTH, height, false, Image.FORMAT_RGBA8)
	for key in regions:
		var image: Image = _images[key]
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), regions[key].position)
	# HeadArtDB's small faces require mipmaps. Gutters isolate adjacent sprites.
	atlas.generate_mipmaps()
	var texture := CanvasTexture.new()
	texture.diffuse_texture = ImageTexture.create_from_image(atlas)
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_texture = texture
	_regions = regions
	_atlas_size = atlas.get_size()
	invalidate()
	return true


func invalidate() -> void:
	_mesh = null
	_sample_time = -INF


func _needed_world(field) -> Rect2:
	var scale: float = field.get("_scale")
	var origin: Vector2 = field.to_px(Vector2.ZERO)
	var screen := Rect2(Vector2.ZERO, field.size).grow(ACTOR_MARGIN * scale)
	return Rect2((screen.position - origin) / scale, screen.size / scale)


func needs_pose(field, clock: float) -> bool:
	return _mesh == null or clock < _sample_time or clock - _sample_time >= POSE_INTERVAL \
		or field.size != _last_size or not _covered.encloses(_needed_world(field))


func begin_pose(field) -> void:
	_scale = field.get("_scale")
	_origin = field.to_px(Vector2.ZERO)
	_last_size = field.size
	_covered = _needed_world(field).grow(CAMERA_MARGIN)
	_transform = Transform2D.IDENTITY
	_vertices = PackedVector2Array()
	_uvs = PackedVector2Array()
	_colors = PackedColorArray()
	_indices = PackedInt32Array()


func contains_actor(position: Vector2) -> bool:
	return _covered.has_point(Vector2(position.y, -position.x))


func end_pose(clock: float) -> void:
	var mesh := ArrayMesh.new()
	if not _vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vertices
		arrays[Mesh.ARRAY_TEX_UV] = _uvs
		arrays[Mesh.ARRAY_COLOR] = _colors
		arrays[Mesh.ARRAY_INDEX] = _indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh = mesh
	_sample_time = clock


func draw_on(field) -> void:
	if _mesh == null or _mesh.get_surface_count() == 0:
		return
	var scale: float = field.get("_scale")
	field.draw_set_transform(field.to_px(Vector2.ZERO), 0.0, Vector2.ONE * scale)
	field.draw_mesh(_mesh, _texture)
	field.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_set_transform(position: Vector2, rotation: float, scale: Vector2) -> void:
	_transform = Transform2D(rotation, scale, 0.0, position)


func draw_texture_rect(sprite, rect: Rect2, _tile: bool, color: Color = Color.WHITE) -> void:
	var region: Rect2i = _regions[sprite]
	var lo := Vector2(region.position) / _atlas_size
	var hi := Vector2(region.end) / _atlas_size
	_quad([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)],
		[lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)], color)


func draw_circle(position: Vector2, radius: float, color: Color) -> void:
	draw_texture_rect("shadow", Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, color)


func draw_line(from: Vector2, to: Vector2, color: Color, width: float, _antialias: bool = false) -> void:
	var normal := (to - from).orthogonal().normalized() * width * 0.5
	var region: Rect2i = _regions["white"]
	var uv := Vector2(region.get_center()) / _atlas_size
	_quad([from - normal, from + normal, to + normal, to - normal], [uv, uv, uv, uv], color)


func _quad(points: Array, texcoords: Array, color: Color) -> void:
	var first := _vertices.size()
	for i in 4:
		_vertices.append((_transform * points[i] - _origin) / _scale)
		_uvs.append(texcoords[i])
		_colors.append(color)
	_indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))
