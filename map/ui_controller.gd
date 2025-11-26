# ui_controller.gd
extends CanvasLayer

@export var tower_placement_manager: Node3D

func _ready():
	# Create simple button
	var button = Button.new()
	button.text = "Place Tower ($100)"
	button.position = Vector2(10, 10)
	button.size = Vector2(150, 40)
	button.pressed.connect(_on_place_tower_pressed)
	add_child(button)
	
	# Gold display
	var gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "Gold: 500"
	gold_label.position = Vector2(10, 60)
	add_child(gold_label)

func _on_place_tower_pressed():
	if tower_placement_manager:
		tower_placement_manager.toggle_placement_mode(true)

func update_gold_display(amount: int):
	$GoldLabel.text = "Gold: " + str(amount)
