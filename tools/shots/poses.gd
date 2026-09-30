extends Node3D
# Dev-only: pose sheet. args: <glb res path> <out png> [view: side|front]
const SHOTS := [["idle", 0.3], ["run", 0.0], ["run", 0.2], ["run", 0.4], ["jump", 0.45], ["slide", 0.3],
	["slide", 0.55], ["hit", 0.3], ["death", 0.79], ["cheer", 0.6]]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var view: String = a[2] if a.size() > 2 else "side"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.62, 0.72, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.8, 0.85); env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -30, 0); sun.shadow_enabled = true; add_child(sun)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 20); floor.mesh = pm; add_child(floor)
	var sc: PackedScene = load(a[0])
	for i in SHOTS.size():
		var inst: Node3D = sc.instantiate()
		add_child(inst)
		inst.position = Vector3(0, 0, -i * 2.0) if view == "side" else Vector3(i * 1.9, 0, 0)
		if view == "front": inst.rotation.y = 0.5
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		ap.play(SHOTS[i][0]); ap.seek(SHOTS[i][1], true); ap.pause()
	var cam := Camera3D.new(); add_child(cam); cam.current = true
	var mid := (SHOTS.size() - 1) * (2.0 if view == "side" else 1.9) / 2.0
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 3.2
	if view == "side":
		cam.size = 3.6; cam.position = Vector3(20, 1.0, -mid); cam.look_at(Vector3(0, 1.0, -mid))
	else:
		cam.size = 3.6; cam.position = Vector3(mid, 1.2, 20); cam.look_at(Vector3(mid, 1.0, 0))
	for i in 12: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(a[1])
	get_tree().quit()
