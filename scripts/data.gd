class_name Data
extends RefCounted

# ---------------------------------------------------------------- lanes / world
const LANES := [-2.2, 0.0, 2.2]
const CHUNK_LEN := 12.0
const ACTIVE_CHUNKS := 9

# ---------------------------------------------------------------- speed / score
const START_SPEED := 8.0
const MAX_SPEED := 24.0
const SCORE_PER_M := 1.0

# ---------------------------------------------------------------- player
const JUMP_VELOCITY := 8.2
const GRAVITY := 22.0
const LANE_CHANGE_TIME := 0.12
const ROLL_TIME := 0.6
const CHAR_SCALE := 0.8

# lagoon / bridge biome: every BIOME_CYCLE chunks, LAGOON_LEN chunks of bridge
const BIOME_CYCLE := 28
const LAGOON_START := 14
const LAGOON_LEN := 7

const MODELS := "res://assets/models/"
const KK_CITY := "res://assets/thirdparty/kaykit/city/"
const KK_CHARS := "res://assets/thirdparty/kaykit/characters/"
const KENNEY := "res://assets/thirdparty/kenney/"
const CITY_SCALE := 4.8

# obstacle kind: "jump" (leap over), "roll" (roll under), "block" (switch lane)
# col = [cx, cy, cz, sx, sy, sz] danger volume. Optional: scale, rot (deg Y), tex (albedo override)
const OBSTACLES := {
	"barrier":     {"model": MODELS + "obstacles/barrier.glb", "kind": "jump", "col": [0, 0.4, 0, 1.7, 0.8, 0.4]},
	"pothole":     {"model": MODELS + "obstacles/pothole.glb", "kind": "jump", "col": [0, 0.35, 0, 1.6, 0.7, 1.3]},
	"tire":        {"model": MODELS + "obstacles/tire.glb", "kind": "jump", "col": [0, 0.5, 0, 1.1, 1.0, 1.0]},
	"cone":        {"model": MODELS + "obstacles/cone.glb", "kind": "jump", "col": [0, 0.4, 0, 0.7, 0.8, 0.7]},
	"drum":        {"model": MODELS + "obstacles/drum.glb", "kind": "jump", "col": [0, 0.55, 0, 0.9, 1.1, 0.9]},
	"lowbar":      {"model": MODELS + "obstacles/lowbar.glb", "kind": "roll", "col": [0, 1.45, 0, 2.1, 1.3, 0.3]},
	"taxi":        {"model": KK_CITY + "car_taxi.gltf", "kind": "block", "col": [0, 1.0, 0, 1.8, 2.0, 4.2],
					"scale": CITY_SCALE, "rot": 180, "tex": KK_CITY + "citybits_abidjan.png"},
	"woro":        {"model": KK_CITY + "car_sedan.gltf", "kind": "block", "col": [0, 1.0, 0, 1.8, 2.0, 4.2],
					"scale": CITY_SCALE, "rot": 180, "tex": KK_CITY + "citybits_abidjan.png"},
	"dumpster":    {"model": KK_CITY + "dumpster.gltf", "kind": "block", "col": [0, 1.0, 0, 1.6, 2.0, 2.6],
					"scale": 4.2, "rot": 90},
	"cart":        {"model": MODELS + "obstacles/cart.glb", "kind": "block", "col": [0, 1.0, 0, 1.5, 2.0, 1.1]},
	"stall":       {"model": MODELS + "obstacles/stall.glb", "kind": "block", "col": [0, 1.0, 0, 1.7, 2.0, 1.1]},
}

# collectibles: coin is currency; others bonus score
const COLLECTIBLES := {
	"coin":    {"model": KENNEY + "platformer/coin.glb", "coins": 1, "score": 10, "spin": true, "y": 0.75, "scale": 1.5},
	"coconut": {"model": MODELS + "collectibles/coconut.glb", "coins": 0, "score": 50, "spin": false, "y": 0.5},
	"alloco":  {"model": MODELS + "collectibles/alloco.glb", "coins": 0, "score": 40, "spin": false, "y": 0.6},
	"akpakpa": {"model": MODELS + "collectibles/akpakpa.glb", "coins": 0, "score": 40, "spin": false, "y": 0.6},
	"phone":   {"model": MODELS + "collectibles/phone.glb", "coins": 5, "score": 100, "spin": true, "y": 0.9},
}

const POWERUPS := {
	"magnet": {"model": MODELS + "collectibles/pu_magnet.glb", "y": 1.0, "dur": 7.0, "color": Color(1.0, 0.3, 0.3)},
	"shield": {"model": MODELS + "collectibles/pu_shield.glb", "y": 1.0, "dur": 0.0, "color": Color(0.3, 0.7, 1.0)},
	"x2":     {"model": MODELS + "collectibles/pu_x2.glb", "y": 1.0, "dur": 8.0, "color": Color(1.0, 0.85, 0.2)},
}

# 4 skins built from KayKit rigs (CC0) with recoloured palette textures
const SKINS := {
	"urban": {"base": "mage", "name": "Urbain", "price": 0},
	"trad":  {"base": "mage", "name": "Habits Traditionnels", "price": 500},
	"foot":  {"base": "barbarian", "name": "Footballeur", "price": 800},
	"biz":   {"base": "knight", "name": "Businessman", "price": 1200},
}

# logical animation -> KayKit clip
const ANIMS := {
	"idle": "Idle", "run": "Running_A", "jump": "Jump_Full_Short", "roll": "Dodge_Forward",
	"hit": "Hit_A", "death": "Death_A", "cheer": "Cheer", "land": "Jump_Land",
}

const BUILDINGS := ["building_A", "building_B", "building_C", "building_D",
	"building_E", "building_F", "building_G", "building_H"]
const TOWERS := ["tower_0", "tower_1", "tower_2", "tower_3"]
const PALMS := ["palm_0", "palm_1", "palm_2"]
const SIDEWALK_PROPS := ["bench", "bush", "firehydrant", "trash_A", "trash_B", "box_A"]

static var _cache := {}

static func scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]

static func model_scene(rel: String) -> PackedScene:
	return scene(MODELS + rel)

static func skin_texture(skin: String) -> Texture2D:
	return scene_tex(KK_CHARS + "skins/%s.png" % skin)

static func scene_tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]

# Apply an albedo texture override to every mesh in a model (keeps imported material settings).
# Materials are cached per (source material, texture) so instances keep sharing them.
static func retexture(root: Node, tex: Texture2D) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		for s in m3.mesh.get_surface_count():
			var base := m3.mesh.surface_get_material(s)
			if not (base is StandardMaterial3D):
				continue
			var key := "mat:%d:%d" % [base.get_instance_id(), tex.get_instance_id()]
			if not _cache.has(key):
				var m: StandardMaterial3D = base.duplicate()
				m.albedo_texture = tex
				_cache[key] = m
			m3.set_surface_override_material(s, _cache[key])
