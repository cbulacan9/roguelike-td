# BuildMenu.gd
extends Panel

signal tower_selected(tower_type: String)

@onready var tower_buttons = $MarginContainer/VBoxContainer/GridContainer

func _ready():
	# Create buttons for each tower type
	for tower_data in GameManager.tower_types:
		var button = Button.new()
		button.text = "%s\n%d Gold" % [tower_data.name, tower_data.cost]
		button.pressed.connect(_on_tower_button_pressed.bind(tower_data.type))
		tower_buttons.add_child(button)
	
	# Update button states based on resources
	GameManager.resource_changed.connect(_update_button_states)

func _on_tower_button_pressed(tower_type: String):
	tower_selected.emit(tower_type)

func _update_button_states(resource_type: String, amount: int):
	if resource_type == "gold":
		for button in tower_buttons.get_children():
			var tower_data = GameManager.get_tower_data(button.text)
			button.disabled = amount < tower_data.cost
