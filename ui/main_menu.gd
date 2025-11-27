# main_menu.gd
extends Control

@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton

func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	
	# Add a subtle animation to the button
	_animate_button()

func _on_new_game_pressed() -> void:
	# Transition to the main game scene
	get_tree().change_scene_to_file("res://kitchen_defense.tscn")

func _animate_button() -> void:
	# Create a subtle pulse effect on the button
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(new_game_button, "modulate", Color(1.1, 1.1, 1.2), 0.8)
	tween.tween_property(new_game_button, "modulate", Color.WHITE, 0.8)
