extends Node


var channel_count : int = 10

var audio_players : Array[AudioStreamPlayer] = []
var spatial_audio_players : Array[AudioStreamPlayer2D] = []

var current_channel : int = 0
var current_spatial_channel : int = 0

func _ready():
	for i in channel_count:
		var new_player = AudioStreamPlayer.new()
		audio_players.append(new_player)
		add_child(new_player)
		var new_spatial_player = AudioStreamPlayer2D.new()
		spatial_audio_players.append(new_spatial_player)
		add_child(new_spatial_player)


func play_sound(stream: AudioStream, vol: float = 1.0) -> void:
	var player : AudioStreamPlayer = get_audio_player(audio_players)
	
	player.volume_db = linear_to_db(vol)
	player.stream = stream
	player.play()


func play_sound_pitched(stream: AudioStream, pitch_range: float = 0.1, vol: float = 1.0) -> void:
	var player : AudioStreamPlayer = get_audio_player(audio_players)
	
	player.volume_db = linear_to_db(vol)
	player.stream = stream
	player.pitch_scale = 1 + randf_range(-pitch_range, pitch_range)
	player.play()


func play_spatial_sound(stream: AudioStream, pos: Vector2, vol: float = 1.0) -> void:
	var player : AudioStreamPlayer2D = get_audio_player(spatial_audio_players)
	
	player.volume_db = linear_to_db(vol)
	player.stream = stream
	player.global_position = pos
	player.play()


func play_spatial_sound_pitched(stream: AudioStream, pos: Vector2, pitch_range: float = 0.1, vol: float = 1.0) -> void:
	var player : AudioStreamPlayer2D = get_audio_player(spatial_audio_players)
	
	player.volume_db = linear_to_db(vol)
	player.stream = stream
	player.global_position = pos
	player.pitch_scale * randf_range(-pitch_range, pitch_range)
	player.play()


func get_audio_player(players: Array):
	var player = players[current_channel]
	current_channel += 1
	current_channel %= channel_count
	
	return player
