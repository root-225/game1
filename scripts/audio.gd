extends Node
# SFX + music manager. Kenney CC0 sounds for core actions, generated WAVs for the rest.

var _players: Array[AudioStreamPlayer] = []
var _idx := 0
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sfx := {}

const SFX := {
	"coin": "res://assets/audio/kenney/coin.ogg",
	"jump": "res://assets/audio/kenney/jump.ogg",
	"land": "res://assets/audio/kenney/land.ogg",
	"break": "res://assets/audio/kenney/break.ogg",
	"roll": "res://assets/audio/roll.wav",
	"hit": "res://assets/audio/hit.wav",
	"powerup": "res://assets/audio/powerup.wav",
	"click": "res://assets/audio/click.wav",
	"gameover": "res://assets/audio/gameover.wav",
}
const VOLUME := {"land": -10.0, "jump": -4.0, "coin": -3.0}

func _ready() -> void:
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for key in SFX:
		var stream = load(SFX[key])
		if stream:
			_sfx[key] = stream
	_music = _looping_player("res://assets/audio/music.wav", -9.0)
	_ambience = _looping_player("res://assets/audio/kenney/city_ambience.ogg", -16.0)

func _looping_player(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	add_child(p)
	var s = load(path)
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2   # 16-bit mono => 2 bytes/frame
	elif s is AudioStreamOggVorbis:
		s.loop = true
	p.stream = s
	return p

func play(name: String, pitch := 1.0) -> void:
	if not Global.sfx_on or not _sfx.has(name):
		return
	var p := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = _sfx[name]
	p.pitch_scale = pitch
	p.volume_db = VOLUME.get(name, 0.0)
	p.play()

func start_music() -> void:
	if Global.music_on and _music.stream and not _music.playing:
		_music.play()
	if Global.sfx_on and _ambience.stream and not _ambience.playing:
		_ambience.play()

func stop_music() -> void:
	_music.stop()
	_ambience.stop()

func toggle_music(on: bool) -> void:
	if on:
		start_music()
	else:
		_music.stop()
