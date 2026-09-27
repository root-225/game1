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

func configure(model: PackedScene, coldef: Array, cat: String, sub: String, meta: Dictionary, spin: bool) -> void:
	category = cat
	subtype = sub
	info = meta
	_spin = spin
	monitoring = false
	monitorable = true
	if cat == "obstacle":
		collision_layer = 4      # obstacle layer (bit 3)
	else:
		collision_layer = 8      # pickup layer (bit 4)
	collision_mask = 0
	var vis := model.instantiate()
	vis.name = "Vis"
	add_child(vis)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(coldef[3], coldef[4], coldef[5])
	shape.shape = box
	shape.position = Vector3(coldef[0], coldef[1], coldef[2])
	add_child(shape)

func activate(pos: Vector3) -> void:
	position = pos
	_base_y = pos.y
	collected = false
	visible = true
	monitorable = true
	_t = randf() * TAU
	set_process(_spin or category != "obstacle")

func deactivate() -> void:
	visible = false
	monitorable = false
	collected = true
	set_process(false)

func mark_collected() -> void:
	collected = true
	monitorable = false
	visible = false

func _process(delta: float) -> void:
	_t += delta
	if category == "obstacle":
		return
	var vis := get_node_or_null("Vis")
	if _spin and vis:
		vis.rotation.y += delta * 3.0
	# gentle float
	position.y = _base_y + sin(_t * 3.0) * 0.12
	# magnet attraction for pickups
	if magnet_active and not collected:
		var to_player: Vector3 = magnet_target - global_position
		if to_player.length() < 7.0:
			global_position = global_position.lerp(magnet_target, delta * 6.0)
