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

const STAND_CENTER := Vector3(0, 1.0, 0)
const STAND_SIZE := Vector3(0.7, 1.5, 0.7)
const ROLL_CENTER := Vector3(0, 0.35, 0)
const ROLL_SIZE := Vector3(0.7, 0.55, 0.7)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1        # only ground for floor snapping (world layer)
	target_x = Data.LANES[lane]
	_build_hurtbox()
	set_skin(Global.selected_skin)

func _build_hurtbox() -> void:
	var area := Area3D.new()
	area.name = "Hurtbox"
	area.collision_layer = 0
	area.collision_mask = 4 | 8      # obstacles + pickups
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

func set_skin(skin: String) -> void:
	if _model:
		_model.queue_free()
		_model = null
	var scene := Data.model_scene(Data.SKINS[skin]["model"])
	if scene == null:
		return
	_model = scene.instantiate()
	add_child(_model)
	_anim = _find_anim(_model)
	if _anim:
		for a in ["run", "idle"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_play("idle")

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null

func _play(anim: String, speed := 1.0) -> void:
	if _anim and _anim.has_animation(anim):
		_anim.play(anim, 0.12, speed)

# ---------------------------------------------------------------- lifecycle
func begin_run() -> void:
	alive = true
	control_enabled = true
	lane = 1
	target_x = 0.0
	position = Vector3(0, 0, 0)
	vy = 0.0
	rolling = false
	on_ground = true
	_set_hurt(false)
	_play("run", 1.4)

func stop() -> void:
	control_enabled = false

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
		Audio.play("jump")
		_play("jump")

func do_roll() -> void:
	if not control_enabled or rolling:
		return
	rolling = true
	roll_timer = Data.ROLL_TIME
	if not on_ground:
		vy = -Data.JUMP_VELOCITY   # fast-fall into roll
	_set_hurt(true)
	Audio.play("roll")
	_play("roll", 1.0 / Data.ROLL_TIME * 0.6)

func _set_hurt(roll: bool) -> void:
	var box: BoxShape3D = _hurt_shape.shape
	if roll:
		box.size = ROLL_SIZE
		_hurt_shape.position = ROLL_CENTER
	else:
		box.size = STAND_SIZE
		_hurt_shape.position = STAND_CENTER

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
			if not rolling:
				_play("run", 1.4)
		vy = 0.0

	if rolling:
		roll_timer -= delta
		if roll_timer <= 0.0:
			rolling = false
			_set_hurt(false)
			if on_ground:
				_play("run", 1.4)

	# tilt model slightly toward lane movement for juice
	if _model:
		var dx := target_x - position.x
		_model.rotation.z = lerp(_model.rotation.z, clamp(-dx * 0.25, -0.3, 0.3), delta * 10.0)

func die() -> void:
	if not alive:
		return
	alive = false
	control_enabled = false
	_play("hit")
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
