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
		"sidewalk": m = _tri("res://assets/textures/pavers.png", 0.45, 0.85)
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
