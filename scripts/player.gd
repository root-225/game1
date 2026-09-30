class_name Player
extends CharacterBody3D
# 3-lane runner: swipe / keys to change lane, jump, roll. Detects obstacles & pickups.

signal hit_obstacle(node)
signal picked(node)

var lane := 1
var target_x := 0.0
var vy := 0.0
var on_ground := true
var rolling := false
var roll_timer := 0.0
var alive := true
var control_enabled := false

var _anim: AnimationPlayer
var _model: Node3D
var _hurt_shape: CollisionShape3D
var _swipe_start := Vector2.ZERO
var _swiping := false
var _dust: CPUParticles3D
var _land_puff: CPUParticles3D
var _sparkle: CPUParticles3D
var _bubble: MeshInstance3D
var _facing := PI            # PI = back to camera (running), 0 = facing camera (menu)

const STAND_CENTER := Vector3(0, 1.0, 0)
const STAND_SIZE := Vector3(0.7, 1.5, 0.7)
const ROLL_CENTER := Vector3(0, 0.35, 0)
const ROLL_SIZE := Vector3(0.7, 0.55, 0.7)
const AIR_TIME := 2.0 * Data.JUMP_VELOCITY / Data.GRAVITY

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	target_x = Data.LANES[lane]
	_build_hurtbox()
	_build_fx()
	set_skin(Global.selected_skin)

func _build_hurtbox() -> void:
	var area := Area3D.new()
	area.name = "Hurtbox"
	area.collision_layer = 0
	area.collision_mask = 4 | 8
	area.monitoring = true
	area.monitorable = false
	_hurt_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = STAND_SIZE
	_hurt_shape.shape = box
	_hurt_shape.position = STAND_CENTER
	area.add_child(_hurt_shape)
	add_child(area)
	area.area_entered.connect(_on_area_entered)

# ---------------------------------------------------------------- FX
func _sprite_mat(tex_path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(tex_path)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	return m

func _particles(tex: String, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	q.material = _sprite_mat(tex)
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.8, 0.72, 0.45))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = sc
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _build_fx() -> void:
	_dust = _particles("res://assets/textures/dust.png", 14, 0.5)
	_dust.position = Vector3(0, 0.05, 0.4)
	_dust.direction = Vector3(0, 0.6, 1)
	_dust.spread = 25
	_dust.initial_velocity_min = 1.0
	_dust.initial_velocity_max = 2.2
	_dust.gravity = Vector3(0, 0.5, 0)
	_dust.emitting = false

	_land_puff = _particles("res://assets/textures/dust.png", 16, 0.45)
	_land_puff.position = Vector3(0, 0.1, 0)
	_land_puff.one_shot = true
	_land_puff.explosiveness = 1.0
	_land_puff.direction = Vector3(0, 0.2, 0)
	_land_puff.spread = 90
	_land_puff.flatness = 0.8
	_land_puff.initial_velocity_min = 2.0
	_land_puff.initial_velocity_max = 3.5
	_land_puff.emitting = false

	_sparkle = _particles("res://assets/textures/sparkle.png", 10, 0.35)
	_sparkle.position = Vector3(0, 1.1, -0.3)
	_sparkle.one_shot = true
	_sparkle.explosiveness = 1.0
	_sparkle.spread = 180
	_sparkle.initial_velocity_min = 2.0
	_sparkle.initial_velocity_max = 3.5
	_sparkle.gravity = Vector3.ZERO
	_sparkle.emitting = false

	_bubble = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.05
	sph.height = 2.1
	sph.radial_segments = 24
	sph.rings = 12
	_bubble.mesh = sph
	var bm := StandardMaterial3D.new()
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.35, 0.75, 1.0, 0.3)
	bm.emission_enabled = true
	bm.emission = Color(0.2, 0.55, 1.0)
	bm.emission_energy_multiplier = 0.6
	_bubble.material_override = bm
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.position.y = 0.95
	_bubble.visible = false
	add_child(_bubble)

func sparkle() -> void:
	_sparkle.restart()

func set_shield_visual(on: bool) -> void:
	_bubble.visible = on

# ---------------------------------------------------------------- skin / anims
func set_skin(skin: String) -> void:
	if _model:
		_model.queue_free()
		_model = null
	_model = Data.scene(Data.SKINS[skin]["model"]).instantiate()
	_model.scale = Vector3.ONE * Data.CHAR_SCALE
	_model.rotation.y = _facing
	Mats.add_outline(_model, 0.012, Data.CHAR_SCALE, Color(0.06, 0.05, 0.08), ["Face", "Eye"])
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false)
	if _anim:
		for key in ["run", "idle", "cheer"]:
			var clip: String = Data.ANIMS[key]
			if _anim.has_animation(clip):
				_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_play("idle")

func face(angle: float, instant := false) -> void:
	_facing = angle
	if not _model:
		return
	if instant:
		_model.rotation.y = angle
	else:
		create_tween().tween_property(_model, "rotation:y", angle, 0.35).set_trans(Tween.TRANS_SINE)

var run_rate := 1.0

# The run cycle speeds up with the game; other clips play at their own timing.
func set_run_rate(r: float) -> void:
	run_rate = r
	if _anim and _anim.current_animation == Data.ANIMS["run"]:
		_anim.speed_scale = r

func _play(key: String, speed := 1.0) -> void:
	var clip: String = Data.ANIMS.get(key, key)
	if _anim and _anim.has_animation(clip):
		_anim.speed_scale = run_rate if key == "run" else 1.0
		_anim.play(clip, 0.15, speed)

func _clip_len(key: String) -> float:
	var clip: String = Data.ANIMS[key]
	return _anim.get_animation(clip).length if _anim and _anim.has_animation(clip) else 1.0

# ---------------------------------------------------------------- lifecycle
func begin_run() -> void:
	alive = true
	control_enabled = true
	lane = 1
	target_x = 0.0
	position = Vector3.ZERO
	vy = 0.0
	rolling = false
	on_ground = true
	_set_hurt(false)
	set_shield_visual(false)
	face(PI)
	_play("run")
	_dust.emitting = true

func stop() -> void:
	control_enabled = false
	_dust.emitting = false

# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if not control_enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start = event.position
			_swiping = true
		elif _swiping:
			_resolve_swipe(event.position - _swipe_start)
			_swiping = false
	elif event is InputEventScreenDrag and _swiping:
		if (event.position - _swipe_start).length() > 60:
			_resolve_swipe(event.position - _swipe_start)
			_swiping = false

func _resolve_swipe(d: Vector2) -> void:
	if abs(d.x) > abs(d.y):
		if d.x > 0: do_right()
		else: do_left()
	else:
		if d.y < 0: do_jump()
		else: do_roll()

func do_left() -> void:
	if control_enabled and lane > 0:
		lane -= 1
		target_x = Data.LANES[lane]

func do_right() -> void:
	if control_enabled and lane < 2:
		lane += 1
		target_x = Data.LANES[lane]

func do_jump() -> void:
	if control_enabled and on_ground and not rolling:
		vy = Data.JUMP_VELOCITY
		on_ground = false
		_dust.emitting = false
		Audio.play("jump")
		_play("jump", _clip_len("jump") / AIR_TIME)

func do_roll() -> void:
	if not control_enabled or rolling:
		return
	rolling = true
	roll_timer = Data.ROLL_TIME
	if not on_ground:
		vy = -Data.JUMP_VELOCITY
	_set_hurt(true)
	Audio.play("roll")
	_play("roll", _clip_len("roll") / Data.ROLL_TIME)

func _set_hurt(roll: bool) -> void:
	var box: BoxShape3D = _hurt_shape.shape
	box.size = ROLL_SIZE if roll else STAND_SIZE
	_hurt_shape.position = ROLL_CENTER if roll else STAND_CENTER

# ---------------------------------------------------------------- physics
func _physics_process(delta: float) -> void:
	if not control_enabled:
		return
	if Input.is_action_just_pressed("move_left"): do_left()
	if Input.is_action_just_pressed("move_right"): do_right()
	if Input.is_action_just_pressed("jump"): do_jump()
	if Input.is_action_just_pressed("roll"): do_roll()

	position.x = lerp(position.x, target_x, clamp(delta / Data.LANE_CHANGE_TIME, 0, 1))

	vy -= Data.GRAVITY * delta
	position.y += vy * delta
	if position.y <= 0.0:
		position.y = 0.0
		if not on_ground:
			on_ground = true
			_land_puff.restart()
			Audio.play("land")
			_dust.emitting = true
			if not rolling:
				_play("run")
		vy = 0.0

	if rolling:
		roll_timer -= delta
		if roll_timer <= 0.0:
			rolling = false
			_set_hurt(false)
			if on_ground:
				_play("run")

	if _model:
		var dx := target_x - position.x
		_model.rotation.z = lerp(_model.rotation.z, clamp(-dx * 0.2, -0.25, 0.25), delta * 10.0)

func die() -> void:
	if not alive:
		return
	alive = false
	control_enabled = false
	_dust.emitting = false
	_play("death")
	Audio.play("hit")

func _on_area_entered(area: Area3D) -> void:
	if not (area is Spawnable) or not alive:
		return
	var s: Spawnable = area
	if s.collected:
		return
	if s.category == "obstacle":
		hit_obstacle.emit(s)
	else:
		s.mark_collected()
		picked.emit(s)
