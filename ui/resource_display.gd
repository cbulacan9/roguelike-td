# resource_display.gd
extends MarginContainer

# Get references to labels
@onready var gold_label: Label = $VBoxContainer/GoldContainer/GoldLabel
@onready var lives_label: Label = $VBoxContainer/LivesContainer/LivesLabel
@onready var wave_label: Label = $VBoxContainer/WaveContainer/WaveLabel

func _ready():
	# Connect to GameManager signals
	GameManager.resource_changed.connect(_on_resource_changed)
	GameManager.wave_changed.connect(_on_wave_changed)
	
	# Initialize with current values
	_update_gold(GameManager.gold)
	_update_lives(GameManager.lives)
	_update_wave(GameManager.current_wave)

func _on_resource_changed(resource_type: String, amount: int):
	match resource_type:
		"gold":
			_update_gold(amount)
		"lives":
			_update_lives(amount)

func _on_wave_changed(wave_number: int):
	_update_wave(wave_number)

func _update_gold(amount: int):
	gold_label.text = "Gold: %d" % amount

func _update_lives(amount: int):
	lives_label.text = "Lives: %d" % amount
	
	# Optional: Change color based on lives remaining
	if amount <= 5:
		lives_label.add_theme_color_override("font_color", Color.RED)
	elif amount <= 10:
		lives_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		lives_label.add_theme_color_override("font_color", Color.WHITE)

func _update_wave(wave_number: int):
	wave_label.text = "Wave: %d" % wave_number
