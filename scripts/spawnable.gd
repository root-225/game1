class_name Spawnable
extends Area3D
# A pooled obstacle / collectible / power-up. Player's hurtbox detects these.

static var magnet_active := false
static var magnet_target := Vector3.ZERO

var category := ""      # "obstacle" | "collect" | "powerup"
var subtype := ""
var info := {}
var collected := false
var _spin := false
var _base_y := 0.0
var _t := 0.0
var _vis: Node3D
var _halo: MeshInstance3D

func configure(def: Dictionary, coldef: Array, cat: String, sub: String, spin: bool) -> void:
	category = cat
	subtype = sub
	info = def
	_spin = spin
	monitoring = false
	collision_layer = 4 if cat == "obstacle" else 8
	collision_mask = 0
	_vis = Data.scene(def["model"]).instantiate()
	_vis.name = "Vis"
	var s: float = def.get("scale", 1.0)
	_vis.scale = Vector3.ONE * s
	_vis.rotation.y = deg_to_rad(def.get("rot", 0.0))
	if def.has("tex"):
		Data.retexture(_vis, Data.scene_tex(def["tex"]))
	add_child(_vis)
	if cat == "obstacle":
		Mats.add_outline(_vis, 0.035, s)
		add_child(Mats.blob(Vector2(coldef[3], coldef[5]) * 1.35 + Vector2(0.4, 0.4), 0.5))
	else:   # small pickups: no shadow pass (saves draw calls on mobile)
		for gi in _vis.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(coldef[3], coldef[4], coldef[5])
	shape.shape = box
	shape.position = Vector3(coldef[0], coldef[1], coldef[2])
	add_child(shape)
	if cat == "powerup":
		_add_halo(def["color"])

func _add_halo(col: Color) -> void:
	_halo = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.5
	t.outer_radius = 0.62
	t.rings = 24
	t.ring_segments = 6
	_halo.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	_halo.material_override = m
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.position.y = -0.55
	add_child(_halo)

func activate(pos: Vector3) -> void:
	position = pos
	_base_y = pos.y
	collected = false
	visible = true
	set_deferred("monitorable", true)
	_t = randf() * TAU
	set_process(category != "obstacle")

func deactivate() -> void:
	visible = false
	set_deferred("monitorable", false)
	collected = true
	set_process(false)

# Called from the player's area_entered signal: physics state must change deferred.
func mark_collected() -> void:
	collected = true
	visible = false
	set_deferred("monitorable", false)

func _process(delta: float) -> void:
	_t += delta
	if _spin:
		_vis.rotation.y += delta * 3.0
	if _halo:
		_halo.rotation.x = sin(_t * 2.0) * 0.25
		_halo.scale = Vector3.ONE * (1.0 + sin(_t * 4.0) * 0.08)
	position.y = _base_y + sin(_t * 3.0) * 0.12
	if magnet_active and not collected:
		var to_player: Vector3 = magnet_target - global_position
		if to_player.length() < 7.0:
			global_position = global_position.lerp(magnet_target, delta * 6.0)
