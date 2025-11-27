# build_menu.gd
extends Panel

@onready var button_container: GridContainer = $MarginContainer/VBoxContainer/ButtonContainer
@onready var info_label: Label = $MarginContainer/VBoxContainer/InfoLabel

var tower_buttons: Dictionary = {}  # tower_id -> Button

func _ready() -> void:
	# Wait a frame for GameManager to initialize
	await get_tree().process_frame
	_create_tower_buttons()
	
	# Connect to signals
	GameManager.resource_changed.connect(_on_resource_changed)
	GameManager.tower_selected.connect(_on_tower_selected)
	
	# Initial update
	_update_button_states()
	_update_info_label(GameManager.selected_tower)

func _create_tower_buttons() -> void:
	# Clear existing buttons
	for child in button_container.get_children():
		child.queue_free()
	tower_buttons.clear()
	
	# Create a button for each tower type
	for i in range(GameManager.tower_types.size()):
		var tower_data: TowerData = GameManager.tower_types[i]
		
		var button := Button.new()
		button.custom_minimum_size = Vector2(120, 60)
		button.text = "%s\n%d Gold [%d]" % [tower_data.display_name, tower_data.cost, i + 1]
		button.pressed.connect(_on_tower_button_pressed.bind(tower_data.id))
		
		# Style the button
		button.add_theme_font_size_override("font_size", 12)
		
		button_container.add_child(button)
		tower_buttons[tower_data.id] = button
	
	# Highlight the initially selected tower
	if GameManager.selected_tower:
		_highlight_button(GameManager.selected_tower.id)

func _on_tower_button_pressed(tower_id: String) -> void:
	# Deselect any placed tower when switching to build mode
	GameManager.deselect_placed_tower()
	GameManager.select_tower(tower_id)

func _on_resource_changed(resource_type: String, _amount: int) -> void:
	if resource_type == "gold":
		_update_button_states()

func _on_tower_selected(tower_data: TowerData) -> void:
	_highlight_button(tower_data.id)
	_update_info_label(tower_data)

func _update_button_states() -> void:
	for tower_id in tower_buttons:
		var button: Button = tower_buttons[tower_id]
		var tower_data := GameManager.get_tower_data(tower_id)
		if tower_data:
			button.disabled = GameManager.gold < tower_data.cost

func _highlight_button(selected_id: String) -> void:
	for tower_id in tower_buttons:
		var button: Button = tower_buttons[tower_id]
		if tower_id == selected_id:
			button.modulate = Color(1.2, 1.2, 0.8)  # Slight yellow highlight
		else:
			button.modulate = Color.WHITE

func _update_info_label(tower_data: TowerData) -> void:
	if info_label == null:
		return
	
	if tower_data == null:
		info_label.text = "Select a tower"
		return
	
	info_label.text = "%s\nDamage: %.0f | Range: %.0f | Speed: %.1f/s\n%s" % [
		tower_data.display_name,
		tower_data.damage,
		tower_data.range_display,
		tower_data.attack_speed,
		tower_data.description
	]
