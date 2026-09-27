extends Node
# Persistent player data: coins, best score, unlocked/selected skins, settings, daily missions.

const SAVE_PATH := "user://abidjan_runner_save.json"

var coins: int = 0
var best_score: int = 0
var total_runs: int = 0
var selected_skin: String = "urban"
var unlocked_skins: Array = ["urban"]
var sfx_on: bool = true
var music_on: bool = true
var missions: Array = []          # [{id,text,type,target,progress,reward,done,claimed}]
var missions_date: String = ""

signal coins_changed(value)
signal missions_changed()

func _ready() -> void:
	load_game()
	_refresh_missions()

# ---------------------------------------------------------------- currency
func add_coins(n: int) -> void:
	coins += n
	coins_changed.emit(coins)

func spend_coins(n: int) -> bool:
	if coins >= n:
		coins -= n
		coins_changed.emit(coins)
		save_game()
		return true
	return false

# ---------------------------------------------------------------- skins
func is_unlocked(skin: String) -> bool:
	return unlocked_skins.has(skin)

func unlock_skin(skin: String) -> bool:
	if is_unlocked(skin):
		return true
	var price: int = Data.SKINS[skin]["price"]
	if spend_coins(price):
		unlocked_skins.append(skin)
		save_game()
		return true
	return false

func select_skin(skin: String) -> void:
	if is_unlocked(skin):
		selected_skin = skin
		save_game()

# ---------------------------------------------------------------- run results
func register_run(score: int, coins_collected: int, distance_m: int = 0) -> bool:
	total_runs += 1
	add_coins(coins_collected)
	var is_best := score > best_score
	if is_best:
		best_score = score
	_progress_mission("run", 1)
	_progress_mission("distance", distance_m)
	_progress_mission("coins", coins_collected)
	save_game()
	return is_best

# ---------------------------------------------------------------- daily missions
func _today() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func _refresh_missions() -> void:
	var today := _today()
	if missions_date == today and missions.size() == 3:
		return
	missions_date = today
	var seed_val := hash(today)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var pool := [
		{"type": "coins", "text": "Ramasser %d pièces CFA", "opts": [40, 60, 80], "reward": [150, 220, 300]},
		{"type": "distance", "text": "Parcourir %d m en une course", "opts": [800, 1200, 1800], "reward": [150, 250, 350]},
		{"type": "run", "text": "Jouer %d parties", "opts": [3, 5, 8], "reward": [120, 200, 280]},
	]
	missions.clear()
	var i := 0
	for m in pool:
		var idx := rng.randi_range(0, 2)
		var target: int = m["opts"][idx]
		missions.append({
			"id": i,
			"type": m["type"],
			"text": m["text"] % target,
			"target": target,
			"progress": 0,
			"reward": m["reward"][idx],
			"done": false,
			"claimed": false,
		})
		i += 1
	save_game()
	missions_changed.emit()

func _progress_mission(mtype: String, amount: int) -> void:
	for m in missions:
		if m["type"] == mtype and not m["done"]:
			if mtype == "distance":
				m["progress"] = max(m["progress"], amount)  # best single run
			else:
				m["progress"] += amount
			if m["progress"] >= m["target"]:
				m["progress"] = m["target"]
				m["done"] = true
	missions_changed.emit()

func claim_mission(id: int) -> int:
	for m in missions:
		if m["id"] == id and m["done"] and not m["claimed"]:
			m["claimed"] = true
			add_coins(m["reward"])
			save_game()
			missions_changed.emit()
			return m["reward"]
	return 0

# ---------------------------------------------------------------- save / load
func save_game() -> void:
	var d := {
		"coins": coins, "best_score": best_score, "total_runs": total_runs,
		"selected_skin": selected_skin, "unlocked_skins": unlocked_skins,
		"sfx_on": sfx_on, "music_on": music_on,
		"missions": missions, "missions_date": missions_date,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var txt := f.get_as_text()
	f.close()
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		return
	coins = int(d.get("coins", 0))
	best_score = int(d.get("best_score", 0))
	total_runs = int(d.get("total_runs", 0))
	selected_skin = str(d.get("selected_skin", "urban"))
	unlocked_skins = d.get("unlocked_skins", ["urban"])
	if not unlocked_skins.has("urban"):
		unlocked_skins.append("urban")
	sfx_on = bool(d.get("sfx_on", true))
	music_on = bool(d.get("music_on", true))
	missions = d.get("missions", [])
	missions_date = str(d.get("missions_date", ""))
