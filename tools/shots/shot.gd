extends Node
# Dev-only screenshot harness (excluded from exports). Usage:
# godot --path . res://tools/shots/shot.tscn -- <out_dir>
var out := "user://"
var main

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0].trim_suffix("/") + "/"
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(50)
	_save("01_menu")
	main.ui.show_shop()
	main.game.preview_skin("foot")
	await _wait(40)
	_save("02_shop")
	main.ui.shop_closed.emit()
	main.ui.show_menu()
	await _wait(10)
	main._start()
	main.game.player.hit_obstacle.disconnect(main.game._on_hit)  # invincible for shots
	await _wait(70)
	_save("03_run")
	var rs := RenderingServer
	print("PERF draw_calls=%d objects=%d primitives=%d nodes=%d" % [
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		get_tree().get_node_count()])
	main.game.player.do_left()
	await _wait(18)
	main.game.player.do_jump()
	await _wait(12)
	_save("04_jump")
	await _wait(30)
	main.game.player.do_roll()
	await _wait(4)
	_save("04b_slide")
	main.game._apply_powerup("shield")
	main.game._apply_powerup("magnet")
	await _wait(120)
	_save("05_run_power")
	main._pause()
	await _wait(5)
	_save("06_pause")
	main._resume()
	main.game._do_game_over()
	await _wait(40)
	_save("07_gameover")
	# lagoon / bridge section
	main.game.chunks.biome_offset = Data.LAGOON_START - 1
	main._start()
	await _wait(25)
	_save("08_lagoon")
	get_tree().quit()

func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _save(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + name + ".png")
	print("shot ", name, " ", img.get_size())
