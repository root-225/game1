extends Node
# Simple SFX + music manager (loads generated WAV files).

var _players: Array[AudioStreamPlayer] = []
var _idx := 0
var _music: AudioStreamPlayer
var _sfx := {}

const SFX := ["coin", "jump", "roll", "hit", "powerup", "click", "gameover"]

func _ready() -> void:
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = -8.0
	add_child(_music)
	for s in SFX:
		var stream := load("res://assets/audio/%s.wav" % s)
		if stream:
			_sfx[s] = stream
	var mus = load("res://assets/audio/music.wav")
	if mus:
		if mus is AudioStreamWAV:
			mus.loop_mode = AudioStreamWAV.LOOP_FORWARD
			mus.loop_begin = 0
			mus.loop_end = mus.data.size() / 2   # 16-bit mono => 2 bytes/frame
		_music.stream = mus

func play(name: String, pitch := 1.0) -> void:
	if not Global.sfx_on or not _sfx.has(name):
		return
	var p := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = _sfx[name]
	p.pitch_scale = pitch
	p.play()

func start_music() -> void:
	if Global.music_on and _music.stream and not _music.playing:
		_music.play()

func stop_music() -> void:
	_music.stop()

func toggle_music(on: bool) -> void:
	if on:
		start_music()
	else:
		stop_music()
