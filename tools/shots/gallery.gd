extends Node3D
# Dev-only: render rows of models + print their world AABB sizes.
var out := "/tmp/"
const SETS := {
	"chars": ["res://assets/thirdparty/gdquest/runner_urban.glb", "res://assets/thirdparty/gdquest/runner_trad.glb",
		"res://assets/thirdparty/gdquest/runner_foot.glb", "res://assets/thirdparty/gdquest/runner_biz.glb"],
	"city": ["res://assets/thirdparty/kaykit/city/building_A.gltf", "res://assets/thirdparty/kaykit/city/building_B.gltf",
		"res://assets/thirdparty/kaykit/city/building_C.gltf", "res://assets/thirdparty/kaykit/city/building_D.gltf",
		"res://assets/thirdparty/kaykit/city/building_E.gltf", "res://assets/thirdparty/kaykit/city/building_F.gltf",
		"res://assets/thirdparty/kaykit/city/building_G.gltf", "res://assets/thirdparty/kaykit/city/building_H.gltf"],
	"props": ["res://assets/thirdparty/kaykit/city/car_taxi.gltf", "res://assets/thirdparty/kaykit/city/car_sedan.gltf",
		"res://assets/thirdparty/kaykit/city/streetlight.gltf", "res://assets/thirdparty/kaykit/city/trafficlight_A.gltf",
		"res://assets/thirdparty/kaykit/city/bench.gltf", "res://assets/thirdparty/kaykit/city/bush.gltf",
		"res://assets/thirdparty/kaykit/city/dumpster.gltf", "res://assets/thirdparty/kaykit/city/trash_A.gltf",
		"res://assets/thirdparty/kaykit/city/firehydrant.gltf", "res://assets/thirdparty/kenney/platformer/coin.glb",
		"res://assets/thirdparty/kenney/platformer/cloud.glb"],
}

func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = c.global_transform * c.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "chars"
	if args.size() > 1: out = args[1].trim_suffix("/") + "/"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.7, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, -35, 0); sun.shadow_enabled = true; add_child(sun)
	var x := 0.0
	var models: Array = SETS.get(which, [])
	var maxh := 0.0
	if which == "runners":
		models = []
		for k in ["urban", "trad", "foot", "biz"]: models.append("res://assets/thirdparty/gdquest/work/runner_%s.glb" % k)
	if which == "man":
		models = ["res://assets/thirdparty/gdquest/mannequiny.glb", "res://assets/thirdparty/gdquest/mannequiny.glb"]
	if which == "cars":
		models = [Data.OBSTACLES["taxi"], Data.OBSTACLES["woro"], Data.OBSTACLES["dumpster"]]
	if which == "vendors":
		models = [Data.OBSTACLES["stall"], Data.OBSTACLES["cart"], Data.OBSTACLES["barrier"], Data.OBSTACLES["cone"], Data.OBSTACLES["tire"], Data.OBSTACLES["drum"]]
	if which == "obstacles":
		models = []
		for k in Data.OBSTACLES: models.append(Data.OBSTACLES[k])
		for k in ["coin", "coconut", "alloco", "akpakpa", "phone"]: models.append(Data.COLLECTIBLES[k])
		for k in Data.POWERUPS: models.append(Data.POWERUPS[k])
	for p0 in models:
		var p = p0
		var inst: Node3D
		if false:
			pass
		elif p is Dictionary:
			inst = load(p["model"]).instantiate()
			inst.scale = Vector3.ONE * p.get("scale", 1.0)
			inst.rotation.y = deg_to_rad(p.get("rot", 0.0))
			if p.has("tex"): Data.retexture(inst, load(p["tex"]))
			p = p["model"]
		else:
			inst = load(p).instantiate()
		add_child(inst)
		var ap := inst.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation("Running_A"): ap.play("Running_A"); ap.seek(0.2, true)
		if ap and ap.has_animation("run") and x > 0.0: ap.play("run"); ap.seek(0.2, true)
		if ap and which == "runners": ap.play("idle"); ap.seek(0.3, true)
		var a := _aabb(inst)
		print("%-60s size=(%.2f, %.2f, %.2f) min=(%.2f,%.2f,%.2f)" % [p.get_file(), a.size.x, a.size.y, a.size.z, a.position.x, a.position.y, a.position.z])
		inst.position.x = x - a.position.x
		x += a.size.x + 0.4
		maxh = max(maxh, a.size.y)
	var cam := Camera3D.new(); add_child(cam)
	if which == "runners" and OS.get_cmdline_user_args().size() > 2:
		cam.current = true
		cam.fov = 30
		cam.position = Vector3(x * 0.5, 1.45, 3.4)
		cam.look_at(Vector3(x * 0.5, 1.4, 0))
		for i in 20: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "gallery_faces.png")
		get_tree().quit()
		return
	var mid := x * 0.5
	cam.position = Vector3(mid, maxh * 0.7, max(x * 0.62, maxh * 1.6))
	cam.look_at(Vector3(mid, maxh * 0.4, 0))
	cam.current = true
	for i in 20: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "gallery_" + which + ".png")
	get_tree().quit()
