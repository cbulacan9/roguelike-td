# game_manager.gd
extends Node

# Signals for UI to listen to
signal resource_changed(resource_type: String, amount: int)
signal wave_changed(wave_number: int)

# Game resources
var gold: int = 500:
	set(value):
		gold = value
		resource_changed.emit("gold", gold)

var lives: int = 20:
	set(value):
		lives = value
		resource_changed.emit("lives", lives)

var current_wave: int = 1:
	set(value):
		current_wave = value
		wave_changed.emit(current_wave)

func _ready():
	print("GameManager loaded")

# Helper methods for modifying resources
func add_gold(amount: int):
	gold += amount

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

func lose_life():
	lives -= 1
	if lives <= 0:
		game_over()

func game_over():
	print("Game Over!")
	# You'll implement this later
