class_name Game
extends Node3D
# 3D gameplay: world, camera, player, streaming, score, power-ups.

signal score_changed(score, coins, distance)
signal power_changed(states)
signal game_over(score, coins, best, is_best)
signal started()

enum St { IDLE, PLAYING, DEAD }

var state := St.IDLE
var speed := Data.START_SPEED
var distance := 0.0
var score := 0.0
var coins_run := 0

var magnet_t := 0.0
var x2_t := 0.0
var shield := false

var player: Player
var chunks: ChunkManager
var camera: Camera3D
var _ground: MeshInstance3D
var _sun: DirectionalLight3D

func _ready() -> void:
	_build_environment()
	chunks = ChunkManager.new()
	chunks.name = "Chunks"
	add_child(chunks)
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.hit_obstacle.connect(_on_hit)
	player.picked.connect(_on_pick)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.current = true
	add_child(camera)
	_update_camera(1.0, true)

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.85, 0.80, 0.70)
	sky_mat.ground_horizon_color = Color(0.85, 0.80, 0.70)
	sky_mat.ground_bottom_color = Color(0.55, 0.60, 0.55)
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.82, 0.82, 0.74)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-40), 0)
	_sun.light_energy = 1.15
	_sun.light_color = Color(1.0, 0.96, 0.86)
	_sun.shadow_enabled = true
	add_child(_sun)

	_ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(240, 400)
	_ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.30, 0.42, 0.22)
	gm.roughness = 1.0
	_ground.material_override = gm
	_ground.position.y = -0.18
	add_child(_ground)

# ---------------------------------------------------------------- flow
func start_run() -> void:
	speed = Data.START_SPEED
	distance = 0.0
	score = 0.0
	coins_run = 0
	magnet_t = 0.0
	x2_t = 0.0
	shield = false
	Spawnable.magnet_active = false
	chunks.reset()
	player.begin_run()
	state = St.PLAYING
	Audio.start_music()
	started.emit()
	_emit_score()
	_emit_power()

func _physics_process(delta: float) -> void:
	if state != St.PLAYING:
		if state == St.IDLE:
			_idle_spin(delta)
		return
	speed = min(Data.START_SPEED + distance * 0.02, Data.MAX_SPEED)
	var d := speed * delta
	distance += d
	player.position.z -= d
	var mult := 2.0 if x2_t > 0 else 1.0
	score += d * Data.SCORE_PER_M * mult

	if player._anim:
		player._anim.speed_scale = clamp(speed / Data.START_SPEED, 1.0, 2.2)

	# power-up timers
	if magnet_t > 0:
		magnet_t -= delta
		Spawnable.magnet_active = magnet_t > 0
		Spawnable.magnet_target = player.global_position + Vector3(0, 0.6, 0)
	if x2_t > 0:
		x2_t -= delta
	if magnet_t <= 0:
		Spawnable.magnet_active = false

	chunks.update_stream(player.position.z, clamp(distance / 2000.0, 0, 1))
	_update_camera(delta, false)
	_emit_score()

func _idle_spin(delta: float) -> void:
	# gentle camera drift on menu
	if player:
		_update_camera(delta, false)

func _update_camera(delta: float, instant: bool) -> void:
	var tx: float = player.position.x * 0.45
	var target := Vector3(tx, 4.3, player.position.z + 7.0)
	if instant:
		camera.position = target
	else:
		camera.position = camera.position.lerp(target, clamp(delta * 6.0, 0, 1))
	camera.look_at(Vector3(player.position.x * 0.5, 1.2, player.position.z - 6.0), Vector3.UP)
	_ground.position.z = player.position.z
	_sun.position = player.position

# ---------------------------------------------------------------- events
func _on_hit(obstacle: Spawnable) -> void:
	if state != St.PLAYING:
		return
	if shield:
		shield = false
		Audio.play("powerup", 0.7)
		obstacle.mark_collected()
		_emit_power()
		return
	_do_game_over()

func _on_pick(s: Spawnable) -> void:
	if s.category == "powerup":
		_apply_powerup(s.subtype)
		Audio.play("powerup")
	else:
		var mult := 2 if x2_t > 0 else 1
		var c: int = s.info.get("coins", 0)
		var sc: int = s.info.get("score", 0)
		if c > 0:
			coins_run += c
			Audio.play("coin", randf_range(0.95, 1.15))
		else:
			Audio.play("coin", 1.3)
		score += sc * mult
	_emit_score()

func _apply_powerup(kind: String) -> void:
	match kind:
		"magnet":
			magnet_t = Data.POWERUPS["magnet"]["dur"]
		"x2":
			x2_t = Data.POWERUPS["x2"]["dur"]
		"shield":
			shield = true
	_emit_power()

func _do_game_over() -> void:
	state = St.DEAD
	player.die()
	Audio.stop_music()
	Audio.play("gameover")
	var final_score := int(score)
	var is_best := Global.register_run(final_score, coins_run, int(distance))
	game_over.emit(final_score, coins_run, Global.best_score, is_best)

func _emit_score() -> void:
	score_changed.emit(int(score), coins_run, int(distance))

func _emit_power() -> void:
	power_changed.emit({
		"magnet": magnet_t, "x2": x2_t, "shield": shield,
		"magnet_dur": Data.POWERUPS["magnet"]["dur"], "x2_dur": Data.POWERUPS["x2"]["dur"],
	})

func set_paused(p: bool) -> void:
	if state == St.PLAYING or state == St.DEAD:
		get_tree().paused = p

# show a character idling on the menu
func show_menu_player() -> void:
	state = St.IDLE
	player.position = Vector3(0, 0, 0)
	player.stop()
	if player._anim:
		player._anim.speed_scale = 1.0
		player._play("idle")
	chunks.reset()
	_update_camera(1.0, true)
