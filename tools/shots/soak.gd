extends Node
# Dev-only soak test: 2+ minutes of invincible play (fixed 60 fps, headless), prints stats.
func _ready() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._start()
	var g = main.game
	g.player.hit_obstacle.disconnect(g._on_hit)
	var lagoon_seen := 0
	for sec in range(150):
		for f in 60:
			if f % 20 == 0:
				[g.player.do_left, g.player.do_right, g.player.do_jump, g.player.do_roll].pick_random().call()
			await get_tree().physics_frame
		if sec % 10 == 0:
			g._apply_powerup(["magnet", "x2", "shield"].pick_random())
		for c in g.chunks._chunks:
			if c["biome"] == ChunkManager.Biome.LAGOON: lagoon_seen += 1
		if sec % 30 == 0:
			var pooled := 0
			for k in g.chunks._deco_pools: pooled += g.chunks._deco_pools[k].size()
			var spawn_total := 0
			for k in g.chunks._pools: spawn_total += g.chunks._pools[k].size()
			var in_use := 0
			for c in g.chunks._chunks: in_use += c["items"].size()
			var ui_nodes: int = main.ui.get_child_count()
			print("   spawnables: pooled=%d in_use=%d  ui_hud_nodes=%d pw_icons=%d" % [spawn_total, in_use,
				main.ui.hud.find_children("*", "", true, false).size(), main.ui._pw_box.get_child_count()])
			print("t=%3ds dist=%5dm speed=%4.1f score=%6d coins=%4d nodes=%d pooled_deco=%d orphans=%d" % [
				sec, int(g.distance), g.speed, int(g.score), g.coins_run, get_tree().get_node_count(),
				pooled, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	print("SOAK OK lagoon_chunk_frames=%d" % lagoon_seen)
	get_tree().quit()
