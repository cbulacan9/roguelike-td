# game_ui_manager.gd
extends Node

# Preload the end game screens
const GameOverScreen := preload("res://ui/game_over_screen.tscn")
const VictoryScreen := preload("res://ui/victory_screen.tscn")

var end_screen_instance: Control = null

func _ready() -> void:
	# Connect to game end signals
	GameManager.game_lost.connect(_on_game_lost)
	GameManager.game_won.connect(_on_game_won)

func _on_game_lost() -> void:
	if end_screen_instance != null:
		return  # Already showing an end screen
	
	_show_end_screen(GameOverScreen)

func _on_game_won() -> void:
	if end_screen_instance != null:
		return  # Already showing an end screen
	
	_show_end_screen(VictoryScreen)

func _show_end_screen(screen_scene: PackedScene) -> void:
	# Create and add the screen
	end_screen_instance = screen_scene.instantiate()
	
	# Add to the UI layer (find existing CanvasLayer or create one)
	var ui_layer := get_tree().current_scene.get_node_or_null("UI")
	if ui_layer:
		ui_layer.add_child(end_screen_instance)
	else:
		# Fallback: add directly to current scene
		get_tree().current_scene.add_child(end_screen_instance)
