class_name ChunkManager
extends Node3D
# Infinite procedural road built from recycled chunks. Obstacles, pickups AND scenery are
# pooled: after warm-up nothing is instantiated during play.
# Biomes: "city" (Abidjan street: KayKit facades, Plateau towers, palms) and
# "lagoon" (bridge over the Ébrié lagoon with the Plateau skyline across the water).

enum Biome { CITY, LAGOON }

var _chunks: Array = []          # [{node, items, decos, biome, statics}]
var _pools := {}                 # spawnables: key -> Array[Spawnable]
var _deco_pools := {}            # scenery: scene path -> Array[Node3D]
var _holder: Node3D
var _rng := RandomNumberGenerator.new()
var _spawn_index := 0
var biome_offset := 0            # debug/screenshot hook: shift the biome sequence
var difficulty := 0.0
var active_pickups: Array = []

func _ready() -> void:
	_rng.randomize()
	_holder = Node3D.new()
	_holder.name = "PoolHolder"
	_holder.visible = false
	add_child(_holder)
	_warmup()

func _warmup() -> void:
	# pool sizes ~ peak concurrent use measured in a 2-minute soak test (no instancing mid-run)
	for name in Data.OBSTACLES.keys():
		_ensure_pool("o:" + name, 7)
	_ensure_pool("c:coin", 110)
	for name in ["coconut", "alloco", "akpakpa", "phone"]:
		_ensure_pool("c:" + name, 3)
	for name in Data.POWERUPS.keys():
		_ensure_pool("p:" + name, 2)
	for b in Data.BUILDINGS:
		_warm_deco(Data.KK_CITY + b + ".gltf", 5)
	for t in Data.TOWERS:
		_warm_deco(Data.MODELS + "env/%s.glb" % t, 6)
	_warm_deco(Data.KK_CITY + "streetlight.gltf", 20)
	_warm_deco(Data.MODELS + "env/kiosk.glb", 4)
	_warm_deco(Data.KK_CITY + "trafficlight_A.gltf", 3)
	for p in Data.PALMS:
		_warm_deco(Data.MODELS + "env/%s.glb" % p, 6)
	for prop in Data.SIDEWALK_PROPS:
		_warm_deco(Data.KK_CITY + prop + ".gltf", 3)

func build_initial() -> void:
	for c in _chunks:
		_clear_items(c)
		_clear_decos(c)
		c["node"].queue_free()
	_chunks.clear()
	_spawn_index = 0
	for i in range(Data.ACTIVE_CHUNKS):
		var rec := _make_chunk()
		rec["node"].position.z = -i * Data.CHUNK_LEN
		add_child(rec["node"])
		_chunks.append(rec)
		_dress(rec)
		if i >= 2:
			_populate(rec)

# ---------------------------------------------------------------- spawnable pooling
func _ensure_pool(key: String, n: int) -> void:
	if not _pools.has(key):
		_pools[key] = []
	while _pools[key].size() < n:
		_pools[key].append(_make_spawnable(key))

func _make_spawnable(key: String) -> Spawnable:
	var s := Spawnable.new()
	var parts := key.split(":")
	var cat := parts[0]
	var sub := parts[1]
	if cat == "o":
		var d: Dictionary = Data.OBSTACLES[sub]
		s.configure(d, d["col"], "obstacle", sub, false)
	elif cat == "c":
		var d: Dictionary = Data.COLLECTIBLES[sub]
		s.configure(d, [0, 0, 0, 0.8, 1.0, 0.8], "collect", sub, d["spin"])
	else:
		var d: Dictionary = Data.POWERUPS[sub]
		s.configure(d, [0, 0, 0, 0.9, 1.1, 0.9], "powerup", sub, true)
	s.deactivate()
	_holder.add_child(s)
	return s

func _acquire(key: String) -> Spawnable:
	_ensure_pool(key, 1)
	return _pools[key].pop_back()

func _release(s: Spawnable) -> void:
	s.deactivate()
	if s.get_parent():
		s.get_parent().remove_child(s)
	_holder.add_child(s)
	var key := ("o:" if s.category == "obstacle" else ("p:" if s.category == "powerup" else "c:")) + s.subtype
	_pools[key].append(s)
	active_pickups.erase(s)

# ---------------------------------------------------------------- scenery pooling
func _warm_deco(path: String, n: int) -> void:
	if not _deco_pools.has(path):
		_deco_pools[path] = []
	for i in n:
		var d := _new_deco(path)
		d.visible = false
		_holder.add_child(d)
		_deco_pools[path].append(d)

func _new_deco(path: String) -> Node3D:
	var d: Node3D = Data.scene(path).instantiate()
	d.set_meta("pool", path)
	if path.contains("/tower_"):   # distant skyline: never inside the shadow range anyway
		for gi in d.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return d

func _deco(rec: Dictionary, path: String, pos: Vector3, rot_y: float, scl: float) -> Node3D:
	if not _deco_pools.has(path):
		_deco_pools[path] = []
	var d: Node3D = _deco_pools[path].pop_back() if not _deco_pools[path].is_empty() else _new_deco(path)
	if d.get_parent():
		d.get_parent().remove_child(d)
	rec["node"].add_child(d)
	d.position = pos
	d.rotation = Vector3(0, rot_y, 0)
	d.scale = Vector3.ONE * scl
	d.visible = true
	rec["decos"].append(d)
	return d

func _clear_decos(rec: Dictionary) -> void:
	for d in rec["decos"]:
		d.get_parent().remove_child(d)
		d.visible = false
		_holder.add_child(d)
		_deco_pools[d.get_meta("pool")].append(d)
	rec["decos"].clear()

# ---------------------------------------------------------------- chunk construction
func _plane(size: Vector2, pos: Vector3, mat: Material, shadow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.position = pos
	mi.material_override = mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _make_chunk() -> Dictionary:
	var node := Node3D.new()
	var road: Node3D = Data.model_scene("env/road.glb").instantiate()
	Mats.apply_named(road)
	for gi in road.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(road)
	var city := Node3D.new(); city.name = "City"; node.add_child(city)
	var lagoon := Node3D.new(); lagoon.name = "Lagoon"; node.add_child(lagoon)
	for side: int in [-1, 1]:
		# city: laterite lots behind the sidewalk
		city.add_child(_plane(Vector2(60, Data.CHUNK_LEN), Vector3(side * 36.5, -0.03, 0), Mats.get_mat("ground")))
		# lagoon: water, bridge balustrade and the far shore of the Plateau
		lagoon.add_child(_plane(Vector2(46, Data.CHUNK_LEN), Vector3(side * 29.5, -2.2, 0), Mats.get_mat("water")))
		lagoon.add_child(_plane(Vector2(80, Data.CHUNK_LEN), Vector3(side * 92.0, -0.4, 0), Mats.get_mat("ground")))
		var rail: Node3D = Data.model_scene("env/railing.glb").instantiate()
		if side < 0:
			rail.rotation.y = PI
		lagoon.add_child(rail)
	return {"node": node, "items": [], "decos": [], "biome": Biome.CITY, "city": city, "lagoon": lagoon}

func _biome_for(index: int) -> int:
	var k := index % Data.BIOME_CYCLE
	return Biome.LAGOON if k >= Data.LAGOON_START and k < Data.LAGOON_START + Data.LAGOON_LEN else Biome.CITY

# Random variant, preferring one that is free in its pool (avoids instancing mid-run).
func _pick(prefix: String, names: Array, suffix: String) -> String:
	var order := names.duplicate()
	order.shuffle()
	for n in order:
		var path: String = prefix + n + suffix
		if _deco_pools.has(path) and not _deco_pools[path].is_empty():
			return path
	return prefix + order[0] + suffix

# scenery for one chunk (buildings, lights, palms, props)
func _dress(rec: Dictionary) -> void:
	_clear_decos(rec)
	var biome := _biome_for(_spawn_index + biome_offset)
	_spawn_index += 1
	rec["biome"] = biome
	rec["city"].visible = biome == Biome.CITY
	rec["lagoon"].visible = biome == Biome.LAGOON
	for side: int in [-1, 1]:
		var face := -PI / 2 if side > 0 else PI / 2          # KayKit fronts face +Z
		var light_rot := 0.0 if side > 0 else PI             # streetlight arm points -X
		var lz := -3.0 if side > 0 else 3.0
		if biome == Biome.CITY:
			_deco(rec, _pick(Data.KK_CITY, Data.BUILDINGS, ".gltf"), Vector3(side * 12.1, 0, _rng.randf_range(-0.4, 0.4)), face, 5.2)
			if _rng.randf() < 0.6:
				_deco(rec, _pick(Data.MODELS + "env/", Data.TOWERS, ".glb"), Vector3(side * _rng.randf_range(24, 34), 0,
					_rng.randf_range(-3, 3)), _rng.randi_range(0, 3) * PI / 2, _rng.randf_range(1.9, 2.7))
			_deco(rec, Data.KK_CITY + "streetlight.gltf", Vector3(side * 5.9, 0.2, lz), light_rot, Data.CITY_SCALE)
			var r := _rng.randf()
			if r < 0.55:
				_deco(rec, _pick(Data.MODELS + "env/", Data.PALMS, ".glb"), Vector3(side * 5.5, 0.2, -lz), _rng.randf() * TAU, _rng.randf_range(0.9, 1.15))
			elif r < 0.72:
				_deco(rec, Data.MODELS + "env/kiosk.glb", Vector3(side * 5.4, 0.2, -lz), face, 0.9)
			else:
				_deco(rec, _pick(Data.KK_CITY, Data.SIDEWALK_PROPS, ".gltf"), Vector3(side * 5.6, 0.2, -lz), face, Data.CITY_SCALE)
			if _rng.randf() < 0.12:
				_deco(rec, Data.KK_CITY + "trafficlight_A.gltf", Vector3(side * 4.3, 0.2, 0), light_rot, Data.CITY_SCALE)
		else:
			_deco(rec, Data.KK_CITY + "streetlight.gltf", Vector3(side * 6.1, 0.2, lz), light_rot, Data.CITY_SCALE)
			for k in _rng.randi_range(1, 2):
				_deco(rec, _pick(Data.MODELS + "env/", Data.TOWERS, ".glb"), Vector3(side * _rng.randf_range(58, 80), -0.4,
					_rng.randf_range(-5, 5)), _rng.randi_range(0, 3) * PI / 2, _rng.randf_range(2.6, 3.6))

# ---------------------------------------------------------------- obstacles & pickups
func _populate(rec: Dictionary) -> void:
	var rows := 2 if difficulty < 0.35 else 3
	var z_positions := []
	for i in range(rows):
		z_positions.append(-Data.CHUNK_LEN / 2 + 2.0 + i * (Data.CHUNK_LEN - 3.0) / rows)
	var obst_names: Array = Data.OBSTACLES.keys()
	for z: float in z_positions:
		var block_count := 1
		if _rng.randf() < 0.25 + difficulty * 0.4:
			block_count = 2
		var lanes := [0, 1, 2]
		lanes.shuffle()
		var blocked := lanes.slice(0, block_count)
		var free_lanes := []
		for l in [0, 1, 2]:
			if not blocked.has(l):
				free_lanes.append(l)
		for l in blocked:
			_place(rec, _acquire(_pick_obstacle(obst_names)), Vector3(Data.LANES[l], 0, z))
		var coin_lane: int = free_lanes[_rng.randi() % free_lanes.size()]
		if _rng.randf() < 0.85:
			for k in range(_rng.randi_range(3, 5)):
				var cz: float = z + 1.2 + k * 0.9
				if cz > Data.CHUNK_LEN / 2 - 0.5:
					break
				var coin := _acquire("c:coin")
				_place(rec, coin, Vector3(Data.LANES[coin_lane], Data.COLLECTIBLES["coin"]["y"], cz))
				active_pickups.append(coin)
		if _rng.randf() < 0.3:
			var item_name: String = ["coconut", "alloco", "akpakpa", "phone"][_rng.randi() % 4]
			if item_name == "phone" and _rng.randf() < 0.6:
				item_name = "alloco"
			var il: int = free_lanes[_rng.randi() % free_lanes.size()]
			var it := _acquire("c:" + item_name)
			_place(rec, it, Vector3(Data.LANES[il], Data.COLLECTIBLES[item_name]["y"], z + 0.5))
			active_pickups.append(it)
	if _rng.randf() < 0.12:
		var pu_name: String = Data.POWERUPS.keys()[_rng.randi() % Data.POWERUPS.size()]
		var pu := _acquire("p:" + pu_name)
		_place(rec, pu, Vector3(Data.LANES[_rng.randi() % 3], Data.POWERUPS[pu_name]["y"], _rng.randf_range(-3, 3)))
		active_pickups.append(pu)

func _pick_obstacle(names: Array) -> String:
	var order := names.duplicate()
	order.shuffle()
	for n in order:
		if not _pools["o:" + n].is_empty():
			return "o:" + n
	return "o:" + order[0]

func _place(rec: Dictionary, s: Spawnable, local_pos: Vector3) -> void:
	if s.get_parent():
		s.get_parent().remove_child(s)
	rec["node"].add_child(s)
	s.activate(local_pos)
	rec["items"].append(s)

func _clear_items(rec: Dictionary) -> void:
	for s in rec["items"]:
		_release(s)
	rec["items"].clear()

# ---------------------------------------------------------------- recycle
func update_stream(player_z: float, diff: float) -> void:
	difficulty = diff
	var min_z := INF
	for rec in _chunks:
		min_z = min(min_z, rec["node"].position.z)
	for rec in _chunks:
		if rec["node"].position.z - Data.CHUNK_LEN * 0.5 > player_z + Data.CHUNK_LEN:
			_clear_items(rec)
			min_z -= Data.CHUNK_LEN
			rec["node"].position.z = min_z
			_dress(rec)
			_populate(rec)

func reset() -> void:
	active_pickups.clear()
	difficulty = 0.0
	build_initial()
