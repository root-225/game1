class_name Mats
extends RefCounted
# Shared world materials. Road/ground use world-space triplanar mapping so textures tile
# seamlessly across recycled chunks without needing UVs.

static var _m := {}

static func _tri(tex_path: String, scale: float, rough := 0.9, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(tex_path)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func get_mat(name: String) -> Material:
	if _m.has(name):
		return _m[name]
	var m: Material
	match name:
		"asphalt": m = _tri("res://assets/textures/asphalt.png", 0.22, 0.95)
		"sidewalk": m = _tri("res://assets/textures/pavers.png", 0.45, 0.85, Color(0.8, 0.77, 0.74))
		"ground": m = _tri("res://assets/textures/laterite.png", 0.06, 1.0)
		"water":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://assets/shaders/water.gdshader")
			m = sm
		_: return null
	_m[name] = m
	return m

# Replace imported glTF materials whose name matches a library material.
static func apply_named(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		for s in m3.mesh.get_surface_count():
			var src := m3.mesh.surface_get_material(s)
			if src:
				var lib := get_mat(src.resource_name)
				if lib:
					m3.set_surface_override_material(s, lib)

# Toon outline via next_pass on every surface. `world_width` is divided by the node scale so
# a 4.8x-scaled KayKit car gets the same outline as a 1x procedural cone.
static func add_outline(root: Node, world_width: float, scale: float, col := Color(0.06, 0.05, 0.08)) -> void:
	var w: float = world_width / maxf(scale, 0.001)
	var okey := "outline:%.4f:%s" % [w, col.to_html()]
	if not _m.has(okey):
		var om := ShaderMaterial.new()
		om.shader = load("res://assets/shaders/outline.gdshader")
		om.set_shader_parameter("width", w)
		om.set_shader_parameter("outline_color", col)
		_m[okey] = om
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		for s in m3.mesh.get_surface_count():
			var src: Material = m3.get_surface_override_material(s)
			if src == null:
				src = m3.mesh.surface_get_material(s)
			if src == null:
				continue
			var key := "ol:%d:%s" % [src.get_instance_id(), okey]
			if not _m.has(key):
				var d: Material = src.duplicate()
				d.next_pass = _m[okey]
				_m[key] = d
			m3.set_surface_override_material(s, _m[key])

# Soft dark contact shadow under objects (reads better than real shadows at distance).
static func blob(size: Vector2, alpha := 0.45) -> MeshInstance3D:
	var key := "blob:%.2f" % alpha
	if not _m.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/textures/dust.png")
		m.albedo_color = Color(0, 0, 0, alpha)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_m[key] = m
	var q := QuadMesh.new()
	q.size = size
	q.orientation = PlaneMesh.FACE_Y
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _m[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.025
	return mi
