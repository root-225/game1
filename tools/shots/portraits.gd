extends Node3D
# Dev-only: render transparent shop portraits of each skin -> assets/ui/skins/<skin>.png
func _ready() -> void:
	get_viewport().transparent_bg = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 25, 0); sun.light_energy = 1.1; add_child(sun)
	var cam := Camera3D.new(); add_child(cam)
	cam.fov = 30
	cam.position = Vector3(0.45, 1.35, 3.6)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/skins"))
	for skin in Data.SKINS.keys():
		var m: Node3D = Data.scene(Data.SKINS[skin]["model"]).instantiate()
		m.scale = Vector3.ONE * Data.CHAR_SCALE
		add_child(m)
		var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
		ap.play("idle"); ap.seek(0.3, true)
		for i in 8: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://assets/ui/skins/%s.png" % skin)
		print("portrait ", skin)
		m.queue_free()
		await get_tree().process_frame
	get_tree().quit()
