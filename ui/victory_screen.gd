# victory_screen.gd
extends Control

@onready var stats_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatsLabel
@onready var play_again_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/PlayAgainButton
@onready var main_menu_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/MainMenuButton

func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	# Update the stats display
	stats_label.text = "Waves Completed: %d\nLives Remaining: %d\nGold: %d" % [
		GameManager.current_wave,
		GameManager.lives,
		GameManager.gold
	]
	
	# Pause the game while showing victory
	get_tree().paused = true
	
	# Animate the panel appearing
	_animate_entrance()

func _animate_entrance() -> void:
	var panel := $CenterContainer/PanelContainer
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.8, 0.8)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Add a celebratory particle effect via color pulse
	tween.chain().tween_property($CenterContainer/PanelContainer, "modulate", Color(1.2, 1.2, 0.9), 0.3)
	tween.tween_property($CenterContainer/PanelContainer, "modulate", Color.WHITE, 0.3)

func _on_play_again_pressed() -> void:
	get_tree().paused = false
	GameManager.reset_game()
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
