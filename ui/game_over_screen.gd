# game_over_screen.gd
extends Control

@onready var final_wave_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FinalWaveLabel
@onready var retry_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/RetryButton
@onready var main_menu_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/MainMenuButton

func _ready() -> void:
	retry_button.pressed.connect(_on_retry_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	# Update the wave display
	final_wave_label.text = "You reached Wave %d" % GameManager.current_wave
	
	# Pause the game while showing game over
	get_tree().paused = true
	
	# Animate the panel appearing
	_animate_entrance()

func _animate_entrance() -> void:
	var panel := $CenterContainer/PanelContainer
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.8, 0.8)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_retry_pressed() -> void:
	get_tree().paused = false
	GameManager.reset_game()
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
