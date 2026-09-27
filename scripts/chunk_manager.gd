class_name ChunkManager
extends Node3D
# Infinite procedural road built from recycled chunks + pooled obstacles/pickups.

var _chunks: Array = []          # [{node, items:Array}]
var _pools := {}                 # key -> Array[Spawnable]
var _holder: Node3D
var _road_scene: PackedScene
var _building_scenes: Array = []
var _palm_scenes: Array = []
var _kiosk_scene: PackedScene
var _rng := RandomNumberGenerator.new()
var difficulty := 0.0
var active_pickups: Array = []

func _ready() -> void:
	_rng.randomize()
	_holder = Node3D.new()
	_holder.name = "PoolHolder"
	_holder.visible = false
	add_child(_holder)
	_road_scene = Data.model_scene(Data.ENV["road"])
	for b in Data.ENV["buildings"]:
		_building_scenes.append(Data.model_scene(b))
	for p in Data.ENV["palms"]:
		_palm_scenes.append(Data.model_scene(p))
	_kiosk_scene = Data.model_scene(Data.ENV["kiosk"])
	_warmup()

func _warmup() -> void:
	for name in Data.OBSTACLES.keys():
		_ensure_pool("o:" + name, 3)
	_ensure_pool("c:coin", 40)
	for name in ["coconut", "alloco", "akpakpa", "phone"]:
		_ensure_pool("c:" + name, 2)
	for name in Data.POWERUPS.keys():
		_ensure_pool("p:" + name, 2)

func build_initial() -> void:
	for c in _chunks:
		c["node"].queue_free()
	_chunks.clear()
	for i in range(Data.ACTIVE_CHUNKS):
		var node := _make_chunk_node()
		node.position.z = -i * Data.CHUNK_LEN
		add_child(node)
		var rec := {"node": node, "items": []}
		_chunks.append(rec)
		if i >= 2:
			_populate(rec)

# ---------------------------------------------------------------- pooling
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
		s.configure(Data.model_scene(d["model"]), d["col"], "obstacle", sub, d, false)
	elif cat == "c":
		var d: Dictionary = Data.COLLECTIBLES[sub]
		var col := [0, 0, 0, 0.8, 1.0, 0.8]
		s.configure(Data.model_scene(d["model"]), col, "collect", sub, d, d["spin"])
	else:
		var d: Dictionary = Data.POWERUPS[sub]
		var col := [0, 0, 0, 0.9, 1.1, 0.9]
		s.configure(Data.model_scene(d["model"]), col, "powerup", sub, d, true)
	s.deactivate()
	_holder.add_child(s)
	return s

func _acquire(key: String) -> Spawnable:
	_ensure_pool(key, 1)
	var arr: Array = _pools[key]
	var s: Spawnable
	if arr.is_empty():
		s = _make_spawnable(key)
	else:
		s = arr.pop_back()
	return s

func _release(s: Spawnable) -> void:
	s.deactivate()
	if s.get_parent():
		s.get_parent().remove_child(s)
	_holder.add_child(s)
	var key := ("o:" if s.category == "obstacle" else ("p:" if s.category == "powerup" else "c:")) + s.subtype
	if not _pools.has(key):
		_pools[key] = []
	_pools[key].append(s)
	active_pickups.erase(s)

# ---------------------------------------------------------------- chunks
func _make_chunk_node() -> Node3D:
	var node := Node3D.new()
	var road := _road_scene.instantiate()
	node.add_child(road)
	_decorate(node)
	return node

func _decorate(node: Node3D) -> void:
	for side: int in [-1, 1]:
		var z := -Data.CHUNK_LEN / 2
		while z < Data.CHUNK_LEN / 2:
			var r := _rng.randf()
			var deco: Node3D
			var x: float = side * _rng.randf_range(6.0, 10.0)
			if r < 0.55:
				deco = _building_scenes[_rng.randi() % _building_scenes.size()].instantiate()
				x = side * _rng.randf_range(6.5, 9.0)
			elif r < 0.8:
				deco = _palm_scenes[_rng.randi() % _palm_scenes.size()].instantiate()
				x = side * _rng.randf_range(4.6, 5.6)
			else:
				deco = _kiosk_scene.instantiate()
				x = side * _rng.randf_range(5.0, 5.8)
			deco.position = Vector3(x, 0, z + _rng.randf_range(-1, 1))
			deco.rotation.y = _rng.randf_range(-0.3, 0.3) + (0 if side < 0 else PI)
			node.add_child(deco)
			z += _rng.randf_range(3.5, 6.0)

func _populate(rec: Dictionary) -> void:
	var node: Node3D = rec["node"]
	var rows := 2 if difficulty < 0.35 else 3
	var z_positions := []
	for i in range(rows):
		z_positions.append(-Data.CHUNK_LEN / 2 + 2.0 + i * (Data.CHUNK_LEN - 3.0) / rows)
	var obst_names: Array = Data.OBSTACLES.keys()
	var free_lane_history := 1
	for zi in range(z_positions.size()):
		var z: float = z_positions[zi]
		# how many lanes to block (never all 3)
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
			var name: String = obst_names[_rng.randi() % obst_names.size()]
			# avoid two blocking obstacles fully walling if 2 blocked: keep variety
			var s := _acquire("o:" + name)
			_place(rec, s, Vector3(Data.LANES[l], 0, z))
		# coins along a free lane between rows
		var coin_lane: int = free_lanes[_rng.randi() % free_lanes.size()]
		free_lane_history = coin_lane
		if _rng.randf() < 0.85:
			var count := _rng.randi_range(3, 5)
			for k in range(count):
				var cz: float = z + 1.2 + k * 0.9
				if cz > Data.CHUNK_LEN / 2 - 0.5:
					break
				var coin := _acquire("c:coin")
				_place(rec, coin, Vector3(Data.LANES[coin_lane], Data.COLLECTIBLES["coin"]["y"], cz))
				active_pickups.append(coin)
		# occasional food item
		if _rng.randf() < 0.3:
			var item_name: String = ["coconut", "alloco", "akpakpa", "phone"][_rng.randi() % 4]
			if item_name == "phone" and _rng.randf() < 0.6:
				item_name = "alloco"
			var il: int = free_lanes[_rng.randi() % free_lanes.size()]
			var it := _acquire("c:" + item_name)
			_place(rec, it, Vector3(Data.LANES[il], Data.COLLECTIBLES[item_name]["y"], z + 0.5))
			active_pickups.append(it)
	# power-up (rare)
	if _rng.randf() < 0.12:
		var pu_name: String = Data.POWERUPS.keys()[_rng.randi() % Data.POWERUPS.size()]
		var pu := _acquire("p:" + pu_name)
		_place(rec, pu, Vector3(Data.LANES[_rng.randi() % 3], Data.POWERUPS[pu_name]["y"], _rng.randf_range(-3, 3)))
		active_pickups.append(pu)

func _place(rec: Dictionary, s: Spawnable, local_pos: Vector3) -> void:
	var node: Node3D = rec["node"]
	if s.get_parent():
		s.get_parent().remove_child(s)
	node.add_child(s)
	s.activate(local_pos)
	rec["items"].append(s)

func _clear_items(rec: Dictionary) -> void:
	for s in rec["items"]:
		_release(s)
	rec["items"].clear()

# ---------------------------------------------------------------- recycle
func update_stream(player_z: float, diff: float) -> void:
	difficulty = diff
	# find most-behind (max z) and most-ahead (min z)
	var back_i := 0
	var min_z := INF
	for i in range(_chunks.size()):
		var z: float = _chunks[i]["node"].position.z
		if z < min_z:
			min_z = z
	# recycle any chunk that is fully behind the player
	for rec in _chunks:
		if rec["node"].position.z - Data.CHUNK_LEN * 0.5 > player_z + Data.CHUNK_LEN:
			_clear_items(rec)
			min_z -= Data.CHUNK_LEN
			rec["node"].position.z = min_z
			_populate(rec)

func reset() -> void:
	active_pickups.clear()
	difficulty = 0.0
	build_initial()
