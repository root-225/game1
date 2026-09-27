class_name Data
extends RefCounted

# ---------------------------------------------------------------- lanes / world
const LANES := [-2.2, 0.0, 2.2]
const CHUNK_LEN := 12.0
const ACTIVE_CHUNKS := 8

# ---------------------------------------------------------------- speed / score
const START_SPEED := 8.0
const MAX_SPEED := 24.0
const ACCEL := 0.09          # m/s gained per second of play
const SCORE_PER_M := 1.0
const COIN_SCORE := 10

# ---------------------------------------------------------------- player
const JUMP_VELOCITY := 8.2
const GRAVITY := 22.0
const LANE_CHANGE_TIME := 0.12
const ROLL_TIME := 0.6

const MODELS := "res://assets/models/"

# obstacle kind: "jump" (leap over), "roll" (roll under), "block" (switch lane)
# col = [cx, cy, cz, sx, sy, sz] danger volume
const OBSTACLES := {
	"barrier":      {"model": "obstacles/barrier.glb",      "kind": "jump",  "col": [0, 0.4, 0, 1.7, 0.8, 0.4]},
	"pothole":      {"model": "obstacles/pothole.glb",      "kind": "jump",  "col": [0, 0.35, 0, 1.6, 0.7, 1.3]},
	"tire":         {"model": "obstacles/tire.glb",         "kind": "jump",  "col": [0, 0.5, 0, 1.1, 1.0, 1.0]},
	"cone":         {"model": "obstacles/cone.glb",         "kind": "jump",  "col": [0, 0.4, 0, 0.7, 0.8, 0.7]},
	"drum":         {"model": "obstacles/drum.glb",         "kind": "jump",  "col": [0, 0.55, 0, 0.9, 1.1, 0.9]},
	"lowbar":       {"model": "obstacles/lowbar.glb",       "kind": "roll",  "col": [0, 1.45, 0, 2.1, 1.3, 0.3]},
	"parked_taxi":  {"model": "obstacles/parked_taxi.glb",  "kind": "block", "col": [0, 1.0, 0, 1.5, 2.0, 2.4]},
	"cart":         {"model": "obstacles/cart.glb",         "kind": "block", "col": [0, 1.0, 0, 1.5, 2.0, 1.1]},
	"stall":        {"model": "obstacles/stall.glb",        "kind": "block", "col": [0, 1.0, 0, 1.7, 2.0, 1.1]},
}

# collectibles: coin is currency; others bonus score
const COLLECTIBLES := {
	"coin":    {"model": "collectibles/coin.glb",    "coins": 1, "score": 10, "spin": true, "y": 0.9},
	"coconut": {"model": "collectibles/coconut.glb", "coins": 0, "score": 50, "spin": false, "y": 0.5},
	"alloco":  {"model": "collectibles/alloco.glb",  "coins": 0, "score": 40, "spin": false, "y": 0.6},
	"akpakpa": {"model": "collectibles/akpakpa.glb", "coins": 0, "score": 40, "spin": false, "y": 0.6},
	"phone":   {"model": "collectibles/phone.glb",   "coins": 5, "score": 100, "spin": true, "y": 0.9},
}

const POWERUPS := {
	"magnet": {"model": "collectibles/pu_magnet.glb", "y": 1.0, "dur": 7.0},
	"shield": {"model": "collectibles/pu_shield.glb", "y": 1.0, "dur": 0.0},
	"x2":     {"model": "collectibles/pu_x2.glb",     "y": 1.0, "dur": 8.0},
}

const SKINS := {
	"urban": {"model": "characters/urban.glb", "name": "Urbain Casual", "price": 0},
	"trad":  {"model": "characters/trad.glb",  "name": "Habits Traditionnels", "price": 500},
	"foot":  {"model": "characters/foot.glb",  "name": "Footballeur", "price": 800},
	"biz":   {"model": "characters/biz.glb",   "name": "Businessman", "price": 1200},
}

const ENV := {
	"road":    "env/road.glb",
	"ground":  "env/ground.glb",
	"bridge":  "env/bridge.glb",
	"kiosk":   "env/kiosk.glb",
	"taxi":    "env/taxi.glb",
	"buildings": ["env/building_0.glb", "env/building_1.glb", "env/building_2.glb"],
	"palms":   ["env/palm_0.glb", "env/palm_1.glb"],
}

static func model_scene(rel: String) -> PackedScene:
	return load(MODELS + rel) as PackedScene
