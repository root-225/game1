extends Node
# Root orchestrator: owns the 3D Game and the 2D UI, routes signals & app state.

var game: Game
var ui: UI

func _ready() -> void:
	get_tree().paused = false
	game = Game.new()
	game.name = "Game"
	add_child(game)
	ui = UI.new()
	ui.name = "UI"
	add_child(ui)
	ui.game = game

	game.score_changed.connect(func(s, c, d): ui.update_hud(s, c, d))
	game.power_changed.connect(func(st): ui.update_power(st))
	game.game_over.connect(_on_game_over)

	ui.play_pressed.connect(_start)
	ui.retry_pressed.connect(_start)
	ui.restart_pressed.connect(_start)
	ui.resume_pressed.connect(_resume)
	ui.pause_pressed.connect(_pause)
	ui.menu_pressed.connect(_to_menu)
	ui.skin_chosen.connect(_on_skin)

	game.show_menu_player()
	ui.show_menu()

func _start() -> void:
	get_tree().paused = false
	ui.hide_pause()
	ui.show_hud()
	game.start_run()

func _pause() -> void:
	if game.state == Game.St.PLAYING:
		get_tree().paused = true
		ui.show_pause()

func _resume() -> void:
	ui.hide_pause()
	get_tree().paused = false

func _to_menu() -> void:
	get_tree().paused = false
	ui.hide_pause()
	Audio.stop_music()
	game.show_menu_player()
	ui.show_menu()

func _on_game_over(score: int, coins: int, best: int, is_best: bool) -> void:
	ui.show_over(score, coins, best, is_best)

func _on_skin(skin: String) -> void:
	game.player.set_skin(skin)
	game.show_menu_player()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if game.state == Game.St.PLAYING:
			if get_tree().paused:
				_resume()
			else:
				_pause()
