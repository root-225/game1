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
var _sun: DirectionalLight3D
var _clouds: Array[Node3D] = []
var _menu_t := 0.0
var _power_acc := 0.0
# menu/shop framing: camera distance, camera height, look-at height (lower = runner higher on screen)
var _menu_view := Vector3(5.4, 1.0, 0.1)

const SKY_TOP := Color(0.12, 0.36, 0.78)
const HORIZON := Color(0.56, 0.72, 0.88)
const CAM_RUN_OFFSET := Vector3(0, 4.5, 7.3)
const CLOUD_SPAN := 220.0

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
	camera.fov = 60.0
	camera.far = 260.0
	camera.current = true
	add_child(camera)
	_build_clouds()

func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SKY_TOP
	sky_mat.sky_horizon_color = HORIZON
	sky_mat.sky_curve = 0.09
	sky_mat.ground_horizon_color = HORIZON
	sky_mat.ground_bottom_color = Color(0.30, 0.38, 0.42)
	sky_mat.sun_angle_max = 18.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# less ambient + stronger sun = real shadows/contrast instead of a flat, washed-out image
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.95, 0.88, 0.80)
	env.ambient_light_sky_contribution = 0.55     # rest is warm neutral: no blue cast on asphalt
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 5.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15
	env.adjustment_brightness = 1.0
	# depth fog only fades the far end of the stream (hides chunk pop-in), tinted sky blue
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HORIZON
	env.fog_density = 1.0
	env.fog_depth_begin = 70.0
	env.fog_depth_end = 140.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.0
	env.glow_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-35), 0)
	_sun.light_energy = 1.45
	_sun.light_color = Color(1.0, 0.93, 0.80)
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.2
	_sun.shadow_opacity = 0.85
	_sun.directional_shadow_max_distance = 55.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(_sun)

func _build_clouds() -> void:
	var scene := Data.scene(Data.KENNEY + "platformer/cloud.glb")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 14:
		var c: Node3D = scene.instantiate()
		c.scale = Vector3(rng.randf_range(9, 16), rng.randf_range(2.5, 4.5), rng.randf_range(6, 10))
		c.position = Vector3(rng.randf_range(-70, 70), rng.randf_range(34, 52), -rng.randf_range(0, CLOUD_SPAN))
		c.rotation.y = rng.randf() * TAU
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(c)
		_clouds.append(c)

func _update_clouds(delta: float) -> void:
	var pz := player.position.z
	for c in _clouds:
		c.position.x += delta * 0.6
		if c.position.z > pz + 40.0:
			c.position.z -= CLOUD_SPAN
		elif c.position.z < pz - CLOUD_SPAN:
			c.position.z += CLOUD_SPAN

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
	var retry := state == St.DEAD
	if retry:
		chunks.reset()
	player.set_skin(Global.selected_skin)
	player.begin_run()
	if retry:
		camera.position = CAM_RUN_OFFSET
	state = St.PLAYING
	Audio.start_music()
	started.emit()
	_emit_score()
	_emit_power()

func _physics_process(delta: float) -> void:
	_update_clouds(delta)
	if state == St.IDLE:
		_menu_camera(delta)
		return
	if state == St.DEAD:
		_update_camera(delta)
		return
	speed = min(Data.START_SPEED + distance * 0.02, Data.MAX_SPEED)
	var d := speed * delta
	distance += d
	player.position.z -= d
	var mult := 2.0 if x2_t > 0 else 1.0
	score += d * Data.SCORE_PER_M * mult
	player.set_run_rate(clamp(speed / Data.START_SPEED, 1.0, 1.9))

	var timed := magnet_t > 0 or x2_t > 0
	if magnet_t > 0:
		magnet_t -= delta
		Spawnable.magnet_target = player.global_position + Vector3(0, 0.6, 0)
	Spawnable.magnet_active = magnet_t > 0
	if x2_t > 0:
		x2_t -= delta
	if timed:
		# keep the HUD timer bars moving and drop icons as soon as an effect ends
		_power_acc += delta
		if _power_acc >= 0.1 or (magnet_t <= 0 and x2_t <= 0):
			_power_acc = 0.0
			_emit_power()

	chunks.update_stream(player.position.z, clamp(distance / 2000.0, 0, 1))
	_update_camera(delta)
	_emit_score()

func _update_camera(delta: float) -> void:
	var p := player.position
	var target := Vector3(p.x * 0.45, CAM_RUN_OFFSET.y + p.y * 0.25, p.z + CAM_RUN_OFFSET.z)
	camera.position = camera.position.lerp(target, clamp(delta * 5.0, 0, 1))
	var look := Vector3(p.x * 0.5, 0.9 + p.y * 0.3, p.z - 9.0)
	camera.transform = camera.transform.looking_at(look, Vector3.UP)
	_sun.position = p

func _menu_camera(delta: float) -> void:
	# slow orbit in front of the runner, street behind him
	_menu_t += delta
	var p := player.position
	var ang := sin(_menu_t * 0.35) * 0.35
	var d := _menu_view.x
	var target := p + Vector3(sin(ang) * d, _menu_view.y, cos(ang) * d)
	camera.position = camera.position.lerp(target, clamp(delta * 3.0, 0, 1))
	camera.transform = camera.transform.looking_at(p + Vector3(0, _menu_view.z, 0), Vector3.UP)

func set_menu_view(dist: float, cam_h: float, look_y: float) -> void:
	_menu_view = Vector3(dist, cam_h, look_y)

# ---------------------------------------------------------------- events
func _on_hit(obstacle: Spawnable) -> void:
	if state != St.PLAYING:
		return
	if shield:
		shield = false
		player.set_shield_visual(false)
		Audio.play("break")
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
			Audio.play("coin", randf_range(0.95, 1.12))
		else:
			Audio.play("coin", 1.3)
		score += sc * mult
		player.sparkle()
	_emit_score()

func _apply_powerup(kind: String) -> void:
	match kind:
		"magnet":
			magnet_t = Data.POWERUPS["magnet"]["dur"]
		"x2":
			x2_t = Data.POWERUPS["x2"]["dur"]
		"shield":
			shield = true
			player.set_shield_visual(true)
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

# ---------------------------------------------------------------- menu / shop
func show_menu_player() -> void:
	state = St.IDLE
	player.stop()
	player.position = Vector3.ZERO
	player.set_skin(Global.selected_skin)
	player.face(0.0, true)
	player.set_run_rate(1.0)
	player._play("idle")
	chunks.reset()
	_menu_t = 0.0
	var p := player.position
	camera.position = p + Vector3(0, _menu_view.y, _menu_view.x)
	camera.transform = camera.transform.looking_at(p + Vector3(0, _menu_view.z, 0), Vector3.UP)

func preview_skin(skin: String) -> void:
	player.set_skin(skin)
	player.face(0.0, true)
	player._play("cheer")
