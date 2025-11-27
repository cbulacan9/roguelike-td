# music_manager.gd
extends Node

# Audio players
var music_player: AudioStreamPlayer

# Music tracks
var menu_music: AudioStream
var game_music: AudioStream

# Loop settings
var use_builtin_loop: bool = true  # File is already trimmed to 10 seconds

# Settings
var music_volume: float = 0.8:
	set(value):
		music_volume = clamp(value, 0.0, 1.0)
		if music_player:
			music_player.volume_db = linear_to_db(music_volume)

var music_enabled: bool = true:
	set(value):
		music_enabled = value
		if music_player:
			if music_enabled:
				music_player.volume_db = linear_to_db(music_volume)
			else:
				music_player.volume_db = -80.0  # Effectively mute

func _ready() -> void:
	# Create the audio player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"  # Use Master bus (or create a "Music" bus later)
	add_child(music_player)
	
	# Load music tracks
	game_music = load("res://ui/assets/kitchen_loop.wav")
	
	# Connect to scene changes to manage music
	get_tree().node_added.connect(_on_node_added)
	
	# Start with appropriate music based on current scene
	call_deferred("_check_initial_scene")

func _process(_delta: float) -> void:
	# Restart music when it ends (simple loop)
	if use_builtin_loop and music_player.stream and not music_player.playing:
		music_player.play()

func _check_initial_scene() -> void:
	var current_scene = get_tree().current_scene
	if current_scene:
		if current_scene.name == "MainMenu":
			play_music(game_music)  # Same track for now, can be different later
		else:
			play_music(game_music)

func _on_node_added(node: Node) -> void:
	# Check if a new main scene was loaded
	if node == get_tree().current_scene:
		_handle_scene_change(node)

func _handle_scene_change(scene: Node) -> void:
	# Play appropriate music for the scene
	if scene.name == "MainMenu":
		play_music(game_music)  # Can set different menu music later
	elif scene.name == "Main":  # Main game scene
		play_music(game_music)

func play_music(stream: AudioStream, fade_in: bool = true) -> void:
	if stream == null:
		return
	
	# If same track is already playing, don't restart
	if music_player.stream == stream and music_player.playing:
		return
	
	if fade_in and music_player.playing:
		# Crossfade to new track
		_crossfade_to(stream)
	else:
		# Direct play
		music_player.stream = stream
		music_player.volume_db = linear_to_db(music_volume) if music_enabled else -80.0
		music_player.play()

func _crossfade_to(new_stream: AudioStream) -> void:
	var tween = create_tween()
	
	# Fade out current
	tween.tween_property(music_player, "volume_db", -40.0, 0.5)
	
	# Switch and fade in
	tween.tween_callback(func():
		music_player.stream = new_stream
		music_player.play()
	)
	tween.tween_property(music_player, "volume_db", linear_to_db(music_volume) if music_enabled else -80.0, 0.5)

func stop_music(fade_out: bool = true) -> void:
	if fade_out:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, 0.5)
		tween.tween_callback(music_player.stop)
	else:
		music_player.stop()

func pause_music() -> void:
	music_player.stream_paused = true

func resume_music() -> void:
	music_player.stream_paused = false

func set_volume(volume: float) -> void:
	music_volume = volume

func toggle_music() -> void:
	music_enabled = !music_enabled
